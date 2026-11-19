(function () {
  "use strict";

  const GHOST_WS_URL = "ws://127.0.0.1:51937";
  const capVideo = document.getElementById("capVideo");
  const cropCanvas = document.getElementById("cropCanvas");
  const supportsOffscreen = typeof OffscreenCanvas !== "undefined";
  const encodeCanvas = supportsOffscreen ? new OffscreenCanvas(448, 252) : cropCanvas;
  const ctx = encodeCanvas.getContext("2d", { alpha: false, desynchronized: true });

  let mediaStream = null;
  let workerTicker = null;
  let rvfcHandle = null;
  let ws = null;
  let wsReconnectTimer = null;
  let wsConnected = false;
  let streamingActive = false;
  let inflightEncodes = 0;
  let frameSeq = 0;
  let lastSentSeq = 0;
  let lastCaptureTs = 0;
  let streamStartedAt = 0;
  let lastEncodedMediaTime = -1;
  let lastRvfcMediaTime = -1;
  let idleHeartbeatFrames = 0;

  // Normalized crop box [0..1] within the captured tab viewport
  let cropBox = { nx: 0, ny: 0, nw: 1, nh: 1, aspect: 16 / 9, subtitle: "" };
  let currentState = null;
  let hasCrossTabViewers = false;

  function connectGhostWs() {
    if (!streamingActive) return;
    if (ws && (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING)) {
      return;
    }

    try {
      ws = new WebSocket(GHOST_WS_URL);
      ws.binaryType = "arraybuffer";

      ws.onopen = () => {
        wsConnected = true;
        chrome.runtime.sendMessage({
          type: "GECKO_GHOST_WS_STATUS",
          connected: true,
        }).catch(() => {});
        sendMetaToGhost();
        // Push first video frame immediately on WS connect for zero startup delay
        processVideoFrame(true);
      };

      ws.onmessage = (ev) => {
        if (typeof ev.data === "string") {
          try {
            const msg = JSON.parse(ev.data);
            if (msg.type === "cmd") {
              chrome.runtime.sendMessage({
                type: "GECKO_REMOTE_VIDEO_CMD",
                action: msg.action,
                delta: msg.delta,
                value: msg.value,
              }).catch(() => {});
            } else if (msg.type === "statePatch" && msg.patch) {
              chrome.runtime.sendMessage({
                type: "GECKO_REMOTE_STATE_PATCH",
                patch: msg.patch,
              }).catch(() => {});
            }
          } catch (_) {}
        }
      };

      ws.onclose = () => {
        wsConnected = false;
        chrome.runtime.sendMessage({
          type: "GECKO_GHOST_WS_STATUS",
          connected: false,
        }).catch(() => {});
        if (streamingActive) {
          clearTimeout(wsReconnectTimer);
          wsReconnectTimer = setTimeout(connectGhostWs, 1200);
        }
      };

      ws.onerror = () => {
        try { ws.close(); } catch (_) {}
      };
    } catch (_) {
      if (streamingActive) {
        clearTimeout(wsReconnectTimer);
        wsReconnectTimer = setTimeout(connectGhostWs, 1500);
      }
    }
  }

  function sendMetaToGhost() {
    if (!ws || ws.readyState !== WebSocket.OPEN) return;
    try {
      ws.send(
        JSON.stringify({
          type: "meta",
          aspect: cropBox.aspect || 16 / 9,
          subtitle: cropBox.subtitle || "",
          player: cropBox.player || null,
        })
      );
    } catch (_) {}
  }

  function sendStatePatchToGhost(patch) {
    if (!ws || ws.readyState !== WebSocket.OPEN || !patch) return;
    try {
      ws.send(JSON.stringify({ type: "statePatch", patch }));
    } catch (_) {}
  }

  async function startCapture(streamId, initialState, initialCrop) {
    stopCapture(false);
    streamingActive = true;
    streamStartedAt = performance.now();
    lastEncodedMediaTime = -1;
    lastRvfcMediaTime = -1;
    idleHeartbeatFrames = 0;
    inflightEncodes = 0;
    if (initialState) currentState = initialState;
    if (initialCrop) cropBox = { ...cropBox, ...initialCrop };

    try {
      mediaStream = await navigator.mediaDevices.getUserMedia({
        audio: false,
        video: {
          mandatory: {
            chromeMediaSource: "tab",
            chromeMediaSourceId: streamId,
            maxWidth: 768,
            maxHeight: 432,
            minFrameRate: 24,
            maxFrameRate: 60,
          },
        },
      });
    } catch (err) {
      streamingActive = false;
      return { ok: false, error: String(err) };
    }

    const videoTrack = mediaStream.getVideoTracks()[0];
    if (videoTrack) {
      videoTrack.addEventListener("ended", () => {
        stopCapture(true);
      });
    }

    capVideo.srcObject = mediaStream;
    await capVideo.play().catch(() => {});

    connectGhostWs();
    startHighFpsLoop();
    return { ok: true };
  }

  function stopCapture(notifyBg = true) {
    streamingActive = false;
    clearTimeout(wsReconnectTimer);
    if (workerTicker) {
      workerTicker.terminate();
      workerTicker = null;
    }
    if (rvfcHandle !== null && typeof capVideo.cancelVideoFrameCallback === "function") {
      try { capVideo.cancelVideoFrameCallback(rvfcHandle); } catch (_) {}
      rvfcHandle = null;
    }
    if (mediaStream) {
      mediaStream.getTracks().forEach((t) => t.stop());
      mediaStream = null;
    }
    capVideo.srcObject = null;
    if (ws) {
      try {
        ws.send(JSON.stringify({ type: "streamStopped" }));
        ws.close();
      } catch (_) {}
      ws = null;
    }
    wsConnected = false;
    if (notifyBg) {
      chrome.runtime.sendMessage({ type: "GECKO_STREAM_STOPPED" }).catch(() => {});
    }
  }

  function processVideoFrame(force = false) {
    if (!streamingActive || inflightEncodes >= 1) return;
    if (capVideo.readyState < 2 || !capVideo.videoWidth) return;
    if (!wsConnected && !hasCrossTabViewers) return;
    if (currentState?.bossMode) return;
    if (ws && ws.readyState === WebSocket.OPEN && ws.bufferedAmount > 40 * 1024) return;

    const now = performance.now();
    // Cap at ~60fps (15.5ms min delta) so rvfc + backup timer never double-encode the same frame
    if (!force && now - lastCaptureTs < 15.5) return;

    // Skip encoding identical unchanged frames (unless periodic keepalive every ~500ms)
    const curMediaTime = lastRvfcMediaTime >= 0 ? lastRvfcMediaTime : capVideo.currentTime;
    if (!force && curMediaTime === lastEncodedMediaTime && idleHeartbeatFrames < 30) {
      idleHeartbeatFrames++;
      return;
    }
    idleHeartbeatFrames = 0;
    lastEncodedMediaTime = curMediaTime;
    lastCaptureTs = now;

    const vw = capVideo.videoWidth;
    const vh = capVideo.videoHeight;

    const sx = Math.max(0, Math.min(vw - 2, Math.round(cropBox.nx * vw)));
    const sy = Math.max(0, Math.min(vh - 2, Math.round(cropBox.ny * vh)));
    const sw = Math.max(16, Math.min(vw - sx, Math.round(cropBox.nw * vw)));
    const sh = Math.max(16, Math.min(vh - sy, Math.round(cropBox.nh * vh)));

    const aspect = sw / Math.max(1, sh);
    const warmingUp = now - streamStartedAt < 1800;
    const targetW = aspect < 0.85 ? 268 : (warmingUp ? 384 : 448);
    const targetH = Math.max(135, Math.round(targetW / aspect));
    const quality = warmingUp ? 0.62 : 0.72;

    if (encodeCanvas.width !== targetW || encodeCanvas.height !== targetH) {
      encodeCanvas.width = targetW;
      encodeCanvas.height = targetH;
    }

    ctx.drawImage(capVideo, sx, sy, sw, sh, 0, 0, targetW, targetH);

    const mySeq = ++frameSeq;
    inflightEncodes++;

    const handleEncodedBlob = async (blob) => {
      inflightEncodes = Math.max(0, inflightEncodes - 1);
      if (!blob || !streamingActive || mySeq < lastSentSeq) return;
      lastSentSeq = mySeq;

      if (ws && ws.readyState === WebSocket.OPEN && ws.bufferedAmount < 128 * 1024) {
        try {
          const buf = await blob.arrayBuffer();
          if (mySeq >= lastSentSeq && ws && ws.readyState === WebSocket.OPEN) {
            ws.send(buf);
          }
        } catch (_) {}
      }

      if (hasCrossTabViewers && mySeq % 2 === 0) {
        const reader = new FileReader();
        reader.onloadend = () => {
          if (typeof reader.result === "string") {
            chrome.runtime
              .sendMessage({
                type: "GECKO_BROADCAST_FRAME",
                dataUrl: reader.result,
                aspect,
                subtitle: cropBox.subtitle || "",
              })
              .catch(() => {});
          }
        };
        reader.readAsDataURL(blob);
      }
    };

    if (supportsOffscreen && typeof encodeCanvas.convertToBlob === "function") {
      encodeCanvas
        .convertToBlob({ type: "image/jpeg", quality })
        .then(handleEncodedBlob)
        .catch(() => {
          inflightEncodes = Math.max(0, inflightEncodes - 1);
        });
    } else {
      cropCanvas.toBlob(handleEncodedBlob, "image/jpeg", quality);
    }
  }

  function startHighFpsLoop() {
    if (workerTicker) {
      workerTicker.terminate();
      workerTicker = null;
    }
    if (typeof capVideo.requestVideoFrameCallback === "function") {
      const onFrame = (_now, metadata) => {
        if (!streamingActive) return;
        if (metadata && Number.isFinite(metadata.mediaTime)) {
          lastRvfcMediaTime = metadata.mediaTime;
        }
        processVideoFrame(false);
        rvfcHandle = capVideo.requestVideoFrameCallback(onFrame);
      };
      rvfcHandle = capVideo.requestVideoFrameCallback(onFrame);
    }
    // Unthrottled Dedicated Web Worker 60Hz clock (immune to Chrome background tab timer throttling!)
    try {
      const blob = new Blob(["setInterval(() => postMessage(1), 16);"], { type: "application/javascript" });
      workerTicker = new Worker(URL.createObjectURL(blob));
      workerTicker.onmessage = () => processVideoFrame(false);
    } catch (_) {
      setInterval(() => processVideoFrame(false), 16);
    }
  }

  chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
    if (!msg || typeof msg !== "object") return false;

    if (msg.type === "GECKO_OFFSCREEN_START") {
      startCapture(msg.streamId, msg.state, msg.crop).then((res) =>
        sendResponse(res)
      );
      return true;
    }

    if (msg.type === "GECKO_OFFSCREEN_STOP") {
      stopCapture(false);
      sendResponse({ ok: true });
      return false;
    }

    if (msg.type === "GECKO_OFFSCREEN_UPDATE_META") {
      if (msg.crop) {
        cropBox = { ...cropBox, ...msg.crop };
        sendMetaToGhost();
      }
      if (msg.state) {
        const prev = currentState || {};
        currentState = msg.state;
        const diff = {};
        for (const k of ["mode", "stealth", "feather", "bossMode", "mirrorSubtitles", "hoverReveal"]) {
          if (msg.state[k] !== undefined && msg.state[k] !== prev[k]) diff[k] = msg.state[k];
        }
        if (Object.keys(diff).length > 0) sendStatePatchToGhost(diff);
      }
      if (typeof msg.hasCrossTabViewers === "boolean") {
        hasCrossTabViewers = msg.hasCrossTabViewers;
      }
      sendResponse({ ok: true, wsConnected, streamingActive });
      return false;
    }

    if (msg.type === "GECKO_OFFSCREEN_PING") {
      sendResponse({ streamingActive, wsConnected });
      return false;
    }

    return false;
  });
})();

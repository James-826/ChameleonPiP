(function () {
  "use strict";

  const GHOST_WS_URL = "ws://127.0.0.1:51937";
  const capVideo = document.getElementById("capVideo");
  const cropCanvas = document.getElementById("cropCanvas");
  const supportsOffscreen = typeof OffscreenCanvas !== "undefined";
  const encodeCanvas = supportsOffscreen ? new OffscreenCanvas(448, 252) : cropCanvas;
  const ctx = encodeCanvas.getContext("2d", { alpha: false, desynchronized: true });
  const supportsTrackProcessor = typeof MediaStreamTrackProcessor === "function";

  let mediaStream = null;
  let frameReader = null;
  let pendingVideoFrame = null;
  let encodingBusy = false;
  let workerTicker = null;
  let ws = null;
  let wsReconnectTimer = null;
  let wsConnected = false;
  let streamingActive = false;
  let frameSeq = 0;
  let lastSentSeq = 0;
  let lastCaptureTs = 0;
  let streamStartedAt = 0;
  let lastDecodedFrames = -1;
  let idleHeartbeatFrames = 0;
  let crossTabSendBusy = false;

  // Normalized crop box [0..1] within the captured tab viewport
  let cropBox = { nx: 0, ny: 0, nw: 1, nh: 1, aspect: 16 / 9, subtitle: "" };
  let currentState = null;
  let hasCrossTabViewers = false;
  let directBypassActive = false;

  function syncTrackConstraintsForBypass() {
    const track = mediaStream?.getVideoTracks?.()?.[0];
    if (!track || typeof track.applyConstraints !== "function") return;
    if (directBypassActive && !hasCrossTabViewers) {
      track.applyConstraints({ width: 64, height: 36, frameRate: 1 }).catch(() => {});
    } else {
      track.applyConstraints({ width: 640, height: 360, frameRate: 60 }).catch(() => {});
    }
  }

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
        try {
          ws.send(JSON.stringify({ type: "register", role: "offscreenController" }));
        } catch (_) {}
        chrome.runtime.sendMessage({
          type: "GECKO_GHOST_WS_STATUS",
          connected: true,
        }).catch(() => {});
        sendMetaToGhost();
        // Push first fallback frame immediately if using legacy <video> pipeline
        if (!frameReader) processFallbackVideoFrame(true);
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
    directBypassActive = false;
    streamStartedAt = performance.now();
    lastDecodedFrames = -1;
    idleHeartbeatFrames = 0;
    encodingBusy = false;
    crossTabSendBusy = false;
    lastCaptureTs = 0;
    if (initialState) currentState = initialState;
    if (initialCrop) cropBox = { ...cropBox, ...initialCrop };

    try {
      mediaStream = await navigator.mediaDevices.getUserMedia({
        audio: false,
        video: {
          mandatory: {
            chromeMediaSource: "tab",
            chromeMediaSourceId: streamId,
            minWidth: 480,
            maxWidth: 854,
            minHeight: 270,
            maxHeight: 480,
            minFrameRate: 30,
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
      if ("contentHint" in videoTrack) {
        try { videoTrack.contentHint = "motion"; } catch (_) {}
      }
      videoTrack.addEventListener("ended", () => {
        stopCapture(true);
      });
    }

    connectGhostWs();

    if (supportsTrackProcessor && videoTrack) {
      startProcessorLoop(videoTrack);
    } else {
      capVideo.srcObject = mediaStream;
      await capVideo.play().catch(() => {});
      startFallbackVideoLoop();
    }
    return { ok: true };
  }

  function closeFrameSafe(src) {
    if (src && typeof src.close === "function") {
      try { src.close(); } catch (_) {}
    }
  }

  function stopCapture(notifyBg = true) {
    streamingActive = false;
    directBypassActive = false;
    clearTimeout(wsReconnectTimer);
    if (pendingVideoFrame) {
      closeFrameSafe(pendingVideoFrame);
      pendingVideoFrame = null;
    }
    if (frameReader) {
      try { frameReader.cancel().catch(() => {}); } catch (_) {}
      frameReader = null;
    }
    if (workerTicker) {
      workerTicker.terminate();
      workerTicker = null;
    }
    if (mediaStream) {
      mediaStream.getTracks().forEach((t) => t.stop());
      mediaStream = null;
    }
    capVideo.srcObject = null;
    encodingBusy = false;
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

  function encodeCanvasToBlob(quality) {
    if (supportsOffscreen && typeof encodeCanvas.convertToBlob === "function") {
      return encodeCanvas.convertToBlob({ type: "image/jpeg", quality });
    }
    return new Promise((resolve) => cropCanvas.toBlob(resolve, "image/jpeg", quality));
  }

  async function encodeAndDispatchSource(src) {
    encodingBusy = true;
    const isVideoFrame = typeof src?.close === "function";
    try {
      const vw = src.displayWidth || src.codedWidth || src.videoWidth || 0;
      const vh = src.displayHeight || src.codedHeight || src.videoHeight || 0;
      if (!vw || !vh) {
        closeFrameSafe(src);
        return;
      }

      const now = performance.now();
      lastCaptureTs = now;

      const sx = Math.max(0, Math.min(vw - 2, Math.round(cropBox.nx * vw)));
      const sy = Math.max(0, Math.min(vh - 2, Math.round(cropBox.ny * vh)));
      const sw = Math.max(16, Math.min(vw - sx, Math.round(cropBox.nw * vw)));
      const sh = Math.max(16, Math.min(vh - sy, Math.round(cropBox.nh * vh)));

      const aspect = sw / Math.max(1, sh);
      const warmingUp = now - streamStartedAt < 1800;
      const targetW = aspect < 0.85 ? 268 : warmingUp ? 384 : 448;
      const targetH = Math.max(135, Math.round(targetW / aspect));
      const quality = warmingUp ? 0.64 : 0.72;

      if (encodeCanvas.width !== targetW || encodeCanvas.height !== targetH) {
        encodeCanvas.width = targetW;
        encodeCanvas.height = targetH;
      }

      ctx.drawImage(src, sx, sy, sw, sh, 0, 0, targetW, targetH);
      // Immediately release GPU capture buffer before async JPEG compression!
      if (isVideoFrame) closeFrameSafe(src);

      const mySeq = ++frameSeq;
      const blob = await encodeCanvasToBlob(quality);
      if (!blob || !streamingActive || mySeq < lastSentSeq) return;
      lastSentSeq = mySeq;

      if (!directBypassActive && ws && ws.readyState === WebSocket.OPEN && ws.bufferedAmount < 18 * 1024) {
        try {
          const buf = await blob.arrayBuffer();
          if (!directBypassActive && mySeq >= lastSentSeq && ws && ws.readyState === WebSocket.OPEN) {
            ws.send(buf);
          }
        } catch (_) {}
      }

      if (hasCrossTabViewers && !crossTabSendBusy) {
        crossTabSendBusy = true;
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
              .catch(() => {})
              .finally(() => {
                crossTabSendBusy = false;
              });
          } else {
            crossTabSendBusy = false;
          }
        };
        reader.onerror = () => {
          crossTabSendBusy = false;
        };
        reader.readAsDataURL(blob);
      }
    } catch (_) {
      if (isVideoFrame) closeFrameSafe(src);
    } finally {
      encodingBusy = false;
      if (streamingActive && pendingVideoFrame) {
        const next = pendingVideoFrame;
        pendingVideoFrame = null;
        if (!currentState?.bossMode && (wsConnected || hasCrossTabViewers)) {
          encodeAndDispatchSource(next);
        } else {
          closeFrameSafe(next);
        }
      }
    }
  }

  async function startProcessorLoop(videoTrack) {
    try {
      const processor = new MediaStreamTrackProcessor({ track: videoTrack });
      frameReader = processor.readable.getReader();
      while (streamingActive) {
        const { value: videoFrame, done } = await frameReader.read();
        if (done || !videoFrame) {
          closeFrameSafe(videoFrame);
          break;
        }
        if (!streamingActive || currentState?.bossMode || (!wsConnected && !hasCrossTabViewers)) {
          closeFrameSafe(videoFrame);
          continue;
        }
        if (directBypassActive && !hasCrossTabViewers) {
          closeFrameSafe(videoFrame);
          continue;
        }
        if (!directBypassActive && ws && ws.readyState === WebSocket.OPEN && ws.bufferedAmount >= 18 * 1024) {
          closeFrameSafe(videoFrame);
          continue;
        }
        const now = performance.now();
        if (!encodingBusy && now - lastCaptureTs < 8) {
          closeFrameSafe(videoFrame);
          continue;
        }
        if (encodingBusy) {
          // Strict 1-slot latest-frame mailbox: never leak or stall Chrome's C++ capturer!
          if (pendingVideoFrame) closeFrameSafe(pendingVideoFrame);
          pendingVideoFrame = videoFrame;
          continue;
        }
        encodeAndDispatchSource(videoFrame);
      }
    } catch (_) {
      if (streamingActive && !workerTicker && mediaStream) {
        capVideo.srcObject = mediaStream;
        await capVideo.play().catch(() => {});
        startFallbackVideoLoop();
      }
    }
  }

  function processFallbackVideoFrame(force = false) {
    if (!streamingActive || encodingBusy) return;
    if (capVideo.readyState < 2 || !capVideo.videoWidth) return;
    if (!wsConnected && !hasCrossTabViewers) return;
    if (currentState?.bossMode) return;
    if (directBypassActive && !hasCrossTabViewers) return;
    if (!directBypassActive && ws && ws.readyState === WebSocket.OPEN && ws.bufferedAmount >= 18 * 1024) return;

    const now = performance.now();
    if (!force && now - lastCaptureTs < 9.5) return;

    const totalFrames = capVideo.getVideoPlaybackQuality?.().totalVideoFrames ?? -1;
    if (!force && totalFrames >= 0 && totalFrames === lastDecodedFrames && idleHeartbeatFrames < 8) {
      idleHeartbeatFrames++;
      return;
    }
    idleHeartbeatFrames = 0;
    if (totalFrames >= 0) lastDecodedFrames = totalFrames;

    encodeAndDispatchSource(capVideo);
  }

  function startFallbackVideoLoop() {
    if (workerTicker) {
      workerTicker.terminate();
      workerTicker = null;
    }
    // Unthrottled Dedicated Web Worker 60Hz clock (immune to Chrome background tab timer throttling!)
    try {
      const blob = new Blob(["setInterval(() => postMessage(1), 16);"], { type: "application/javascript" });
      workerTicker = new Worker(URL.createObjectURL(blob));
      workerTicker.onmessage = () => processFallbackVideoFrame(false);
    } catch (_) {
      setInterval(() => processFallbackVideoFrame(false), 16);
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
        for (const k of ["mode", "stealth", "feather", "bossMode", "mirrorSubtitles", "stealthSubtitle", "hoverReveal"]) {
          if (msg.state[k] !== undefined && msg.state[k] !== prev[k]) diff[k] = msg.state[k];
        }
        if (Object.keys(diff).length > 0) sendStatePatchToGhost(diff);
      }
      if (typeof msg.hasCrossTabViewers === "boolean") {
        hasCrossTabViewers = msg.hasCrossTabViewers;
        syncTrackConstraintsForBypass();
      }
      sendResponse({ ok: true, wsConnected, streamingActive });
      return false;
    }

    if (msg.type === "GECKO_OFFSCREEN_DIRECT_BYPASS") {
      directBypassActive = Boolean(msg.active);
      syncTrackConstraintsForBypass();
      sendResponse({ ok: true });
      return false;
    }

    if (msg.type === "GECKO_OFFSCREEN_PING") {
      sendResponse({ streamingActive, wsConnected });
      return false;
    }

    return false;
  });
})();

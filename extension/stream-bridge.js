(function () {
  "use strict";

  const GHOST_WS_URLS = ["ws://127.0.0.1:27182", "ws://127.0.0.1:51937"];
  let wsUrlIdx = 0;
  let ws = null;
  let reconnectTimer = null;
  let active = true;
  let reportedDirectActive = false;
  let workerFramePort = null;

  function sendFrameBufferNow(buf) {
    if (!active) return;
    if (!ws || ws.readyState === WebSocket.CLOSED) connectWs();
    if (buf instanceof ArrayBuffer && ws && ws.readyState === WebSocket.OPEN && ws.bufferedAmount < 8 * 1024) {
      try {
        ws.send(buf);
        if (!reportedDirectActive) reportDirectStatus(true);
      } catch (_) {}
    }
  }

  function notifyParentWsState(open) {
    try {
      window.parent?.postMessage({ type: "GECKO_BRIDGE_WS_STATE", open: Boolean(open) }, "*");
    } catch (_) {}
  }

  function reportDirectStatus(isActive) {
    const val = Boolean(isActive);
    if (reportedDirectActive === val) return;
    reportedDirectActive = val;
    try {
      chrome.runtime.sendMessage({ type: "GECKO_DIRECT_STREAM_STATUS", active: val }).catch(() => {});
    } catch (_) {}
  }

  function connectWs() {
    if (!active) return;
    if (ws && (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING)) {
      return;
    }
    try {
      const targetUrl = GHOST_WS_URLS[wsUrlIdx % GHOST_WS_URLS.length];
      let opened = false;
      ws = new WebSocket(targetUrl);
      ws.binaryType = "arraybuffer";

      ws.onopen = () => {
        if (!active) {
          try { ws.close(); } catch (_) {}
          return;
        }
        opened = true;
        wsUrlIdx = 0;
        try {
          ws.send(JSON.stringify({ type: "register", role: "streamProducer" }));
        } catch (_) {}
        try {
          chrome.runtime.sendMessage({ type: "GECKO_GHOST_WS_STATUS", connected: true }).catch(() => {});
        } catch (_) {}
        notifyParentWsState(true);
      };

      ws.onmessage = (ev) => {
        if (typeof ev.data !== "string") return;
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
      };

      ws.onclose = () => {
        ws = null;
        if (!opened) wsUrlIdx = (wsUrlIdx + 1) % GHOST_WS_URLS.length;
        notifyParentWsState(false);
        try {
          chrome.runtime.sendMessage({ type: "GECKO_GHOST_WS_STATUS", connected: false }).catch(() => {});
        } catch (_) {}
        if (reportedDirectActive) reportDirectStatus(false);
        if (active) {
          clearTimeout(reconnectTimer);
          reconnectTimer = setTimeout(connectWs, opened ? 800 : 350);
        }
      };

      ws.onerror = () => {
        try { ws?.close(); } catch (_) {}
      };
    } catch (_) {
      wsUrlIdx = (wsUrlIdx + 1) % GHOST_WS_URLS.length;
      notifyParentWsState(false);
      if (active) {
        clearTimeout(reconnectTimer);
        reconnectTimer = setTimeout(connectWs, 500);
      }
    }
  }

  window.addEventListener("message", (ev) => {
    const msg = ev.data;
    if (!msg || typeof msg !== "object") return;

    if (msg.type === "GECKO_BRIDGE_BIND_PORT" && ev.ports && ev.ports[0]) {
      if (workerFramePort) {
        try { workerFramePort.close(); } catch (_) {}
      }
      workerFramePort = ev.ports[0];
      workerFramePort.onmessage = (pev) => sendFrameBufferNow(pev.data);
      workerFramePort.start?.();
      return;
    }

    if (msg.type === "GECKO_BRIDGE_START") {
      active = true;
      connectWs();
      return;
    }

    if (msg.type === "GECKO_BRIDGE_FRAME") {
      sendFrameBufferNow(msg.buf);
      return;
    }

    if (msg.type === "GECKO_BRIDGE_META" && msg.meta) {
      if (ws && ws.readyState === WebSocket.OPEN) {
        try {
          ws.send(JSON.stringify({ type: "meta", ...msg.meta }));
        } catch (_) {}
      }
      return;
    }

    if (msg.type === "GECKO_BRIDGE_STATE_PATCH" && msg.patch) {
      if (ws && ws.readyState === WebSocket.OPEN) {
        try {
          ws.send(JSON.stringify({ type: "statePatch", patch: msg.patch }));
        } catch (_) {}
      }
      return;
    }

    if (msg.type === "GECKO_BRIDGE_STOP") {
      active = false;
      clearTimeout(reconnectTimer);
      reportDirectStatus(false);
      notifyParentWsState(false);
      if (workerFramePort) {
        try { workerFramePort.close(); } catch (_) {}
        workerFramePort = null;
      }
      if (ws) {
        if (msg.notifySessionEnd && ws.readyState === WebSocket.OPEN) {
          try { ws.send(JSON.stringify({ type: "streamStopped" })); } catch (_) {}
        }
        try { ws.close(); } catch (_) {}
        ws = null;
      }
    }
  });

  connectWs();
  try {
    window.parent?.postMessage({ type: "GECKO_BRIDGE_LOADED" }, "*");
  } catch (_) {}
})();

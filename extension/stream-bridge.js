(function () {
  "use strict";

  const GHOST_WS_URL = "ws://127.0.0.1:51937";
  let ws = null;
  let reconnectTimer = null;
  let active = true;
  let reportedDirectActive = false;

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
      ws = new WebSocket(GHOST_WS_URL);
      ws.binaryType = "arraybuffer";

      ws.onopen = () => {
        if (!active) {
          try { ws.close(); } catch (_) {}
          return;
        }
        try {
          ws.send(JSON.stringify({ type: "register", role: "streamProducer" }));
        } catch (_) {}
        notifyParentWsState(true);
      };

      ws.onmessage = () => {
        // Control cmds & statePatch are handled exclusively by offscreen.js to avoid duplicates.
      };

      ws.onclose = () => {
        ws = null;
        notifyParentWsState(false);
        if (reportedDirectActive) reportDirectStatus(false);
        if (active) {
          clearTimeout(reconnectTimer);
          reconnectTimer = setTimeout(connectWs, 800);
        }
      };

      ws.onerror = () => {
        try { ws?.close(); } catch (_) {}
      };
    } catch (_) {
      notifyParentWsState(false);
      if (active) {
        clearTimeout(reconnectTimer);
        reconnectTimer = setTimeout(connectWs, 900);
      }
    }
  }

  window.addEventListener("message", (ev) => {
    const msg = ev.data;
    if (!msg || typeof msg !== "object") return;

    if (msg.type === "GECKO_BRIDGE_START") {
      active = true;
      connectWs();
      return;
    }

    if (msg.type === "GECKO_BRIDGE_FRAME") {
      if (!active) return;
      if (!ws || ws.readyState === WebSocket.CLOSED) connectWs();
      if (msg.buf instanceof ArrayBuffer && ws && ws.readyState === WebSocket.OPEN && ws.bufferedAmount < 24 * 1024) {
        try {
          ws.send(msg.buf);
          if (!reportedDirectActive) reportDirectStatus(true);
        } catch (_) {}
      }
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

    if (msg.type === "GECKO_BRIDGE_STOP") {
      active = false;
      clearTimeout(reconnectTimer);
      reportDirectStatus(false);
      notifyParentWsState(false);
      if (ws) {
        try { ws.close(); } catch (_) {}
        ws = null;
      }
    }
  });

  connectWs();
})();

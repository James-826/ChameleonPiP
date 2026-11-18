"use strict";

let activePipTabId = null;
let streamingTabId = null;
let ghostWsConnected = false;
let cropPollTimer = null;
const parasitePorts = new Set();

async function ensureOffscreenDocument() {
  if (chrome.offscreen.hasDocument) {
    const exists = await chrome.offscreen.hasDocument();
    if (exists) return;
  }
  try {
    await chrome.offscreen.createDocument({
      url: "offscreen.html",
      reasons: ["USER_MEDIA"],
      justification: "Capture active tab video frames for borderless Gecko camouflage overlay",
    });
  } catch (err) {
    if (!String(err).includes("Only a single offscreen")) {
      throw err;
    }
  }
}

async function queryVideoCropFromTab(tabId) {
  try {
    return await chrome.tabs.sendMessage(tabId, { type: "GECKO_GET_VIDEO_CROP" });
  } catch (_) {
    return null;
  }
}

function startCropPolling() {
  stopCropPolling();
  cropPollTimer = setInterval(async () => {
    if (!streamingTabId) {
      stopCropPolling();
      return;
    }
    const crop = await queryVideoCropFromTab(streamingTabId);
    const stored = await chrome.storage.local.get(["geckoState"]);
    chrome.runtime
      .sendMessage({
        type: "GECKO_OFFSCREEN_UPDATE_META",
        crop: crop || undefined,
        state: stored?.geckoState || undefined,
        hasCrossTabViewers: parasitePorts.size > 0,
      })
      .catch(() => {});
  }, 180);
}

function stopCropPolling() {
  if (cropPollTimer) {
    clearInterval(cropPollTimer);
    cropPollTimer = null;
  }
}

async function startTabStream(tabId, preIssuedStreamId) {
  if (chrome.offscreen.closeDocument) {
    await chrome.offscreen.closeDocument().catch(() => {});
  }
  await ensureOffscreenDocument();
  const streamId =
    preIssuedStreamId ||
    (await new Promise((resolve) => {
      chrome.tabCapture.getMediaStreamId({ targetTabId: tabId }, (id) => {
        if (chrome.runtime.lastError || !id) resolve(null);
        else resolve(id);
      });
    }));

  if (!streamId) {
    return {
      ok: false,
      reason: "stream_id_failed",
      error: chrome.runtime.lastError?.message || "无法获取标签页画面流，请点击浏览器右上角壁虎图标启动",
    };
  }

  const crop = await queryVideoCropFromTab(tabId);
  const stored = await chrome.storage.local.get(["geckoState"]);

  const res = await chrome.runtime.sendMessage({
    type: "GECKO_OFFSCREEN_START",
    streamId,
    state: stored?.geckoState || {},
    crop: crop || { nx: 0, ny: 0, nw: 1, nh: 1, aspect: 16 / 9, subtitle: "" },
  });

  if (res?.ok) {
    streamingTabId = tabId;
    startCropPolling();
  }
  return { ...res, streamingTabId };
}

async function stopTabStream() {
  stopCropPolling();
  streamingTabId = null;
  ghostWsConnected = false;
  try {
    await chrome.runtime.sendMessage({ type: "GECKO_OFFSCREEN_STOP" });
  } catch (_) {}
  for (const port of parasitePorts) {
    try {
      port.postMessage({ type: "GECKO_STREAM_ENDED" });
    } catch (_) {}
  }
}

// Cross-Tab Parasite Viewer Port Subscriptions
chrome.runtime.onConnect.addListener((port) => {
  if (port.name !== "gecko-parasite-viewer") return;
  parasitePorts.add(port);
  chrome.runtime
    .sendMessage({
      type: "GECKO_OFFSCREEN_UPDATE_META",
      hasCrossTabViewers: true,
    })
    .catch(() => {});

  port.onMessage.addListener((msg) => {
    if (msg?.type === "GECKO_VIEWER_CMD" && streamingTabId) {
      chrome.tabs
        .sendMessage(streamingTabId, {
          type: "GECKO_EXEC_VIDEO_CMD",
          action: msg.action,
          delta: msg.delta,
          value: msg.value,
        })
        .catch(() => {});
    }
  });

  port.onDisconnect.addListener(() => {
    parasitePorts.delete(port);
    chrome.runtime
      .sendMessage({
        type: "GECKO_OFFSCREEN_UPDATE_META",
        hasCrossTabViewers: parasitePorts.size > 0,
      })
      .catch(() => {});
  });
});

chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (!msg || typeof msg !== "object") return false;

  if (msg.type === "GECKO_PIP_STATUS") {
    if (msg.open && sender.tab?.id) {
      activePipTabId = sender.tab.id;
    } else if (!msg.open && sender.tab?.id === activePipTabId) {
      activePipTabId = null;
    }
    sendResponse({ ok: true, activePipTabId });
    return false;
  }

  if (msg.type === "GECKO_GHOST_WS_STATUS") {
    ghostWsConnected = Boolean(msg.connected);
    return false;
  }

  if (msg.type === "GECKO_STREAM_STOPPED") {
    stopCropPolling();
    streamingTabId = null;
    ghostWsConnected = false;
    return false;
  }

  if (msg.type === "GECKO_BROADCAST_FRAME") {
    for (const port of parasitePorts) {
      try {
        port.postMessage({
          type: "GECKO_FRAME",
          dataUrl: msg.dataUrl,
          aspect: msg.aspect,
          subtitle: msg.subtitle,
        });
      } catch (_) {}
    }
    return false;
  }

  if (msg.type === "GECKO_REMOTE_VIDEO_CMD") {
    const targetId = streamingTabId || activePipTabId;
    if (targetId) {
      chrome.tabs
        .sendMessage(targetId, {
          type: "GECKO_EXEC_VIDEO_CMD",
          action: msg.action,
          delta: msg.delta,
          value: msg.value,
        })
        .catch(() => {});
    }
    return false;
  }

  if (msg.type === "GECKO_REMOTE_STATE_PATCH") {
    chrome.storage.local.get(["geckoState"], (stored) => {
      const prev = stored?.geckoState || {};
      chrome.storage.local.set({ geckoState: { ...prev, ...msg.patch } });
    });
    return false;
  }

  if (msg.type === "GECKO_GET_STATUS_SUMMARY") {
    sendResponse({
      activePipTabId,
      streamingTabId,
      ghostWsConnected,
      parasiteViewerCount: parasitePorts.size,
    });
    return false;
  }

  if (msg.type === "GECKO_START_TAB_STREAM") {
    startTabStream(msg.tabId, msg.streamId).then((res) => sendResponse(res));
    return true;
  }

  if (msg.type === "GECKO_STOP_TAB_STREAM") {
    stopTabStream().then(() => sendResponse({ ok: true }));
    return true;
  }

  return false;
});

chrome.storage.onChanged.addListener((changes, area) => {
  if (area === "local" && changes.geckoState?.newValue && streamingTabId) {
    chrome.runtime
      .sendMessage({
        type: "GECKO_OFFSCREEN_UPDATE_META",
        state: changes.geckoState.newValue,
      })
      .catch(() => {});
  }
});

chrome.tabs.onRemoved.addListener((tabId) => {
  if (tabId === activePipTabId) activePipTabId = null;
  if (tabId === streamingTabId) stopTabStream();
});

// Mac-Native Global Extension Shortcuts (⌃Control + ⇧Shift + G / B)
chrome.commands.onCommand.addListener(async (command) => {
  if (command === "toggle-boss-mode") {
    const data = await chrome.storage.local.get(["geckoState"]);
    const prev = data.geckoState || {};
    const nextBoss = !prev.bossMode;
    await chrome.storage.local.set({
      geckoState: { ...prev, bossMode: nextBoss },
    });
    return;
  }

  if (command === "toggle-gecko-pip") {
    const data = await chrome.storage.local.get(["geckoState"]);
    const st = data.geckoState || {};
    const targetMode = st.displayTarget || "ghost";

    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    if (!tab?.id) return;

    if (targetMode === "ghost") {
      if (streamingTabId) {
        await stopTabStream();
      } else {
        await startTabStream(tab.id);
      }
      return;
    }

    if (targetMode === "parasite") {
      chrome.tabs
        .sendMessage(tab.id, { type: "GECKO_TOGGLE_PARASITE" })
        .catch(() => {});
      return;
    }

    // Classic Document PiP fallback
    if (activePipTabId) {
      chrome.tabs
        .sendMessage(activePipTabId, { type: "GECKO_CLOSE_PIP" })
        .catch(() => {});
      activePipTabId = null;
    } else {
      chrome.tabs
        .sendMessage(tab.id, { type: "GECKO_REQUEST_OPEN_OR_PROMPT" })
        .catch(() => {});
    }
  }
});

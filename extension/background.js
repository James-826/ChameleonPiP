"use strict";

let activePipTabId = null;
let streamingTabId = null;
let ghostWsConnected = false;
let cropPollTimer = null;
let cachedGeckoState = null;
let offscreenBootstrappedThisRun = false;
const parasitePorts = new Set();

chrome.storage.local.get(["geckoState"], (res) => {
  if (res?.geckoState) cachedGeckoState = res.geckoState;
});

async function reinjectOpenHttpTabs() {
  try {
    const tabs = await chrome.tabs.query({ url: ["http://*/*", "https://*/*"] });
    for (const t of tabs) {
      if (t?.id) {
        ensureTabContentScripts(t.id).catch(() => {});
      }
    }
  } catch (_) {}
}

chrome.runtime.onInstalled.addListener(() => {
  reinjectOpenHttpTabs();
});
reinjectOpenHttpTabs();

async function ensureOffscreenDocument() {
  if (!offscreenBootstrappedThisRun) {
    offscreenBootstrappedThisRun = true;
    if (chrome.offscreen.hasDocument) {
      const stale = await chrome.offscreen.hasDocument().catch(() => false);
      if (stale) {
        await chrome.offscreen.closeDocument().catch(() => {});
      }
    }
  } else if (chrome.offscreen.hasDocument) {
    const exists = await chrome.offscreen.hasDocument();
    if (exists) return;
  }
  try {
    await chrome.offscreen.createDocument({
      url: "offscreen.html",
      reasons: ["USER_MEDIA"],
      justification: "Capture active tab video frames for borderless ChameleonPiP camouflage overlay",
    });
  } catch (err) {
    if (!String(err).includes("Only a single offscreen")) {
      throw err;
    }
  }
}

async function ensureTabContentScripts(tabId) {
  try {
    await chrome.tabs.sendMessage(tabId, { type: "GECKO_GET_VIDEO_CROP" });
    return true;
  } catch (_) {
    try {
      await chrome.scripting.executeScript({
        target: { tabId },
        world: "MAIN",
        files: ["page-hooks.js"],
      }).catch(() => {});
      await chrome.scripting.insertCSS({ target: { tabId }, files: ["content.css"] }).catch(() => {});
      await chrome.scripting.executeScript({
        target: { tabId },
        files: ["gecko-core.js", "content.js"],
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}

async function queryVideoCropFromTab(tabId) {
  try {
    const [crop, tab] = await Promise.all([
      chrome.tabs.sendMessage(tabId, { type: "GECKO_GET_VIDEO_CROP" }).catch(() => null),
      chrome.tabs.get(tabId).catch(() => null),
    ]);
    if (crop && crop.player && tab) {
      crop.player.tabMuted = Boolean(tab.mutedInfo?.muted);
      crop.player.muted = Boolean(tab.mutedInfo?.muted) || Boolean(crop.player.muted);
    }
    return crop;
  } catch (_) {
    return null;
  }
}

async function pushImmediateMetaForTab(tabId) {
  if (!tabId) return;
  const crop = await queryVideoCropFromTab(tabId);
  if (!crop) return;
  chrome.runtime
    .sendMessage({
      type: "GECKO_OFFSCREEN_UPDATE_META",
      crop,
      hasCrossTabViewers: parasitePorts.size > 0,
    })
    .catch(() => {});
}

function startCropPolling() {
  stopCropPolling();
  cropPollTimer = setInterval(async () => {
    if (!streamingTabId) {
      stopCropPolling();
      return;
    }
    const crop = await queryVideoCropFromTab(streamingTabId);
    chrome.runtime
      .sendMessage({
        type: "GECKO_OFFSCREEN_UPDATE_META",
        crop: crop || undefined,
        state: cachedGeckoState || undefined,
        hasCrossTabViewers: parasitePorts.size > 0,
      })
      .catch(() => {});
  }, 450);
}

function stopCropPolling() {
  if (cropPollTimer) {
    clearInterval(cropPollTimer);
    cropPollTimer = null;
  }
}

async function setTabStreamKeepAwake(tabId, enabled) {
  if (!tabId) return;
  chrome.tabs.update(tabId, { autoDiscardable: !enabled }).catch(() => {});
  try {
    const results = await chrome.scripting.executeScript({
      target: { tabId },
      world: "MAIN",
      args: [Boolean(enabled)],
      func: (active) => {
        window.__CHAMELEON_STREAM_AWAKE__ = active;
        if (document.documentElement) {
          document.documentElement.dataset.chameleonStreamAwake = active ? "1" : "0";
        }
        if (!window.__CHAMELEON_VIS_HOOKED__) {
          window.__CHAMELEON_VIS_HOOKED__ = true;
          const origHidden = Object.getOwnPropertyDescriptor(Document.prototype, "hidden");
          const origVis = Object.getOwnPropertyDescriptor(Document.prototype, "visibilityState");
          if (origHidden?.get) {
            try {
              Object.defineProperty(document, "hidden", {
                configurable: true,
                get: () => (window.__CHAMELEON_STREAM_AWAKE__ ? false : origHidden.get.call(document)),
              });
            } catch (_) {}
          }
          if (origVis?.get) {
            try {
              Object.defineProperty(document, "visibilityState", {
                configurable: true,
                get: () => (window.__CHAMELEON_STREAM_AWAKE__ ? "visible" : origVis.get.call(document)),
              });
            } catch (_) {}
          }
          const stopVis = (e) => {
            if (window.__CHAMELEON_STREAM_AWAKE__) e.stopImmediatePropagation();
          };
          document.addEventListener("visibilitychange", stopVis, true);
          document.addEventListener("webkitvisibilitychange", stopVis, true);
          window.addEventListener("visibilitychange", stopVis, true);
        }

        const vids = Array.from(document.querySelectorAll("video"));
        const mainVid =
          vids.find((v) => !v.paused && v.readyState >= 2) ||
          vids.sort((a, b) => b.clientWidth * b.clientHeight - a.clientWidth * a.clientHeight)[0];
        if (!mainVid) return { hadMutedVideo: false };

        if (active) {
          if (mainVid.muted || mainVid.volume === 0) {
            mainVid.__chameleonWasElementMuted = true;
            mainVid.__chameleonPrevVol = mainVid.volume;
            mainVid.muted = false;
            if (mainVid.volume < 0.05) mainVid.volume = 0.5;
            return { hadMutedVideo: true };
          }
        } else if (mainVid.__chameleonWasElementMuted) {
          mainVid.muted = true;
          if (typeof mainVid.__chameleonPrevVol === "number") {
            mainVid.volume = mainVid.__chameleonPrevVol;
          }
          delete mainVid.__chameleonWasElementMuted;
          delete mainVid.__chameleonPrevVol;
        }
        return { hadMutedVideo: false };
      },
    });
    if (enabled && results?.[0]?.result?.hadMutedVideo) {
      await chrome.tabs.update(tabId, { muted: true }).catch(() => {});
    }
  } catch (_) {}
}

async function startDirectStreamForTab(tabId) {
  if (!tabId) return { ok: false, reason: "no_tab" };
  if (streamingTabId && streamingTabId !== tabId) {
    stopCropPolling();
    chrome.tabs.sendMessage(streamingTabId, { type: "GECKO_STOP_DIRECT_STREAM", notifySessionEnd: false }).catch(() => {});
    setTabStreamKeepAwake(streamingTabId, false);
    chrome.runtime.sendMessage({ type: "GECKO_OFFSCREEN_STOP" }).catch(() => {});
  }
  await ensureTabContentScripts(tabId);
  await setTabStreamKeepAwake(tabId, true);
  const res = await chrome.tabs
    .sendMessage(tabId, { type: "GECKO_START_DIRECT_STREAM", directOnly: true })
    .catch(() => null);
  if (res?.ok) {
    streamingTabId = tabId;
    return { ok: true, streamingTabId, mode: "direct" };
  }
  setTabStreamKeepAwake(tabId, false);
  return { ok: false, reason: res?.reason || "direct_failed" };
}

async function startTabStream(tabId, preIssuedStreamId) {
  if (streamingTabId && streamingTabId !== tabId) {
    chrome.tabs.sendMessage(streamingTabId, { type: "GECKO_STOP_DIRECT_STREAM" }).catch(() => {});
    setTabStreamKeepAwake(streamingTabId, false);
  }
  await ensureTabContentScripts(tabId);
  // Reuse existing offscreen document if already alive in this SW session
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
    // Fallback cleanly to zero-permission direct <video>.captureStream() pipeline!
    return await startDirectStreamForTab(tabId);
  }

  await setTabStreamKeepAwake(tabId, true);
  const crop = await queryVideoCropFromTab(tabId);
  if (!cachedGeckoState) {
    const stored = await chrome.storage.local.get(["geckoState"]);
    cachedGeckoState = stored?.geckoState || {};
  }

  const res = await chrome.runtime.sendMessage({
    type: "GECKO_OFFSCREEN_START",
    streamId,
    state: cachedGeckoState || {},
    crop: crop || { nx: 0, ny: 0, nw: 1, nh: 1, aspect: 16 / 9, subtitle: "" },
  });

  if (res?.ok) {
    streamingTabId = tabId;
    startCropPolling();
    // Keep Chrome's unthrottled offscreen tabCapture active even if the user switches tabs!
    chrome.tabs.sendMessage(tabId, { type: "GECKO_STOP_DIRECT_STREAM", notifySessionEnd: false }).catch(() => {});
  } else {
    setTabStreamKeepAwake(tabId, false);
  }
  return { ...res, streamingTabId };
}

async function stopTabStream() {
  stopCropPolling();
  const prevTabId = streamingTabId;
  streamingTabId = null;
  ghostWsConnected = false;
  if (prevTabId) {
    chrome.tabs
      .sendMessage(prevTabId, { type: "GECKO_STOP_DIRECT_STREAM", notifySessionEnd: true })
      .catch(() => {});
    setTabStreamKeepAwake(prevTabId, false);
  }
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
    const prevTabId = streamingTabId;
    streamingTabId = null;
    ghostWsConnected = false;
    if (prevTabId) {
      chrome.tabs.sendMessage(prevTabId, { type: "GECKO_STOP_DIRECT_STREAM" }).catch(() => {});
      setTabStreamKeepAwake(prevTabId, false);
    }
    return false;
  }

  if (msg.type === "GECKO_DIRECT_STREAM_STATUS") {
    if (streamingTabId && (!sender.tab || sender.tab.id === streamingTabId)) {
      chrome.runtime
        .sendMessage({
          type: "GECKO_OFFSCREEN_DIRECT_BYPASS",
          active: Boolean(msg.active),
        })
        .catch(() => {});
    }
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
    const targetId = msg.tabId || streamingTabId || activePipTabId;
    if (targetId) {
      // Instant OS-level Chrome Tab Mute (<5ms, immune to Bilibili/YouTube/Douyin player overrides!)
      if (msg.action === "setMuted" || msg.action === "toggleMute") {
        chrome.tabs.get(targetId, (tab) => {
          if (chrome.runtime.lastError || !tab) return;
          const nextMuted =
            msg.action === "setMuted"
              ? Boolean(msg.value)
              : !Boolean(tab.mutedInfo?.muted);
          chrome.tabs.update(targetId, { muted: nextMuted }).catch(() => {});
          // When unmuting, also ensure the webpage <video> element isn't muted or volume===0
          if (!nextMuted) {
            chrome.tabs
              .sendMessage(targetId, { type: "GECKO_EXEC_VIDEO_CMD", action: "setMuted", value: false })
              .catch(() => {});
          }
          setTimeout(() => pushImmediateMetaForTab(targetId), 25);
        });
        return false;
      }

      chrome.tabs
        .sendMessage(targetId, {
          type: "GECKO_EXEC_VIDEO_CMD",
          action: msg.action,
          delta: msg.delta,
          value: msg.value,
        })
        .then(() => {
          setTimeout(() => pushImmediateMetaForTab(targetId), 30);
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

  if (msg.type === "GECKO_START_DIRECT_FROM_POPUP") {
    startDirectStreamForTab(msg.tabId).then((res) => sendResponse(res));
    return true;
  }

  if (msg.type === "GECKO_REGISTER_DIRECT_PAGE_STREAM") {
    const tid = sender.tab?.id;
    if (!tid) {
      sendResponse({ ok: false });
      return false;
    }
    (async () => {
      if (streamingTabId && streamingTabId !== tid) {
        stopCropPolling();
        chrome.tabs
          .sendMessage(streamingTabId, { type: "GECKO_STOP_DIRECT_STREAM", notifySessionEnd: false })
          .catch(() => {});
        setTabStreamKeepAwake(streamingTabId, false);
        chrome.runtime.sendMessage({ type: "GECKO_OFFSCREEN_STOP" }).catch(() => {});
      }
      streamingTabId = tid;
      await chrome.scripting
        .executeScript({ target: { tabId: tid }, world: "MAIN", files: ["page-hooks.js"] })
        .catch(() => {});
      await setTabStreamKeepAwake(tid, true);
      sendResponse({ ok: true, streamingTabId });
    })();
    return true;
  }

  if (msg.type === "GECKO_STOP_TAB_STREAM") {
    stopTabStream().then(() => sendResponse({ ok: true }));
    return true;
  }

  return false;
});

chrome.storage.onChanged.addListener((changes, area) => {
  if (area === "local" && changes.geckoState?.newValue) {
    cachedGeckoState = changes.geckoState.newValue;
    if (streamingTabId) {
      chrome.runtime
        .sendMessage({
          type: "GECKO_OFFSCREEN_UPDATE_META",
          state: changes.geckoState.newValue,
        })
        .catch(() => {});
    }
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

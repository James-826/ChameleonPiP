(function () {
  "use strict";

  const Core = window.GeckoCore;
  let state = { ...Core.DEFAULT_STATE };
  let activeTabId = null;
  let streamingTabId = null;
  let ghostWsConnected = false;
  let parasiteOpen = false;
  let hasVideo = false;

  const els = {
    statusText: document.getElementById("statusText"),
    btnBossToggle: document.getElementById("btnBossToggle"),
    btnMacGhost: document.getElementById("btnMacGhost"),
    btnInPageParasite: document.getElementById("btnInPageParasite"),
    chkAutoSense: document.getElementById("chkAutoSense"),
    rngStealth: document.getElementById("rngStealth"),
    valStealth: document.getElementById("valStealth"),
    rngOpacity: document.getElementById("rngOpacity"),
    valOpacity: document.getElementById("valOpacity"),
    rngFeather: document.getElementById("rngFeather"),
    valFeather: document.getElementById("valFeather"),
    chkSubtitles: document.getElementById("chkSubtitles"),
  };

  function checkGhostAlive(timeoutMs = 350) {
    return new Promise((resolve) => {
      let settled = false;
      const done = (ok) => {
        if (!settled) {
          settled = true;
          resolve(ok);
        }
      };
      try {
        const ws = new WebSocket("ws://127.0.0.1:51937");
        const timer = setTimeout(() => {
          try { ws.close(); } catch (_) {}
          done(false);
        }, timeoutMs);
        ws.onopen = () => {
          clearTimeout(timer);
          ws.close();
          done(true);
        };
        ws.onerror = () => {
          clearTimeout(timer);
          done(false);
        };
      } catch (_) {
        done(false);
      }
    });
  }

  function wakeMacGhostApp() {
    if (!activeTabId) return;
    chrome.tabs
      .sendMessage(activeTabId, { type: "GECKO_WAKE_MAC_APP" })
      .catch(() => {});
  }

  async function ensureContentScriptAndQuery(tabId) {
    try {
      return await chrome.tabs.sendMessage(tabId, { type: "GECKO_GET_PAGE_INFO" });
    } catch (_) {
      try {
        await chrome.scripting.insertCSS({ target: { tabId }, files: ["content.css"] });
        await chrome.scripting.executeScript({
          target: { tabId },
          files: ["gecko-core.js", "content.js"],
        });
        return await chrome.tabs.sendMessage(tabId, { type: "GECKO_GET_PAGE_INFO" });
      } catch (_) {
        return null;
      }
    }
  }

  async function init() {
    const stored = await chrome.storage.local.get(["geckoState"]);
    if (stored?.geckoState) {
      state = { ...Core.DEFAULT_STATE, ...stored.geckoState };
    }

    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    activeTabId = tab?.id || null;

    const summary = await chrome.runtime.sendMessage({ type: "GECKO_GET_STATUS_SUMMARY" });
    streamingTabId = summary?.streamingTabId || null;
    ghostWsConnected = Boolean(summary?.ghostWsConnected) || (await checkGhostAlive());

    if (activeTabId) {
      const info = await ensureContentScriptAndQuery(activeTabId);
      if (info) {
        hasVideo = Boolean(info.hasVideo);
        parasiteOpen = Boolean(info.parasiteOpen);
      }
    }
    render();
  }

  function updateState(patch) {
    state = { ...state, ...patch };
    chrome.storage.local.set({ geckoState: state });
    render();
  }

  function render() {
    if (streamingTabId) {
      els.statusText.textContent = ghostWsConnected
        ? "桌面无边框画中画运行中"
        : "正在唤醒桌面端 GeckoGhost.app…";
      els.btnMacGhost.innerHTML = `<span>停止桌面无边框画中画</span><span class="kbd">⌃⇧G</span>`;
      els.btnMacGhost.classList.add("active");
    } else if (parasiteOpen) {
      els.statusText.textContent = "当前网页内无边框小窗播放中";
      els.btnMacGhost.innerHTML = `<span>切换到 Mac 桌面全局画中画</span><span class="kbd">⌃⇧G</span>`;
      els.btnMacGhost.classList.remove("active");
    } else if (hasVideo) {
      els.statusText.textContent = "已识别视频 · 可一键开启无边框画中画";
      els.btnMacGhost.innerHTML = `<span>开启 Mac 桌面无边框画中画</span><span class="kbd">⌃⇧G</span>`;
      els.btnMacGhost.classList.remove("active");
    } else {
      els.statusText.textContent = "请先打开带视频的网页（B站 / 抖音 / YouTube）";
      els.btnMacGhost.innerHTML = `<span>开启 Mac 桌面无边框画中画</span><span class="kbd">⌃⇧G</span>`;
      els.btnMacGhost.classList.remove("active");
    }

    els.btnInPageParasite.classList.toggle("active", parasiteOpen);
    els.btnInPageParasite.textContent = parasiteOpen
      ? "关闭当前网页内悬浮"
      : "仅在当前浏览器页面内悬浮";

    els.btnBossToggle.classList.toggle("active", Boolean(state.bossMode));
    if (els.chkAutoSense) els.chkAutoSense.checked = Boolean(state.autoSense);

    document.querySelectorAll(".mode-tab").forEach((tab) => {
      tab.classList.toggle("active", tab.dataset.mode === state.mode);
    });

    els.rngStealth.value = String(state.stealth);
    els.valStealth.textContent = `${state.stealth}%`;
    const op = state.opacity ?? 100;
    if (els.rngOpacity) els.rngOpacity.value = String(op);
    if (els.valOpacity) els.valOpacity.textContent = `${op}%`;
    els.rngFeather.value = String(state.feather);
    els.valFeather.textContent = `${state.feather}%`;

    els.chkSubtitles.checked = Boolean(state.mirrorSubtitles);
  }

  // Primary Action: Stream to Mac Desktop Borderless Ghost Window
  els.btnMacGhost.addEventListener("click", async () => {
    if (streamingTabId) {
      await chrome.runtime.sendMessage({ type: "GECKO_STOP_TAB_STREAM" });
      streamingTabId = null;
      render();
      return;
    }
    if (!activeTabId) return;

    // Close in-page parasite if open so there aren't two windows at once!
    if (parasiteOpen) {
      await chrome.tabs.sendMessage(activeTabId, { type: "GECKO_CLOSE_PIP" }).catch(() => {});
      parasiteOpen = false;
    }

    updateState({ displayTarget: "ghost", bossMode: false });

    const alive = await checkGhostAlive(300);
    if (!alive) {
      wakeMacGhostApp();
    }

    chrome.tabCapture.getMediaStreamId({ targetTabId: activeTabId }, async (streamId) => {
      if (chrome.runtime.lastError || !streamId) {
        els.statusText.textContent =
          "捕获失败：" + (chrome.runtime.lastError?.message || "请刷新当前视频页重试");
        return;
      }
      const res = await chrome.runtime.sendMessage({
        type: "GECKO_START_TAB_STREAM",
        tabId: activeTabId,
        streamId,
      });
      if (res?.ok) {
        streamingTabId = activeTabId;
        setTimeout(async () => {
          ghostWsConnected = await checkGhostAlive(500);
          render();
          if (ghostWsConnected) window.close();
        }, 650);
      }
    });
  });

  // Secondary Action: In-Page Only Floating
  els.btnInPageParasite.addEventListener("click", async () => {
    if (!activeTabId) return;
    if (streamingTabId && !parasiteOpen) {
      await chrome.runtime.sendMessage({ type: "GECKO_STOP_TAB_STREAM" });
      streamingTabId = null;
    }
    updateState({ displayTarget: "parasite", bossMode: false });
    const res = await chrome.tabs.sendMessage(activeTabId, {
      type: "GECKO_TOGGLE_PARASITE",
    });
    if (res?.ok) {
      parasiteOpen = Boolean(res.open);
      render();
      if (parasiteOpen) window.close();
    }
  });

  els.btnBossToggle.addEventListener("click", () => {
    updateState({ bossMode: !state.bossMode });
  });

  els.chkAutoSense?.addEventListener("change", () => {
    updateState({ autoSense: els.chkAutoSense.checked });
  });

  // Style tabs do NOT disable AutoSense color matching!
  document.querySelectorAll(".mode-tab").forEach((tab) => {
    tab.addEventListener("click", () => {
      updateState({ mode: tab.dataset.mode });
    });
  });

  document.querySelectorAll(".mark-btn").forEach((btn) => {
    btn.addEventListener("click", () => {
      updateState({ stealth: Number(btn.dataset.val) });
    });
  });

  els.rngStealth.addEventListener("input", () => {
    updateState({ stealth: Number(els.rngStealth.value) });
  });
  els.rngOpacity?.addEventListener("input", () => {
    updateState({ opacity: Number(els.rngOpacity.value) });
  });
  els.rngFeather.addEventListener("input", () => {
    updateState({ feather: Number(els.rngFeather.value) });
  });

  els.chkSubtitles.addEventListener("change", () => {
    updateState({ mirrorSubtitles: els.chkSubtitles.checked });
  });

  chrome.storage.onChanged.addListener((changes, area) => {
    if (area === "local" && changes.geckoState?.newValue) {
      state = { ...Core.DEFAULT_STATE, ...changes.geckoState.newValue };
      render();
    }
  });

  // Real-time video playback control from toolbar popup
  let livePlayer = { paused: true, currentTime: 0, duration: 0, muted: false, playbackRate: 1.0 };
  let popScrubbing = false;

  function getTargetVideoTabId() {
    return streamingTabId || activeTabId;
  }

  async function sendCmdToTabVideo(cmd) {
    const tid = getTargetVideoTabId();
    if (!tid) return;
    chrome.tabs.sendMessage(tid, { type: "GECKO_EXEC_VIDEO_CMD", ...cmd }).catch(() => {});
  }

  function renderLivePlayerUi() {
    const pBtn = document.getElementById("popPlay");
    const mBtn = document.getElementById("popMute");
    const rBtn = document.getElementById("popRate");
    const fill = document.getElementById("popFill");
    const timeLbl = document.getElementById("popTime");
    if (!pBtn) return;

    pBtn.textContent = livePlayer.paused ? "▶ 播放" : "⏸ 暂停";
    mBtn.textContent = livePlayer.muted ? "已静音" : "静音";
    const r = Number(livePlayer.playbackRate || 1);
    rBtn.textContent = `${r.toFixed(r % 1 === 0 ? 1 : 2).replace(/\.00$/, ".0")}x`;
    const dur = livePlayer.duration > 0 ? livePlayer.duration : 0;
    const cur = Core.clamp(livePlayer.currentTime || 0, 0, dur || Infinity);
    if (!popScrubbing) {
      fill.style.width = dur > 0 ? `${((cur / dur) * 100).toFixed(2)}%` : "0%";
    }
    timeLbl.textContent = `${Core.formatTime(cur)} / ${Core.formatTime(dur)}`;
  }

  async function pollTabPlayer() {
    const tid = getTargetVideoTabId();
    if (!tid) return;
    try {
      const crop = await chrome.tabs.sendMessage(tid, { type: "GECKO_GET_VIDEO_CROP" });
      if (crop?.player) {
        livePlayer = { ...livePlayer, ...crop.player };
        renderLivePlayerUi();
      }
    } catch (_) {}
  }

  document.getElementById("popPlay")?.addEventListener("click", () => {
    livePlayer.paused = !livePlayer.paused;
    renderLivePlayerUi();
    sendCmdToTabVideo({ action: "togglePlay" });
  });
  document.getElementById("popBack")?.addEventListener("click", () => sendCmdToTabVideo({ action: "seek", delta: -10 }));
  document.getElementById("popFwd")?.addEventListener("click", () => sendCmdToTabVideo({ action: "seek", delta: 10 }));
  document.getElementById("popMute")?.addEventListener("click", () => {
    livePlayer.muted = !livePlayer.muted;
    renderLivePlayerUi();
    sendCmdToTabVideo({ action: "toggleMute" });
  });
  const popRates = [1.0, 1.25, 1.5, 2.0];
  document.getElementById("popRate")?.addEventListener("click", () => {
    const next = popRates[(popRates.indexOf(Number(livePlayer.playbackRate || 1)) + 1) % popRates.length];
    livePlayer.playbackRate = next;
    renderLivePlayerUi();
    sendCmdToTabVideo({ action: "setRate", value: next });
  });

  const popTrack = document.getElementById("popTrack");
  function seekPopAt(clientX) {
    if (!popTrack || !(livePlayer.duration > 0)) return;
    const rect = popTrack.getBoundingClientRect();
    const ratio = Core.clamp((clientX - rect.left) / Math.max(1, rect.width), 0, 1);
    const val = ratio * livePlayer.duration;
    livePlayer.currentTime = val;
    document.getElementById("popFill").style.width = `${(ratio * 100).toFixed(2)}%`;
    renderLivePlayerUi();
    sendCmdToTabVideo({ action: "seekTo", value: val });
  }
  popTrack?.addEventListener("mousedown", (e) => { popScrubbing = true; seekPopAt(e.clientX); });
  window.addEventListener("mousemove", (e) => { if (popScrubbing) seekPopAt(e.clientX); });
  window.addEventListener("mouseup", () => { popScrubbing = false; });

  setInterval(pollTabPlayer, 250);
  setTimeout(pollTabPlayer, 80);

  document.getElementById("btnOpenArena")?.addEventListener("click", () => {
    chrome.tabs.create({ url: chrome.runtime.getURL("arena.html") });
  });

  init();
})();

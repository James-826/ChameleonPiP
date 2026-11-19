(function () {
  "use strict";

  const Core = window.GeckoCore;
  const Stats = window.ChameleonStats;
  let state = { ...Core.DEFAULT_STATE };
  let membership = Stats ? Stats.loadMembership() : { tier: "free", isPro: false };
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
    chkHoverReveal: document.getElementById("chkHoverReveal"),
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

  function renderMembershipBar() {
    if (!Stats) return;
    const isPro = Stats.isProMember(membership);
    const strip = document.getElementById("memberStrip");
    const pill = document.getElementById("popMemberBadge");
    const desc = document.getElementById("popMemberDesc");
    const btn = document.getElementById("btnPopUpgrade");
    const btnTrial = document.getElementById("btnPopTrial");

    if (strip) strip.classList.toggle("is-pro", isPro);
    if (pill) {
      pill.textContent = membership.tier === "lifetime" ? "MAX" : isPro ? "PRO" : "FREE";
      pill.classList.toggle("pro", isPro);
    }
    if (desc) {
      desc.textContent = isPro
        ? `${membership.planName || "Pro 会员"} · 有效期至 ${Stats.formatExpiryDate(membership.expiresAt)}`
        : "免费版 · 升级解锁浮雕/彩透/会议隐身";
    }
    if (btn) btn.textContent = isPro ? "会员中心" : "升级 / 激活";
    if (btnTrial) {
      btnTrial.style.display = isPro ? "none" : "inline-block";
      if (membership.trialUsed) {
        btnTrial.disabled = true;
        btnTrial.textContent = "已用过 3 天试用";
        btnTrial.style.opacity = "0.5";
      }
    }
    document.querySelectorAll(".mini-pro-tag").forEach((el) => {
      el.style.display = isPro ? "none" : "inline-block";
    });
  }

  function openPopupProDrawer(reason) {
    const drawer = document.getElementById("popProDrawer");
    const msg = document.getElementById("popProMsg");
    if (msg && reason) msg.textContent = reason;
    if (drawer) drawer.style.display = "flex";
  }

  function syncMembershipToDesktopApp(mem) {
    try {
      const ws = new WebSocket("ws://127.0.0.1:51937");
      ws.onopen = () => {
        ws.send(JSON.stringify({ type: "register", role: "arenaView" }));
        ws.send(JSON.stringify({ type: "membershipUpdated", membership: mem }));
        setTimeout(() => ws.close(), 120);
      };
    } catch (_) {}
  }

  async function init() {
    const stored = await chrome.storage.local.get(["geckoState", "geckoMembership"]);
    if (stored?.geckoState) {
      state = { ...Core.DEFAULT_STATE, ...stored.geckoState };
    }
    if (stored?.geckoMembership && Stats) {
      membership = Stats.saveMembership(stored.geckoMembership);
    }
    if (Stats) {
      const prof = Stats.loadProfile();
      Stats.refreshMembership(prof.userId).then((m) => {
        membership = m;
        renderMembershipBar();
      });
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

    if (els.chkHoverReveal) els.chkHoverReveal.checked = Boolean(state.hoverReveal);
    els.chkSubtitles.checked = Boolean(state.mirrorSubtitles);
    renderMembershipBar();
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

  // Style tabs: Emboss & Cinema require Pro membership
  document.querySelectorAll(".mode-tab").forEach((tab) => {
    tab.addEventListener("click", () => {
      const targetMode = tab.dataset.mode;
      if (targetMode !== "projector" && Stats && !Stats.isProMember(membership)) {
        openPopupProDrawer("「浮雕隐身」与「彩透变色」为 Pro 会员专属变色龙模式，可一键开启 3 天免费体验或输入激活码解锁！");
        return;
      }
      updateState({ mode: targetMode });
    });
  });

  document.getElementById("btnPopUpgrade")?.addEventListener("click", () => {
    const drawer = document.getElementById("popProDrawer");
    if (!drawer) return;
    drawer.style.display = drawer.style.display === "none" ? "flex" : "none";
  });

  document.getElementById("btnPopPlans")?.addEventListener("click", () => {
    chrome.tabs.create({ url: chrome.runtime.getURL("arena.html#upgrade") });
  });

  document.getElementById("btnPopTrial")?.addEventListener("click", async () => {
    if (!Stats) return;
    const btn = document.getElementById("btnPopTrial");
    const msg = document.getElementById("popProMsg");
    btn.disabled = true;
    btn.textContent = "开通中...";
    const res = await Stats.startFreeTrial(Stats.loadProfile().userId);
    if (res?.ok && res.entitlement) {
      membership = Stats.saveMembership(res.entitlement);
      syncMembershipToDesktopApp(membership);
      if (msg) msg.textContent = res.message || "已开启 3 天 Pro 体验，所有模式已解锁！";
    } else {
      btn.disabled = false;
      btn.textContent = "一键免费试用 3 天 Pro";
      if (msg) msg.textContent = res?.message || "试用开通失败，请稍后重试。";
    }
    renderMembershipBar();
  });

  document.getElementById("btnPopActivate")?.addEventListener("click", async () => {
    if (!Stats) return;
    const inp = document.getElementById("popKeyInput");
    const msg = document.getElementById("popProMsg");
    const key = inp?.value.trim();
    if (!key) {
      if (msg) msg.textContent = "请输入 Pro 激活码（CHM-PRO-...）";
      return;
    }
    const res = await Stats.activateLicenseKey(key, Stats.loadProfile().userId);
    if (res?.ok && res.entitlement) {
      membership = Stats.saveMembership(res.entitlement);
      syncMembershipToDesktopApp(membership);
      if (inp) inp.value = "";
      if (msg) msg.textContent = res.message || "激活成功！已解锁全部 Pro 权益。";
    } else if (msg) {
      msg.textContent = res?.message || "激活码无效，请检查后重试。";
    }
    renderMembershipBar();
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

  els.chkHoverReveal?.addEventListener("change", () => {
    updateState({ hoverReveal: els.chkHoverReveal.checked });
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
    const tid = getTargetVideoTabId();
    if (tid) {
      chrome.runtime.sendMessage({
        type: "GECKO_REMOTE_VIDEO_CMD",
        tabId: tid,
        action: "setMuted",
        value: livePlayer.muted,
      }).catch(() => {});
    }
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

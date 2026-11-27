(function () {
  "use strict";

  const Core = window.GeckoCore;
  const Stats = window.ChameleonStats;
  let state = { ...Core.DEFAULT_STATE };
  let membership = Stats ? Stats.loadMembership() : { tier: "free", isPro: false };
  const GHOST_WS_PORTS = [27182, 51937];
  let activeTabId = null;
  let videoTabId = null;
  let streamingTabId = null;
  let ghostWsConnected = false;
  let parasiteOpen = false;
  let hasVideo = false;

  const els = {
    statusText: document.getElementById("statusText"),
    btnBossToggle: document.getElementById("btnBossToggle"),
    btnMacGhost: document.getElementById("btnMacGhost"),
    btnInPageParasite: document.getElementById("btnInPageParasite"),
    btnOpenDesktopSearch: document.getElementById("btnOpenDesktopSearch"),
    chkAutoSense: document.getElementById("chkAutoSense"),
    rngStealth: document.getElementById("rngStealth"),
    valStealth: document.getElementById("valStealth"),
    rngOpacity: document.getElementById("rngOpacity"),
    valOpacity: document.getElementById("valOpacity"),
    rngFeather: document.getElementById("rngFeather"),
    valFeather: document.getElementById("valFeather"),
    chkHoverReveal: document.getElementById("chkHoverReveal"),
    chkSubtitles: document.getElementById("chkSubtitles"),
    chkStealthSubtitle: document.getElementById("chkStealthSubtitle"),
  };

  function probeGhostPort(port, timeoutMs) {
    return new Promise((resolve) => {
      let settled = false;
      const done = (ok) => {
        if (!settled) {
          settled = true;
          resolve(ok);
        }
      };
      try {
        const ws = new WebSocket(`ws://127.0.0.1:${port}`);
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

  async function checkGhostAlive(timeoutMs = 350) {
    for (const p of GHOST_WS_PORTS) {
      if (await probeGhostPort(p, timeoutMs)) return true;
    }
    return false;
  }

  function wakeMacGhostApp(action = "wakeup") {
    try {
      const iframe = document.createElement("iframe");
      iframe.style.cssText = "display:none;width:0;height:0;border:0;";
      iframe.src = `chameleonpip://${action}`;
      document.body.appendChild(iframe);
      setTimeout(() => iframe.remove(), 1200);
    } catch (_) {}
    const tid = videoTabId || activeTabId;
    if (tid) {
      chrome.tabs
        .sendMessage(tid, { type: "GECKO_WAKE_MAC_APP" })
        .catch(() => {});
    }
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
      const lbl =
        membership.plan === "patron" || (membership.tier === "lifetime" && membership.plan !== "coffee" && membership.plan !== "latte")
          ? "MAX"
          : membership.plan === "latte"
          ? "VIP"
          : membership.plan === "coffee"
          ? "SUP"
          : isPro
          ? "PRO"
          : "FREE";
      pill.textContent = lbl;
      pill.classList.toggle("pro", isPro);
    }
    if (desc) {
      desc.textContent = isPro
        ? `${membership.planName || "咖啡支持者"} · 感谢支持`
        : "全功能永久免费无限制 · 零套路";
    }
    if (btn) btn.textContent = isPro ? "致谢中心" : "请喝咖啡";
    if (btnTrial) {
      btnTrial.style.display = isPro ? "none" : "inline-block";
      btnTrial.disabled = false;
      btnTrial.textContent = "一键点亮支持者金标";
      btnTrial.style.opacity = "1";
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
    const tryPort = (idx) => {
      if (idx >= GHOST_WS_PORTS.length) return;
      try {
        let opened = false;
        const ws = new WebSocket(`ws://127.0.0.1:${GHOST_WS_PORTS[idx]}`);
        ws.onopen = () => {
          opened = true;
          ws.send(JSON.stringify({ type: "register", role: "arenaView" }));
          ws.send(JSON.stringify({ type: "membershipUpdated", membership: mem }));
          setTimeout(() => ws.close(), 120);
        };
        ws.onerror = () => {
          if (!opened) tryPort(idx + 1);
        };
      } catch (_) {
        tryPort(idx + 1);
      }
    };
    tryPort(0);
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
        if (hasVideo) videoTabId = activeTabId;
      }
    }

    if (!videoTabId) {
      try {
        const allTabs = await chrome.tabs.query({ url: ["http://*/*", "https://*/*"] });
        allTabs.sort((a, b) => Number(Boolean(b.audible)) - Number(Boolean(a.audible)));
        for (const t of allTabs) {
          if (!t.id || t.id === activeTabId) continue;
          const info = await ensureContentScriptAndQuery(t.id);
          if (info?.hasVideo) {
            videoTabId = t.id;
            hasVideo = true;
            if (!parasiteOpen) parasiteOpen = Boolean(info.parasiteOpen);
            break;
          }
        }
      } catch (_) {}
    }

    if (!videoTabId && streamingTabId) {
      videoTabId = streamingTabId;
      hasVideo = true;
    }

    render();
  }

  let patchWs = null;
  let patchWsConnecting = false;
  let patchWsPortIdx = 0;
  let pendingDesktopPatch = null;

  function pushStatePatchToDesktop(patch) {
    if (!patch || typeof patch !== "object") return;
    pendingDesktopPatch = { ...(pendingDesktopPatch || {}), ...patch };
    if (patchWs && patchWs.readyState === WebSocket.OPEN) {
      const payload = pendingDesktopPatch;
      pendingDesktopPatch = null;
      try {
        patchWs.send(JSON.stringify({ type: "statePatch", patch: payload }));
      } catch (_) {}
      return;
    }
    if (patchWsConnecting) return;
    const tryConnect = () => {
      if (patchWsPortIdx >= GHOST_WS_PORTS.length) {
        patchWsPortIdx = 0;
        patchWsConnecting = false;
        return;
      }
      patchWsConnecting = true;
      let opened = false;
      try {
        const ws = new WebSocket(`ws://127.0.0.1:${GHOST_WS_PORTS[patchWsPortIdx]}`);
        ws.onopen = () => {
          opened = true;
          patchWsConnecting = false;
          patchWsPortIdx = 0;
          patchWs = ws;
          try {
            ws.send(JSON.stringify({ type: "register", role: "popupController" }));
            if (pendingDesktopPatch) {
              const p = pendingDesktopPatch;
              pendingDesktopPatch = null;
              ws.send(JSON.stringify({ type: "statePatch", patch: p }));
            }
          } catch (_) {}
        };
        ws.onclose = () => {
          if (patchWs === ws) patchWs = null;
          patchWsConnecting = false;
          if (!opened) {
            patchWsPortIdx++;
            tryConnect();
          }
        };
        ws.onerror = () => {
          try { ws.close(); } catch (_) {}
        };
      } catch (_) {
        patchWsConnecting = false;
      }
    };
    tryConnect();
  }

  function updateState(patch) {
    state = { ...state, ...patch };
    chrome.storage.local.set({ geckoState: state });
    pushStatePatchToDesktop(patch);
    render();
  }

  function render() {
    if (streamingTabId) {
      els.statusText.textContent = ghostWsConnected
        ? "桌面无边框画中画运行中"
        : "正在唤醒桌面端 ChameleonPiP.app…";
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
    if (els.chkStealthSubtitle) els.chkStealthSubtitle.checked = Boolean(state.stealthSubtitle);
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

    const targetId = videoTabId || activeTabId;
    let alive = await checkGhostAlive(250);
    if (!alive) {
      els.statusText.textContent = "正在唤醒桌面端变色龙客户端…";
      wakeMacGhostApp(hasVideo && targetId ? "wakeup" : "search");
      for (let i = 0; i < 6; i++) {
        await new Promise((r) => setTimeout(r, 250));
        alive = await checkGhostAlive(250);
        if (alive) break;
      }
      ghostWsConnected = alive;
    }

    if (!hasVideo || !targetId) {
      if (alive) wakeMacGhostApp("search");
      els.statusText.textContent = "已打开桌面独立端 · 可直接搜片或打开视频页";
      return;
    }

    // Close in-page parasite if open so there aren't two windows at once!
    if (parasiteOpen) {
      await chrome.tabs.sendMessage(targetId, { type: "GECKO_CLOSE_PIP" }).catch(() => {});
      parasiteOpen = false;
    }

    updateState({ displayTarget: "ghost", bossMode: false });

    const tryDirectFallback = async () => {
      const directRes = await chrome.runtime.sendMessage({
        type: "GECKO_START_DIRECT_FROM_POPUP",
        tabId: targetId,
      });
      if (directRes?.ok) {
        streamingTabId = targetId;
        setTimeout(async () => {
          ghostWsConnected = await checkGhostAlive(400);
          render();
          if (ghostWsConnected) window.close();
        }, 450);
        return true;
      }
      els.statusText.textContent = "未获取到视频流：请确认视频正在播放后重试";
      return false;
    };

    if (targetId !== activeTabId) {
      await tryDirectFallback();
      return;
    }

    chrome.tabCapture.getMediaStreamId({ targetTabId: targetId }, async (streamId) => {
      if (chrome.runtime.lastError || !streamId) {
        await tryDirectFallback();
        return;
      }
      const res = await chrome.runtime.sendMessage({
        type: "GECKO_START_TAB_STREAM",
        tabId: targetId,
        streamId,
      });
      if (res?.ok) {
        streamingTabId = targetId;
        setTimeout(async () => {
          ghostWsConnected = await checkGhostAlive(400);
          render();
          if (ghostWsConnected) window.close();
        }, 550);
      } else {
        await tryDirectFallback();
      }
    });
  });

  // Secondary Action: In-Page Only Floating
  els.btnInPageParasite.addEventListener("click", async () => {
    const targetId = hasVideo && videoTabId ? videoTabId : activeTabId;
    if (!targetId) return;
    if (streamingTabId && !parasiteOpen) {
      await chrome.runtime.sendMessage({ type: "GECKO_STOP_TAB_STREAM" });
      streamingTabId = null;
    }
    await ensureContentScriptAndQuery(targetId);
    if (targetId !== activeTabId) {
      await chrome.tabs.update(targetId, { active: true }).catch(() => {});
    }
    updateState({ displayTarget: "parasite", bossMode: false });
    const res = await chrome.tabs
      .sendMessage(targetId, { type: "GECKO_TOGGLE_PARASITE" })
      .catch(() => null);
    if (res?.ok) {
      parasiteOpen = Boolean(res.open);
      render();
      if (parasiteOpen) window.close();
    } else {
      els.statusText.textContent = "当前页面未检测到可悬浮视频";
    }
  });

  els.btnOpenDesktopSearch?.addEventListener("click", () => {
    wakeMacGhostApp("search");
    setTimeout(() => window.close(), 350);
  });

  els.btnBossToggle.addEventListener("click", () => {
    updateState({ bossMode: !state.bossMode });
  });

  els.chkAutoSense?.addEventListener("change", () => {
    updateState({ autoSense: els.chkAutoSense.checked });
  });

  // All 3 Chameleon visual modes (环境变色 / 迷彩斑纹 / 应激隐身) are 100% FREE forever!
  document.querySelectorAll(".mode-tab").forEach((tab) => {
    tab.addEventListener("click", () => {
      updateState({ mode: tab.dataset.mode });
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
    btn.textContent = "点亮中...";
    const res = await (Stats.claimHonorSupporter || Stats.startFreeTrial)(Stats.loadProfile().userId);
    if (res?.ok && res.entitlement) {
      membership = Stats.saveMembership(res.entitlement);
      syncMembershipToDesktopApp(membership);
      if (msg) msg.textContent = res.message || "感谢支持！已为你点亮榜单 SUP 支持者徽章！";
    } else {
      btn.disabled = false;
      btn.textContent = "一键点亮支持者金标";
      if (msg) msg.textContent = res?.message || "连接服务器失败，请稍后重试。";
    }
    renderMembershipBar();
  });

  document.getElementById("btnPopActivate")?.addEventListener("click", async () => {
    if (!Stats) return;
    const inp = document.getElementById("popKeyInput");
    const msg = document.getElementById("popProMsg");
    const key = inp?.value.trim();
    if (!key) {
      if (msg) msg.textContent = "如有 VIP / MAX 荣誉码，请先粘贴后再点击（所有功能均已免费开放）";
      return;
    }
    const res = await Stats.activateLicenseKey(key, Stats.loadProfile().userId);
    if (res?.ok && res.entitlement) {
      membership = Stats.saveMembership(res.entitlement);
      syncMembershipToDesktopApp(membership);
      if (inp) inp.value = "";
      if (msg) msg.textContent = res.message || "感谢支持！专属鎏金徽章已点亮。";
    } else if (msg) {
      msg.textContent = res?.message || "荣誉码无效，请检查后重试。";
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

  els.chkStealthSubtitle?.addEventListener("change", () => {
    const on = els.chkStealthSubtitle.checked;
    updateState({ stealthSubtitle: on, mirrorSubtitles: on ? true : state.mirrorSubtitles });
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
    return streamingTabId || videoTabId || activeTabId;
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

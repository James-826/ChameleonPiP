/**
 * ChameleonPiP Content Script v5.5
 * - Full two-way PiP player state & controls sync (Play/Pause, Progress Seek, -10s/+10s, Mute, Speed)
 * - Apple/Arc-grade Glass Borderless PiP Player HUD with Biomimetic Chameleon Camouflage Slider
 */
(function () {
  "use strict";

  // Clean up any stale DOM hosts from a previous extension reload in chrome://extensions
  for (const staleId of [
    "gecko-pip-hover-host",
    "gecko-parasite-host",
    "gecko-topbar-host",
    "gecko-stream-bridge-frame",
  ]) {
    const old = document.getElementById(staleId);
    if (old) old.remove();
  }
  window.__GECKO_PIP_CLEANUP__?.();

  const Core = window.GeckoCore;
  if (!Core) return;

  let state = { ...Core.DEFAULT_STATE };
  let activeVideo = null;
  let videoRestoreInfo = null;
  let isHoveringStage = false;
  let isTyping = false;
  let typingTimer = null;
  let wasPlayingBeforeBoss = false;
  let uiSyncTimer = null;

  let hoverHost = null;
  let hoverCandidateVideo = null;
  let hideHoverTimer = null;

  let parasiteHost = null;
  let parasiteOpen = false;
  let parasiteClickThrough = false;
  let parasiteStreamPort = null;
  let parasiteUsingCrossTab = false;
  let autoSenseTimer = null;

  function loadState() {
    if (!chrome?.storage?.local) return;
    chrome.storage.local.get(["geckoState"], (res) => {
      if (res?.geckoState) {
        state = { ...Core.DEFAULT_STATE, ...res.geckoState };
        applyStateToParasite();
      }
    });
  }

  function saveState(patch, persist = true) {
    const prevBoss = state.bossMode;
    state = { ...state, ...patch };
    if (prevBoss !== state.bossMode) {
      handleBossModeTransition(state.bossMode);
    }
    applyStateToParasite();
    if (persist && chrome?.storage?.local) {
      chrome.storage.local.set({ geckoState: state });
    }
  }

  if (chrome?.storage?.onChanged) {
    chrome.storage.onChanged.addListener((changes, area) => {
      if (area === "local" && changes.geckoState?.newValue) {
        const prevState = state;
        const prevBoss = state.bossMode;
        state = { ...Core.DEFAULT_STATE, ...changes.geckoState.newValue };
        if (prevBoss !== state.bossMode) {
          handleBossModeTransition(state.bossMode);
        }
        applyStateToParasite();
        if (directStreamActive && directBridgeReady && directBridgeFrame?.contentWindow) {
          const diff = {};
          for (const k of ["mode", "stealth", "feather", "bossMode", "mirrorSubtitles", "stealthSubtitle", "hoverReveal"]) {
            if (state[k] !== prevState[k]) diff[k] = state[k];
          }
          if (Object.keys(diff).length > 0) {
            try {
              directBridgeFrame.contentWindow.postMessage(
                { type: "GECKO_BRIDGE_STATE_PATCH", patch: diff },
                directBridgeOrigin
              );
            } catch (_) {}
          }
        }
      }
    });
  }
  loadState();

  function wakeMacGhostViaScheme() {
    const iframe = document.createElement("iframe");
    iframe.style.display = "none";
    iframe.src = "chameleonpip://wakeup";
    document.documentElement.appendChild(iframe);
    setTimeout(() => iframe.remove(), 1500);
  }

  function showToast(text) {
    const toast = document.createElement("div");
    toast.style.cssText =
      "position:fixed;top:18px;left:50%;transform:translateX(-50%);z-index:2147483647;padding:9px 16px;border-radius:999px;background:rgba(12,18,26,0.92);backdrop-filter:blur(12px);border:1px solid rgba(52,211,153,0.5);color:#f1f5f9;font:500 12.5px -apple-system,BlinkMacSystemFont,'PingFang SC',sans-serif;box-shadow:0 10px 30px rgba(0,0,0,0.45);pointer-events:none;transition:opacity 0.25s ease;";
    toast.textContent = text;
    document.documentElement.appendChild(toast);
    setTimeout(() => {
      toast.style.opacity = "0";
      setTimeout(() => toast.remove(), 300);
    }, 3400);
  }

  function onGeckoKeyDown(e) {
    if (e.ctrlKey && e.shiftKey && !e.metaKey && !e.altKey) {
      if (e.code === "KeyB" && parasiteOpen) {
        e.preventDefault();
        saveState({ bossMode: !state.bossMode });
        return;
      }
      if (e.code === "KeyM" && parasiteOpen) {
        e.preventDefault();
        parasiteClickThrough = !parasiteClickThrough;
        showToast(
          parasiteClickThrough
            ? "已开启鼠标穿透 · 再按 Control+Shift+M 恢复播放器控制"
            : "已恢复鼠标控制"
        );
        applyStateToParasite();
        return;
      }
    }

    if (!e.ctrlKey && !e.metaKey && !e.altKey && (state.typingLurk || state.mode === "cinema" || state.mode === "projector")) {
      if (!isTyping) {
        isTyping = true;
        applyStateToParasite();
      }
      clearTimeout(typingTimer);
      typingTimer = setTimeout(() => {
        isTyping = false;
        applyStateToParasite();
      }, 1400);
    }
  }
  window.addEventListener("keydown", onGeckoKeyDown, true);

  // ---------------------------------------------------------------------------
  // Video Discovery & Full Player Telemetry
  // ---------------------------------------------------------------------------
  function collectAllVideos() {
    const videos = Array.from(document.querySelectorAll("video"));
    for (const frame of document.querySelectorAll("iframe")) {
      try {
        if (frame.contentDocument) {
          videos.push(...frame.contentDocument.querySelectorAll("video"));
        }
      } catch (_) {}
    }
    return videos;
  }

  function scoreVideo(v) {
    if (!v || !v.isConnected) return -1;
    if (parasiteHost && parasiteHost.shadowRoot?.contains(v) && v !== activeVideo) return -1;
    const rect = v.getBoundingClientRect();
    const area = Math.max(0, rect.width) * Math.max(0, rect.height);
    if (area < 5000 && v !== activeVideo) return -1;

    let score = area / 1000;
    if (!v.paused && !v.ended) score += 5000;
    if (v.readyState >= 2) score += 1200;
    if (v.currentTime > 0) score += 600;
    if (rect.bottom > 0 && rect.top < window.innerHeight) score += 1500;
    return score;
  }

  function findBestVideo() {
    if (activeVideo && activeVideo.isConnected) return activeVideo;
    let best = null;
    let bestScore = -1;
    // Fast-path: check top-document <video> elements first to avoid costly iframe queries
    for (const v of document.querySelectorAll("video")) {
      const s = scoreVideo(v);
      if (s > bestScore) {
        bestScore = s;
        best = v;
      }
    }
    if (best && bestScore >= 1200) return best;

    for (const v of collectAllVideos()) {
      const s = scoreVideo(v);
      if (s > bestScore) {
        bestScore = s;
        best = v;
      }
    }
    return best;
  }

  function getNormalizedVideoCrop() {
    const v = findBestVideo();
    if (!v) return null;
    const r = v.getBoundingClientRect();
    const vw = Math.max(1, window.innerWidth);
    const vh = Math.max(1, window.innerHeight);

    const vidRatio = (v.videoWidth || 16) / Math.max(1, v.videoHeight || 9);
    const boxRatio = r.width / Math.max(1, r.height);
    let contentLeft = r.left;
    let contentTop = r.top;
    let contentW = r.width;
    let contentH = r.height;

    const fit = window.getComputedStyle(v).objectFit;
    if (fit === "contain" || fit === "" || fit === "scale-down") {
      if (boxRatio > vidRatio) {
        contentW = r.height * vidRatio;
        contentLeft = r.left + (r.width - contentW) / 2;
      } else {
        contentH = r.width / vidRatio;
        contentTop = r.top + (r.height - contentH) / 2;
      }
    }

    return {
      nx: Core.clamp(contentLeft / vw, 0, 0.98),
      ny: Core.clamp(contentTop / vh, 0, 0.98),
      nw: Core.clamp(contentW / vw, 0.05, 1),
      nh: Core.clamp(contentH / vh, 0.05, 1),
      aspect: vidRatio,
      subtitle: readHostSubtitles(v),
      player: {
        paused: v.paused,
        ended: Boolean(v.ended),
        readyState: v.readyState || 0,
        currentTime: v.currentTime || 0,
        duration: Number.isFinite(v.duration) ? v.duration : 0,
        muted: v.muted || v.volume === 0,
        volume: v.volume,
        playbackRate: v.playbackRate || 1,
      },
    };
  }

  const seenDanmaku = [];
  const seenDanmakuSet = new Set();
  let lastDanmakuText = "";
  let lastDanmakuAt = 0;

  function readHostSubtitles(targetVid) {
    const selectors = [
      ".bpx-player-subtitle-panel-text",
      ".bili-subtitle-x-subtitle-panel-text",
      ".bilibili-player-video-subtitle .subtitle-item-text",
      ".ytp-caption-segment",
      ".txp_subtitle_text",
      ".iqp-subtitle-text",
      ".xg-text-track-span",
    ];
    for (const sel of selectors) {
      const nodes = document.querySelectorAll(sel);
      if (nodes.length > 0) {
        const text = Array.from(nodes)
          .map((n) => n.textContent.trim())
          .filter(Boolean)
          .join(" ");
        if (text) return text;
      }
    }
    const v = targetVid || activeVideo;
    if (v?.textTracks) {
      if (state.stealthSubtitle) {
        let hasActiveTrack = false;
        for (const track of v.textTracks) {
          if (track.mode === "showing" || track.mode === "hidden") {
            hasActiveTrack = true;
            break;
          }
        }
        if (!hasActiveTrack) {
          for (const track of v.textTracks) {
            if (track.kind === "subtitles" || track.kind === "captions") {
              try {
                track.mode = "hidden";
              } catch (_) {}
              break;
            }
          }
        }
      }
      for (const track of v.textTracks) {
        if ((track.mode === "showing" || track.mode === "hidden") && track.activeCues?.length) {
          return Array.from(track.activeCues)
            .map((c) => c.text || "")
            .join(" ")
            .replace(/<[^>]+>/g, "")
            .trim();
        }
      }
    }
    if (state.stealthSubtitle) {
      const now = performance.now();
      const dmNodes = document.querySelectorAll(
        ".bpx-player-row-dm-wrap .bili-danmaku-x-dm, .bilibili-player-video-danmaku .b-danmaku, .xgplayer-danmu div"
      );
      if (dmNodes.length > 0 && now - lastDanmakuAt < 1100 && lastDanmakuText) {
        return lastDanmakuText;
      }
      const picked = [];
      for (const dn of dmNodes) {
        const txt = (dn.textContent || "").replace(/\s+/g, " ").trim();
        if (txt.length >= 2 && txt.length <= 60 && !seenDanmakuSet.has(txt)) {
          seenDanmakuSet.add(txt);
          seenDanmaku.push(txt);
          if (seenDanmaku.length > 80) {
            const old = seenDanmaku.shift();
            seenDanmakuSet.delete(old);
          }
          picked.push(txt);
          if (picked.length >= 2) break;
        }
      }
      if (picked.length > 0) {
        lastDanmakuText = picked.join("  //  ");
        lastDanmakuAt = now;
        return lastDanmakuText;
      }
      if (now - lastDanmakuAt < 3200 && lastDanmakuText) {
        return lastDanmakuText;
      }
    }
    return "";
  }

  // ---------------------------------------------------------------------------
  // Refined On-Video Launch Pill
  // ---------------------------------------------------------------------------
  function ensureHoverBadge() {
    if (hoverHost) return;
    hoverHost = document.createElement("div");
    hoverHost.id = "gecko-pip-hover-host";
    hoverHost.style.cssText =
      "position:fixed;top:0;left:0;width:0;height:0;z-index:2147483646;pointer-events:none;";
    const shadow = hoverHost.attachShadow({ mode: "open" });
    shadow.innerHTML = `
      <style>
        .bar {
          position: fixed;
          display: inline-flex;
          align-items: center;
          gap: 3px;
          padding: 4px;
          border-radius: 999px;
          border: 1px solid rgba(255, 255, 255, 0.16);
          background: rgba(12, 17, 24, 0.84);
          backdrop-filter: blur(12px);
          -webkit-backdrop-filter: blur(12px);
          opacity: 0;
          transform: translateY(-3px);
          transition: opacity 0.18s ease, transform 0.18s ease;
          pointer-events: auto;
          box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
          font: 600 11.5px/1 -apple-system, BlinkMacSystemFont, "PingFang SC", sans-serif;
        }
        .bar.visible { opacity: 1; transform: translateY(0); }
        button {
          appearance: none;
          border: none;
          border-radius: 999px;
          padding: 5px 10px;
          background: transparent;
          color: #e2e8f0;
          font: inherit;
          cursor: pointer;
          display: inline-flex;
          align-items: center;
          gap: 6px;
          transition: background 0.14s ease, color 0.14s ease;
        }
        button:hover { background: rgba(255, 255, 255, 0.12); color: #fff; }
        .dot { width: 7px; height: 7px; border-radius: 50%; background: #34d399; box-shadow: 0 0 8px #34d399; }
        .sep { width: 1px; height: 12px; background: rgba(255,255,255,0.14); }
      </style>
      <div class="bar" id="hoverBar">
        <button type="button" id="btnDesktopGhost" title="开启桌面无边框变色龙小窗">
          <span class="dot"></span><span>桌面变色龙小窗</span>
        </button>
        <span class="sep"></span>
        <button type="button" id="btnPageFloat" title="在当前网页内开启无边框变色龙小窗">
          页内小窗
        </button>
      </div>
    `;
    const bar = shadow.getElementById("hoverBar");
    const btnDesktop = shadow.getElementById("btnDesktopGhost");
    const desktopLabel = btnDesktop.querySelector("span:last-child");
    btnDesktop.addEventListener("click", (e) => {
      e.preventDefault();
      e.stopPropagation();
      bar.classList.remove("visible");

      if (!chrome?.runtime?.id) {
        showToast("扩展刚更新重载，请刷新一下当前网页即可恢复");
        return;
      }

      if (directStreamActive) {
        chrome.runtime.sendMessage({ type: "GECKO_STOP_TAB_STREAM" }).catch(() => {});
        stopDirectVideoStream(false, true);
        if (desktopLabel) desktopLabel.textContent = "桌面变色龙小窗";
        showToast("已停止桌面变色龙小窗投送");
        return;
      }

      if (parasiteOpen) {
        closeParasiteOverlay();
      }
      saveState({ displayTarget: "ghost", bossMode: false });

      const targetVid = hoverCandidateVideo || findBestVideo();
      const res = startDirectVideoStream(targetVid, { directOnly: true });
      if (!res?.ok) {
        wakeMacGhostViaScheme();
        showToast("当前视频源需浏览器授权 · 请按 Control+Shift+G 开启桌面画中画");
        return;
      }

      chrome.runtime.sendMessage({ type: "GECKO_REGISTER_DIRECT_PAGE_STREAM" }).catch(() => {});
      if (desktopLabel) desktopLabel.textContent = "停止桌面投送";
      setTimeout(() => {
        if (directStreamActive && !directBridgeReady) {
          wakeMacGhostViaScheme();
        }
      }, 350);
      showToast("已一键投送至 Mac 桌面无边框画中画");
    });
    shadow.getElementById("btnPageFloat").addEventListener("click", (e) => {
      e.preventDefault();
      e.stopPropagation();
      bar.classList.remove("visible");
      openParasiteOverlay({ video: hoverCandidateVideo || findBestVideo() });
    });
    document.documentElement.appendChild(hoverHost);
  }

  function refreshHoverButtonLabel() {
    const lbl = hoverHost?.shadowRoot?.querySelector("#btnDesktopGhost span:last-child");
    if (lbl) {
      lbl.textContent = directStreamActive ? "停止桌面投送" : "桌面变色龙小窗";
    }
  }

  function hideHoverBadge() {
    hoverHost?.shadowRoot?.getElementById("hoverBar")?.classList.remove("visible");
  }

  function onHoverMouseMove(e) {
    if (parasiteOpen) return;
    let matched = null;
    for (const v of collectAllVideos()) {
      if (v.ownerDocument !== document) continue;
      const r = v.getBoundingClientRect();
      if (
        r.width >= 200 &&
        r.height >= 120 &&
        e.clientX >= r.left &&
        e.clientX <= r.right &&
        e.clientY >= r.top &&
        e.clientY <= r.bottom
      ) {
        matched = { video: v, rect: r };
        break;
      }
    }
    if (!matched) {
      if (hoverHost && e.composedPath?.().includes(hoverHost)) return;
      hideHoverBadge();
      return;
    }
    ensureHoverBadge();
    refreshHoverButtonLabel();
    hoverCandidateVideo = matched.video;
    const bar = hoverHost.shadowRoot.getElementById("hoverBar");
    bar.style.top = `${Math.max(10, matched.rect.top + 12)}px`;
    bar.style.left = `${Math.max(10, matched.rect.right - 210)}px`;
    bar.classList.add("visible");
    clearTimeout(hideHoverTimer);
    hideHoverTimer = setTimeout(hideHoverBadge, 2400);
  }
  window.addEventListener("mousemove", onHoverMouseMove, { passive: true });

  // ---------------------------------------------------------------------------
  // Apple/Arc-Grade Glass Borderless PiP Player (In-Page & Cross-Tab)
  // ---------------------------------------------------------------------------
  async function toggleParasiteOverlay() {
    if (parasiteOpen) {
      closeParasiteOverlay();
      return { ok: true, open: false };
    }
    return await openParasiteOverlay({});
  }

  async function openParasiteOverlay({ video } = {}) {
    closeParasiteOverlay();
    const localVideo = video || findBestVideo();
    let useCrossTab = false;

    if (!localVideo) {
      try {
        const bgStatus = await chrome.runtime.sendMessage({
          type: "GECKO_GET_STATUS_SUMMARY",
        });
        if (bgStatus?.streamingTabId) useCrossTab = true;
        else return { ok: false, reason: "no_video" };
      } catch (_) {
        return { ok: false, reason: "no_video" };
      }
    }

    parasiteOpen = true;
    parasiteUsingCrossTab = useCrossTab;
    parasiteClickThrough = false;
    hideHoverBadge();

    parasiteHost = document.createElement("div");
    parasiteHost.id = "gecko-parasite-host";
    parasiteHost.style.cssText =
      "position:fixed;right:24px;bottom:24px;width:380px;height:214px;z-index:2147483645;background:transparent;border:none;box-shadow:none;";

    const shadow = parasiteHost.attachShadow({ mode: "open" });
    shadow.innerHTML = `
      <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        .p-root {
          position: relative;
          width: 100%;
          height: 100%;
          background: transparent !important;
          overflow: hidden;
          user-select: none;
          border-radius: 12px;
          font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "PingFang SC", sans-serif;
        }
        .p-root.hovered:not(.boss-active):not(.click-through) {
          box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.16);
        }
        .p-stage {
          position: relative;
          width: 100%;
          height: 100%;
          display: flex;
          align-items: center;
          justify-content: center;
          cursor: grab;
        }
        .p-media {
          display: block !important;
          visibility: visible !important;
          position: relative !important;
          inset: 0 !important;
          transform: none !important;
          width: 100% !important;
          height: 100% !important;
          object-fit: cover !important;
          background: transparent !important;
          pointer-events: none !important;
          transition: opacity 0.15s ease;
        }
        .p-subtitle {
          position: absolute;
          bottom: 12px;
          left: 8%;
          right: 8%;
          text-align: center;
          font-size: 12px;
          font-weight: 600;
          line-height: 1.35;
          pointer-events: none;
          transition: bottom 0.18s ease;
          text-shadow: 0 1px 3px rgba(0,0,0,0.28);
        }
        .p-subtitle.stealth-log {
          bottom: 8px;
          left: 8px;
          right: 8px;
          text-align: left;
          font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, monospace;
          font-size: 10.5px;
          font-weight: 500;
          line-height: 1.4;
          padding: 4px 8px;
          border-radius: 6px;
          background: rgba(13, 17, 23, 0.86);
          border: 1px solid rgba(52, 211, 153, 0.24);
          color: #c9d1d9;
          text-shadow: none;
          white-space: pre-wrap;
          word-break: break-word;
          max-height: 54px;
          overflow: hidden;
        }
        .p-subtitle.stealth-log.light-bg {
          background: rgba(248, 250, 252, 0.9);
          border-color: rgba(15, 23, 42, 0.16);
          color: #1e293b;
        }
        .p-root.hovered:not(.click-through) .p-subtitle { bottom: 60px; }

        .hud-top {
          position: absolute;
          top: 0; left: 0; right: 0; height: 42px;
          padding: 7px 9px;
          display: flex; align-items: center; justify-content: space-between;
          background: linear-gradient(to bottom, rgba(8,12,18,0.78) 0%, rgba(8,12,18,0.3) 70%, transparent 100%);
          opacity: 0; pointer-events: none; transition: opacity 0.16s ease; z-index: 10;
        }
        .hud-bottom {
          position: absolute;
          bottom: 0; left: 0; right: 0;
          padding: 9px 11px 8px;
          display: flex; flex-direction: column; gap: 5px;
          background: linear-gradient(to top, rgba(8,12,18,0.86) 0%, rgba(8,12,18,0.45) 72%, transparent 100%);
          opacity: 0; pointer-events: none; transition: opacity 0.16s ease; z-index: 10;
        }
        .p-root.hovered:not(.click-through):not(.boss-active) .hud-top,
        .p-root.hovered:not(.click-through):not(.boss-active) .hud-bottom {
          opacity: 1; pointer-events: auto;
        }

        .pill-group {
          display: inline-flex; background: rgba(18,24,34,0.72);
          backdrop-filter: blur(12px); border: 1px solid rgba(255,255,255,0.12);
          border-radius: 7px; padding: 2px; gap: 1px;
        }
        .seg-btn {
          appearance: none; border: none; background: transparent;
          color: rgba(226,232,240,0.78); font-size: 11px; font-weight: 500;
          padding: 3px 8px; border-radius: 5px; cursor: pointer;
        }
        .seg-btn.active { background: rgba(255,255,255,0.16); color: #fff; font-weight: 600; }

        .icon-btn {
          appearance: none; border: 1px solid rgba(255,255,255,0.12);
          background: rgba(18,24,34,0.68); backdrop-filter: blur(12px);
          color: #e2e8f0; width: 25px; height: 25px; border-radius: 7px;
          display: inline-flex; align-items: center; justify-content: center; cursor: pointer;
        }
        .icon-btn:hover { background: rgba(255,255,255,0.18); color: #fff; }

        .progress-row { display: flex; align-items: center; gap: 8px; }
        .progress-track { flex: 1; height: 12px; display: flex; align-items: center; cursor: pointer; }
        .progress-bg { width: 100%; height: 3.5px; border-radius: 999px; background: rgba(255,255,255,0.22); overflow: hidden; }
        .progress-track:hover .progress-bg { height: 5.5px; }
        .progress-fill { height: 100%; width: 0%; background: #34d399; border-radius: 999px; }
        .time-lbl { font-size: 10.5px; font-variant-numeric: tabular-nums; color: rgba(226,232,240,0.85); }

        .ctrl-row { display: flex; align-items: center; justify-content: space-between; gap: 6px; }
        .ctrl-left { display: flex; align-items: center; gap: 3px; }
        .mini-ctrl {
          appearance: none; border: none; background: transparent; color: #f1f5f9;
          width: 25px; height: 23px; border-radius: 5px;
          display: inline-flex; align-items: center; justify-content: center; cursor: pointer;
        }
        .mini-ctrl:hover { background: rgba(255,255,255,0.15); }
        .rate-btn {
          appearance: none; border: 1px solid rgba(255,255,255,0.16);
          background: rgba(255,255,255,0.08); color: #e2e8f0;
          border-radius: 5px; padding: 2px 6px; font-size: 10px; font-weight: 600; cursor: pointer;
        }
        .gecko-pill {
          display: inline-flex; align-items: center; gap: 5px;
          background: rgba(18,24,34,0.72); border: 1px solid rgba(52,211,153,0.32);
          border-radius: 999px; padding: 2px 8px; font-size: 10.5px; color: #d1fae5;
        }
        .gecko-pill input[type="range"] { width: 66px; height: 3.5px; accent-color: #34d399; cursor: pointer; }
        .gecko-pct { min-width: 26px; text-align: right; font-weight: 600; color: #6ee7b7; font-variant-numeric: tabular-nums; }

        /* 8-Direction Direct Resize Handles (with visible 4-corner brackets on hover!) */
        .rz { position: absolute; z-index: 55; }
        .rz-n  { top: 0; left: 24px; right: 24px; height: 12px; cursor: ns-resize; }
        .rz-s  { bottom: 0; left: 24px; right: 24px; height: 12px; cursor: ns-resize; }
        .rz-e  { right: 0; top: 24px; bottom: 24px; width: 12px; cursor: ew-resize; }
        .rz-w  { left: 0; top: 24px; bottom: 24px; width: 12px; cursor: ew-resize; }
        .rz-nw, .rz-ne, .rz-sw, .rz-se {
          width: 24px; height: 24px; z-index: 60;
          opacity: 0; transition: opacity 0.15s ease;
        }
        .rz-nw { top: 0; left: 0; cursor: nwse-resize; border-top: 2.5px solid rgba(52,211,153,0.9); border-left: 2.5px solid rgba(52,211,153,0.9); border-top-left-radius: 11px; }
        .rz-ne { top: 0; right: 0; cursor: nesw-resize; border-top: 2.5px solid rgba(52,211,153,0.9); border-right: 2.5px solid rgba(52,211,153,0.9); border-top-right-radius: 11px; }
        .rz-sw { bottom: 0; left: 0; cursor: nesw-resize; border-bottom: 2.5px solid rgba(52,211,153,0.9); border-left: 2.5px solid rgba(52,211,153,0.9); border-bottom-left-radius: 11px; }
        .rz-se {
          right: 0; bottom: 0;
          cursor: nwse-resize; color: rgba(110,231,183,0.95);
          border-bottom: 2.5px solid rgba(52,211,153,0.9); border-right: 2.5px solid rgba(52,211,153,0.9); border-bottom-right-radius: 11px;
          display: flex; align-items: flex-end; justify-content: flex-end; padding: 3px;
        }
        .p-root.hovered:not(.click-through):not(.boss-active) .rz-nw,
        .p-root.hovered:not(.click-through):not(.boss-active) .rz-ne,
        .p-root.hovered:not(.click-through):not(.boss-active) .rz-sw,
        .p-root.hovered:not(.click-through):not(.boss-active) .rz-se { opacity: 1; }

        .p-root.boss-active .p-stage { opacity: 0 !important; pointer-events: none !important; }
        .boss-recover {
          position: absolute; top: 50%; left: 50%; transform: translate(-50%,-50%);
          display: none; padding: 6px 12px; border-radius: 999px;
          background: rgba(15,23,32,0.9); border: 1px solid rgba(251,191,36,0.5);
          color: #fde68a; font-size: 11px; font-weight: 600; cursor: pointer; z-index: 30; white-space: nowrap;
        }
        .p-root.boss-active.hovered .boss-recover { display: inline-flex; }
      </style>
      <style id="parasiteFeatherStyle"></style>

      <div class="p-root" id="pRoot">
        <svg style="position:absolute;width:0;height:0;pointer-events:none" xmlns="http://www.w3.org/2000/svg">
          <defs id="pSvgDefs"></defs>
        </svg>

        <div class="p-stage" id="pStage">
          <div id="pMediaSlot" style="width:100%;height:100%;display:flex;align-items:center;justify-content:center"></div>
          <div class="p-subtitle" id="pSub"></div>
        </div>

        <div class="hud-top" style="z-index:65;padding-top:10px">
          <div class="pill-group">
            <button class="seg-btn" data-mode="projector">拟态</button>
            <button class="seg-btn" data-mode="emboss">浮雕</button>
            <button class="seg-btn" data-mode="cinema">彩透</button>
          </div>
          <div style="display:flex;gap:4px">
            <button class="icon-btn" data-size="260" style="width:auto;padding:0 6px;font-size:10px" title="小窗">S</button>
            <button class="icon-btn" data-size="392" style="width:auto;padding:0 6px;font-size:10px" title="标准">M</button>
            <button class="icon-btn" data-size="520" style="width:auto;padding:0 6px;font-size:10px" title="大窗">L</button>
            <button class="icon-btn" id="pBtnThrough" style="width:auto;padding:0 6px;gap:3px;font-size:10px" title="开启鼠标穿透（按 ⌃⇧M 恢复）">${Core.ICONS.cursorThrough}<span>穿透</span></button>
            <button class="icon-btn" id="pBtnBoss" title="老板键隐藏 (⌃⇧B)">${Core.ICONS.eyeHide}</button>
            <button class="icon-btn" id="pBtnClose" title="关闭并收回原视频">${Core.ICONS.close}</button>
          </div>
        </div>

        <div class="hud-bottom">
          <div class="progress-row">
            <div class="progress-track" id="pTrack">
              <div class="progress-bg"><div class="progress-fill" id="pFill"></div></div>
            </div>
            <span class="time-lbl" id="pTime">00:00 / 00:00</span>
          </div>
          <div class="ctrl-row">
            <div class="ctrl-left">
              <button class="mini-ctrl" id="pBtnPlay">${Core.ICONS.pause}</button>
              <button class="mini-ctrl" id="pBtnBack">${Core.ICONS.back10}</button>
              <button class="mini-ctrl" id="pBtnFwd">${Core.ICONS.fwd10}</button>
              <button class="mini-ctrl" id="pBtnMute">${Core.ICONS.volOn}</button>
              <button class="rate-btn" id="pBtnRate">1.0x</button>
            </div>
            <label class="gecko-pill">
              <span>浓度</span>
              <input type="range" id="pRngStealth" min="10" max="95" value="58" />
              <span class="gecko-pct" id="pLblStealth">58%</span>
            </label>
          </div>
        </div>

        <div class="rz rz-n" data-dir="n"></div>
        <div class="rz rz-s" data-dir="s"></div>
        <div class="rz rz-e" data-dir="e"></div>
        <div class="rz rz-w" data-dir="w"></div>
        <div class="rz rz-nw" data-dir="nw"></div>
        <div class="rz rz-ne" data-dir="ne"></div>
        <div class="rz rz-sw" data-dir="sw"></div>
        <div class="rz rz-se" data-dir="se" title="按住任意边角自由缩放窗口大小">${Core.ICONS.resizeGrip}</div>
        <button class="boss-recover" id="pBtnRecover">已隐藏并暂停 · 点击恢复播放</button>
      </div>
    `;

    const pRoot = shadow.getElementById("pRoot");
    const mediaSlot = shadow.getElementById("pMediaSlot");

    if (!useCrossTab && localVideo) {
      activeVideo = localVideo;
      const placeholder = document.createElement("div");
      placeholder.className = "gecko-pip-placeholder";
      placeholder.innerHTML = `
        <div class="gecko-pip-placeholder-badge">视频正在右下角无边框变色龙小窗播放中</div>
        <button type="button" class="gecko-pip-placeholder-btn">收回视频原位</button>
      `;
      placeholder
        .querySelector(".gecko-pip-placeholder-btn")
        .addEventListener("click", () => closeParasiteOverlay());

      const wasPlaying = !localVideo.paused && !localVideo.ended;
      videoRestoreInfo = {
        video: localVideo,
        parent: localVideo.parentNode,
        placeholder,
        cssText: localVideo.style.cssText,
        hadControls: localVideo.hasAttribute("controls"),
        hadClass: localVideo.className,
      };

      localVideo.parentNode?.insertBefore(placeholder, localVideo);
      localVideo.removeAttribute("controls");
      localVideo.classList.add("p-media");
      mediaSlot.appendChild(localVideo);
      if (wasPlaying && !state.bossMode) localVideo.play().catch(() => {});
    } else {
      const streamCanvas = document.createElement("canvas");
      streamCanvas.className = "p-media";
      streamCanvas.width = 448;
      streamCanvas.height = 252;
      const streamCtx = streamCanvas.getContext("2d", { alpha: false, desynchronized: true });
      mediaSlot.appendChild(streamCanvas);

      let pendingFrameUrl = null;
      let decodingFrame = false;
      const consumeNextFrame = () => {
        if (decodingFrame || !pendingFrameUrl || !parasiteOpen) return;
        const url = pendingFrameUrl;
        pendingFrameUrl = null;
        decodingFrame = true;
        fetch(url)
          .then((r) => r.blob())
          .then((b) => createImageBitmap(b))
          .then((bmp) => {
            decodingFrame = false;
            if (!parasiteOpen) {
              bmp.close();
              return;
            }
            if (streamCanvas.width !== bmp.width || streamCanvas.height !== bmp.height) {
              streamCanvas.width = bmp.width;
              streamCanvas.height = bmp.height;
            }
            streamCtx?.drawImage(bmp, 0, 0);
            bmp.close();
            if (pendingFrameUrl) consumeNextFrame();
          })
          .catch(() => {
            decodingFrame = false;
            if (pendingFrameUrl) consumeNextFrame();
          });
      };

      parasiteStreamPort = chrome.runtime.connect({ name: "gecko-parasite-viewer" });
      parasiteStreamPort.onMessage.addListener((msg) => {
        if (msg.type === "GECKO_FRAME" && msg.dataUrl) {
          pendingFrameUrl = msg.dataUrl;
          consumeNextFrame();
          renderParasiteSubtitle(shadow.getElementById("pSub"), state.mirrorSubtitles ? msg.subtitle || "" : "");
        } else if (msg.type === "GECKO_STREAM_ENDED") {
          closeParasiteOverlay();
        }
      });
    }

    document.documentElement.appendChild(parasiteHost);

    parasiteHost.addEventListener("mouseenter", () => {
      if (!state.hoverReveal && !state.bossMode) return;
      isHoveringStage = true;
      pRoot.classList.add("hovered");
    });
    parasiteHost.addEventListener("mouseleave", () => {
      isHoveringStage = false;
      pRoot.classList.remove("hovered");
    });

    // Drag (with 4px threshold so single click toggles Play/Pause!) & 8-Direction Resize
    let drag = null;
    let resize = null;
    shadow.getElementById("pStage").addEventListener("mousedown", (e) => {
      if (parasiteClickThrough) return;
      const r = parasiteHost.getBoundingClientRect();
      drag = { dx: e.clientX - r.left, dy: e.clientY - r.top, sx: e.clientX, sy: e.clientY, moved: false };
    });

    shadow.querySelectorAll(".rz").forEach((h) => {
      h.addEventListener("mousedown", (e) => {
        e.stopPropagation();
        e.preventDefault();
        const r = parasiteHost.getBoundingClientRect();
        resize = {
          dir: h.dataset.dir,
          sx: e.clientX,
          sy: e.clientY,
          left: r.left,
          top: r.top,
          w: r.width,
          h: r.height,
        };
      });
    });

    shadow.querySelectorAll("[data-size]").forEach((b) => {
      b.addEventListener("click", (e) => {
        e.stopPropagation();
        const nw = Number(b.dataset.size);
        const nh = Math.round((nw * 9) / 16);
        parasiteHost.style.width = `${nw}px`;
        parasiteHost.style.height = `${nh}px`;
        runDomAutoSenseOnce();
      });
    });

    const onMove = (e) => {
      if (resize) {
        const dx = e.clientX - resize.sx;
        const dy = e.clientY - resize.sy;
        let nl = resize.left, nt = resize.top, nw = resize.w, nh = resize.h;
        if (resize.dir.includes("e")) nw = Core.clamp(resize.w + dx, 200, window.innerWidth - resize.left - 8);
        if (resize.dir.includes("s")) nh = Core.clamp(resize.h + dy, 115, window.innerHeight - resize.top - 8);
        if (resize.dir.includes("w")) {
          const d = Core.clamp(dx, -resize.left + 8, resize.w - 200);
          nl = resize.left + d;
          nw = resize.w - d;
        }
        if (resize.dir.includes("n")) {
          const d = Core.clamp(dy, -resize.top + 8, resize.h - 115);
          nt = resize.top + d;
          nh = resize.h - d;
        }
        parasiteHost.style.left = `${nl}px`;
        parasiteHost.style.top = `${nt}px`;
        parasiteHost.style.right = "auto";
        parasiteHost.style.bottom = "auto";
        parasiteHost.style.width = `${nw}px`;
        parasiteHost.style.height = `${nh}px`;
        return;
      }
      if (drag) {
        if (!drag.moved && Math.hypot(e.clientX - drag.sx, e.clientY - drag.sy) > 4) {
          drag.moved = true;
        }
        if (drag.moved) {
          const left = Core.clamp(e.clientX - drag.dx, 0, window.innerWidth - 140);
          const top = Core.clamp(e.clientY - drag.dy, 0, window.innerHeight - 90);
          parasiteHost.style.left = `${left}px`;
          parasiteHost.style.top = `${top}px`;
          parasiteHost.style.right = "auto";
          parasiteHost.style.bottom = "auto";
          runDomAutoSenseOnce();
        }
      }
    };
    const onUp = () => {
      if (resize) runDomAutoSenseOnce();
      if (drag && !drag.moved && activeVideo) {
        if (activeVideo.paused) activeVideo.play().catch(() => {});
        else activeVideo.pause();
      }
      drag = null;
      resize = null;
    };
    window.addEventListener("mousemove", onMove);
    window.addEventListener("mouseup", onUp);
    parasiteHost._cleanup = () => {
      window.removeEventListener("mousemove", onMove);
      window.removeEventListener("mouseup", onUp);
    };

    // Player controls wiring
    const execLocalOrRemote = (action, extra = {}) => {
      if (activeVideo) {
        execCmdOnVideo(activeVideo, { action, ...extra });
        syncPlayerUi();
      } else if (parasiteStreamPort) {
        parasiteStreamPort.postMessage({ type: "GECKO_VIEWER_CMD", action, ...extra });
      }
    };

    shadow.getElementById("pBtnPlay").addEventListener("click", (e) => {
      e.stopPropagation();
      execLocalOrRemote("togglePlay");
    });
    shadow.getElementById("pBtnBack").addEventListener("click", (e) => {
      e.stopPropagation();
      execLocalOrRemote("seek", { delta: -10 });
    });
    shadow.getElementById("pBtnFwd").addEventListener("click", (e) => {
      e.stopPropagation();
      execLocalOrRemote("seek", { delta: 10 });
    });
    shadow.getElementById("pBtnMute").addEventListener("click", (e) => {
      e.stopPropagation();
      execLocalOrRemote("toggleMute");
    });
    const rates = [1.0, 1.25, 1.5, 2.0];
    shadow.getElementById("pBtnRate").addEventListener("click", (e) => {
      e.stopPropagation();
      const cur = activeVideo?.playbackRate || 1.0;
      const next = rates[(rates.indexOf(cur) + 1) % rates.length];
      execLocalOrRemote("setRate", { value: next });
      e.currentTarget.textContent = `${next.toFixed(next % 1 === 0 ? 1 : 2).replace(/\.00$/, ".0")}x`;
    });

    const pTrack = shadow.getElementById("pTrack");
    pTrack.addEventListener("mousedown", (e) => {
      e.stopPropagation();
      const r = pTrack.getBoundingClientRect();
      const ratio = Core.clamp((e.clientX - r.left) / Math.max(1, r.width), 0, 1);
      if (activeVideo && Number.isFinite(activeVideo.duration)) {
        execLocalOrRemote("seekTo", { value: ratio * activeVideo.duration });
      }
    });

    shadow.querySelectorAll(".seg-btn").forEach((b) => {
      b.addEventListener("click", (e) => {
        e.stopPropagation();
        saveState({ mode: b.dataset.mode });
      });
    });

    shadow.getElementById("pRngStealth").addEventListener("input", (e) => {
      e.stopPropagation();
      saveState({ stealth: Number(e.target.value) });
    });

    shadow.getElementById("pBtnThrough").addEventListener("click", (e) => {
      e.stopPropagation();
      parasiteClickThrough = true;
      showToast("已开启鼠标穿透 · 按 Control + Shift + M 恢复控制");
      applyStateToParasite();
    });
    shadow.getElementById("pBtnBoss").addEventListener("click", (e) => {
      e.stopPropagation();
      saveState({ bossMode: true });
    });
    shadow.getElementById("pBtnRecover").addEventListener("click", (e) => {
      e.stopPropagation();
      saveState({ bossMode: false });
    });
    shadow.getElementById("pBtnClose").addEventListener("click", (e) => {
      e.stopPropagation();
      closeParasiteOverlay();
    });

    startDomAutoSenseLoop();
    startUiSyncLoop();
    applyStateToParasite();
    return { ok: true, open: true };
  }

  let topBarHost = null;
  function mountTopControlBar() {
    removeTopControlBar();
    topBarHost = document.createElement("div");
    topBarHost.id = "gecko-topbar-host";
    topBarHost.style.cssText =
      "position:fixed;top:10px;right:18px;z-index:2147483647;background:transparent;";
    const ts = topBarHost.attachShadow({ mode: "open" });
    ts.innerHTML = `
      <style>
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", sans-serif; }
        .top-pill {
          appearance: none;
          border: 1px solid rgba(52, 211, 153, 0.55);
          background: rgba(12, 18, 26, 0.88);
          backdrop-filter: blur(14px); -webkit-backdrop-filter: blur(14px);
          color: #d1fae5;
          padding: 5px 12px;
          border-radius: 999px;
          font-size: 12px;
          font-weight: 600;
          cursor: pointer;
          box-shadow: 0 6px 20px rgba(0,0,0,0.4);
          display: inline-flex; align-items: center; gap: 6px;
        }
        .top-pill:hover { background: rgba(18, 30, 42, 0.96); color: #fff; }
        .pop {
          position: absolute; top: 36px; right: 0; width: 288px;
          background: rgba(13, 18, 26, 0.96);
          backdrop-filter: blur(18px); -webkit-backdrop-filter: blur(18px);
          border: 1px solid rgba(255,255,255,0.14);
          border-radius: 12px; padding: 12px;
          box-shadow: 0 20px 50px rgba(0,0,0,0.6);
          color: #e2e8f0; display: none; flex-direction: column; gap: 9px;
        }
        .pop.open { display: flex; }
        .row2 { display: grid; grid-template-columns: 1fr 1fr; gap: 6px; }
        .t-btn {
          appearance: none; border: 1px solid rgba(255,255,255,0.12);
          background: #17212d; color: #cbd5e1; border-radius: 7px;
          padding: 6px 8px; font-size: 11px; font-weight: 600; cursor: pointer;
        }
        .t-btn.active { background: rgba(16,185,129,0.22); border-color: #34d399; color: #a7f3d0; }
        .seg4 { display: grid; grid-template-columns: repeat(3, 1fr); background: #090d13; padding: 2px; border-radius: 7px; gap: 2px; }
        .sb { appearance: none; border: none; background: transparent; color: #94a3b8; font-size: 11px; padding: 5px 2px; border-radius: 5px; cursor: pointer; }
        .sb.active { background: #1e293b; color: #fff; font-weight: 600; }
        .sl { display: flex; flex-direction: column; gap: 3px; font-size: 11px; color: #cbd5e1; }
        .sl div { display: flex; justify-content: space-between; }
        .sl strong { color: #34d399; }
        input[type="range"] { width: 100%; height: 4px; accent-color: #10b981; cursor: pointer; }
        .strip { display: grid; grid-template-columns: repeat(4, 1fr); gap: 4px; }
        .mb { appearance: none; border: 1px solid rgba(255,255,255,0.1); background: rgba(255,255,255,0.05); color: #cbd5e1; border-radius: 5px; padding: 4px 2px; font-size: 10.5px; cursor: pointer; }
        .mb:hover { border-color: #34d399; color: #fff; }
      </style>
      <button class="top-pill" id="tbTrigger">变色龙控制栏 ▾</button>
      <div class="pop" id="tbPop">
        <div class="row2">
          <button class="t-btn" id="tbBoss">老板键隐藏</button>
          <button class="t-btn" id="tbThrough">鼠标穿透</button>
        </div>
        <div class="seg4">
          <button class="sb" data-mode="projector">拟态</button>
          <button class="sb" data-mode="emboss">浮雕</button>
          <button class="sb" data-mode="cinema">彩透</button>
        </div>
        <div class="sl">
          <div><span>变色融合浓度</span><strong id="tbValStealth">58%</strong></div>
          <input type="range" id="tbRngStealth" min="10" max="95" value="58" />
        </div>
        <div class="sl">
          <div><span>窗口实度（100%=实心）</span><strong id="tbValOpacity">100%</strong></div>
          <input type="range" id="tbRngOpacity" min="15" max="100" value="100" />
        </div>
        <div class="strip" style="grid-template-columns:repeat(3,1fr)">
          <button class="mb" data-size="260">迷你 260</button>
          <button class="mb" data-size="384">标准 384</button>
          <button class="mb" data-size="520">大窗 520</button>
        </div>
        <div class="strip">
          <button class="mb" data-corner="tl">↖ 左上</button>
          <button class="mb" data-corner="tr">↗ 右上</button>
          <button class="mb" data-corner="bl">↙ 左下</button>
          <button class="mb" data-corner="br">↘ 右下</button>
        </div>
      </div>
    `;
    const pop = ts.getElementById("tbPop");
    ts.getElementById("tbTrigger").addEventListener("click", (e) => {
      e.stopPropagation();
      pop.classList.toggle("open");
    });
    ts.getElementById("tbBoss").addEventListener("click", () => saveState({ bossMode: !state.bossMode }));
    ts.getElementById("tbThrough").addEventListener("click", () => {
      parasiteClickThrough = !parasiteClickThrough;
      applyStateToParasite();
    });
    ts.querySelectorAll(".sb").forEach((b) => {
      b.addEventListener("click", () => saveState({ mode: b.dataset.mode }));
    });
    ts.getElementById("tbRngStealth").addEventListener("input", (e) => saveState({ stealth: Number(e.target.value) }));
    ts.getElementById("tbRngOpacity").addEventListener("input", (e) => saveState({ opacity: Number(e.target.value) }));
    ts.querySelectorAll("[data-size]").forEach((b) => {
      b.addEventListener("click", () => {
        if (!parasiteHost) return;
        const w = Number(b.dataset.size);
        parasiteHost.style.width = `${w}px`;
        parasiteHost.style.height = `${Math.round((w * 9) / 16)}px`;
        runDomAutoSenseOnce();
      });
    });
    ts.querySelectorAll("[data-corner]").forEach((b) => {
      b.addEventListener("click", () => {
        if (!parasiteHost) return;
        const c = b.dataset.corner;
        const pad = 22;
        parasiteHost.style.left = c.includes("l") ? `${pad}px` : "auto";
        parasiteHost.style.right = c.includes("r") ? `${pad}px` : "auto";
        parasiteHost.style.top = c.includes("t") ? `${pad}px` : "auto";
        parasiteHost.style.bottom = c.includes("b") ? `${pad}px` : "auto";
        setTimeout(runDomAutoSenseOnce, 20);
      });
    });
    document.documentElement.appendChild(topBarHost);
  }

  function removeTopControlBar() {
    if (topBarHost) {
      topBarHost.remove();
      topBarHost = null;
    }
  }

  function renderParasiteSubtitle(subEl, rawText) {
    if (!subEl) return;
    const clean = String(rawText || "").trim();
    if (!clean && !state.stealthSubtitle) {
      subEl.style.display = "none";
      subEl.textContent = "";
      subEl.classList.remove("stealth-log", "light-bg");
      return;
    }
    subEl.style.display = "block";
    if (state.stealthSubtitle && Core.formatStealthLogParts) {
      const displayLine = clean || "stream::worker — 日志伪装运行中 · 自动捕获字幕/弹幕";
      const p = Core.formatStealthLogParts(displayLine);
      const isLight = Core.getLuminance(state.bgColor || "#505050") > 0.62;
      subEl.classList.add("stealth-log");
      subEl.classList.toggle("light-bg", isLight);
      subEl.style.color = "";
      const safe = p.text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
      subEl.innerHTML = `<span style="color:#64748b">[${p.ts}]</span> <span style="color:${isLight ? "#059669" : "#34d399"};font-weight:700">[${p.level}]</span> <span style="color:${isLight ? "#0284c7" : "#79c0ff"}">${p.mod}</span> — ${safe}`;
    } else {
      subEl.classList.remove("stealth-log", "light-bg");
      subEl.style.color = state.autoInk ? Core.deriveAutoInkColor(state.bgColor) : state.inkColor;
      subEl.textContent = clean;
    }
  }

  function syncPlayerUi() {
    if (!parasiteOpen || !parasiteHost?.shadowRoot || !activeVideo) return;
    const s = parasiteHost.shadowRoot;
    s.getElementById("pBtnPlay").innerHTML = activeVideo.paused ? Core.ICONS.play : Core.ICONS.pause;
    s.getElementById("pBtnMute").innerHTML =
      activeVideo.muted || activeVideo.volume === 0 ? Core.ICONS.volMute : Core.ICONS.volOn;
    const dur = Number.isFinite(activeVideo.duration) ? activeVideo.duration : 0;
    const cur = activeVideo.currentTime || 0;
    const pct = dur > 0 ? (cur / dur) * 100 : 0;
    s.getElementById("pFill").style.width = `${pct.toFixed(2)}%`;
    s.getElementById("pTime").textContent = `${Core.formatTime(cur)} / ${Core.formatTime(dur)}`;
    if (!parasiteUsingCrossTab) {
      renderParasiteSubtitle(s.getElementById("pSub"), state.mirrorSubtitles ? readHostSubtitles() : "");
    }
  }

  function startUiSyncLoop() {
    stopUiSyncLoop();
    syncPlayerUi();
    uiSyncTimer = setInterval(syncPlayerUi, 250);
  }

  function stopUiSyncLoop() {
    if (uiSyncTimer) {
      clearInterval(uiSyncTimer);
      uiSyncTimer = null;
    }
  }

  function runDomAutoSenseOnce() {
    if (!parasiteOpen || !parasiteHost || !state.autoSense) return;
    const r = parasiteHost.getBoundingClientRect();
    const sensed = Core.senseDomEnvironment(r.left + r.width / 2, r.top + r.height / 2, [parasiteHost]);
    const patch = Core.computeAutoScenePatch(sensed, state);
    state.bgColor = Core.lerpColor(state.bgColor, patch.bgColor, 0.55);
    state.inkColor = Core.deriveAutoInkColor(state.bgColor, sensed.archetype);
    applyStateToParasite();
  }

  function startDomAutoSenseLoop() {
    stopDomAutoSenseLoop();
    runDomAutoSenseOnce();
    autoSenseTimer = setInterval(runDomAutoSenseOnce, 550);
  }

  function stopDomAutoSenseLoop() {
    if (autoSenseTimer) {
      clearInterval(autoSenseTimer);
      autoSenseTimer = null;
    }
  }

  function applyStateToParasite() {
    if (!parasiteOpen || !parasiteHost?.shadowRoot) return;
    const shadow = parasiteHost.shadowRoot;
    const pRoot = shadow.getElementById("pRoot");
    const svgDefs = shadow.getElementById("pSvgDefs");
    const mediaEl = shadow.querySelector(".p-media");
    if (!pRoot || !svgDefs) return;

    parasiteHost.style.pointerEvents = parasiteClickThrough ? "none" : "auto";
    pRoot.classList.toggle("click-through", parasiteClickThrough);
    pRoot.classList.toggle("boss-active", Boolean(state.bossMode));
    if (!state.hoverReveal && !state.bossMode) {
      isHoveringStage = false;
      pRoot.classList.remove("hovered");
    }

    if (mediaEl) {
      Core.applySvgFilterToMedia(svgDefs, mediaEl, state, {
        isHovering: isHoveringStage,
        isTyping,
      });
      mediaEl.style.opacity = String(Core.computeMediaOpacity(state, { isTyping }));
    }

    const featherEl = shadow.getElementById("parasiteFeatherStyle");
    if (featherEl) {
      featherEl.textContent = Core.buildFeatherRuleCss(".p-media", state.feather, state.mode);
    }

    const ink = state.autoInk ? Core.deriveAutoInkColor(state.bgColor) : state.inkColor;
    shadow.getElementById("pSub").style.color = ink;

    shadow.querySelectorAll(".seg-btn").forEach((b) => {
      b.classList.toggle("active", b.dataset.mode === state.mode);
    });

    const rng = shadow.getElementById("pRngStealth");
    const lbl = shadow.getElementById("pLblStealth");
    if (rng && shadow.activeElement !== rng) rng.value = String(state.stealth);
    if (lbl) lbl.textContent = `${state.stealth}%`;

    if (topBarHost?.shadowRoot) {
      const ts = topBarHost.shadowRoot;
      ts.getElementById("tbBoss")?.classList.toggle("active", Boolean(state.bossMode));
      ts.getElementById("tbThrough")?.classList.toggle("active", parasiteClickThrough);
      ts.querySelectorAll(".sb").forEach((b) => {
        b.classList.toggle("active", b.dataset.mode === state.mode);
      });
      const tbS = ts.getElementById("tbRngStealth");
      const tbVS = ts.getElementById("tbValStealth");
      if (tbS && ts.activeElement !== tbS) tbS.value = String(state.stealth);
      if (tbVS) tbVS.textContent = `${state.stealth}%`;
      const op = state.opacity ?? 100;
      const tbO = ts.getElementById("tbRngOpacity");
      const tbVO = ts.getElementById("tbValOpacity");
      if (tbO && ts.activeElement !== tbO) tbO.value = String(op);
      if (tbVO) tbVO.textContent = `${op}%`;
    }
  }

  function closeParasiteOverlay() {
    removeTopControlBar();
    stopDomAutoSenseLoop();
    stopUiSyncLoop();
    if (parasiteStreamPort) {
      try { parasiteStreamPort.disconnect(); } catch (_) {}
      parasiteStreamPort = null;
    }
    if (parasiteHost) {
      parasiteHost._cleanup?.();
      restoreMovedVideoIfAny();
      parasiteHost.remove();
      parasiteHost = null;
    }
    parasiteOpen = false;
  }

  function restoreMovedVideoIfAny() {
    if (!videoRestoreInfo) return;
    const { video, placeholder, cssText, hadControls, hadClass } = videoRestoreInfo;
    const shouldResume = !video.paused && !video.ended;
    video.classList.remove("p-media");
    if (hadClass !== undefined) video.className = hadClass;
    video.style.cssText = cssText;
    if (hadControls) video.setAttribute("controls", "");
    else video.removeAttribute("controls");
    if (placeholder?.parentNode) placeholder.replaceWith(video);
    else if (videoRestoreInfo.parent?.isConnected) videoRestoreInfo.parent.appendChild(video);
    if (shouldResume) video.play().catch(() => {});
    videoRestoreInfo = null;
    activeVideo = null;
  }

  function handleBossModeTransition(bossActive) {
    const v = activeVideo || findBestVideo();
    if (!v) return;
    if (bossActive) {
      wasPlayingBeforeBoss = !v.paused && !v.ended;
      v.pause();
    } else if (wasPlayingBeforeBoss) {
      v.play().catch(() => {});
    }
  }

  function execCmdOnVideo(v, msg) {
    if (!v) return;
    if (msg.action === "togglePlay") {
      if (v.paused) v.play().catch(() => {});
      else v.pause();
    } else if (msg.action === "setPaused") {
      if (msg.value) v.pause();
      else v.play().catch(() => {});
    } else if (msg.action === "pause") {
      v.pause();
    } else if (msg.action === "play") {
      v.play().catch(() => {});
    } else if (msg.action === "seek") {
      v.currentTime = Core.clamp(v.currentTime + Number(msg.delta || 0), 0, v.duration || Infinity);
    } else if (msg.action === "seekTo" && Number.isFinite(msg.value)) {
      v.currentTime = Core.clamp(msg.value, 0, v.duration || Infinity);
    } else if (msg.action === "setMuted") {
      const targetMuted = Boolean(msg.value);
      v.muted = targetMuted;
      if (!targetMuted && v.volume < 0.05) {
        v.volume = 0.85;
      }
    } else if (msg.action === "toggleMute") {
      const currentlyMuted = v.muted || v.volume === 0;
      v.muted = !currentlyMuted;
      if (currentlyMuted && v.volume < 0.05) {
        v.volume = 0.85;
      }
    } else if (msg.action === "setVolume" && Number.isFinite(msg.value)) {
      v.volume = Core.clamp(msg.value, 0, 1);
      if (v.volume > 0) v.muted = false;
    } else if (msg.action === "setRate" && Number.isFinite(msg.value)) {
      v.playbackRate = msg.value;
    }
  }

  // ---------------------------------------------------------------------------
  // Zero-Lag Direct <video>.captureStream() Hardware Decoder Pipeline
  // Bypasses Viz background tab compositor throttling completely!
  // ---------------------------------------------------------------------------
  let directStreamActive = false;
  let directBridgeFrame = null;
  let directBridgeReady = false;
  let directBridgeLoaded = false;
  let pendingBridgePort = null;
  let directBridgeOrigin = "*";
  let directMediaStream = null;
  let directFrameReader = null;
  let directCaptureWorker = null;
  let directPendingFrame = null;
  let directEncodingBusy = false;
  let directEncodeCanvas = null;
  let directEncodeCtx = null;
  let directSupportsOffscreen = false;
  let directLastFrameTs = 0;
  let directVideoEl = null;
  let directWatchdogTimer = null;
  let directFramesSent = 0;
  let directBindStartedAt = 0;
  let directLastFrameAt = 0;
  let directLastObsTime = -1;
  let directFrameSeq = 0;
  let directLastSentSeq = 0;
  let directOnlyMode = false;
  let directMetaTimer = null;
  let loopbackPcA = null;
  let loopbackPcB = null;
  let loopbackAudioCtx = null;
  let loopbackOscNode = null;
  let loopbackAudioEl = null;
  let loopbackLockRelease = null;

  function flushPendingBridgePort() {
    if (!directBridgeLoaded || !pendingBridgePort || !directBridgeFrame?.contentWindow) return;
    const p = pendingBridgePort;
    pendingBridgePort = null;
    try {
      directBridgeFrame.contentWindow.postMessage({ type: "GECKO_BRIDGE_BIND_PORT" }, directBridgeOrigin, [p]);
    } catch (_) {
      try { p.close(); } catch (_2) {}
    }
  }

  function startLoopbackRtcKeepAlive() {
    if (!loopbackLockRelease && navigator.locks?.request) {
      try {
        navigator.locks
          .request("chameleon_pip_awake_" + Math.random().toString(36).slice(2), () => {
            return new Promise((resolve) => {
              loopbackLockRelease = resolve;
            });
          })
          .catch(() => {});
      } catch (_) {}
    }
    if (loopbackPcA || typeof RTCPeerConnection !== "function") return;
    try {
      const pcA = new RTCPeerConnection({ iceServers: [] });
      const pcB = new RTCPeerConnection({ iceServers: [] });
      loopbackPcA = pcA;
      loopbackPcB = pcB;
      pcA.createDataChannel("chameleon-keepalive");

      // Attach a silent WebAudio track over WebRTC so Chromium marks this tab as active real-time audio and never throttles video!
      try {
        const Ctx = window.AudioContext || window.webkitAudioContext;
        if (Ctx) {
          const actx = new Ctx();
          loopbackAudioCtx = actx;
          const dest = actx.createMediaStreamDestination();
          const src = typeof actx.createConstantSource === "function" ? actx.createConstantSource() : null;
          if (src) {
            src.offset.value = 0.00001;
            src.connect(dest);
            src.start();
            loopbackOscNode = src;
          }
          const track = dest.stream.getAudioTracks()[0];
          if (track) pcA.addTrack(track, dest.stream);
          if (actx.state === "suspended") actx.resume().catch(() => {});
        }
      } catch (_) {}

      pcB.ontrack = (ev) => {
        try {
          if (!loopbackAudioEl && ev.streams && ev.streams[0]) {
            const a = new Audio();
            a.volume = 0.0001;
            a.srcObject = ev.streams[0];
            a.play().catch(() => {});
            loopbackAudioEl = a;
          }
        } catch (_) {}
      };

      pcA.onicecandidate = (e) => {
        if (e.candidate && pcB.signalingState !== "closed") {
          pcB.addIceCandidate(e.candidate).catch(() => {});
        }
      };
      pcB.onicecandidate = (e) => {
        if (e.candidate && pcA.signalingState !== "closed") {
          pcA.addIceCandidate(e.candidate).catch(() => {});
        }
      };
      pcA
        .createOffer()
        .then((offer) => pcA.setLocalDescription(offer))
        .then(() => pcB.setRemoteDescription(pcA.localDescription))
        .then(() => pcB.createAnswer())
        .then((ans) => pcB.setLocalDescription(ans))
        .then(() => pcA.setRemoteDescription(pcB.localDescription))
        .catch(() => {});
    } catch (_) {}
  }

  function stopLoopbackRtcKeepAlive() {
    if (loopbackLockRelease) {
      try { loopbackLockRelease(); } catch (_) {}
      loopbackLockRelease = null;
    }
    try { loopbackOscNode?.stop?.(); } catch (_) {}
    try { loopbackAudioCtx?.close?.(); } catch (_) {}
    if (loopbackAudioEl) {
      try { loopbackAudioEl.pause(); loopbackAudioEl.srcObject = null; } catch (_) {}
    }
    loopbackOscNode = null;
    loopbackAudioCtx = null;
    loopbackAudioEl = null;
    try { loopbackPcA?.close(); } catch (_) {}
    try { loopbackPcB?.close(); } catch (_) {}
    loopbackPcA = null;
    loopbackPcB = null;
  }

  function pushDirectMetaNow() {
    if (!directOnlyMode || !directStreamActive || !directBridgeReady || !directBridgeFrame?.contentWindow) return;
    const crop = getNormalizedVideoCrop();
    if (!crop) return;
    try {
      directBridgeFrame.contentWindow.postMessage(
        {
          type: "GECKO_BRIDGE_META",
          meta: {
            aspect: crop.aspect || 16 / 9,
            subtitle: crop.subtitle || "",
            player: crop.player || null,
            state: {
              mirrorSubtitles: Boolean(state.mirrorSubtitles),
              stealthSubtitle: Boolean(state.stealthSubtitle),
            },
          },
        },
        directBridgeOrigin
      );
    } catch (_) {}
  }

  function releaseDirectFrameSafe(frame) {
    if (frame && typeof frame.close === "function") {
      try {
        frame.close();
      } catch (_) {}
    }
  }

  function onBridgeWindowMessage(ev) {
    if (!directBridgeFrame || ev.source !== directBridgeFrame.contentWindow) return;
    const msg = ev.data;
    if (msg && msg.type === "GECKO_BRIDGE_LOADED") {
      directBridgeLoaded = true;
      flushPendingBridgePort();
      return;
    }
    if (msg && msg.type === "GECKO_BRIDGE_WS_STATE") {
      directBridgeLoaded = true;
      directBridgeReady = Boolean(msg.open);
      flushPendingBridgePort();
      if (directBridgeReady && directOnlyMode) {
        pushDirectMetaNow();
      }
    }
  }
  window.addEventListener("message", onBridgeWindowMessage);

  function ensureDirectEncodeSurface(w, h) {
    if (!directEncodeCanvas) {
      if (typeof OffscreenCanvas !== "undefined") {
        directEncodeCanvas = new OffscreenCanvas(w, h);
        directSupportsOffscreen = true;
      } else {
        directEncodeCanvas = document.createElement("canvas");
        directEncodeCanvas.width = w;
        directEncodeCanvas.height = h;
        directSupportsOffscreen = false;
      }
      directEncodeCtx = directEncodeCanvas.getContext("2d", {
        alpha: false,
        desynchronized: true,
      });
    }
    if (directEncodeCanvas.width !== w || directEncodeCanvas.height !== h) {
      directEncodeCanvas.width = w;
      directEncodeCanvas.height = h;
    }
    return directEncodeCtx;
  }

  function encodeDirectSurfaceToBlob(quality) {
    if (directSupportsOffscreen && typeof directEncodeCanvas.convertToBlob === "function") {
      return directEncodeCanvas.convertToBlob({ type: "image/jpeg", quality });
    }
    return new Promise((resolve) => directEncodeCanvas.toBlob(resolve, "image/jpeg", quality));
  }

  function ensureStreamBridgeFrame() {
    if (!chrome?.runtime?.getURL) return null;
    const bridgeUrl = chrome.runtime.getURL("stream-bridge.html");
    try {
      directBridgeOrigin = new URL(bridgeUrl).origin;
    } catch (_) {
      directBridgeOrigin = "*";
    }
    if (directBridgeFrame && directBridgeFrame.isConnected) {
      try {
        directBridgeFrame.contentWindow?.postMessage({ type: "GECKO_BRIDGE_START" }, directBridgeOrigin);
      } catch (_) {}
      return directBridgeFrame;
    }
    const old = document.getElementById("gecko-stream-bridge-frame");
    if (old) old.remove();

    const frame = document.createElement("iframe");
    frame.id = "gecko-stream-bridge-frame";
    frame.src = bridgeUrl;
    frame.setAttribute("aria-hidden", "true");
    frame.style.cssText =
      "position:fixed !important;right:0 !important;bottom:0 !important;width:2px !important;height:2px !important;opacity:0.002 !important;border:0 !important;pointer-events:none !important;z-index:-2147483647 !important;";
    directBridgeReady = false;
    directBridgeLoaded = false;
    frame.addEventListener("load", () => {
      directBridgeLoaded = true;
      flushPendingBridgePort();
      try {
        frame.contentWindow?.postMessage({ type: "GECKO_BRIDGE_START" }, directBridgeOrigin);
      } catch (_) {}
    });
    (document.documentElement || document.body)?.appendChild(frame);
    directBridgeFrame = frame;
    return frame;
  }

  function cleanupDirectCaptureReaderOnly() {
    if (directCaptureWorker) {
      try { directCaptureWorker.postMessage({ type: "stop" }); } catch (_) {}
      try { directCaptureWorker.terminate(); } catch (_) {}
      directCaptureWorker = null;
    }
    if (pendingBridgePort) {
      try { pendingBridgePort.close(); } catch (_) {}
      pendingBridgePort = null;
    }
    if (directPendingFrame) {
      releaseDirectFrameSafe(directPendingFrame);
      directPendingFrame = null;
    }
    if (directFrameReader) {
      const r = directFrameReader;
      directFrameReader = null;
      try {
        r.cancel().catch(() => {});
      } catch (_) {}
    }
    if (directMediaStream) {
      try {
        directMediaStream.getTracks().forEach((t) => t.stop());
      } catch (_) {}
      directMediaStream = null;
    }
    directEncodingBusy = false;
  }

  async function encodeAndPostDirectFrame(frame, ownerReader) {
    directEncodingBusy = true;
    try {
      const vw = frame.displayWidth || frame.codedWidth || 0;
      const vh = frame.displayHeight || frame.codedHeight || 0;
      if (!vw || !vh) {
        releaseDirectFrameSafe(frame);
        return;
      }
      directLastFrameTs = performance.now();
      const aspect = vw / Math.max(1, vh);
      const targetW = aspect < 0.85 ? 268 : 420;
      const targetH = Math.max(135, Math.round(targetW / aspect));

      const ctx = ensureDirectEncodeSurface(targetW, targetH);
      if (!ctx) {
        releaseDirectFrameSafe(frame);
        return;
      }

      ctx.drawImage(frame, 0, 0, targetW, targetH);
      // Release hardware decoder VideoFrame immediately before async JPEG encode
      releaseDirectFrameSafe(frame);

      const mySeq = ++directFrameSeq;
      const blob = await encodeDirectSurfaceToBlob(0.68);
      if (!blob || !directStreamActive || mySeq < directLastSentSeq) return;
      directLastSentSeq = mySeq;

      if (directBridgeFrame?.contentWindow && directBridgeReady) {
        const buf = await blob.arrayBuffer();
        if (directStreamActive && mySeq >= directLastSentSeq && directBridgeFrame?.contentWindow) {
          directBridgeFrame.contentWindow.postMessage(
            { type: "GECKO_BRIDGE_FRAME", buf },
            directBridgeOrigin,
            [buf]
          );
          directFramesSent += 1;
          directLastFrameAt = performance.now();
        }
      }
    } catch (err) {
      releaseDirectFrameSafe(frame);
      // Cross-origin tainted <video> or codec error -> seamless fallback to offscreen tabCapture!
      if (
        err &&
        (err.name === "SecurityError" ||
          String(err).toLowerCase().includes("tainted") ||
          String(err).toLowerCase().includes("security"))
      ) {
        stopDirectVideoStream(true);
      }
    } finally {
      directEncodingBusy = false;
      if (directStreamActive && directPendingFrame && directFrameReader === ownerReader) {
        const next = directPendingFrame;
        directPendingFrame = null;
        if (!state.bossMode && directBridgeReady) {
          encodeAndPostDirectFrame(next, ownerReader);
        } else {
          releaseDirectFrameSafe(next);
        }
      }
    }
  }

  function bindDirectCaptureToVideo(v) {
    cleanupDirectCaptureReaderOnly();
    if (!v || v.readyState < 2 || !v.videoWidth || !v.videoHeight || v.mediaKeys) {
      return false;
    }
    if (typeof MediaStreamTrackProcessor !== "function") {
      return false;
    }
    const captureFn = v.captureStream || v.mozCaptureStream;
    if (typeof captureFn !== "function") {
      return false;
    }

    let stream = null;
    try {
      stream = captureFn.call(v);
    } catch (_) {
      return false;
    }
    const track = stream?.getVideoTracks?.()?.[0];
    if (!track || track.readyState === "ended") {
      try {
        stream?.getTracks?.().forEach((t) => t.stop());
      } catch (_) {}
      return false;
    }
    if ("contentHint" in track) {
      try {
        track.contentHint = "motion";
      } catch (_) {}
    }

    let processor = null;
    try {
      processor = new MediaStreamTrackProcessor({ track });
    } catch (_) {
      try {
        stream.getTracks().forEach((t) => t.stop());
      } catch (_2) {}
      return false;
    }

    directVideoEl = v;
    directMediaStream = stream;
    directFramesSent = 0;
    directBindStartedAt = performance.now();
    directLastFrameAt = directBindStartedAt;
    directLastObsTime = v.currentTime || 0;

    // Fast unthrottled Dedicated Web Worker pipeline (runs completely off the tab main thread!)
    if (typeof Worker === "function" && typeof OffscreenCanvas === "function" && typeof MessageChannel === "function") {
      try {
        const workerCode = `
          let running = true, busy = false, pending = null, reader = null, canvas = null, ctx = null, port = null, seq = 0, sent = 0, lastTs = 0;
          function rel(f) { if (f && typeof f.close === 'function') { try { f.close(); } catch (_) {} } }
          async function pumpOne(f) {
            busy = true;
            try {
              const vw = f.displayWidth || f.codedWidth || 0;
              const vh = f.displayHeight || f.codedHeight || 0;
              if (!vw || !vh) { rel(f); return; }
              lastTs = performance.now();
              const asp = vw / Math.max(1, vh);
              const tw = asp < 0.85 ? 268 : 420;
              const th = Math.max(135, Math.round(tw / asp));
              if (!canvas) {
                canvas = new OffscreenCanvas(tw, th);
                ctx = canvas.getContext('2d', { alpha: false, desynchronized: true });
              } else if (canvas.width !== tw || canvas.height !== th) {
                canvas.width = tw; canvas.height = th;
              }
              ctx.drawImage(f, 0, 0, tw, th);
              rel(f);
              const mySeq = ++seq;
              const blob = await canvas.convertToBlob({ type: 'image/jpeg', quality: 0.68 });
              if (!running || !blob || !port) return;
              const buf = await blob.arrayBuffer();
              if (running && mySeq === seq && port) {
                port.postMessage(buf, [buf]);
                sent += 1;
                if (sent <= 3 || sent % 10 === 0) self.postMessage({ type: 'tick', sent });
              }
            } catch (_) {
              rel(f);
            } finally {
              busy = false;
              if (running && pending) {
                const nxt = pending; pending = null; pumpOne(nxt);
              }
            }
          }
          self.onmessage = async (e) => {
            const d = e.data || {};
            if (d.type === 'stop') {
              running = false; rel(pending); pending = null;
              try { reader?.cancel?.().catch(() => {}); } catch (_) {}
              try { port?.close?.(); } catch (_) {}
              return;
            }
            if (d.type === 'init' && d.readable && d.port) {
              port = d.port;
              reader = d.readable.getReader();
              try {
                while (running) {
                  const { value: vf, done } = await reader.read();
                  if (done || !vf) { rel(vf); break; }
                  const now = performance.now();
                  if (!busy && now - lastTs < 8) { rel(vf); continue; }
                  if (busy) { rel(pending); pending = vf; continue; }
                  pumpOne(vf);
                }
              } catch (_) {}
            }
          };
        `;
        const wBlob = new Blob([workerCode], { type: "application/javascript" });
        const wUrl = URL.createObjectURL(wBlob);
        const worker = new Worker(wUrl);
        URL.revokeObjectURL(wUrl);
        const ch = new MessageChannel();
        directCaptureWorker = worker;
        pendingBridgePort = ch.port2;
        flushPendingBridgePort();
        worker.onmessage = (ev) => {
          if (ev.data?.type === "tick" && directStreamActive) {
            directFramesSent += 1;
            directLastFrameAt = performance.now();
          }
        };
        worker.postMessage(
          { type: "init", readable: processor.readable, port: ch.port1 },
          [processor.readable, ch.port1]
        );
        return true;
      } catch (_) {
        // CSP blocked blob Worker -> fall through cleanly to main-thread reader!
        if (directCaptureWorker) {
          try { directCaptureWorker.terminate(); } catch (_2) {}
          directCaptureWorker = null;
        }
        if (pendingBridgePort) {
          try { pendingBridgePort.close(); } catch (_2) {}
          pendingBridgePort = null;
        }
      }
    }

    const localReader = processor.readable.getReader();
    directFrameReader = localReader;

    (async () => {
      try {
        while (directStreamActive && directFrameReader === localReader) {
          const { value: videoFrame, done } = await localReader.read();
          if (done || !videoFrame) {
            releaseDirectFrameSafe(videoFrame);
            break;
          }
          if (!directStreamActive || directFrameReader !== localReader || state.bossMode || !directBridgeReady) {
            releaseDirectFrameSafe(videoFrame);
            continue;
          }
          const now = performance.now();
          if (!directEncodingBusy && now - directLastFrameTs < 8) {
            releaseDirectFrameSafe(videoFrame);
            continue;
          }
          if (directEncodingBusy) {
            if (directPendingFrame) releaseDirectFrameSafe(directPendingFrame);
            directPendingFrame = videoFrame;
            continue;
          }
          encodeAndPostDirectFrame(videoFrame, localReader);
        }
      } catch (_) {
        if (directStreamActive && directFrameReader === localReader) {
          stopDirectVideoStream(true);
        }
      }
    })();

    return true;
  }

  function startDirectVideoStream(preferredVideo = null, options = {}) {
    const asDirectOnly = Boolean(options?.directOnly);
    if (document.documentElement) {
      document.documentElement.dataset.chameleonStreamAwake = "1";
    }
    if (typeof MediaStreamTrackProcessor !== "function") {
      return { ok: false, reason: "no_track_processor" };
    }
    const v = (preferredVideo && preferredVideo.isConnected ? preferredVideo : null) || findBestVideo();
    if (!v || v.readyState < 2 || !v.videoWidth || !v.videoHeight || v.mediaKeys) {
      return { ok: false, reason: "unsupported" };
    }

    stopDirectVideoStream(false, false);
    if (document.documentElement) {
      document.documentElement.dataset.chameleonStreamAwake = "1";
    }
    directStreamActive = true;
    directOnlyMode = asDirectOnly;
    startLoopbackRtcKeepAlive();
    ensureStreamBridgeFrame();

    if (!bindDirectCaptureToVideo(v)) {
      stopDirectVideoStream(!asDirectOnly, false);
      return { ok: false, reason: "capture_failed" };
    }

    refreshHoverButtonLabel();
    if (directOnlyMode) {
      pushDirectMetaNow();
      directMetaTimer = setInterval(pushDirectMetaNow, 450);
    }

    directWatchdogTimer = setInterval(() => {
      if (!directStreamActive) {
        clearInterval(directWatchdogTimer);
        directWatchdogTimer = null;
        return;
      }
      const best = findBestVideo();
      if (best && best !== directVideoEl && best.readyState >= 2 && best.videoWidth > 0 && !best.mediaKeys) {
        if (!bindDirectCaptureToVideo(best)) {
          stopDirectVideoStream(!directOnlyMode, directOnlyMode);
        }
        return;
      }
      if (!directVideoEl || !directVideoEl.isConnected || directVideoEl.mediaKeys) {
        stopDirectVideoStream(!directOnlyMode, directOnlyMode);
        return;
      }
      if (!directVideoEl.paused && !directVideoEl.ended && directVideoEl.readyState >= 2 && directBridgeReady) {
        const curT = directVideoEl.currentTime || 0;
        const advancing = Math.abs(curT - directLastObsTime) > 0.08;
        directLastObsTime = curT;
        const now = performance.now();
        if (
          advancing &&
          ((directFramesSent === 0 && now - directBindStartedAt > 1800) ||
            (directFramesSent > 0 && now - directLastFrameAt > 2600))
        ) {
          stopDirectVideoStream(!directOnlyMode, directOnlyMode);
        }
      } else if (directVideoEl) {
        directLastObsTime = directVideoEl.currentTime || 0;
        directLastFrameAt = performance.now();
      }
    }, 900);

    return { ok: true };
  }

  function stopDirectVideoStream(notifyFallback = false, notifySessionEnd = false) {
    const wasDirectOnly = directOnlyMode;
    directStreamActive = false;
    directOnlyMode = false;
    if (directMetaTimer) {
      clearInterval(directMetaTimer);
      directMetaTimer = null;
    }
    if (directWatchdogTimer) {
      clearInterval(directWatchdogTimer);
      directWatchdogTimer = null;
    }
    stopLoopbackRtcKeepAlive();
    cleanupDirectCaptureReaderOnly();
    directVideoEl = null;
    directBridgeReady = false;
    refreshHoverButtonLabel();
    if (notifySessionEnd || wasDirectOnly) {
      if (document.documentElement) {
        delete document.documentElement.dataset.chameleonStreamAwake;
      }
    }
    if (directBridgeFrame) {
      try {
        directBridgeFrame.contentWindow?.postMessage(
          { type: "GECKO_BRIDGE_STOP", notifySessionEnd: Boolean(notifySessionEnd) },
          directBridgeOrigin
        );
      } catch (_) {}
      directBridgeFrame.remove();
      directBridgeFrame = null;
    }
    if (notifyFallback && !wasDirectOnly && chrome?.runtime?.sendMessage) {
      chrome.runtime.sendMessage({ type: "GECKO_DIRECT_STREAM_STATUS", active: false }).catch(() => {});
    }
  }

  window.__GECKO_PIP_CLEANUP__ = () => {
    stopDirectVideoStream(false, false);
    closeParasiteOverlay();
    window.removeEventListener("message", onBridgeWindowMessage);
    window.removeEventListener("keydown", onGeckoKeyDown, true);
    window.removeEventListener("mousemove", onHoverMouseMove, { passive: true });
  };

  if (chrome?.runtime?.onMessage) {
    chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
      if (!msg || typeof msg !== "object") return false;
      if (msg.type === "GECKO_GET_PAGE_INFO") {
        sendResponse({ hasVideo: Boolean(findBestVideo()), parasiteOpen, state });
        return false;
      }
      if (msg.type === "GECKO_WAKE_MAC_APP") {
        wakeMacGhostViaScheme();
        sendResponse({ ok: true });
        return false;
      }
      if (msg.type === "GECKO_GET_VIDEO_CROP") {
        sendResponse(getNormalizedVideoCrop());
        return false;
      }
      if (msg.type === "GECKO_START_DIRECT_STREAM") {
        const asDirectOnly = Boolean(msg.directOnly);
        if (asDirectOnly && parasiteOpen) {
          closeParasiteOverlay();
        }
        const res = startDirectVideoStream(null, { directOnly: asDirectOnly });
        if (res?.ok && asDirectOnly) {
          setTimeout(() => {
            if (directStreamActive && !directBridgeReady) {
              wakeMacGhostViaScheme();
            }
          }, 350);
        }
        sendResponse(res);
        return false;
      }
      if (msg.type === "GECKO_STOP_DIRECT_STREAM") {
        if (document.documentElement) {
          delete document.documentElement.dataset.chameleonStreamAwake;
        }
        stopDirectVideoStream(false, Boolean(msg.notifySessionEnd));
        sendResponse({ ok: true });
        return false;
      }
      if (msg.type === "GECKO_TOGGLE_PARASITE") {
        toggleParasiteOverlay().then((res) => sendResponse(res));
        return true;
      }
      if (msg.type === "GECKO_CLOSE_PIP") {
        closeParasiteOverlay();
        sendResponse({ ok: true });
        return false;
      }
      if (msg.type === "GECKO_EXEC_VIDEO_CMD") {
        execCmdOnVideo(activeVideo || findBestVideo(), msg);
        sendResponse({ ok: true });
        return false;
      }
      return false;
    });
  }
})();

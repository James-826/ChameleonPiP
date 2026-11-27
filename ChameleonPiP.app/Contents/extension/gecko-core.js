/**
 * ChameleonPiP Core Engine v5.5 — Biomimetic Chameleon Skin Camouflage Engine
 *
 * Biomimetic principle:
 * Instead of painting a flat box color over the desktop, modulates the video into
 * Chameleon Light (ambient-tinted highlights) and Shadow alpha layers so whatever
 * is underneath on the user's desktop (red/green wallpaper, colored code, white doc,
 * spreadsheets) shines straight through in its OWN real colors while adapting to
 * environmental warmth, texture, and subtitles.
 */
(function (global) {
  "use strict";

  let filterSeq = 0;

  const DEFAULT_STATE = {
    autoSense: true, // Auto-adjusts light/shadow pivot for extreme white (#fff) or pitch black (#000) surfaces
    displayTarget: "ghost",
    bgColor: "#505050",
    mode: "projector", // 'projector' (拟态同色) | 'emboss' (鳞纹浮雕) | 'cinema' (虹彩显色)
    stealth: 58, // 投影浓度 (Projector Intensity: 12% 极淡微影 -> 58% 自然融合 -> 95% 浓郁清晰)
    feather: 28, // 镜头边缘柔化 (0% 清晰圆角 -> 80% 羽化无界)
    detail: 72,
    mirrorSubtitles: true,
    stealthSubtitle: false, // 黑科技：将字幕伪装成 VS Code / 终端编译日志条（静音摸鱼神器）
    hoverReveal: false, // 悬停小窗显示控制条开关（默认关闭：鼠标碰到小窗不显形、保持纯隐身）
    bossMode: false,
    pipWidth: 392,
    pipHeight: 220,
  };

  const ICONS = {
    play: `<svg viewBox="0 0 24 24" width="15" height="15" fill="currentColor"><path d="M8 5.14v14l11-7-11-7z"/></svg>`,
    pause: `<svg viewBox="0 0 24 24" width="15" height="15" fill="currentColor"><path d="M6 5h4v14H6V5zm8 0h4v14h-4V5z"/></svg>`,
    back10: `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/></svg>`,
    fwd10: `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12a9 9 0 1 1-9-9c2.52 0 4.93 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/></svg>`,
    volOn: `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"/><path d="M15.54 8.46a5 5 0 0 1 0 7.07"/><path d="M19.07 4.93a10 10 0 0 1 0 14.14"/></svg>`,
    volMute: `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"/><line x1="23" y1="9" x2="17" y2="15"/><line x1="17" y1="9" x2="23" y2="15"/></svg>`,
    eyeHide: `<svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"/><line x1="1" y1="1" x2="23" y2="23"/></svg>`,
    cursorThrough: `<svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m4 4 7.07 17 2.51-7.39L21 11.07z"/></svg>`,
    close: `<svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>`,
    resizeGrip: `<svg viewBox="0 0 12 12" width="11" height="11" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"><line x1="10" y1="3" x2="3" y2="10"/><line x1="10" y1="7" x2="7" y2="10"/></svg>`,
    menubarAperture: `<svg viewBox="0 0 18 18" width="15" height="15" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="3.5" width="14" height="11" rx="2.5"/><circle cx="9" cy="9" r="2.6"/><path d="M13.2 6.2h.01"/></svg>`,
  };

  function clamp(v, min, max) {
    return Math.max(min, Math.min(max, v));
  }

  function formatTime(sec) {
    if (!Number.isFinite(sec) || sec < 0) return "00:00";
    const total = Math.floor(sec);
    const h = Math.floor(total / 3600);
    const m = Math.floor((total % 3600) / 60);
    const s = total % 60;
    const mm = String(m).padStart(2, "0");
    const ss = String(s).padStart(2, "0");
    return h > 0 ? `${h}:${mm}:${ss}` : `${mm}:${ss}`;
  }

  function hexToRgb(hex) {
    const clean = String(hex || "#505050").replace(/[^0-9a-fA-F]/g, "");
    const full =
      clean.length === 3
        ? clean
            .split("")
            .map((c) => c + c)
            .join("")
        : clean.padEnd(6, "0").slice(0, 6);
    const num = parseInt(full, 16);
    return {
      r: (num >> 16) & 255,
      g: (num >> 8) & 255,
      b: num & 255,
    };
  }

  function rgbToHex(r, g, b) {
    const toHex = (n) =>
      clamp(Math.round(n), 0, 255).toString(16).padStart(2, "0");
    return `#${toHex(r)}${toHex(g)}${toHex(b)}`;
  }

  function lerpColor(hexA, hexB, t) {
    const a = hexToRgb(hexA);
    const b = hexToRgb(hexB);
    const k = clamp(t, 0, 1);
    return rgbToHex(
      a.r + (b.r - a.r) * k,
      a.g + (b.g - a.g) * k,
      a.b + (b.b - a.b) * k
    );
  }

  function getLuminance(hex) {
    const { r, g, b } = hexToRgb(hex);
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255;
  }

  function deriveAutoInkColor(bgHex) {
    return getLuminance(bgHex) < 0.55 ? "rgba(255,255,255,0.78)" : "rgba(15,23,42,0.78)";
  }

  function computeAutoScenePatch(sensor, currentState) {
    return {
      bgColor: sensor.bgColor || currentState?.bgColor || "#505050",
    };
  }

  function senseDomEnvironment(x, y, ignoreElements = []) {
    const px = clamp(x, 4, Math.max(5, window.innerWidth - 5));
    const py = clamp(y, 4, Math.max(5, window.innerHeight - 5));
    const stack = document.elementsFromPoint
      ? document.elementsFromPoint(px, py)
      : [document.body];

    let rAcc = 0,
      gAcc = 0,
      bAcc = 0,
      aRem = 1.0;

    for (const el of stack) {
      if (!el || ignoreElements.includes(el)) continue;
      if (el.id && String(el.id).startsWith("gecko")) continue;
      if (el.classList?.contains("ghost-pip")) continue;

      const cs = window.getComputedStyle(el);
      const m =
        cs.backgroundColor &&
        cs.backgroundColor.match(
          /rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)(?:\s*[,/]\s*([\d.]+))?\s*\)/
        );
      if (m) {
        const er = Number(m[1]),
          eg = Number(m[2]),
          eb = Number(m[3]);
        const ea = m[4] !== undefined ? Number(m[4]) : 1.0;
        if (ea > 0.01) {
          rAcc += er * ea * aRem;
          gAcc += eg * ea * aRem;
          bAcc += eb * ea * aRem;
          aRem *= 1 - ea;
          if (aRem < 0.03) break;
        }
      }
    }

    if (aRem > 0.03) {
      rAcc += 128 * aRem;
      gAcc += 128 * aRem;
      bAcc += 128 * aRem;
    }

    return { bgColor: rgbToHex(rAcc, gAcc, bAcc), archetype: "web" };
  }

  function fmt(n) {
    return Number(n).toFixed(4);
  }

  /**
   * Builds GPU-accelerated Biomimetic Chameleon Skin SVG <filter> primitives.
   *
   * How it works:
   * - Modulates video highlights & shadows with ambient desktop color temperature tint
   *   so underlying pixels (e.g. half Red & half Green, VS Code syntax, white docs)
   *   keep 100% of their own hue/color while blending like real chameleon skin!
   */
  function buildFilterPrimitives(state, options = {}) {
    if (options.isPeeking) {
      return `<feColorMatrix type="matrix" values="1 0 0 0 0  0 1 0 0 0  0 0 1 0 0  0 0 0 1 0" />`;
    }

    // `stealth` stores Camouflage Intensity (10% subtle -> 95% strong)
    const intensity = clamp(Number(state.stealth ?? 58) / 100, 0.08, 0.96);
    const detailStrength = clamp(Number(state.detail ?? 72) / 100, 0, 1.2);
    const mode = state.mode || "projector";

    const bg = hexToRgb(state.bgColor || "#505050");
    const br = bg.r / 255;
    const bgc = bg.g / 255;
    const bb = bg.b / 255;
    const lr = 0.72 + 0.28 * clamp(br * 1.35 + 0.24, 0, 1);
    const lg = 0.72 + 0.28 * clamp(bgc * 1.35 + 0.24, 0, 1);
    const lb = 0.72 + 0.28 * clamp(bb * 1.35 + 0.24, 0, 1);
    const dr = 0.06 * br;
    const dg = 0.06 * bgc;
    const db = 0.06 * bb;

    // Auto-adapt neutral pivot slightly when over pure white (#fff) or pitch black (#000)
    // while keeping symmetric 0.48 on colorful / mixed / red-green / editor surfaces!
    let pivot = 0.48;
    if (state.autoSense && state.bgColor) {
      const bgLum = getLuminance(state.bgColor);
      if (bgLum > 0.86) pivot = 0.72; // Pure white page: emphasize shadow tones so bright scenes stay clear!
      else if (bgLum < 0.14) pivot = 0.28; // Pitch black terminal: emphasize light beam tones!
    }

    // -------------------------------------------------------------------------
    // Mode 1: `projector` (拟态同色 — Chromatophore Habitat Blend)
    // Underlying red stays red, green stays green; highlights & shadows adopt subtle ambient tint!
    // -------------------------------------------------------------------------
    if (mode === "projector") {
      const k = clamp(intensity * 0.94, 0.06, 0.94);
      const contrast = 1 + 0.22 * detailStrength;
      const sDark = (-k * contrast) / pivot;
      const offDark = k * (0.5 + 0.5 * contrast);
      const sLight = (k * contrast) / (1 - pivot);
      const offLight = (-k * (pivot * contrast - 0.5 * (contrast - 1))) / (1 - pivot);

      return `
        <feColorMatrix in="SourceGraphic" type="matrix" result="shadow"
          values="0 0 0 0 ${fmt(dr)}
                  0 0 0 0 ${fmt(dg)}
                  0 0 0 0 ${fmt(db)}
                  ${fmt(0.2126 * sDark)} ${fmt(0.7152 * sDark)} ${fmt(0.0722 * sDark)} 0 ${fmt(offDark)}" />
        <feColorMatrix in="SourceGraphic" type="matrix" result="light"
          values="0 0 0 0 ${fmt(lr)}
                  0 0 0 0 ${fmt(lg)}
                  0 0 0 0 ${fmt(lb)}
                  ${fmt(0.2126 * sLight)} ${fmt(0.7152 * sLight)} ${fmt(0.0722 * sLight)} 0 ${fmt(offLight)}" />
        <feMerge>
          <feMergeNode in="shadow" />
          <feMergeNode in="light" />
        </feMerge>
      `;
    }

    // -------------------------------------------------------------------------
    // Mode 2: `emboss` (鳞纹浮雕 — Dermal Tubercle Scale Micro-Relief)
    // Directional 3x3 emboss kernel: flat areas = 0.5 -> Alpha = 0.000 (100% pure background!),
    // sunlit scale ridges cast ambient highlight tint, shadowed edges cast ambient shadow tint!
    // -------------------------------------------------------------------------
    if (mode === "emboss") {
      const gain = clamp(1.1 + intensity * 2.2, 0.8, 3.4);
      const k = clamp(intensity * 1.15, 0.12, 0.98);
      // Around bias 0.5: shadow for val < 0.485, light for val > 0.515 (deadband eliminates noise!)
      const sDark = -k / 0.485;
      const offDark = k;
      const sLight = k / 0.485;
      const offLight = (-k * 0.515) / 0.485;

      return `
        <feColorMatrix in="SourceGraphic" type="matrix" result="lum"
          values="0.2126 0.7152 0.0722 0 0
                  0.2126 0.7152 0.0722 0 0
                  0.2126 0.7152 0.0722 0 0
                  0      0      0      0 1" />
        <feConvolveMatrix in="lum" order="3" divisor="1" bias="0.5" preserveAlpha="true" edgeMode="duplicate" result="relief"
          kernelMatrix="${fmt(-1.1 * gain)} ${fmt(-0.7 * gain)} 0
                        ${fmt(-0.7 * gain)} 0                   ${fmt(0.7 * gain)}
                        0                   ${fmt(0.7 * gain)}  ${fmt(1.1 * gain)}" />
        <feColorMatrix in="relief" type="matrix" result="shadow"
          values="0 0 0 0 ${fmt(dr)}
                  0 0 0 0 ${fmt(dg)}
                  0 0 0 0 ${fmt(db)}
                  ${fmt(sDark)} 0 0 0 ${fmt(offDark)}" />
        <feColorMatrix in="relief" type="matrix" result="light"
          values="0 0 0 0 ${fmt(lr)}
                  0 0 0 0 ${fmt(lg)}
                  0 0 0 0 ${fmt(lb)}
                  ${fmt(sLight)} 0 0 0 ${fmt(offLight)}" />
        <feMerge>
          <feMergeNode in="shadow" />
          <feMergeNode in="light" />
        </feMerge>
      `;
    }

    // -------------------------------------------------------------------------
    // Mode 3: `cinema` (虹彩显色 — Guanine Nanocrystal Iridophore Harmonization)
    // Preserves video chroma while pulling tones gently toward the desktop surface color!
    // -------------------------------------------------------------------------
    const envPull = clamp((1 - intensity) * 0.30 + 0.08, 0.08, 0.36);
    const diag = (1 - envPull) * 1.08;
    const alpha = clamp(intensity * 0.88, 0.08, 0.92);
    return `
      <feColorMatrix in="SourceGraphic" type="matrix"
        values="${fmt(diag)} 0 0 0 ${fmt(envPull * br)}
                0 ${fmt(diag)} 0 0 ${fmt(envPull * bgc)}
                0 0 ${fmt(diag)} 0 ${fmt(envPull * bb)}
                0 0 0 ${fmt(alpha)} 0" />
    `;
  }

  function computeMediaOpacity() {
    return 1.0;
  }

  function ensureGlobalSvgDefsSlot(doc) {
    let slot = doc.getElementById("gecko-global-defs-slot");
    if (!slot && doc.documentElement) {
      const svg = doc.createElementNS("http://www.w3.org/2000/svg", "svg");
      svg.id = "gecko-global-svg-defs";
      svg.setAttribute("aria-hidden", "true");
      svg.style.cssText =
        "position:fixed;top:-9999px;left:-9999px;width:0;height:0;pointer-events:none;opacity:0;";
      slot = doc.createElementNS("http://www.w3.org/2000/svg", "defs");
      slot.id = "gecko-global-defs-slot";
      svg.appendChild(slot);
      doc.documentElement.appendChild(svg);
    }
    return slot;
  }

  function applySvgFilterToMedia(svgDefsEl, mediaEl, state, options = {}) {
    if (!svgDefsEl || !mediaEl) return;
    const inner = buildFilterPrimitives(state, options);
    const doc = svgDefsEl.ownerDocument || document;
    const rootNode = svgDefsEl.getRootNode ? svgDefsEl.getRootNode() : doc;
    const isShadow = rootNode !== doc && Boolean(doc.documentElement);

    // Fast-path: do NOT tear down or recompile GPU shader if filter primitives haven't changed!
    const hasFilterNode = Boolean(
      mediaEl.__geckoFilterId &&
        svgDefsEl.firstChild &&
        (!isShadow || doc.getElementById(mediaEl.__geckoFilterId))
    );
    if (
      mediaEl.__geckoFilterKey === inner &&
      mediaEl.__geckoFilterDefs === svgDefsEl &&
      hasFilterNode
    ) {
      return;
    }

    const nextId = `gecko-f-${(++filterSeq) % 100000}`;
    const xml = `<svg xmlns="http://www.w3.org/2000/svg"><filter id="${nextId}" x="0%" y="0%" width="100%" height="100%" color-interpolation-filters="sRGB">${inner}</filter></svg>`;

    const parsed = new DOMParser().parseFromString(xml, "image/svg+xml");
    const filterNode = parsed.querySelector("filter");
    if (!filterNode) return;

    const imported = doc.importNode(filterNode, true);
    while (svgDefsEl.firstChild) {
      svgDefsEl.removeChild(svgDefsEl.firstChild);
    }
    svgDefsEl.appendChild(imported);

    // Chromium/Blink resolves CSS `filter: url(#id)` inside Shadow DOM against Light DOM `document`
    if (isShadow) {
      const globalSlot = ensureGlobalSvgDefsSlot(doc);
      if (globalSlot) {
        while (globalSlot.firstChild) {
          globalSlot.removeChild(globalSlot.firstChild);
        }
        globalSlot.appendChild(imported.cloneNode(true));
      }
    }

    mediaEl.__geckoFilterKey = inner;
    mediaEl.__geckoFilterDefs = svgDefsEl;
    mediaEl.__geckoFilterId = nextId;
    mediaEl.style.setProperty("filter", `url(#${nextId})`, "important");
  }

  function buildFeatherMaskCss(feather) {
    const f = clamp(Number(feather ?? 28), 0, 80);
    if (f <= 1) return { maskImage: "none", maskComposite: "add" };
    const pad = clamp(Math.round(f * 0.06), 0, 6);
    const full = clamp(pad + Math.round(4 + f * 0.28), 5, 34);
    const botFull = clamp(pad + Math.round(3 + f * 0.18), 4, 22);

    const maskH = `linear-gradient(to right, transparent 0%, transparent ${pad}%, #000 ${full}%, #000 ${
      100 - full
    }%, transparent ${100 - pad}%, transparent 100%)`;
    const maskV = `linear-gradient(to bottom, transparent 0%, transparent ${pad}%, #000 ${full}%, #000 ${
      100 - botFull
    }%, transparent ${100 - pad}%, transparent 100%)`;
    return {
      webkitMaskImage: `${maskH}, ${maskV}`,
      webkitMaskComposite: "source-in",
      maskImage: `${maskH}, ${maskV}`,
      maskComposite: "intersect",
    };
  }

  function buildFeatherRuleCss(selector, feather) {
    const m = buildFeatherMaskCss(feather);
    if (m.maskImage === "none") {
      return `${selector} { -webkit-mask-image: none !important; mask-image: none !important; border-radius: 12px !important; }`;
    }
    return `${selector} {
      -webkit-mask-image: ${m.webkitMaskImage} !important;
      -webkit-mask-composite: ${m.webkitMaskComposite} !important;
      mask-image: ${m.maskImage} !important;
      mask-composite: ${m.maskComposite} !important;
    }`;
  }

  const STEALTH_LOG_MODULES = ["worker::sync", "build::ast", "kernel::io", "cache::lru", "net::grpc", "sched::tick"];

  function formatStealthLogParts(rawText, nowDate) {
    const clean = String(rawText || "").replace(/\s+/g, " ").trim();
    if (!clean) return null;
    const d = nowDate || new Date();
    const ts = `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}:${String(
      d.getSeconds()
    ).padStart(2, "0")}`;
    let hash = 0;
    for (let i = 0; i < Math.min(18, clean.length); i++) {
      hash = (hash * 31 + clean.charCodeAt(i)) | 0;
    }
    const mod = STEALTH_LOG_MODULES[Math.abs(hash) % STEALTH_LOG_MODULES.length];
    return { ts, level: "INFO", mod, text: clean };
  }

  global.GeckoCore = {
    DEFAULT_STATE,
    ICONS,
    clamp,
    formatTime,
    formatStealthLogParts,
    hexToRgb,
    rgbToHex,
    lerpColor,
    getLuminance,
    deriveAutoInkColor,
    computeAutoScenePatch,
    senseDomEnvironment,
    computeMediaOpacity,
    buildFilterPrimitives,
    applySvgFilterToMedia,
    buildFeatherMaskCss,
    buildFeatherRuleCss,
  };
})(typeof window !== "undefined" ? window : globalThis);

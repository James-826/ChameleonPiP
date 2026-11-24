/**
 * ChameleonPiP (变色龙画中画) — Telemetry, Custom SVG Crests, Medals, Flags & Cloud Arena Client
 * Uses 100% custom-crafted vector SVG emblems, metallic podium medals, and crisp vector mini-flags.
 */
(function (global) {
  "use strict";

  const STORAGE_KEY = "chameleon_arena_v2";
  const API_BASE_KEY = "chameleon_api_base";
  const DEFAULT_API_BASE = "https://chameleonpip.site";

  function getApiBase() {
    try {
      const saved = localStorage.getItem(API_BASE_KEY);
      if (saved && saved.startsWith("https://") && !saved.includes("trycloudflare.com")) {
        return saved.replace(/\/+$/, "");
      }
      return DEFAULT_API_BASE;
    } catch (_) {
      return DEFAULT_API_BASE;
    }
  }

  const SVG_ICONS = {
    streak: `<svg viewBox="0 0 24 24" width="18" height="18" fill="none">
      <defs>
        <linearGradient id="g-streak" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stop-color="#34d399"/>
          <stop offset="100%" stop-color="#06b6d4"/>
        </linearGradient>
      </defs>
      <rect x="2" y="2" width="20" height="20" rx="6" fill="url(#g-streak)" fill-opacity="0.14" stroke="url(#g-streak)" stroke-width="1.4"/>
      <path d="M13 5.5L7.5 13h4.2l-.7 5.5L16.5 11h-4.2L13 5.5z" fill="url(#g-streak)"/>
    </svg>`,
    record: `<svg viewBox="0 0 24 24" width="18" height="18" fill="none">
      <defs>
        <linearGradient id="g-rec" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stop-color="#fbbf24"/>
          <stop offset="100%" stop-color="#f59e0b"/>
        </linearGradient>
      </defs>
      <rect x="2" y="2" width="20" height="20" rx="6" fill="url(#g-rec)" fill-opacity="0.14" stroke="url(#g-rec)" stroke-width="1.4"/>
      <path d="M8 6.5h8v3.2c0 2.2-1.8 4-4 4s-4-1.8-4-4V6.5z" stroke="url(#g-rec)" stroke-width="1.6"/>
      <path d="M9.5 17.5h5M12 13.7v3.8" stroke="url(#g-rec)" stroke-width="1.6" stroke-linecap="round"/>
    </svg>`,
    vault: `<svg viewBox="0 0 24 24" width="18" height="18" fill="none">
      <defs>
        <linearGradient id="g-vault" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stop-color="#38bdf8"/>
          <stop offset="100%" stop-color="#818cf8"/>
        </linearGradient>
      </defs>
      <rect x="2" y="2" width="20" height="20" rx="6" fill="url(#g-vault)" fill-opacity="0.14" stroke="url(#g-vault)" stroke-width="1.4"/>
      <circle cx="12" cy="12" r="5" stroke="url(#g-vault)" stroke-width="1.6"/>
      <circle cx="12" cy="12" r="1.8" fill="url(#g-vault)"/>
    </svg>`,
    swords: `<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><polyline points="14.5 17.5 3 6 3 3 6 3 17.5 14.5"/><line x1="13" y1="19" x2="19" y2="13"/><line x1="16" y1="16" x2="20" y2="20"/><polyline points="14.5 6.5 18 3 21 3 21 6 17.5 9.5"/><line x1="5" y1="14" x2="9" y2="18"/></svg>`,
    layers: `<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><polygon points="12 2 2 7 12 12 22 7 12 2"/><polyline points="2 17 12 22 22 17"/><polyline points="2 12 12 17 22 12"/></svg>`,
  };

  // Crafted Vector Mini-Flags (18x13 rounded rect with crisp geometry & inner rim)
  function renderFlagSvg(code) {
    const c = String(code || "CN").toUpperCase();
    let inner = "";
    if (c === "CN" || c === "HK") {
      inner = `
        <rect width="18" height="13" fill="#de2910"/>
        <polygon points="4.2,2.2 4.8,3.9 6.5,3.9 5.1,4.9 5.6,6.6 4.2,5.5 2.8,6.6 3.3,4.9 1.9,3.9 3.6,3.9" fill="#ffde00"/>
        <circle cx="7.8" cy="2.1" r="0.55" fill="#ffde00"/>
        <circle cx="9.0" cy="3.4" r="0.55" fill="#ffde00"/>
        <circle cx="8.9" cy="5.2" r="0.55" fill="#ffde00"/>
        <circle cx="7.6" cy="6.4" r="0.55" fill="#ffde00"/>
      `;
    } else if (c === "JP") {
      inner = `
        <rect width="18" height="13" fill="#f8fafc"/>
        <circle cx="9" cy="6.5" r="3.4" fill="#bc002d"/>
      `;
    } else if (c === "US") {
      inner = `
        <rect width="18" height="13" fill="#b22234"/>
        <path d="M0,2.5h18 M0,5.5h18 M0,8.5h18 M0,11.5h18" stroke="#ffffff" stroke-width="1.3"/>
        <rect width="8.2" height="7" fill="#3c3b6e"/>
        <circle cx="2.4" cy="2.3" r="0.55" fill="#fff"/>
        <circle cx="5.6" cy="2.3" r="0.55" fill="#fff"/>
        <circle cx="4.0" cy="3.6" r="0.55" fill="#fff"/>
        <circle cx="2.4" cy="4.9" r="0.55" fill="#fff"/>
        <circle cx="5.6" cy="4.9" r="0.55" fill="#fff"/>
      `;
    } else if (c === "SG") {
      inner = `
        <rect width="18" height="6.5" fill="#ef3340"/>
        <rect y="6.5" width="18" height="6.5" fill="#f8fafc"/>
        <circle cx="4.6" cy="3.3" r="2.1" fill="#fff"/>
        <circle cx="5.3" cy="3.3" r="1.9" fill="#ef3340"/>
      `;
    } else if (c === "UK") {
      inner = `
        <rect width="18" height="13" fill="#012169"/>
        <path d="M0,0 L18,13 M18,0 L0,13" stroke="#ffffff" stroke-width="2.2"/>
        <path d="M0,0 L18,13 M18,0 L0,13" stroke="#c8102e" stroke-width="1.1"/>
        <path d="M9,0v13 M0,6.5h18" stroke="#ffffff" stroke-width="3.2"/>
        <path d="M9,0v13 M0,6.5h18" stroke="#c8102e" stroke-width="1.8"/>
      `;
    } else if (c === "DE") {
      inner = `
        <rect width="18" height="4.4" fill="#111827"/>
        <rect y="4.3" width="18" height="4.4" fill="#dd0000"/>
        <rect y="8.6" width="18" height="4.4" fill="#ffce00"/>
      `;
    } else {
      inner = `<rect width="18" height="13" fill="#1e293b"/>`;
    }

    return `<svg viewBox="0 0 18 13" width="18" height="13" style="border-radius:3px;flex-shrink:0;box-shadow:0 0 0 1px rgba(255,255,255,0.16)">${inner}</svg>`;
  }

  // Crafted Metallic Podium Medals (#1 Gold Crown, #2 Platinum Shield, #3 Bronze Crest)
  function renderPodiumBadgeSvg(pos) {
    if (pos === 1) {
      return `<svg viewBox="0 0 28 28" width="26" height="26" fill="none">
        <defs>
          <linearGradient id="m-gold" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0%" stop-color="#fef08a"/>
            <stop offset="50%" stop-color="#f59e0b"/>
            <stop offset="100%" stop-color="#b45309"/>
          </linearGradient>
        </defs>
        <polygon points="14,2 24,7.8 24,20.2 14,26 4,20.2 4,7.8" fill="url(#m-gold)" fill-opacity="0.2" stroke="url(#m-gold)" stroke-width="1.6"/>
        <path d="M9.2 17.5h9.6L20 11l-3.2 2.4L14 9.5l-2.8 3.9L8 11l1.2 6.5z" fill="url(#m-gold)"/>
      </svg>`;
    }
    if (pos === 2) {
      return `<svg viewBox="0 0 28 28" width="26" height="26" fill="none">
        <defs>
          <linearGradient id="m-silv" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0%" stop-color="#f8fafc"/>
            <stop offset="55%" stop-color="#94a3b8"/>
            <stop offset="100%" stop-color="#475569"/>
          </linearGradient>
        </defs>
        <polygon points="14,2.5 23.5,8 23.5,20 14,25.5 4.5,20 4.5,8" fill="url(#m-silv)" fill-opacity="0.18" stroke="url(#m-silv)" stroke-width="1.5"/>
        <text x="14" y="18" text-anchor="middle" fill="#f1f5f9" font-size="11.5" font-weight="800" font-family="ui-monospace,SFMono-Regular,monospace">2</text>
      </svg>`;
    }
    if (pos === 3) {
      return `<svg viewBox="0 0 28 28" width="26" height="26" fill="none">
        <defs>
          <linearGradient id="m-brz" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0%" stop-color="#fed7aa"/>
            <stop offset="55%" stop-color="#ea580c"/>
            <stop offset="100%" stop-color="#9a3412"/>
          </linearGradient>
        </defs>
        <polygon points="14,2.5 23.5,8 23.5,20 14,25.5 4.5,20 4.5,8" fill="url(#m-brz)" fill-opacity="0.18" stroke="url(#m-brz)" stroke-width="1.5"/>
        <text x="14" y="18" text-anchor="middle" fill="#fed7aa" font-size="11.5" font-weight="800" font-family="ui-monospace,SFMono-Regular,monospace">3</text>
      </svg>`;
    }
    return `<span style="display:inline-flex;align-items:center;justify-content:center;width:26px;height:22px;border-radius:5px;background:rgba(255,255,255,0.04);border:1px solid rgba(255,255,255,0.07);font:700 11px ui-monospace,SFMono-Regular,monospace;color:#64748b">${String(pos).padStart(2, "0")}</span>`;
  }

  // Bespoke 10-Tier Vector Rank Crests (Valorant / Apex / Linear style geometric emblems)
  function renderRankCrestSvg(level, size = 22) {
    const lv = Math.max(1, Math.min(10, Number(level || 1)));
    const palettes = {
      1: ["#94a3b8", "#475569"],
      2: ["#34d399", "#059669"],
      3: ["#38bdf8", "#0284c7"],
      4: ["#818cf8", "#4f46e5"],
      5: ["#fbbf24", "#d97706"],
      6: ["#fb7185", "#e11d48"],
      7: ["#c084fc", "#7e22ce"],
      8: ["#2dd4bf", "#0d9488"],
      9: ["#fde047", "#ca8a04"],
      10: ["#f43f5e", "#f59e0b"],
    };
    const [c1, c2] = palettes[lv];
    const gid = `rk-${lv}-${size}`;

    let centerGlyph = "";
    if (lv <= 2) {
      // Chevron sprout / prism
      centerGlyph = `<path d="M8 14.5L12 9.5l4 5M9.5 16.5L12 13.5l2.5 3" stroke="url(#${gid})" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/>`;
    } else if (lv <= 4) {
      // Optical diamond reticle
      centerGlyph = `<polygon points="12,6.5 17,12 12,17.5 7,12" stroke="url(#${gid})" stroke-width="1.6" fill="url(#${gid})" fill-opacity="0.25"/><circle cx="12" cy="12" r="1.8" fill="${c1}"/>`;
    } else if (lv <= 6) {
      // Twin star wings + core
      centerGlyph = `<path d="M12 6l2.1 4.2L18.5 12l-4.4 1.8L12 18l-2.1-4.2L5.5 12l4.4-1.8L12 6z" fill="url(#${gid})"/>`;
    } else if (lv <= 8) {
      // Holographic Chameleon Eye + Orbit
      centerGlyph = `<circle cx="12" cy="12" r="4.8" stroke="url(#${gid})" stroke-width="1.6"/><circle cx="12" cy="12" r="2.1" fill="${c1}"/><path d="M6.5 8.5L12 5.5l5.5 3" stroke="${c1}" stroke-width="1.4" stroke-linecap="round"/>`;
    } else {
      // Sovereign Crown + Radiant Core (Lv.9 & Lv.10)
      centerGlyph = `<path d="M7.2 16.2h9.6L18.2 9.8l-3.1 2.3L12 7.8 8.9 12.1 5.8 9.8l1.4 6.4z" fill="url(#${gid})"/><circle cx="12" cy="6.2" r="1.1" fill="#fff"/>`;
    }

    return `<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="none" style="flex-shrink:0">
      <defs>
        <linearGradient id="${gid}" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stop-color="${c1}"/>
          <stop offset="100%" stop-color="${c2}"/>
        </linearGradient>
      </defs>
      <polygon points="12,1.8 21,6.8 21,17.2 12,22.2 3,17.2 3,6.8" fill="url(#${gid})" fill-opacity="0.16" stroke="url(#${gid})" stroke-width="1.5"/>
      ${centerGlyph}
    </svg>`;
  }

  const RANKS = [
    { level: 1, code: "Lv.1", title: "透明实习生", minMin: 0, color: "#94a3b8", desc: "初入变色潜伏" },
    { level: 2, code: "Lv.2", title: "工位幼龙", minMin: 15, color: "#34d399", desc: "基础底色融合" },
    { level: 3, code: "Lv.3", title: "拟态学徒", minMin: 60, color: "#38bdf8", desc: "代码文档自如切换" },
    { level: 4, code: "Lv.4", title: "拟态猎手", minMin: 180, color: "#818cf8", desc: "三米外无法察觉" },
    { level: 5, code: "Lv.5", title: "幻影魔术师", minMin: 480, color: "#fbbf24", desc: "撞色背景无缝隐形" },
    { level: 6, code: "Lv.6", title: "死角艺术家", minMin: 1200, color: "#fb7185", desc: "余光与截屏双免疫" },
    { level: 7, code: "Lv.7", title: "带薪修行师", minMin: 3000, color: "#c084fc", desc: "周会同步追番" },
    { level: 8, code: "Lv.8", title: "暗影变色龙", minMin: 7200, color: "#2dd4bf", desc: "与屏幕融为一体" },
    { level: 9, code: "Lv.9", title: "殿堂级变色龙", minMin: 18000, color: "#f59e0b", desc: "全球前 0.5% 宗师" },
    { level: 10, code: "Lv.10", title: "摸鱼之神", minMin: 36000, color: "#f43f5e", desc: "万物皆可融入" },
  ];

  const CITIES = [
    { city: "上海", country: "中国", regionCode: "CN" },
    { city: "深圳", country: "中国", regionCode: "CN" },
    { city: "北京", country: "中国", regionCode: "CN" },
    { city: "杭州", country: "中国", regionCode: "CN" },
    { city: "广州", country: "中国", regionCode: "CN" },
    { city: "成都", country: "中国", regionCode: "CN" },
    { city: "香港", country: "中国", regionCode: "HK" },
    { city: "东京", country: "日本", regionCode: "JP" },
    { city: "硅谷", country: "美国", regionCode: "US" },
    { city: "纽约", country: "美国", regionCode: "US" },
    { city: "新加坡", country: "新加坡", regionCode: "SG" },
    { city: "伦敦", country: "英国", regionCode: "UK" },
    { city: "柏林", country: "德国", regionCode: "DE" },
  ];

  const FALLBACK_RIVALS = [
    { userId: "seed-sh-1", nickname: "Lin_Optics", city: "上海", country: "中国", regionCode: "CN", industry: "AI / 算法", mode: "光影 55%", bestStreakSeconds: 14820, todaySeconds: 19400, totalSeconds: 1290000, pkElo: 1680, live: true },
    { userId: "seed-sz-1", nickname: "Nanshan_Ghost", city: "深圳", country: "中国", regionCode: "CN", industry: "互联网", mode: "浮雕 62%", bestStreakSeconds: 13260, todaySeconds: 17900, totalSeconds: 1152000, pkElo: 1620, live: true },
    { userId: "seed-tk-1", nickname: "Shibuya_Camo", city: "东京", country: "日本", regionCode: "JP", industry: "游戏引擎", mode: "光影 48%", bestStreakSeconds: 12540, todaySeconds: 16800, totalSeconds: 1104000, pkElo: 1595, live: true },
    { userId: "seed-sv-1", nickname: "Cupertino_Dev", city: "硅谷", country: "美国", regionCode: "US", industry: "系统架构", mode: "彩透 42%", bestStreakSeconds: 11100, todaySeconds: 15200, totalSeconds: 876000, pkElo: 1540, live: true },
    { userId: "seed-bj-1", nickname: "Haidian_Runner", city: "北京", country: "中国", regionCode: "CN", industry: "互联网", mode: "光影 60%", bestStreakSeconds: 9840, todaySeconds: 14500, totalSeconds: 774000, pkElo: 1495, live: true },
    { userId: "seed-hz-1", nickname: "Xixi_Shader", city: "杭州", country: "中国", regionCode: "CN", industry: "电商平台", mode: "浮雕 58%", bestStreakSeconds: 8760, todaySeconds: 13100, totalSeconds: 588000, pkElo: 1450, live: true },
    { userId: "seed-sg-1", nickname: "MarinaQuant", city: "新加坡", country: "新加坡", regionCode: "SG", industry: "量化金融", mode: "光影 38%", bestStreakSeconds: 7920, todaySeconds: 11800, totalSeconds: 492000, pkElo: 1420, live: false },
    { userId: "seed-ld-1", nickname: "CanaryWharf_K", city: "伦敦", country: "英国", regionCode: "UK", industry: "金融投行", mode: "浮雕 50%", bestStreakSeconds: 6840, todaySeconds: 10200, totalSeconds: 384000, pkElo: 1385, live: true },
    { userId: "seed-sh-2", nickname: "Caohejing_Zero", city: "上海", country: "中国", regionCode: "CN", industry: "游戏引擎", mode: "光影 58%", bestStreakSeconds: 5520, todaySeconds: 8900, totalSeconds: 306000, pkElo: 1350, live: true },
    { userId: "seed-sh-3", nickname: "Lujiazui_Macro", city: "上海", country: "中国", regionCode: "CN", industry: "量化金融", mode: "浮雕 45%", bestStreakSeconds: 3780, todaySeconds: 6400, totalSeconds: 204000, pkElo: 1310, live: true },
  ];

  function todayKey() {
    const d = new Date();
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
  }

  function setApiBase(url) {
    try {
      const clean = String(url || DEFAULT_API_BASE).trim().replace(/\/+$/, "");
      localStorage.setItem(API_BASE_KEY, clean || DEFAULT_API_BASE);
      return clean || DEFAULT_API_BASE;
    } catch (_) {
      return DEFAULT_API_BASE;
    }
  }

  function defaultProfile() {
    const rand = 1000 + Math.floor(Math.random() * 8999);
    return {
      userId: "u_" + Math.random().toString(36).slice(2, 10),
      nickname: "Chameleon_" + rand,
      city: "上海",
      country: "中国",
      regionCode: "CN",
      industry: "互联网",
      hourlyWage: 85,
      totalSeconds: 0,
      todayDate: todayKey(),
      todaySeconds: 0,
      currentStreakSeconds: 0,
      bestStreakSeconds: 0,
      bossDodges: 0,
      pkWins: 0,
      pkLosses: 0,
      pkElo: 1200,
    };
  }

  function loadProfile() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) {
        const init = defaultProfile();
        saveProfile(init);
        return init;
      }
      const parsed = { ...defaultProfile(), ...JSON.parse(raw) };
      if (!parsed.userId) parsed.userId = "u_" + Math.random().toString(36).slice(2, 10);
      if (parsed.todayDate !== todayKey()) {
        parsed.todayDate = todayKey();
        parsed.todaySeconds = 0;
      }
      return parsed;
    } catch (_) {
      return defaultProfile();
    }
  }

  function saveProfile(p) {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(p));
    } catch (_) {}
    return p;
  }

  function getRankForSeconds(totalSec) {
    const mins = Math.max(0, Number(totalSec || 0)) / 60;
    let current = RANKS[0];
    let next = null;
    for (let i = 0; i < RANKS.length; i++) {
      if (mins >= RANKS[i].minMin) {
        current = RANKS[i];
        next = RANKS[i + 1] || null;
      }
    }
    let progressPct = 100;
    let remainMin = 0;
    if (next) {
      const span = Math.max(1, next.minMin - current.minMin);
      progressPct = Math.max(0, Math.min(100, ((mins - current.minMin) / span) * 100));
      remainMin = Math.max(1, Math.ceil(next.minMin - mins));
    }
    return { current, next, progressPct, remainMin };
  }

  function formatDuration(sec, compact = true) {
    const s = Math.max(0, Math.floor(Number(sec || 0)));
    const h = Math.floor(s / 3600);
    const m = Math.floor((s % 3600) / 60);
    const rem = s % 60;
    if (compact) {
      return h > 0
        ? `${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}:${String(rem).padStart(2, "0")}`
        : `${String(m).padStart(2, "0")}:${String(rem).padStart(2, "0")}`;
    }
    if (h > 0) return `${h}h ${m}m`;
    return `${m}m ${rem}s`;
  }

  const MEMBERSHIP_STORAGE_KEY = "chameleon_membership_v1";
  const DEVICE_ID_STORAGE_KEY = "chameleon_device_id_v1";

  const PRO_FEATURE_CATALOG = [
    { key: "optical_modes", name: "全部 3 种变色模式（变色融合 / 浮雕隐身 / 彩透变色）", free: "永久免费", pro: "永久免费" },
    { key: "anti_peek_radar", name: "AI 摄像头背后防偷窥雷达（Apple Vision 100% 本地）", free: "永久免费 · 不限时", pro: "永久免费 · 不限时" },
    { key: "screen_stealth", name: "腾讯会议 / 飞书 / Zoom / 录屏系统级共享隐身", free: "永久免费 · 不限时", pro: "永久免费 · 不限时" },
    { key: "built_in_web", name: "免插件网页直连播放 + 代码终端日志伪装字幕条", free: "永久免费", pro: "永久免费" },
    { key: "pk_unlimited", name: "无限 1v1 耐力 PK + 4位暗号同事房 + 百人淘汰赛", free: "永久免费 · 无限畅玩", pro: "永久免费 · 无限畅玩" },
    { key: "pro_badge", name: "全球 / 同城排行榜专属 SUP · VIP · MAX 鎏金支持者铭牌", free: "标准段位徽章", pro: "点亮专属支持者金标" },
  ];

  const PRICING_PLANS = [
    {
      id: "coffee",
      name: "随心赞赏 · 一杯冰美式",
      priceCny: "¥9.9",
      priceUsd: "$2.99",
      period: "纯自愿赞赏",
      tag: "全功能已免费 · 感谢心意",
      desc: "所有功能均已 100% 永久免费开放。若它让你上班快乐了一点点，请作者喝杯美式并点亮榜单 SUP 金标",
    },
    {
      id: "latte",
      name: "铁杆支持 · 双杯拿铁",
      priceCny: "¥19.9",
      priceUsd: "$5.99",
      period: "纯自愿赞赏",
      tag: "最受欢迎 · 助力持续迭代",
      recommended: true,
      desc: "全功能永久免费无套路。支持服务器日常开销、点亮专属 VIP 鎏金徽章并优先响应你的新点子",
    },
    {
      id: "patron",
      name: "创始赞助 · 荣誉殿堂",
      priceCny: "¥49",
      priceUsd: "$14.9",
      period: "纯自愿赞赏",
      tag: "致谢独立开源赞助人",
      desc: "纯粹的支持与认可，点亮榜单专属 MAX 鎏金标识并列入官网致谢支持者名单",
    },
  ];

  function getDeviceId() {
    try {
      let id = localStorage.getItem(DEVICE_ID_STORAGE_KEY);
      if (!id) {
        id = "dev_" + Math.random().toString(36).slice(2, 10) + Date.now().toString(36).slice(-4);
        localStorage.setItem(DEVICE_ID_STORAGE_KEY, id);
      }
      return id;
    } catch (_) {
      return "dev_local";
    }
  }

  function defaultMembership() {
    return {
      tier: "free",
      isPro: false,
      plan: "free",
      planName: "全功能免费版",
      expiresAt: null,
      trialUsed: false,
      dailyPkLimit: -1,
      dailyPkUsed: 0,
      dailyPkRemaining: 999,
      updatedAt: 0,
    };
  }

  function loadMembership() {
    try {
      const raw = localStorage.getItem(MEMBERSHIP_STORAGE_KEY);
      if (!raw) return defaultMembership();
      const m = { ...defaultMembership(), ...JSON.parse(raw) };
      if (m.tier === "pro" && m.expiresAt && Date.now() > m.expiresAt) {
        m.tier = "free";
        m.isPro = false;
        m.plan = "free";
        m.planName = "Free 免费版";
        saveMembership(m);
      } else {
        m.isPro = m.tier === "pro" || m.tier === "lifetime";
      }
      return m;
    } catch (_) {
      return defaultMembership();
    }
  }

  function saveMembership(m) {
    const clean = {
      ...defaultMembership(),
      ...m,
      isPro: m?.tier === "pro" || m?.tier === "lifetime",
      updatedAt: Date.now(),
    };
    try {
      localStorage.setItem(MEMBERSHIP_STORAGE_KEY, JSON.stringify(clean));
    } catch (_) {}
    try {
      if (typeof chrome !== "undefined" && chrome?.storage?.local) {
        chrome.storage.local.set({ geckoMembership: clean });
      }
    } catch (_) {}
    return clean;
  }

  function isProMember(m) {
    const cur = m || loadMembership();
    if (cur.tier === "lifetime") return true;
    if (cur.tier === "pro") return !cur.expiresAt || Date.now() <= cur.expiresAt;
    return false;
  }

  function hasFeature() {
    return true;
  }

  async function refreshMembership(userId) {
    const uid = userId || loadProfile().userId;
    try {
      const res = await fetch(`${getApiBase()}/api/license/status?userId=${encodeURIComponent(uid)}`);
      if (!res.ok) return loadMembership();
      const data = await res.json();
      if (data?.ok && data.entitlement) {
        return saveMembership(data.entitlement);
      }
    } catch (_) {}
    return loadMembership();
  }

  async function claimHonorSupporter(userId) {
    const uid = userId || loadProfile().userId;
    try {
      const res = await fetch(`${getApiBase()}/api/supporter/honor`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ userId: uid }),
      });
      const data = await res.json();
      if (data?.entitlement) saveMembership(data.entitlement);
      return data;
    } catch (_) {
      return { ok: false, message: "网络异常，无法连接服务器，请稍后再试。" };
    }
  }

  async function startFreeTrial(userId) {
    return claimHonorSupporter(userId);
  }

  async function activateLicenseKey(key, userId) {
    const uid = userId || loadProfile().userId;
    try {
      const res = await fetch(`${getApiBase()}/api/license/activate`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ key: String(key || "").trim(), userId: uid, deviceId: getDeviceId() }),
      });
      const data = await res.json();
      if (data?.ok && data.entitlement) saveMembership(data.entitlement);
      return data;
    } catch (_) {
      return { ok: false, message: "无法连接鉴权服务器，请确认网络畅通后重试。" };
    }
  }

  async function fetchFuelStatus(userId) {
    const uid = userId || loadProfile().userId;
    try {
      const res = await fetch(`${getApiBase()}/api/fuel/status?userId=${encodeURIComponent(uid)}`);
      if (!res.ok) return null;
      const data = await res.json();
      if (data?.ok && data.entitlement) saveMembership(data.entitlement);
      return data;
    } catch (_) {
      return null;
    }
  }

  async function claimDailyFuel(userId, taskType = "daily_30m") {
    const uid = userId || loadProfile().userId;
    try {
      const res = await fetch(`${getApiBase()}/api/fuel/claim`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ userId: uid, taskType }),
      });
      const data = await res.json();
      if (data?.entitlement) saveMembership(data.entitlement);
      return data;
    } catch (_) {
      return { ok: false, message: "网络异常，无法连接能量补给站服务器。" };
    }
  }

  async function claimReferralBonus(inviterId, inviteeId) {
    const uid = inviteeId || loadProfile().userId;
    try {
      const res = await fetch(`${getApiBase()}/api/fuel/referral`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ inviterId, inviteeId: uid }),
      });
      const data = await res.json();
      if (data?.entitlement) saveMembership(data.entitlement);
      return data;
    } catch (_) {
      return { ok: false, message: "网络异常，无法验证好友邀请。" };
    }
  }

  function formatExpiryDate(ts) {
    if (!ts) return "永久有效";
    const d = new Date(ts);
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
  }

  function renderProBadgeSvg(tier = "pro", plan = "") {
    const isPatron = plan === "patron" || (tier === "lifetime" && plan !== "coffee" && plan !== "latte");
    const isLatte = plan === "latte";
    const isCoffee = plan === "coffee";
    const label = isPatron ? "MAX" : isLatte ? "VIP" : isCoffee ? "SUP" : "PRO";
    const gStart = isPatron ? "#fef08a" : isLatte ? "#fde68a" : "#fcd34d";
    const gMid = "#f59e0b";
    const gEnd = isPatron ? "#d97706" : "#b45309";
    return `<svg viewBox="0 0 34 15" width="34" height="15" style="flex-shrink:0;vertical-align:middle" aria-label="${label}">
      <defs>
        <linearGradient id="pg-${label}" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stop-color="${gStart}"/>
          <stop offset="55%" stop-color="${gMid}"/>
          <stop offset="100%" stop-color="${gEnd}"/>
        </linearGradient>
      </defs>
      <rect x="0.6" y="0.6" width="32.8" height="13.8" rx="4" fill="url(#pg-${label})" fill-opacity="0.2" stroke="url(#pg-${label})" stroke-width="1.1"/>
      <text x="17" y="10.6" text-anchor="middle" fill="#fde68a" font-size="8.2" font-weight="800" letter-spacing="0.06em" font-family="ui-monospace,SFMono-Regular,Menlo,sans-serif">${label}</text>
    </svg>`;
  }

  function computeSalaryEarned(seconds, hourlyWage = 85) {
    return ((Math.max(0, seconds) / 3600) * Math.max(0, hourlyWage)).toFixed(2);
  }

  function normalizeLeaderboardItems(rawItems, profile) {
    const myMem = loadMembership();
    return rawItems.map((r, idx) => {
      const isMe = Boolean(r.isMe || r.userId === profile.userId);
      const tier = isMe ? myMem.tier : (r.tier || "free");
      const isPro = isMe ? isProMember(myMem) : Boolean(r.isPro || tier === "pro" || tier === "lifetime");
      return {
        pos: r.pos || idx + 1,
        userId: r.userId,
        isMe,
        nickname: r.nickname,
        city: r.city,
        country: r.country,
        regionCode: r.regionCode || "CN",
        industry: r.industry || "互联网",
        mode: r.mode || "光影 58%",
        streak: Math.max(r.bestStreakSeconds || 0, r.currentStreakSeconds || 0),
        today: r.todaySeconds || 0,
        pkElo: r.pkElo || 1200,
        rankInfo: getRankForSeconds(r.totalSeconds || 1800).current,
        tier,
        isPro,
        live: Boolean(r.live),
      };
    });
  }

  function buildFallbackLeaderboard(profile, scope = "city", metric = "streak") {
    const meBest = Math.max(profile.bestStreakSeconds || 0, profile.currentStreakSeconds || 0);
    const list = FALLBACK_RIVALS.filter((r) => {
      if (scope === "city") return r.city === profile.city;
      if (scope === "country") return r.country === profile.country;
      return true;
    }).map((r) => ({ ...r, isMe: false }));

    list.push({
      userId: profile.userId,
      isMe: true,
      nickname: profile.nickname,
      city: profile.city,
      country: profile.country,
      regionCode: profile.regionCode || "CN",
      industry: profile.industry || "互联网",
      mode: "光影 58%",
      bestStreakSeconds: meBest,
      todaySeconds: profile.todaySeconds || 0,
      totalSeconds: profile.totalSeconds || 0,
      pkElo: profile.pkElo || 1200,
      live: true,
    });

    list.sort((a, b) => {
      if (metric === "today") return b.todaySeconds - a.todaySeconds;
      if (metric === "elo") return b.pkElo - a.pkElo;
      return b.bestStreakSeconds - a.bestStreakSeconds;
    });
    return normalizeLeaderboardItems(list, profile);
  }

  global.ChameleonStats = {
    STORAGE_KEY,
    MEMBERSHIP_STORAGE_KEY,
    DEFAULT_API_BASE,
    SVG_ICONS,
    RANKS,
    CITIES,
    FALLBACK_RIVALS,
    PRO_FEATURE_CATALOG,
    PRICING_PLANS,
    renderFlagSvg,
    renderPodiumBadgeSvg,
    renderRankCrestSvg,
    renderProBadgeSvg,
    getApiBase,
    setApiBase,
    getDeviceId,
    loadProfile,
    saveProfile,
    loadMembership,
    saveMembership,
    isProMember,
    hasFeature,
    refreshMembership,
    claimHonorSupporter,
    startFreeTrial,
    activateLicenseKey,
    fetchFuelStatus,
    claimDailyFuel,
    claimReferralBonus,
    formatExpiryDate,
    getRankForSeconds,
    formatDuration,
    computeSalaryEarned,
    normalizeLeaderboardItems,
    buildFallbackLeaderboard,
  };
})(typeof window !== "undefined" ? window : globalThis);

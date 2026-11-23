#!/usr/bin/env node
/**
 * ChameleonPiP Global Arena Server (Zero-Dependency Node.js HTTP + WebSocket Server)
 *
 * Provides real multi-user persistence, City/Country/Global leaderboards, and
 * real-time 1v1 WebSocket matchmaking & room-code endurance duels.
 *
 * Run locally or on any server (Railway / Render / Fly.io / VPS):
 *   PORT=51938 node server/arena-server.js
 */
"use strict";

const http = require("http");
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");
const { URL } = require("url");

const PORT = Number(process.env.PORT || 51938);
const DATA_DIR = path.join(__dirname, "data");
const DB_FILE = path.join(DATA_DIR, "arena-db.json");
const LICENSES_FILE = path.join(DATA_DIR, "licenses-db.json");
const ADMIN_KEY = process.env.CHAMELEON_ADMIN_KEY || "";
const FREE_DAILY_PK_LIMIT = 3;

const PLAN_CATALOG = {
  trial: { tier: "pro", plan: "trial", planName: "支持者 3天畅享体验", durationDays: 3, maxDevices: 2 },
  coffee: { tier: "lifetime", plan: "coffee", planName: "一杯美式 · 永久支持者", durationDays: 0, maxDevices: 2 },
  latte: { tier: "lifetime", plan: "latte", planName: "双杯拿铁 · 永久进阶支持者", durationDays: 0, maxDevices: 3 },
  patron: { tier: "lifetime", plan: "patron", planName: "创始赞助 · 荣誉殿堂支持者", durationDays: 0, maxDevices: 5 },
  // Legacy plans kept 100% compatible with already-issued keys
  monthly: { tier: "pro", plan: "monthly", planName: "支持者月度体验版", durationDays: 30, maxDevices: 2 },
  yearly: { tier: "pro", plan: "yearly", planName: "支持者年度畅享版", durationDays: 365, maxDevices: 2 },
  lifetime: { tier: "lifetime", plan: "lifetime", planName: "早鸟永久支持者 MAX", durationDays: 0, maxDevices: 3 },
};

const SEED_PLAYERS = [
  { userId: "seed-sh-1", nickname: "Lin_Optics", city: "上海", country: "中国", regionCode: "CN", industry: "AI / 算法", mode: "光影 55%", currentStreakSeconds: 8420, bestStreakSeconds: 14820, todaySeconds: 19400, totalSeconds: 1290000, pkElo: 1680, pkWins: 29, pkLosses: 4, tier: "lifetime", seeded: true },
  { userId: "seed-sz-1", nickname: "Nanshan_Ghost", city: "深圳", country: "中国", regionCode: "CN", industry: "互联网", mode: "浮雕 62%", currentStreakSeconds: 6910, bestStreakSeconds: 13260, todaySeconds: 17900, totalSeconds: 1152000, pkElo: 1620, pkWins: 24, pkLosses: 6, tier: "pro", seeded: true },
  { userId: "seed-tk-1", nickname: "Shibuya_Camo", city: "东京", country: "日本", regionCode: "JP", industry: "游戏引擎", mode: "光影 48%", currentStreakSeconds: 5840, bestStreakSeconds: 12540, todaySeconds: 16800, totalSeconds: 1104000, pkElo: 1595, pkWins: 21, pkLosses: 5, tier: "pro", seeded: true },
  { userId: "seed-sv-1", nickname: "Cupertino_Dev", city: "硅谷", country: "美国", regionCode: "US", industry: "系统架构", mode: "彩透 42%", currentStreakSeconds: 4920, bestStreakSeconds: 11100, todaySeconds: 15200, totalSeconds: 876000, pkElo: 1540, pkWins: 19, pkLosses: 7, tier: "lifetime", seeded: true },
  { userId: "seed-bj-1", nickname: "Haidian_Runner", city: "北京", country: "中国", regionCode: "CN", industry: "互联网", mode: "光影 60%", currentStreakSeconds: 4380, bestStreakSeconds: 9840, todaySeconds: 14500, totalSeconds: 774000, pkElo: 1495, pkWins: 17, pkLosses: 6, tier: "free", seeded: true },
  { userId: "seed-hz-1", nickname: "Xixi_Shader", city: "杭州", country: "中国", regionCode: "CN", industry: "电商平台", mode: "浮雕 58%", currentStreakSeconds: 3690, bestStreakSeconds: 8760, todaySeconds: 13100, totalSeconds: 588000, pkElo: 1450, pkWins: 15, pkLosses: 8, tier: "pro", seeded: true },
  { userId: "seed-sg-1", nickname: "MarinaQuant", city: "新加坡", country: "新加坡", regionCode: "SG", industry: "量化金融", mode: "光影 38%", currentStreakSeconds: 0, bestStreakSeconds: 7920, todaySeconds: 11800, totalSeconds: 492000, pkElo: 1420, pkWins: 14, pkLosses: 6, tier: "free", seeded: true },
  { userId: "seed-ld-1", nickname: "CanaryWharf_K", city: "伦敦", country: "英国", regionCode: "UK", industry: "金融投行", mode: "浮雕 50%", currentStreakSeconds: 2980, bestStreakSeconds: 6840, todaySeconds: 10200, totalSeconds: 384000, pkElo: 1385, pkWins: 12, pkLosses: 7, tier: "free", seeded: true },
  { userId: "seed-sh-2", nickname: "Caohejing_Zero", city: "上海", country: "中国", regionCode: "CN", industry: "游戏引擎", mode: "光影 58%", currentStreakSeconds: 2410, bestStreakSeconds: 5520, todaySeconds: 8900, totalSeconds: 306000, pkElo: 1350, pkWins: 10, pkLosses: 5, tier: "pro", seeded: true },
  { userId: "seed-sh-3", nickname: "Lujiazui_Macro", city: "上海", country: "中国", regionCode: "CN", industry: "量化金融", mode: "浮雕 45%", currentStreakSeconds: 1850, bestStreakSeconds: 3780, todaySeconds: 6400, totalSeconds: 204000, pkElo: 1310, pkWins: 8, pkLosses: 4, tier: "free", seeded: true },
  { userId: "seed-bl-1", nickname: "Kreuzberg_Vim", city: "柏林", country: "德国", regionCode: "DE", industry: "开源社区", mode: "彩透 52%", currentStreakSeconds: 0, bestStreakSeconds: 2940, todaySeconds: 5100, totalSeconds: 138000, pkElo: 1280, pkWins: 6, pkLosses: 4, tier: "free", seeded: true },
  { userId: "seed-cd-1", nickname: "Tianfu_Pixel", city: "成都", country: "中国", regionCode: "CN", industry: "独立开发", mode: "彩透 60%", currentStreakSeconds: 640, bestStreakSeconds: 1520, todaySeconds: 2800, totalSeconds: 42000, pkElo: 1230, pkWins: 3, pkLosses: 2, tier: "free", seeded: true },
];

const players = new Map();
const licenses = new Map();
const userMemberships = new Map();
let saveTimer = null;
let licenseSaveTimer = null;

function todayDateKey() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

function generateLicenseKey(plan = "latte") {
  const prefix =
    plan === "patron" || plan === "lifetime"
      ? "CHM-MAX"
      : plan === "latte"
      ? "CHM-VIP"
      : plan === "coffee"
      ? "CHM-SUP"
      : "CHM-PRO";
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const seg = () => {
    let out = "";
    const bytes = crypto.randomBytes(4);
    for (let i = 0; i < 4; i++) out += alphabet[bytes[i] % alphabet.length];
    return out;
  };
  return `${prefix}-${seg()}-${seg()}-${seg()}`;
}

function scheduleLicenseSave() {
  if (licenseSaveTimer) return;
  licenseSaveTimer = setTimeout(() => {
    licenseSaveTimer = null;
    try {
      fs.mkdirSync(DATA_DIR, { recursive: true });
      const payload = JSON.stringify(
        {
          updatedAt: Date.now(),
          licenses: Array.from(licenses.values()),
          userMemberships: Object.fromEntries(userMemberships.entries()),
        },
        null,
        2
      );
      fs.writeFileSync(LICENSES_FILE, payload, "utf8");
    } catch (_) {}
  }, 400);
}

let lastLicenseFileMtime = 0;
function loadLicensesDatabase(force = false) {
  try {
    fs.mkdirSync(DATA_DIR, { recursive: true });
    if (fs.existsSync(LICENSES_FILE)) {
      const st = fs.statSync(LICENSES_FILE);
      if (!force && st.mtimeMs <= lastLicenseFileMtime) return;
      lastLicenseFileMtime = st.mtimeMs;
      const raw = JSON.parse(fs.readFileSync(LICENSES_FILE, "utf8"));
      if (Array.isArray(raw.licenses)) {
        for (const lic of raw.licenses) {
          if (lic && lic.key) licenses.set(lic.key, lic);
        }
      }
      if (raw.userMemberships && typeof raw.userMemberships === "object") {
        for (const [uid, rec] of Object.entries(raw.userMemberships)) {
          if (uid && rec && !userMemberships.has(uid)) userMemberships.set(uid, rec);
        }
      }
    }
  } catch (_) {}
}

function getUserFuelSummary(userId, recOverride = null) {
  const today = todayDateKey();
  const rec = recOverride || userMemberships.get(userId) || {};
  const pl = players.get(userId);
  const dailyPlaySec = Math.max(
    Number(pl?.todaySeconds || 0),
    rec.dailyFuelDate === today ? Number(rec.dailyFuelPlaySec || 0) : 0
  );
  const dailyTargetSec = 1800; // 30 minutes of verified video playback
  const dailyClaimed = rec.dailyClaimDate === today;
  const referrals = Array.isArray(rec.referrals) ? rec.referrals : [];
  return {
    dailyTargetSec,
    dailyPlaySec,
    dailyPct: Math.min(100, Math.round((dailyPlaySec / dailyTargetSec) * 100)),
    dailyReady: dailyPlaySec >= dailyTargetSec && !dailyClaimed,
    dailyClaimed,
    streakDays: Number(rec.streakDays || 0),
    referralsCount: referrals.length,
    referralMax: 10,
    fuelHoursEarned: Number(rec.fuelHoursEarned || 0),
    referredBy: rec.referredBy || null,
  };
}

function grantFuelProDuration(userId, hoursToAdd) {
  const today = todayDateKey();
  const rec = userMemberships.get(userId) || {
    tier: "free",
    plan: "free",
    planName: "Free 免费版",
    key: null,
    expiresAt: null,
    trialUsed: false,
    dailyPkDate: today,
    dailyPkCount: 0,
  };

  rec.fuelHoursEarned = Number(rec.fuelHoursEarned || 0) + Number(hoursToAdd || 0);
  if (rec.tier !== "lifetime") {
    const now = Date.now();
    const base = rec.tier === "pro" && rec.expiresAt && rec.expiresAt > now ? rec.expiresAt : now;
    rec.expiresAt = base + hoursToAdd * 3600 * 1000;
    rec.tier = "pro";
    if (!rec.plan || rec.plan === "free") {
      rec.plan = "fuel";
      rec.planName = "Pro 能量补给会员";
    }
  }

  userMemberships.set(userId, rec);
  const pl = players.get(userId);
  if (pl) {
    pl.tier = rec.tier;
    scheduleSave();
  }
  scheduleLicenseSave();
  return rec;
}

function getUserEntitlement(userId) {
  const today = todayDateKey();
  const rec = userMemberships.get(userId) || {
    tier: "free",
    plan: "free",
    planName: "Free 免费版",
    key: null,
    expiresAt: null,
    trialUsed: false,
    dailyPkDate: today,
    dailyPkCount: 0,
  };

  if (rec.dailyPkDate !== today) {
    rec.dailyPkDate = today;
    rec.dailyPkCount = 0;
  }

  let activeTier = rec.tier || "free";
  let activePlan = rec.plan || "free";
  let activePlanName = rec.planName || "Free 免费版";
  let activeExpiresAt = rec.expiresAt || null;

  if (activeTier === "pro" && activeExpiresAt && Date.now() > activeExpiresAt) {
    activeTier = "free";
    activePlan = "free";
    activePlanName = "Free 免费版";
    rec.tier = "free";
    rec.plan = "free";
    rec.planName = "Free 免费版";
    scheduleLicenseSave();
  }

  const isPro = activeTier === "pro" || activeTier === "lifetime";
  const remaining = isPro ? 999 : Math.max(0, FREE_DAILY_PK_LIMIT - (rec.dailyPkCount || 0));

  return {
    userId,
    tier: activeTier,
    isPro,
    plan: activePlan,
    planName: activePlanName,
    expiresAt: activeExpiresAt,
    trialUsed: Boolean(rec.trialUsed),
    dailyPkLimit: isPro ? -1 : FREE_DAILY_PK_LIMIT,
    dailyPkUsed: rec.dailyPkCount || 0,
    dailyPkRemaining: remaining,
    dailyShieldFreeMinutes: isPro ? -1 : 30,
    fuel: getUserFuelSummary(userId, rec),
    features: {
      opticalModes: ["projector", "emboss", "cinema"],
      clickThrough: true,
      builtInWebPlayer: true,
      stealthSubtitle: true,
      dailyAntiPeekRadar: true,
      unlimitedRadar: isPro,
      screenShareStealth: isPro,
      roomPkCreate: isPro,
      royalePk: isPro,
      unlimitedPk: isPro,
      proBadge: isPro,
    },
  };
}

function recordUserPkStart(userId) {
  const today = todayDateKey();
  const rec = userMemberships.get(userId) || {
    tier: "free",
    plan: "free",
    planName: "Free 免费版",
    key: null,
    expiresAt: null,
    trialUsed: false,
    dailyPkDate: today,
    dailyPkCount: 0,
  };
  if (rec.dailyPkDate !== today) {
    rec.dailyPkDate = today;
    rec.dailyPkCount = 0;
  }
  rec.dailyPkCount = (rec.dailyPkCount || 0) + 1;
  userMemberships.set(userId, rec);
  scheduleLicenseSave();
}

function loadDatabase() {
  try {
    fs.mkdirSync(DATA_DIR, { recursive: true });
    if (fs.existsSync(DB_FILE)) {
      const raw = JSON.parse(fs.readFileSync(DB_FILE, "utf8"));
      if (Array.isArray(raw.players)) {
        for (const p of raw.players) {
          if (p && p.userId) players.set(p.userId, p);
        }
      }
    }
  } catch (_) {}

  if (players.size === 0) {
    const now = Date.now();
    for (const sp of SEED_PLAYERS) {
      players.set(sp.userId, { ...sp, lastSeenAt: now });
    }
    scheduleSave();
  } else {
    // Backfill tier metadata onto pre-existing seeded benchmark rows
    const seedById = new Map(SEED_PLAYERS.map((s) => [s.userId, s]));
    for (const p of players.values()) {
      const sp = seedById.get(p.userId);
      if (sp && !p.tier && sp.tier) p.tier = sp.tier;
    }
  }
}

function scheduleSave() {
  if (saveTimer) return;
  saveTimer = setTimeout(() => {
    saveTimer = null;
    try {
      const payload = JSON.stringify({ updatedAt: Date.now(), players: Array.from(players.values()) }, null, 2);
      fs.writeFileSync(DB_FILE, payload, "utf8");
    } catch (_) {}
  }, 800);
}

loadDatabase();
loadLicensesDatabase();

// Advance active seed benchmarks gently so global leaderboard stays alive
setInterval(() => {
  const now = Date.now();
  for (const p of players.values()) {
    if (p.seeded && p.currentStreakSeconds > 0) {
      p.currentStreakSeconds += 2;
      p.todaySeconds += 2;
      p.totalSeconds += 2;
      if (p.currentStreakSeconds > p.bestStreakSeconds) {
        p.bestStreakSeconds = p.currentStreakSeconds;
      }
      p.lastSeenAt = now;
    }
  }
}, 2000);

function isPlayerLive(p) {
  if (p.seeded) return p.currentStreakSeconds > 0;
  return Boolean(p.live) && Date.now() - (p.lastSeenAt || 0) < 35000;
}

function buildLeaderboardResponse({ scope, city, country, metric, userId }) {
  const all = Array.from(players.values());
  const filtered = all.filter((p) => {
    if (scope === "city" && city) return p.city === city;
    if (scope === "country" && country) return p.country === country;
    return true;
  });

  const mapped = filtered.map((p) => {
    const live = isPlayerLive(p);
    const bestStreak = Math.max(p.bestStreakSeconds || 0, p.currentStreakSeconds || 0);
    const ent = p.seeded ? { tier: p.tier || "free", isPro: p.tier === "pro" || p.tier === "lifetime" } : getUserEntitlement(p.userId);
    return {
      userId: p.userId,
      isMe: Boolean(userId && p.userId === userId),
      nickname: p.nickname || "匿名变色龙",
      city: p.city || "上海",
      country: p.country || "中国",
      regionCode: p.regionCode || "CN",
      industry: p.industry || "科技",
      mode: p.mode || "光影 58%",
      currentStreakSeconds: live ? p.currentStreakSeconds || 0 : 0,
      bestStreakSeconds: bestStreak,
      todaySeconds: p.todaySeconds || 0,
      totalSeconds: p.totalSeconds || 0,
      pkElo: p.pkElo || 1200,
      tier: ent.tier,
      isPro: ent.isPro,
      live,
    };
  });

  mapped.sort((a, b) => {
    if (metric === "today") return b.todaySeconds - a.todaySeconds;
    if (metric === "elo") return b.pkElo - a.pkElo;
    return b.bestStreakSeconds - a.bestStreakSeconds;
  });

  const items = mapped.slice(0, 50).map((item, idx) => ({ ...item, pos: idx + 1 }));
  const myIndex = mapped.findIndex((x) => x.isMe);

  // Aggregate country stats
  const countryMap = new Map();
  for (const p of all) {
    const cName = p.country || "中国";
    const prev = countryMap.get(cName) || {
      country: cName,
      regionCode: p.regionCode || "CN",
      onlineUsers: 0,
      totalTodaySec: 0,
      count: 0,
      topCity: p.city || "上海",
    };
    prev.count += 1;
    if (isPlayerLive(p)) prev.onlineUsers += 1;
    prev.totalTodaySec += p.todaySeconds || 0;
    countryMap.set(cName, prev);
  }

  const countryStats = Array.from(countryMap.values())
    .map((c) => ({
      country: c.country,
      regionCode: c.regionCode,
      activeCount: c.onlineUsers,
      totalPlayers: c.count,
      avgDailyMin: Math.max(1, Math.round(c.totalTodaySec / Math.max(1, c.count) / 60)),
      topCity: c.topCity,
    }))
    .sort((a, b) => b.avgDailyMin - a.avgDailyMin);

  const onlineCount = all.filter(isPlayerLive).length;

  return {
    ok: true,
    scope,
    metric,
    onlineCount,
    myRank: myIndex >= 0 ? myIndex + 1 : null,
    items,
    countryStats,
  };
}

// ---------------------------------------------------------------------------
// Real-Time WebSocket Matchmaking & Room PK Engine
// ---------------------------------------------------------------------------
const wsClients = new Set();
const waitingQueue = []; // Clients waiting for random 1v1 match
const waitingRooms = new Map(); // roomCode -> client
const activeMatches = new Map(); // matchId -> { id, a, b, isBotMatch, botTimer, startTs }

function encodeWsFrame(opcode, payloadBuf) {
  const len = payloadBuf.length;
  let header;
  if (len < 126) {
    header = Buffer.alloc(2);
    header[0] = 0x80 | opcode;
    header[1] = len;
  } else if (len < 65536) {
    header = Buffer.alloc(4);
    header[0] = 0x80 | opcode;
    header[1] = 126;
    header.writeUInt16BE(len, 2);
  } else {
    header = Buffer.alloc(10);
    header[0] = 0x80 | opcode;
    header[1] = 127;
    header.writeBigUInt64BE(BigInt(len), 2);
  }
  return Buffer.concat([header, payloadBuf]);
}

function sendWsJson(client, obj) {
  if (!client || client.closed) return;
  try {
    const buf = Buffer.from(JSON.stringify(obj), "utf8");
    client.socket.write(encodeWsFrame(0x01, buf));
  } catch (_) {}
}

function removeClientFromQueues(client) {
  const qIdx = waitingQueue.indexOf(client);
  if (qIdx >= 0) waitingQueue.splice(qIdx, 1);
  for (const [code, c] of waitingRooms.entries()) {
    if (c === client) waitingRooms.delete(code);
  }
  if (client.matchTimer) {
    clearTimeout(client.matchTimer);
    client.matchTimer = null;
  }
}

function finishMatch(matchId, winnerSide, reason) {
  const m = activeMatches.get(matchId);
  if (!m) return;
  activeMatches.delete(matchId);
  if (m.botTimer) clearInterval(m.botTimer);

  const eloDelta = 24;
  if (m.a) {
    m.a.matchId = null;
    const won = winnerSide === "a";
    const p = players.get(m.a.userId);
    if (p) {
      p.pkWins = (p.pkWins || 0) + (won ? 1 : 0);
      p.pkLosses = (p.pkLosses || 0) + (won ? 0 : 1);
      p.pkElo = Math.max(800, (p.pkElo || 1200) + (won ? eloDelta : -15));
    }
    sendWsJson(m.a, {
      type: "pk_ended",
      won,
      eloDelta: won ? eloDelta : -15,
      newElo: p ? p.pkElo : 1200,
      reason,
    });
  }
  if (m.b && !m.isBotMatch) {
    m.b.matchId = null;
    const won = winnerSide === "b";
    const p = players.get(m.b.userId);
    if (p) {
      p.pkWins = (p.pkWins || 0) + (won ? 1 : 0);
      p.pkLosses = (p.pkLosses || 0) + (won ? 0 : 1);
      p.pkElo = Math.max(800, (p.pkElo || 1200) + (won ? eloDelta : -15));
    }
    sendWsJson(m.b, {
      type: "pk_ended",
      won,
      eloDelta: won ? eloDelta : -15,
      newElo: p ? p.pkElo : 1200,
      reason,
    });
  }
  scheduleSave();
}

function pairTwoHumanClients(c1, c2, roomCode = null) {
  removeClientFromQueues(c1);
  removeClientFromQueues(c2);
  const matchId = "m_" + crypto.randomBytes(6).toString("hex");
  c1.matchId = matchId;
  c2.matchId = matchId;

  const match = { id: matchId, a: c1, b: c2, isBotMatch: false, startTs: Date.now() };
  activeMatches.set(matchId, match);

  sendWsJson(c1, {
    type: "pk_matched",
    matchId,
    roomCode,
    isRealPlayer: true,
    opponent: {
      userId: c2.userId,
      nickname: c2.nickname,
      city: c2.city,
      regionCode: c2.regionCode,
      mode: c2.mode,
      totalSeconds: c2.totalSeconds || 3600,
    },
  });

  sendWsJson(c2, {
    type: "pk_matched",
    matchId,
    roomCode,
    isRealPlayer: true,
    opponent: {
      userId: c1.userId,
      nickname: c1.nickname,
      city: c1.city,
      regionCode: c1.regionCode,
      mode: c1.mode,
      totalSeconds: c1.totalSeconds || 3600,
    },
  });
}

function pairWithSimulatedOnlineRival(client, targetRivalId = null) {
  removeClientFromQueues(client);
  const matchId = "m_" + crypto.randomBytes(6).toString("hex");
  client.matchId = matchId;

  const pool = SEED_PLAYERS;
  const chosen =
    (targetRivalId && pool.find((x) => x.userId === targetRivalId)) ||
    pool[Math.floor(Math.random() * pool.length)];

  let botSec = 0;
  const breakAtSec = 42 + Math.floor(Math.random() * 65);

  const botTimer = setInterval(() => {
    if (client.closed || client.matchId !== matchId) {
      clearInterval(botTimer);
      return;
    }
    botSec += 1;
    sendWsJson(client, {
      type: "pk_opp_tick",
      oppSeconds: botSec,
    });
    if (botSec >= breakAtSec) {
      finishMatch(matchId, "a", `对手 ${chosen.nickname} 在 ${botSec}s 时触发老板键中断潜伏`);
    }
  }, 1000);

  activeMatches.set(matchId, {
    id: matchId,
    a: client,
    b: null,
    isBotMatch: true,
    botName: chosen.nickname,
    botTimer,
    startTs: Date.now(),
  });

  sendWsJson(client, {
    type: "pk_matched",
    matchId,
    roomCode: null,
    isRealPlayer: false,
    opponent: {
      userId: chosen.userId,
      nickname: chosen.nickname,
      city: chosen.city,
      regionCode: chosen.regionCode,
      mode: chosen.mode,
      totalSeconds: chosen.totalSeconds,
    },
  });
}

function handleWsMessage(client, msg) {
  if (!msg || typeof msg !== "object") return;

  if (msg.type === "hello") {
    client.userId = String(msg.userId || client.userId);
    client.nickname = String(msg.nickname || "工位变色龙");
    client.city = String(msg.city || "上海");
    client.regionCode = String(msg.regionCode || "CN");
    client.mode = String(msg.mode || "光影 58%");
    client.totalSeconds = Number(msg.totalSeconds || 1800);
    return;
  }

  if (msg.type === "join_queue") {
    const ent = getUserEntitlement(client.userId);
    if (!ent.isPro && ent.dailyPkRemaining <= 0) {
      sendWsJson(client, {
        type: "pro_required",
        feature: "daily_pk_limit",
        message: `每日免费额度为 ${FREE_DAILY_PK_LIMIT} 局 1v1 耐力 PK（今日已用完，明天自动刷新）。去能量补给站免费打卡领时长，或请开发者喝杯美式（¥9.9 永久）解锁无限对战！`,
        entitlement: ent,
      });
      return;
    }
    recordUserPkStart(client.userId);
    if (client.matchId) finishMatch(client.matchId, "b", "重新匹配");
    if (msg.targetRivalId) {
      pairWithSimulatedOnlineRival(client, msg.targetRivalId);
      return;
    }
    const other = waitingQueue.find((c) => c !== client && !c.closed);
    if (other) {
      pairTwoHumanClients(other, client, null);
    } else {
      removeClientFromQueues(client);
      waitingQueue.push(client);
      sendWsJson(client, { type: "pk_searching" });
      client.matchTimer = setTimeout(() => {
        if (waitingQueue.includes(client) && !client.matchId) {
          pairWithSimulatedOnlineRival(client, null);
        }
      }, 1200);
    }
    return;
  }

  if (msg.type === "join_room") {
    const code = String(msg.roomCode || "").trim();
    if (!code) return;
    const ent = getUserEntitlement(client.userId);
    const existing = waitingRooms.get(code);
    // Viral PLG: Creating a private room requires Pro; joining an existing room created by a Pro friend is free!
    if (!existing && !ent.isPro) {
      sendWsJson(client, {
        type: "pro_required",
        feature: "room_pk",
        message: "创建私人 4 位暗号约战房为永久支持者专属权益（受邀加入好友房间免费）。请喝杯美式（¥9.9 永久）或领免费能量时长即可创建！",
        entitlement: ent,
      });
      return;
    }
    if (client.matchId) finishMatch(client.matchId, "b", "切换房间");
    removeClientFromQueues(client);

    if (existing && existing !== client && !existing.closed) {
      waitingRooms.delete(code);
      pairTwoHumanClients(existing, client, code);
    } else {
      waitingRooms.set(code, client);
      sendWsJson(client, { type: "pk_room_waiting", roomCode: code });
    }
    return;
  }

  if (msg.type === "pk_tick" && client.matchId) {
    const m = activeMatches.get(client.matchId);
    if (!m || m.isBotMatch) return;
    const peer = m.a === client ? m.b : m.a;
    sendWsJson(peer, { type: "pk_opp_tick", oppSeconds: Number(msg.seconds || 0) });
    return;
  }

  if (msg.type === "pk_signal" && client.matchId) {
    const m = activeMatches.get(client.matchId);
    if (!m) return;
    if (m.isBotMatch) {
      setTimeout(() => {
        if (activeMatches.has(m.id)) {
          const replies = ["收到，稳住节奏", "变色拟态已拉满", "看谁坚持更久"];
          sendWsJson(client, {
            type: "pk_signal",
            from: m.botName || "对手",
            text: replies[Math.floor(Math.random() * replies.length)],
          });
        }
      }, 900);
    } else {
      const peer = m.a === client ? m.b : m.a;
      sendWsJson(peer, { type: "pk_signal", from: client.nickname, text: String(msg.text || "") });
    }
    return;
  }

  if (msg.type === "pk_interrupt" && client.matchId) {
    const m = activeMatches.get(client.matchId);
    if (!m) return;
    const winner = m.a === client ? "b" : "a";
    finishMatch(m.id, winner, String(msg.reason || "中断潜伏"));
  }
}

// ---------------------------------------------------------------------------
// HTTP + WebSocket Server
// ---------------------------------------------------------------------------
const server = http.createServer((req, res) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, X-Admin-Key");

  if (req.method === "OPTIONS") {
    res.writeHead(204);
    res.end();
    return;
  }

  const parsedUrl = new URL(req.url || "/", `http://127.0.0.1:${PORT}`);

  function readJsonBody(cb) {
    let body = "";
    req.on("data", (chunk) => {
      if (body.length < 64 * 1024) body += chunk;
    });
    req.on("end", () => {
      try {
        cb(null, JSON.parse(body || "{}"));
      } catch (err) {
        cb(err, null);
      }
    });
  }

  if (req.method === "GET" && parsedUrl.pathname === "/api/license/status") {
    const userId = String(parsedUrl.searchParams.get("userId") || "").trim();
    if (!userId) {
      res.writeHead(400, { "Content-Type": "application/json; charset=utf-8" });
      res.end(JSON.stringify({ ok: false, error: "missing_userId" }));
      return;
    }
    const entitlement = getUserEntitlement(userId);
    res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
    res.end(JSON.stringify({ ok: true, entitlement }));
    return;
  }

  if (req.method === "POST" && parsedUrl.pathname === "/api/license/trial") {
    readJsonBody((err, data) => {
      if (err) {
        res.writeHead(400, { "Content-Type": "application/json; charset=utf-8" });
        res.end(JSON.stringify({ ok: false, error: "invalid_json" }));
        return;
      }
      const userId = String(data.userId || "").trim();
      if (!userId) {
        res.writeHead(400, { "Content-Type": "application/json; charset=utf-8" });
        res.end(JSON.stringify({ ok: false, error: "missing_userId" }));
        return;
      }
      const prev = userMemberships.get(userId);
      const curEnt = getUserEntitlement(userId);
      if (curEnt.isPro) {
        res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
        res.end(JSON.stringify({ ok: true, message: "您已是 Pro 会员，无需重复开启试用", entitlement: curEnt }));
        return;
      }
      if (prev && prev.trialUsed) {
        res.writeHead(409, { "Content-Type": "application/json; charset=utf-8" });
        res.end(JSON.stringify({ ok: false, error: "trial_already_used", message: "当前账号已使用过 3 天免费试用，请输入 Pro 激活码升级。", entitlement: curEnt }));
        return;
      }
      const spec = PLAN_CATALOG.trial;
      const expiresAt = Date.now() + spec.durationDays * 24 * 3600 * 1000;
      const nextRec = {
        ...(prev || {}),
        tier: spec.tier,
        plan: spec.plan,
        planName: spec.planName,
        key: "TRIAL-3D",
        expiresAt,
        trialUsed: true,
        dailyPkDate: todayDateKey(),
        dailyPkCount: prev?.dailyPkCount || 0,
      };
      userMemberships.set(userId, nextRec);
      const pl = players.get(userId);
      if (pl) {
        pl.tier = spec.tier;
        scheduleSave();
      }
      scheduleLicenseSave();
      const entitlement = getUserEntitlement(userId);
      res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
      res.end(JSON.stringify({ ok: true, message: "已成功开启 3 天 Pro 全功能免费体验！", entitlement }));
    });
    return;
  }

  if (req.method === "POST" && parsedUrl.pathname === "/api/license/activate") {
    readJsonBody((err, data) => {
      if (err) {
        res.writeHead(400, { "Content-Type": "application/json; charset=utf-8" });
        res.end(JSON.stringify({ ok: false, error: "invalid_json" }));
        return;
      }
      const userId = String(data.userId || "").trim();
      const deviceId = String(data.deviceId || userId || "web").slice(0, 64);
      const key = String(data.key || "").trim().toUpperCase();
      if (!userId || !key) {
        res.writeHead(400, { "Content-Type": "application/json; charset=utf-8" });
        res.end(JSON.stringify({ ok: false, error: "missing_params", message: "请输入完整的支持者激活码（格式：CHM-SUP / CHM-VIP / CHM-MAX-XXXX-XXXX-XXXX）。" }));
        return;
      }
      if (!licenses.has(key)) loadLicensesDatabase(false);
      const lic = licenses.get(key);
      if (!lic || lic.status !== "active") {
        res.writeHead(404, { "Content-Type": "application/json; charset=utf-8" });
        res.end(JSON.stringify({ ok: false, error: "invalid_key", message: "激活码无效或已被停用，请检查拼写或联系客服。" }));
        return;
      }
      if (lic.expiresAt && Date.now() > lic.expiresAt) {
        res.writeHead(410, { "Content-Type": "application/json; charset=utf-8" });
        res.end(JSON.stringify({ ok: false, error: "expired_key", message: "该激活码已过期。" }));
        return;
      }
      lic.activatedBy = Array.isArray(lic.activatedBy) ? lic.activatedBy : [];
      const alreadyBound = lic.activatedBy.some((a) => a.userId === userId || a.deviceId === deviceId);
      if (!alreadyBound && lic.activatedBy.length >= (lic.maxDevices || 2)) {
        res.writeHead(403, { "Content-Type": "application/json; charset=utf-8" });
        res.end(JSON.stringify({ ok: false, error: "device_limit_reached", message: `该激活码已达设备绑定上限（${lic.maxDevices || 2} 台设备）。` }));
        return;
      }
      if (!alreadyBound) {
        lic.activatedBy.push({ userId, deviceId, activatedAt: Date.now() });
      }
      if (!lic.expiresAt && lic.durationDays > 0) {
        lic.expiresAt = Date.now() + lic.durationDays * 24 * 3600 * 1000;
      }
      const prev = userMemberships.get(userId);
      userMemberships.set(userId, {
        ...(prev || {}),
        tier: lic.tier || "pro",
        plan: lic.plan || "yearly",
        planName: lic.planName || "Pro 会员",
        key: lic.key,
        expiresAt: lic.expiresAt || null,
        trialUsed: Boolean(prev?.trialUsed),
        dailyPkDate: todayDateKey(),
        dailyPkCount: prev?.dailyPkCount || 0,
      });
      const pl = players.get(userId);
      if (pl) {
        pl.tier = lic.tier || "pro";
        scheduleSave();
      }
      scheduleLicenseSave();
      const entitlement = getUserEntitlement(userId);
      res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
      res.end(JSON.stringify({ ok: true, message: `激活成功！已解锁 ${entitlement.planName} 全部权益。`, entitlement }));
    });
    return;
  }

  if (req.method === "GET" && parsedUrl.pathname === "/api/fuel/status") {
    const userId = String(parsedUrl.searchParams.get("userId") || "").trim();
    if (!userId) {
      res.writeHead(400, { "Content-Type": "application/json; charset=utf-8" });
      res.end(JSON.stringify({ ok: false, error: "missing_userId" }));
      return;
    }
    const entitlement = getUserEntitlement(userId);
    res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
    res.end(JSON.stringify({ ok: true, fuel: entitlement.fuel, entitlement }));
    return;
  }

  if (req.method === "POST" && parsedUrl.pathname === "/api/fuel/claim") {
    readJsonBody((err, data) => {
      if (err) {
        res.writeHead(400, { "Content-Type": "application/json; charset=utf-8" });
        res.end(JSON.stringify({ ok: false, error: "invalid_json" }));
        return;
      }
      const userId = String(data.userId || "").trim();
      const taskType = String(data.taskType || "daily_30m").trim();
      if (!userId) {
        res.writeHead(400, { "Content-Type": "application/json; charset=utf-8" });
        res.end(JSON.stringify({ ok: false, error: "missing_userId" }));
        return;
      }

      const today = todayDateKey();
      const fuel = getUserFuelSummary(userId);
      const rec = userMemberships.get(userId) || {};

      if (taskType === "daily_30m") {
        if (fuel.dailyClaimed) {
          res.writeHead(409, { "Content-Type": "application/json; charset=utf-8" });
          res.end(JSON.stringify({ ok: false, error: "already_claimed", message: "今日 12 小时 Pro 能量打卡已完成，明天继续看视频即可再领！", fuel, entitlement: getUserEntitlement(userId) }));
          return;
        }
        if (fuel.dailyPlaySec < fuel.dailyTargetSec) {
          const remainMin = Math.max(1, Math.ceil((fuel.dailyTargetSec - fuel.dailyPlaySec) / 60));
          res.writeHead(400, { "Content-Type": "application/json; charset=utf-8" });
          res.end(JSON.stringify({ ok: false, error: "not_enough_playtime", message: `今日真实播放视频需满 30 分钟才能领取（当前还差约 ${remainMin} 分钟）。`, fuel, entitlement: getUserEntitlement(userId) }));
          return;
        }
        const yday = new Date(Date.now() - 86400000);
        const ydayKey = `${yday.getFullYear()}-${String(yday.getMonth() + 1).padStart(2, "0")}-${String(yday.getDate()).padStart(2, "0")}`;
        const nextStreak = rec.dailyClaimDate === ydayKey ? Number(rec.streakDays || 0) + 1 : 1;
        rec.dailyClaimDate = today;
        rec.streakDays = nextStreak;
        userMemberships.set(userId, rec);

        // Extra +24h bonus on every 3rd consecutive day!
        const bonusHours = nextStreak > 0 && nextStreak % 3 === 0 ? 24 : 12;
        grantFuelProDuration(userId, bonusHours);
        const entitlement = getUserEntitlement(userId);
        res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
        res.end(
          JSON.stringify({
            ok: true,
            hoursGranted: bonusHours,
            message:
              bonusHours >= 24
                ? `连续第 ${nextStreak} 天打卡达成！已奖励 +24 小时 Pro 会员时长！`
                : `打卡成功！已领取 +12 小时 Pro 会员时长（当前连续 ${nextStreak} 天）。`,
            fuel: entitlement.fuel,
            entitlement,
          })
        );
        return;
      }

      res.writeHead(400, { "Content-Type": "application/json; charset=utf-8" });
      res.end(JSON.stringify({ ok: false, error: "unknown_task" }));
    });
    return;
  }

  if (req.method === "POST" && parsedUrl.pathname === "/api/fuel/referral") {
    readJsonBody((err, data) => {
      if (err) {
        res.writeHead(400, { "Content-Type": "application/json; charset=utf-8" });
        res.end(JSON.stringify({ ok: false, error: "invalid_json" }));
        return;
      }
      const inviterId = String(data.inviterId || "").trim();
      const inviteeId = String(data.inviteeId || "").trim();
      if (!inviterId || !inviteeId || inviterId === inviteeId) {
        res.writeHead(400, { "Content-Type": "application/json; charset=utf-8" });
        res.end(JSON.stringify({ ok: false, error: "invalid_referral", message: "邀请参数无效或不能邀请自己。" }));
        return;
      }

      const inviteeRec = userMemberships.get(inviteeId) || {};
      if (inviteeRec.referredBy) {
        const entitlement = getUserEntitlement(inviteeId);
        res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
        res.end(JSON.stringify({ ok: true, alreadyClaimed: true, message: "当前设备已领取过受邀好友 Pro 奖励。", entitlement, fuel: entitlement.fuel }));
        return;
      }

      const inviterRec = userMemberships.get(inviterId) || {};
      inviterRec.referrals = Array.isArray(inviterRec.referrals) ? inviterRec.referrals : [];
      if (inviterRec.referrals.length >= 10) {
        res.writeHead(429, { "Content-Type": "application/json; charset=utf-8" });
        res.end(JSON.stringify({ ok: false, error: "referral_cap_reached", message: "邀请人本月已达 10 人互赠上限。" }));
        return;
      }

      inviteeRec.referredBy = inviterId;
      userMemberships.set(inviteeId, inviteeRec);
      if (!inviterRec.referrals.includes(inviteeId)) {
        inviterRec.referrals.push(inviteeId);
        userMemberships.set(inviterId, inviterRec);
      }

      grantFuelProDuration(inviteeId, 72);
      grantFuelProDuration(inviterId, 72);

      const entitlement = getUserEntitlement(inviteeId);
      res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
      res.end(
        JSON.stringify({
          ok: true,
          message: "好友邀请绑定成功！你与邀请人已各自获赠 +3 天 Pro 会员时长！",
          entitlement,
          fuel: entitlement.fuel,
        })
      );
    });
    return;
  }

  if (req.method === "POST" && parsedUrl.pathname === "/api/admin/license/generate") {
    const providedAdmin = String(req.headers["x-admin-key"] || "");
    if (!ADMIN_KEY || providedAdmin !== ADMIN_KEY) {
      res.writeHead(403, { "Content-Type": "application/json; charset=utf-8" });
      res.end(JSON.stringify({ ok: false, error: "forbidden" }));
      return;
    }
    readJsonBody((err, data) => {
      if (err) {
        res.writeHead(400, { "Content-Type": "application/json; charset=utf-8" });
        res.end(JSON.stringify({ ok: false, error: "invalid_json" }));
        return;
      }
      const plan = PLAN_CATALOG[data.plan] ? data.plan : "yearly";
      const spec = PLAN_CATALOG[plan];
      const count = Math.min(200, Math.max(1, Number(data.count || 1)));
      const created = [];
      for (let i = 0; i < count; i++) {
        let key = generateLicenseKey(plan);
        while (licenses.has(key)) key = generateLicenseKey(plan);
        const rec = {
          key,
          tier: spec.tier,
          plan: spec.plan,
          planName: spec.planName,
          durationDays: spec.durationDays,
          maxDevices: Number(data.maxDevices || spec.maxDevices),
          activatedBy: [],
          createdAt: Date.now(),
          expiresAt: null,
          status: "active",
        };
        licenses.set(key, rec);
        created.push(key);
      }
      scheduleLicenseSave();
      res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
      res.end(JSON.stringify({ ok: true, plan, count: created.length, keys: created }));
    });
    return;
  }

  if (req.method === "GET" && parsedUrl.pathname === "/api/health") {
    res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
    res.end(
      JSON.stringify({
        ok: true,
        service: "ChameleonPiP Arena Server",
        onlineCount: Array.from(players.values()).filter(isPlayerLive).length,
        totalRegistered: players.size,
        activeMatches: activeMatches.size,
      })
    );
    return;
  }

  if (req.method === "GET" && parsedUrl.pathname === "/api/leaderboard") {
    const scope = parsedUrl.searchParams.get("scope") || "city";
    const city = parsedUrl.searchParams.get("city") || "上海";
    const country = parsedUrl.searchParams.get("country") || "中国";
    const metric = parsedUrl.searchParams.get("metric") || "streak";
    const userId = parsedUrl.searchParams.get("userId") || "";

    const data = buildLeaderboardResponse({ scope, city, country, metric, userId });
    res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
    res.end(JSON.stringify(data));
    return;
  }

  if (req.method === "POST" && parsedUrl.pathname === "/api/heartbeat") {
    let body = "";
    req.on("data", (chunk) => {
      if (body.length < 64 * 1024) body += chunk;
    });
    req.on("end", () => {
      try {
        const data = JSON.parse(body || "{}");
        const userId = String(data.userId || "").trim();
        if (!userId) {
          res.writeHead(400, { "Content-Type": "application/json" });
          res.end(JSON.stringify({ ok: false, error: "missing userId" }));
          return;
        }
        const prev = players.get(userId) || { userId, pkElo: 1200, pkWins: 0, pkLosses: 0 };
        const updated = {
          ...prev,
          userId,
          nickname: String(data.nickname || prev.nickname || "工位变色龙").slice(0, 28),
          city: String(data.city || prev.city || "上海").slice(0, 20),
          country: String(data.country || prev.country || "中国").slice(0, 20),
          regionCode: String(data.regionCode || prev.regionCode || "CN").slice(0, 4),
          industry: String(data.industry || prev.industry || "互联网").slice(0, 24),
          mode: String(data.mode || prev.mode || "光影 58%").slice(0, 20),
          currentStreakSeconds: Math.max(0, Number(data.currentStreakSeconds ?? prev.currentStreakSeconds ?? 0)),
          bestStreakSeconds: Math.max(
            Number(prev.bestStreakSeconds || 0),
            Number(data.bestStreakSeconds || 0),
            Number(data.currentStreakSeconds || 0)
          ),
          todaySeconds: Math.max(Number(prev.todaySeconds || 0), Number(data.todaySeconds || 0)),
          totalSeconds: Math.max(Number(prev.totalSeconds || 0), Number(data.totalSeconds || 0)),
          pkElo: Number(data.pkElo ?? prev.pkElo ?? 1200),
          pkWins: Number(data.pkWins ?? prev.pkWins ?? 0),
          pkLosses: Number(data.pkLosses ?? prev.pkLosses ?? 0),
          live: Boolean(data.live ?? true),
          seeded: false,
          lastSeenAt: Date.now(),
        };
        players.set(userId, updated);
        scheduleSave();

        // Keep server-side daily Fuel playtime synced with verified player heartbeat
        const today = todayDateKey();
        const mRec = userMemberships.get(userId) || {
          tier: "free",
          plan: "free",
          planName: "Free 免费版",
          key: null,
          expiresAt: null,
          trialUsed: false,
          dailyPkDate: today,
          dailyPkCount: 0,
        };
        if (mRec.dailyFuelDate !== today) {
          mRec.dailyFuelDate = today;
          mRec.dailyFuelPlaySec = updated.todaySeconds || 0;
        } else {
          mRec.dailyFuelPlaySec = Math.max(Number(mRec.dailyFuelPlaySec || 0), Number(updated.todaySeconds || 0));
        }
        userMemberships.set(userId, mRec);
        scheduleLicenseSave();

        const lb = buildLeaderboardResponse({
          scope: "city",
          city: updated.city,
          country: updated.country,
          metric: "streak",
          userId,
        });

        res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
        res.end(
          JSON.stringify({
            ok: true,
            cityRank: lb.myRank,
            onlineCount: lb.onlineCount,
            profile: updated,
            entitlement: getUserEntitlement(userId),
          })
        );
      } catch (err) {
        res.writeHead(400, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ ok: false, error: String(err) }));
      }
    });
    return;
  }

  // Serve official landing page (/ -> index.html), Arena (/arena.html), Privacy (/privacy.html)
  const cleanPath = parsedUrl.pathname.replace(/^\/chameleon-arena/, "") || "/index.html";
  const relPath = cleanPath === "/" ? "/index.html" : cleanPath;
  const candidateRoots = ["/var/www/chameleon-arena", path.resolve(__dirname, "..", "web"), path.resolve(__dirname, "..")];
  for (const rootDir of candidateRoots) {
    const fullPath = path.resolve(rootDir, "." + relPath);
    if (fullPath.startsWith(rootDir) && fs.existsSync(fullPath) && fs.statSync(fullPath).isFile()) {
      const ext = path.extname(fullPath).toLowerCase();
      const mime = {
        ".html": "text/html; charset=utf-8",
        ".js": "application/javascript; charset=utf-8",
        ".css": "text/css; charset=utf-8",
        ".png": "image/png",
        ".svg": "image/svg+xml",
        ".json": "application/json; charset=utf-8",
        ".zip": "application/zip",
      }[ext] || "application/octet-stream";
      res.writeHead(200, { "Content-Type": mime, "Cache-Control": "no-store, must-revalidate" });
      res.end(fs.readFileSync(fullPath));
      return;
    }
  }

  res.writeHead(404, { "Content-Type": "application/json" });
  res.end(JSON.stringify({ ok: false, error: "not_found" }));
});

server.on("upgrade", (req, socket) => {
  socket.setNoDelay(true);
  const key = req.headers["sec-websocket-key"];
  if (!key) {
    socket.destroy();
    return;
  }
  const accept = crypto
    .createHash("sha1")
    .update(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11")
    .digest("base64");

  socket.write(
    [
      "HTTP/1.1 101 Switching Protocols",
      "Upgrade: websocket",
      "Connection: Upgrade",
      `Sec-WebSocket-Accept: ${accept}`,
      "\r\n",
    ].join("\r\n")
  );

  const client = {
    socket,
    buf: Buffer.alloc(0),
    closed: false,
    userId: "u_" + crypto.randomBytes(4).toString("hex"),
    nickname: "工位变色龙",
    city: "上海",
    regionCode: "CN",
    mode: "光影 58%",
    totalSeconds: 1800,
    matchId: null,
    matchTimer: null,
  };
  wsClients.add(client);

  socket.on("data", (chunk) => {
    client.buf = Buffer.concat([client.buf, chunk]);
    while (client.buf.length >= 2) {
      const b0 = client.buf[0];
      const b1 = client.buf[1];
      const opcode = b0 & 0x0f;
      const masked = (b1 & 0x80) !== 0;
      let payloadLen = b1 & 0x7f;
      let offset = 2;

      if (payloadLen === 126) {
        if (client.buf.length < 4) return;
        payloadLen = client.buf.readUInt16BE(2);
        offset = 4;
      } else if (payloadLen === 127) {
        if (client.buf.length < 10) return;
        payloadLen = Number(client.buf.readBigUInt64BE(2));
        offset = 10;
      }

      const maskBytes = masked ? 4 : 0;
      if (client.buf.length < offset + maskBytes + payloadLen) return;

      let payload = client.buf.subarray(offset + maskBytes, offset + maskBytes + payloadLen);
      if (masked) {
        const mask = client.buf.subarray(offset, offset + 4);
        const unmasked = Buffer.allocUnsafe(payload.length);
        for (let i = 0; i < payload.length; i++) {
          unmasked[i] = payload[i] ^ mask[i & 3];
        }
        payload = unmasked;
      }
      client.buf = client.buf.subarray(offset + maskBytes + payloadLen);

      if (opcode === 0x08) {
        socket.end();
        return;
      }
      if (opcode === 0x09) {
        socket.write(encodeWsFrame(0x0a, payload));
        continue;
      }
      if (opcode === 0x01) {
        try {
          const msg = JSON.parse(payload.toString("utf8"));
          handleWsMessage(client, msg);
        } catch (_) {}
      }
    }
  });

  const cleanup = () => {
    if (client.closed) return;
    client.closed = true;
    wsClients.delete(client);
    removeClientFromQueues(client);
    if (client.matchId) {
      const m = activeMatches.get(client.matchId);
      if (m) {
        const winner = m.a === client ? "b" : "a";
        finishMatch(m.id, winner, "对方断开连接");
      }
    }
  };
  socket.on("close", cleanup);
  socket.on("error", cleanup);
});

server.listen(PORT, "127.0.0.1", () => {
  console.log(`[ChameleonPiP Arena Server] Listening on http://127.0.0.1:${PORT}`);
});

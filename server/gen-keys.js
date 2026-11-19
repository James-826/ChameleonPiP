#!/usr/bin/env node
/**
 * ChameleonPiP Pro License Key Generator CLI
 *
 * Generates real activation keys directly into server/data/licenses-db.json
 * (auto hot-reloaded by arena-server.js with zero downtime).
 *
 * Usage:
 *   node server/gen-keys.js --plan monthly --count 10
 *   node server/gen-keys.js --plan yearly --count 20
 *   node server/gen-keys.js --plan lifetime --count 5
 */
"use strict";

const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const DATA_DIR = path.join(__dirname, "data");
const LICENSES_FILE = path.join(DATA_DIR, "licenses-db.json");

const PLANS = {
  monthly: { tier: "pro", plan: "monthly", planName: "Pro 月度会员", durationDays: 30, maxDevices: 2, prefix: "CHM-PRO" },
  yearly: { tier: "pro", plan: "yearly", planName: "Pro 年度会员", durationDays: 365, maxDevices: 2, prefix: "CHM-PRO" },
  lifetime: { tier: "lifetime", plan: "lifetime", planName: "Pro 早鸟买断版", durationDays: 0, maxDevices: 3, prefix: "CHM-MAX" },
};

const args = process.argv.slice(2);
function getArg(name, fallback) {
  const idx = args.indexOf(`--${name}`);
  return idx >= 0 && args[idx + 1] ? args[idx + 1] : fallback;
}

const planArg = getArg("plan", "yearly");
const count = Math.min(500, Math.max(1, Number(getArg("count", "5"))));
const spec = PLANS[planArg];
if (!spec) {
  console.error("Invalid --plan. Use: monthly | yearly | lifetime");
  process.exit(1);
}

function genKey(prefix) {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const seg = () => {
    const bytes = crypto.randomBytes(4);
    let out = "";
    for (let i = 0; i < 4; i++) out += alphabet[bytes[i] % alphabet.length];
    return out;
  };
  return `${prefix}-${seg()}-${seg()}-${seg()}`;
}

fs.mkdirSync(DATA_DIR, { recursive: true });
let db = { updatedAt: Date.now(), licenses: [], userMemberships: {} };
if (fs.existsSync(LICENSES_FILE)) {
  try {
    db = JSON.parse(fs.readFileSync(LICENSES_FILE, "utf8"));
  } catch (_) {}
}
if (!Array.isArray(db.licenses)) db.licenses = [];
if (!db.userMemberships || typeof db.userMemberships !== "object") db.userMemberships = {};

const existing = new Set(db.licenses.map((l) => l.key));
const created = [];
for (let i = 0; i < count; i++) {
  let key = genKey(spec.prefix);
  while (existing.has(key)) key = genKey(spec.prefix);
  existing.add(key);
  db.licenses.push({
    key,
    tier: spec.tier,
    plan: spec.plan,
    planName: spec.planName,
    durationDays: spec.durationDays,
    maxDevices: spec.maxDevices,
    activatedBy: [],
    createdAt: Date.now(),
    expiresAt: null,
    status: "active",
  });
  created.push(key);
}

db.updatedAt = Date.now();
fs.writeFileSync(LICENSES_FILE, JSON.stringify(db, null, 2), "utf8");

console.log(`✅ Generated ${created.length} ${spec.planName} keys (${LICENSES_FILE}):\n`);
for (const k of created) console.log(k);

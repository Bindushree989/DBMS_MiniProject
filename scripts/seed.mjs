// Seeds users, ~900 found items and their full lifecycles (claims, verification, handovers, returns),
// then builds a labelled evaluation set for the matcher.
//
// Every row goes through the SAME stored procedures and triggers the application uses (with the DB clock
// simulated via @b2y_now), so the seed data is also a large-scale test of the state machine.
//
//   npm run db:seed                 (900 items)
//   node scripts/seed.mjs --items=300
import fs from 'node:fs';
import path from 'node:path';
import mysql from 'mysql2/promise';
import bcrypt from 'bcryptjs';
import { dbConfig, ROOT } from './_env.mjs';
import {
  rng, FIRST, LAST, CATALOG, newFoundSpec, lostQueryFor, ownerClaimText, impostorClaimText, wrongAnswer,
} from './_data.mjs';

const arg = (k) => process.argv.find((a) => a.startsWith(`--${k}=`))?.split('=')[1];
const N_ITEMS = Number(arg('items') || process.env.SEED_ITEMS || 900);
const N_USERS = 80;
const SEED = Number(process.env.SEED || 2026);
const CONC = 4;
export const DEMO_PASSWORD = 'Back2You@123';

const H = 3600 * 1000;
const REAL_NOW = Date.now();
const fmt = (ms) => new Date(ms).toISOString().slice(0, 19).replace('T', ' ');
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const cfg = dbConfig(true);
const pool = mysql.createPool({ ...cfg, connectionLimit: CONC + 2, decimalNumbers: true });
pool.pool.on('connection', (c) => { c.query("SET time_zone = '+00:00'"); c.query("SET @b2y_actor = 'seed-script'"); });

const [{ n: existing }] = (await pool.query('SELECT COUNT(*) AS n FROM items'))[0];
if (existing > 0) {
  console.error(`The database already contains ${existing} items. Run "npm run db:reset" first to start from scratch.`);
  process.exit(1);
}

const categories = (await pool.query('SELECT category_id, name FROM categories'))[0];
const categoriesByName = Object.fromEntries(categories.map((c) => [c.name, c.category_id]));
const locations = (await pool.query('SELECT location_id, name FROM locations'))[0];

/* ----------------------------------- users ----------------------------------- */
console.log('Creating users ...');
const pwHash = await bcrypt.hash(DEMO_PASSWORD, 10);
const ur = rng(SEED);
async function addUser(name, email, role, phone) {
  const [res] = await pool.query(
    'INSERT INTO users (full_name, email, phone, password_hash, role) VALUES (?,?,?,?,?)', [name, email, phone, pwHash, role]);
  return { id: res.insertId, name, email, role };
}
const phone = () => `+91 ${ur.int(70000, 99999)}${ur.int(10000, 99999)}`;
const admin = await addUser('Asha Admin', 'admin@back2you.dev', 'admin', phone());
const staffNames = ['Ravi Kumar', 'Sunita Rao', 'Imran Khan', 'Latha Menon', 'Deepak Shetty'];
const staff = [];
for (let i = 0; i < staffNames.length; i++) staff.push(await addUser(staffNames[i], `staff${i + 1}@back2you.dev`, 'staff', phone()));
const users = [];
const used = new Set();
for (let i = 0; users.length < N_USERS; i++) {
  const f = ur.pick(FIRST), l = ur.pick(LAST);
  const nm = `${f} ${l}`;
  if (used.has(nm)) continue;
  used.add(nm);
  users.push(await addUser(nm, users.length < 5 ? `user${users.length + 1}@example.com` : `${f}.${l}${users.length}@example.com`.toLowerCase(), 'user', phone()));
}
const badActors = users.splice(users.length - 3, 3);       // reserved for the fraud scenarios
console.log(`  1 admin, ${staff.length} staff, ${users.length + badActors.length} users`);

/* ------------------------------ lifecycle simulation ------------------------------ */
const A = (u) => `app:${u.role}#${u.id}`;
async function call(c, t, name, args, actor) {
  for (let attempt = 0; attempt < 5; attempt++) {
    try {
      await c.query('SET @b2y_now = ?, @b2y_actor = ?', [fmt(t), actor ? A(actor) : 'seed-script']);
      const [res] = await c.query(`CALL ${name}(${args.map(() => '?').join(',')})`, args);
      return res[0]?.[0] ?? {};
    } catch (e) {
      if ((e.errno === 1213 || e.errno === 1205) && attempt < 4) { await sleep(25 * (attempt + 1)); continue; }
      throw e;
    }
  }
}

const WEIGHTS = [['Phone', 16], ['Wallet', 12], ['Bag', 10], ['Keys', 10], ['Laptop', 6], ['Earphones', 10], ['ID / Cards', 8],
  ['Clothing', 7], ['Watch / Jewellery', 5], ['Water Bottle', 6], ['Umbrella', 4], ['Spectacles', 3], ['Documents', 2], ['Other', 1]];
const totalW = WEIGHTS.reduce((s, [, w]) => s + w, 0);
const pickCategory = (r) => { let x = r.next() * totalW; for (const [n, w] of WEIGHTS) { if ((x -= w) < 0) return n; } return 'Other'; };
const PROOFS = ['ID_CARD', 'PHOTO', 'SIGNATURE', 'OTP'];
const proofRef = (r, type) => ({ ID_CARD: `ID-${r.int(100000, 999999)}`, PHOTO: `IMG-${r.int(1000, 9999)}`, SIGNATURE: `SIG-${r.int(1000, 9999)}`, OTP: `OTP-${r.int(1000, 9999)}` }[type]);

const specs = new Map(); // item_id -> { spec, foundAt }
const stats = { items: 0, registered: 0, claims: 0, verified: 0, handed: 0, returned: 0, errors: 0 };

async function simulateItem(c, i) {
  const r = rng(SEED + i * 7919);
  const catName = pickCategory(r);
  const spec = newFoundSpec(r, catName, locations);
  const ageDays = r.chance(0.2) ? r.float(0.05, 3) : r.float(2, 120);
  const foundAt = REAL_NOW - ageDays * 24 * H;
  const finderIsStaff = r.chance(0.15);
  const finder = finderIsStaff ? r.pick(staff) : r.pick(users);
  const limit = REAL_NOW - 10 * 60 * 1000;
  let t = foundAt + r.int(2, 20) * 60 * 1000;

  const rep = await call(c, t, 'sp_report_found_item', [finder.id, spec.title, spec.description, categoriesByName[catName],
    spec.color, spec.brand, spec.loc.location_id, fmt(foundAt), spec.hint, spec.answer, finderIsStaff ? spec.storage : 'With finder'], finder);
  const itemId = rep.item_id;
  specs.set(itemId, { spec, foundAt });
  stats.items++;

  // ---- register (staff takes custody)
  t += r.float(0.5, 30) * H;
  if (t > limit || !r.chance(0.93)) return;
  const registrar = finderIsStaff && r.chance(0.7) ? finder : r.pick(staff);
  const pt = r.pick(PROOFS);
  await call(c, t, 'sp_register_item', [itemId, registrar.id, pt, proofRef(r, pt), spec.storage], registrar);
  stats.registered++;
  let custodian = registrar;

  // ---- claims
  if (!r.chance(0.55)) return;
  const pool_ = users.filter((u) => u.id !== finder.id);
  const n = r.chance(0.8) ? 1 : r.chance(0.75) ? 2 : 3;
  const claimants = r.sample(pool_, n);
  const ownerIdx = r.chance(0.85) ? r.int(0, n - 1) : -1;
  const claims = [];
  for (let k = 0; k < claimants.length; k++) {
    t += r.float(1, 48) * H;
    if (t > limit) break;
    const isOwner = k === ownerIdx;
    const answer = spec.hint ? (isOwner ? spec.answer : wrongAnswer(r, spec)) : null;
    try {
      const res = await call(c, t, 'sp_submit_claim', [itemId, claimants[k].id,
        isOwner ? ownerClaimText(r, spec) : impostorClaimText(r, spec), answer], claimants[k]);
      claims.push({ id: res.claim_id, who: claimants[k], isOwner, t });
      stats.claims++;
    } catch (e) { stats.errors++; }
  }
  if (!claims.length) return;

  // ---- verification
  let verified = null;
  let tv = t;
  for (const cl of claims) {
    if (cl.isOwner) {
      if (!r.chance(0.9)) continue;
      tv = Math.max(tv, cl.t) + r.float(1, 36) * H;
      if (tv > limit) continue;
      const method = spec.hint ? 'HINT_ANSWER' : 'ID_PROOF';
      const out = await call(c, tv, 'sp_verify_claim', [cl.id, custodian.id, method, method === 'ID_PROOF' ? `ID-${r.int(100000, 999999)}` : null, null], custodian);
      if (out.outcome === 'PASS') { verified = cl; stats.verified++; break; }
    } else if (r.chance(0.7)) {
      let tt = Math.max(tv, cl.t);
      if (spec.hint) {
        const tries = r.chance(0.5) ? 3 : r.int(1, 2);
        for (let a = 0; a < tries; a++) {
          tt += r.float(0.5, 12) * H;
          if (tt > limit) break;
          await call(c, tt, 'sp_verify_claim', [cl.id, custodian.id, 'HINT_ANSWER', null, null], custodian);
        }
      } else {
        tt += r.float(0.5, 12) * H;
        if (tt <= limit) await call(c, tt, 'sp_reject_claim', [cl.id, custodian.id, 'Could not describe the item correctly'], custodian);
      }
      tv = Math.max(tv, tt);
    }
  }
  if (!verified) return;

  // ---- optional custody transfer, handover, confirmation
  t = tv;
  if (r.chance(0.15)) {
    t += r.float(1, 24) * H;
    if (t > limit) return;
    const other = r.pick(staff.filter((s) => s.id !== custodian.id));
    const tp = r.pick(PROOFS);
    await call(c, t, 'sp_transfer_custody', [itemId, custodian.id, other.id, tp, proofRef(r, tp), 'Shelf transfer', 'Moved to the claims desk'], custodian);
    custodian = other;
  }
  t += r.float(2, 72) * H;
  if (t > limit || !r.chance(0.92)) return;
  const hp = r.pick(['ID_CARD', 'SIGNATURE', 'OTP']);
  await call(c, t, 'sp_perform_handover', [verified.id, custodian.id, hp, proofRef(r, hp), 'Handed over at the desk'], custodian);
  stats.handed++;
  t += r.float(0.2, 6) * H;
  if (t > limit || !r.chance(0.88)) return;
  await call(c, t, 'sp_confirm_return', [verified.id, verified.who.id], verified.who);
  stats.returned++;
}

console.log(`Simulating ${N_ITEMS} found items through the stored procedures (${CONC} parallel workers) ...`);
let next = 0;
const t0 = Date.now();
await Promise.all(Array.from({ length: CONC }, async () => {
  const c = await pool.getConnection();
  try {
    for (;;) {
      const i = next++;
      if (i >= N_ITEMS) break;
      try { await simulateItem(c, i); } catch (e) { stats.errors++; if (stats.errors < 6) console.error(`  item ${i}: ${e.message}`); }
      if ((i + 1) % 100 === 0) console.log(`  ${i + 1}/${N_ITEMS} items ... (${Math.round((Date.now() - t0) / 1000)}s)`);
    }
  } finally { c.release(); }
}));

/* --------------------------- suspicious-behaviour scenarios --------------------------- */
console.log('Creating fraud scenarios ...');
{
  const c = await pool.getConnection();
  const r = rng(SEED + 99);
  try {
    const [cands] = await c.query(
      `SELECT item_id, finder_id FROM items WHERE status = 'REGISTERED' AND registered_at < NOW() - INTERVAL 7 DAY ORDER BY item_id DESC LIMIT 60`);
    let ci = 0;
    for (let a = 0; a < badActors.length; a++) {
      const actor = badActors[a];
      const base = REAL_NOW - (4 + a * 2) * H;          // all within a 24h window
      let made = 0;
      const mine = [];
      while (made < 5 + a && ci < cands.length) {
        const it = cands[ci++];
        const sp = specs.get(it.item_id);
        if (!sp || it.finder_id === actor.id) continue;
        try {
          const res = await call(c, base + made * 1.5 * H, 'sp_submit_claim', [it.item_id, actor.id, impostorClaimText(r, sp.spec), sp.spec.hint ? wrongAnswer(r, sp.spec) : null], actor);
          mine.push({ ...res, item: it.item_id, sp });
          made++;
        } catch { /* item may no longer be open */ }
      }
      if (a === 0) { // first actor also fails ownership checks three times -> HIGH flag
        const hinted = mine.find((m) => m.sp.spec.hint);
        if (hinted) {
          for (let k = 0; k < 3; k++) {
            const cust = (await c.query('SELECT holder_id FROM custody_log WHERE item_id = ? AND ended_at IS NULL', [hinted.item]))[0][0].holder_id;
            await call(c, REAL_NOW - 2 * H + k * 600000, 'sp_verify_claim', [hinted.claim_id, cust, 'HINT_ANSWER', null, null], staff.find((x) => x.id === cust) ?? admin);
          }
        }
      }
    }
  } finally { c.release(); }
}

/* --------------------------- labelled evaluation set --------------------------- */
console.log('Building the matching evaluation set ...');
const open = (await pool.query(`SELECT item_id, found_at FROM items WHERE status IN ('REGISTERED','CLAIMED')`))[0]
  .filter((x) => specs.has(x.item_id));
const er = rng(SEED + 7);
const pairs = er.sample(open, Math.min(120, open.length)).map((x, idx) => {
  const { spec, foundAt } = specs.get(x.item_id);
  return {
    id: idx + 1,
    truth_item_id: x.item_id,
    query: lostQueryFor(er, spec, { categoriesByName, locations, foundAt: new Date(foundAt) }),
  };
});
fs.mkdirSync(path.join(ROOT, 'data'), { recursive: true });
fs.writeFileSync(path.join(ROOT, 'data', 'eval_pairs.json'), JSON.stringify(pairs, null, 1));
console.log(`  ${pairs.length} lost/found pairs -> data/eval_pairs.json`);

// fresh optimizer statistics (InnoDB's are stale right after a bulk load, which makes EXPLAIN misleading)
for (const t of ['users', 'items', 'claims', 'handovers', 'custody_log', 'verification_attempts', 'audit_log', 'fraud_flags', 'embedding_outbox']) {
  await pool.query(`ANALYZE TABLE \`${t}\``);
}

/* --------------------------------- summary --------------------------------- */
const q = async (sql) => (await pool.query(sql))[0];
console.log('\nSeed complete.');
console.table(await q('SELECT status, COUNT(*) AS items FROM items GROUP BY status ORDER BY FIELD(status,"FOUND","REGISTERED","CLAIMED","VERIFIED","HANDED_OVER","RETURNED")'));
console.table(await q('SELECT status, COUNT(*) AS claims FROM claims GROUP BY status'));
const [tot] = await q(`SELECT (SELECT COUNT(*) FROM users) users, (SELECT COUNT(*) FROM handovers) handovers,
  (SELECT COUNT(*) FROM custody_log) custody_rows, (SELECT COUNT(*) FROM audit_log) audit_rows,
  (SELECT COUNT(*) FROM fraud_flags) fraud_flags, (SELECT COUNT(*) FROM embedding_outbox WHERE processed_at IS NULL) outbox_pending`);
console.table([tot]);
if (stats.errors) console.log(`(${stats.errors} simulated operations were rejected by business rules, which is expected for a few random combinations)`);
console.log(`\nDemo logins (password for all: ${DEMO_PASSWORD})\n  admin@back2you.dev   staff1@back2you.dev .. staff5@back2you.dev   user1@example.com .. user5@example.com`);
console.log('\nNext: npm run vectors:sync');
await pool.end();

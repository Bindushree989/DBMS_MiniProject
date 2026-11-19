// Seeds ~1,900 realistic rows by REPLAYING history through the real stored procedures
// (so every trigger, audit row and custody record is genuine). A business clock
// (@b2y_now) lets us place events at past timestamps; events run in chronological order.
// Deterministic: same seed => same data.
const fs = require('fs'), path = require('path');
const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');
const cfg = require('./env');
const D = require('./seed-data');

function mulberry32(a) { return () => { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }
const rng = mulberry32(2026);
const pick = a => a[Math.floor(rng() * a.length)];
const rint = (a, b) => a + Math.floor(rng() * (b - a + 1));
const chance = p => rng() < p;
const MIN = 60e3, HOUR = 3600e3, DAY = 86400e3;
const fmt = ms => new Date(ms).toISOString().slice(0, 19).replace('T', ' ');
const cap = s => s.charAt(0).toUpperCase() + s.slice(1);

const N_ITEMS = Number(process.env.SEED_ITEMS || 640);
const N_USERS = 70, N_NOISE_REPORTS = 190, N_PAIRS = 70;

(async () => {
  const c = await mysql.createConnection({ ...cfg, database: cfg.database, dateStrings: true });
  const q = async (s, p) => (await c.query(s, p))[0];
  const call = async (s, p) => { const [r] = await c.query('CALL ' + s, p); return Array.isArray(r[0]) ? r[0][0] : r[0]; };

  const nowStr = (await q("SELECT DATE_FORMAT(NOW(),'%Y-%m-%d %H:%i:%s') n"))[0].n;
  const END = Date.parse(nowStr.replace(' ', 'T') + 'Z') - 30 * MIN;
  const START = END - 200 * DAY;

  if ((await q('SELECT COUNT(*) n FROM users'))[0].n > 0) { console.error('Database is not empty. Run: npm run db:reset'); process.exit(1); }
  await q('SET @b2y_now = ?', [fmt(START - DAY)]);

  // ---------------- reference data --------------------------------------
  for (const [name, hv] of D.categories) await q('INSERT INTO categories (name, is_high_value) VALUES (?,?)', [name, hv]);
  for (const l of D.locations) await q('INSERT INTO locations (name, loc_type, city, latitude, longitude, is_staffed) VALUES (?,?,?,?,?,?)', l);
  const cats = Object.fromEntries((await q('SELECT category_id, name FROM categories')).map(r => [r.name, r.category_id]));
  const locs = await q('SELECT location_id, name, latitude, longitude FROM locations');

  // ---------------- users -------------------------------------------------
  const hashes = { admin: bcrypt.hashSync('Admin@123', 8), staff: bcrypt.hashSync('Staff@123', 8), user: bcrypt.hashSync('User@123', 8) };
  const mkUser = async (name, email, role, phone) => (await q('INSERT INTO users (full_name,email,phone,password_hash,role,created_at) VALUES (?,?,?,?,?,?)',
    [name, email, phone, hashes[role], role, fmt(START - rint(1, 60) * DAY)])).insertId;
  const used = new Set(); const nm = () => { let n; do { n = pick(D.first) + ' ' + pick(D.last); } while (used.has(n)); used.add(n); return n; };
  const phone = () => '9' + rint(100000000, 999999999);
  const admin = await mkUser('Meera Admin', 'admin@back2you.dev', 'admin', phone());
  const staff = []; for (let i = 1; i <= 4; i++) staff.push(await mkUser(nm(), `staff${i}@back2you.dev`, 'staff', phone()));
  const users = []; for (let i = 1; i <= N_USERS; i++) users.push(await mkUser(nm(), `user${i}@back2you.dev`, 'user', phone()));
  const fraudsters = [users[users.length - 1], users[users.length - 2]];
  const normal = users.slice(0, users.length - 2);

  // ---------------- plan -------------------------------------------------
  const events = []; let seq = 0;
  const at = (t, run) => events.push({ t, seq: seq++, run });
  const stageDist = [['FOUND', .07], ['REGISTERED', .29], ['CLAIMED', .06], ['VERIFIED', .04], ['HANDED_OVER', .04], ['RETURNED', .50]];
  const rank = { FOUND: 0, REGISTERED: 1, CLAIMED: 2, VERIFIED: 3, HANDED_OVER: 4, RETURNED: 5 };
  const pickStage = () => { let r = rng(), a = 0; for (const [s, p] of stageDist) { a += p; if (r < a) return s; } return 'RETURNED'; };

  function makeProfile(catName) {
    const T = D.templates[catName];
    const feats = [...T.feats].sort(() => rng() - .5).slice(0, rint(2, 3));
    const color = pick(T.colors), brand = T.brands.length ? pick(T.brands) : null;
    const a = rint(0, T.qa.length - 1);
    return { catName, T, color, brand, nounA: pick(T.nounA), nounB: pick(T.nounB),
      featA: feats.map(f => f[0]), featB: feats.map(f => f[1]), question: T.q, answer: T.qa[a] };
  }
  const itemTitle = pr => cap([pr.color, pr.brand, pr.nounA].filter(Boolean).join(' '));
  const itemDesc = pr => `${cap([pr.color, pr.brand, pr.nounA].filter(Boolean).join(' '))} found with ${pr.featA.join(', ')}. ${pick(D.fillers)}`;
  const lostTitle = (pr, withBrand, withColor) => cap(`lost ${withColor ? pr.color + ' ' : ''}${withBrand && pr.brand ? pr.brand + ' ' : ''}${pr.nounB}`);
  const lostDesc = pr => `${pick(D.lostOpeners)} ${pr.nounB} - ${pr.featB.join(', ')}. ${pick(D.lostClosers)}`;

  const pairs = [];       // ground truth for match evaluation
  const plans = [];
  let pairBudget = N_PAIRS;

  for (let i = 0; i < N_ITEMS; i++) {
    const stage = pickStage();
    const catName = pick(D.catWeights);
    const pr = makeProfile(catName);
    const loc = pick(locs);
    const finder = pick(normal);
    const rejectFirst = rank[stage] >= 1 && stage !== 'CLAIMED' && chance(.12);
    const competing = rank[stage] >= 2 && chance(.18);
    const claimant = pick(normal.filter(u => u !== finder));
    const rival = pick(normal.filter(u => u !== finder && u !== claimant));
    const rejecter = pick(normal.filter(u => u !== finder && u !== claimant));
    const p = { i, stage, pr, loc, finder, claimant, rival, rejecter, rejectFirst, competing, itemId: null, holder: null, claimId: null, wrongClaimId: null, rivalClaimId: null };

    // relative timeline (minutes after found_at)
    const st = []; let rel = rint(5, 90);
    const step = (dtMin, run) => { rel += dtMin; st.push({ rel, run }); };
    st.push({ rel, run: async () => { const r = await call('sp_report_found_item(?,?,?,?,?,?,?,?,?,?)', [p.finder, itemTitle(pr), itemDesc(pr), cats[catName], pr.color, pr.brand, p.loc.location_id, p.foundAt, pr.question, pr.answer]); p.itemId = r.item_id; p.holder = p.finder; } });
    if (stage !== 'FOUND') {
      const staffA = pick(staff);
      step(rint(10, 36 * 60), async () => { await call('sp_register_item(?,?,?)', [p.itemId, staffA, pick(D.deskNotes)]); p.holder = staffA; });
      if (chance(.2)) step(rint(60, 24 * 60), async () => { const to = pick(staff.filter(s => s !== p.holder)); await call('sp_transfer_custody(?,?,?,?)', [p.itemId, p.holder, to, 'Moved to central lost-property room']); p.holder = to; });
      if (rejectFirst) {
        step(rint(60, 5 * 24 * 60), async () => { p.wrongClaimId = (await call('sp_submit_claim(?,?,?,?,?)', [p.itemId, p.rejecter, null, `I believe this ${pr.nounB} is mine, it looks like the one I lost.`, pick(D.wrongAnswers)])).claim_id; });
        step(rint(30, 24 * 60), async () => { await call('sp_review_claim(?,?,?,?)', [p.wrongClaimId, pick(staff), 0, 'Hidden detail did not match']); });
      }
      if (rank[stage] >= 2) {
        step(rint(60, 7 * 24 * 60), async () => { p.claimId = (await call('sp_submit_claim(?,?,?,?,?)', [p.itemId, p.claimant, null, `This is my ${pr.color} ${pr.nounB}. ${cap(pr.featB[0])}. I lost it near ${p.loc.name}.`, pr.answer])).claim_id; });
        if (competing) step(rint(5, 600), async () => { p.rivalClaimId = (await call('sp_submit_claim(?,?,?,?,?)', [p.itemId, p.rival, null, `Please check, I think it is my ${pr.nounB}, I lost one just like it.`, pick(D.wrongAnswers)])).claim_id; });
      }
      if (rank[stage] >= 3) step(rint(120, 3 * 24 * 60), async () => { await call('sp_review_claim(?,?,?,?)', [p.claimId, p.holder, 1, 'Ownership verified (ID + hidden detail)']); });
      if (rank[stage] >= 4) step(rint(60, 3 * 24 * 60), async () => { await call('sp_perform_handover(?,?,?,?,?)', [p.itemId, p.holder, pick(['ID_CARD', 'OTP', 'SIGNATURE', 'PHOTO']), 'REF-' + rint(100000, 999999), null]); });
      if (rank[stage] >= 5) step(rint(5, 2 * 24 * 60), async () => { await call('sp_confirm_return(?,?)', [p.itemId, p.claimant]); });
    }
    // choose found_at so the whole journey fits before END
    const totalMs = rel * MIN;
    const latestFound = END - totalMs - 5 * MIN;
    p.foundAtMs = stage === 'FOUND' ? Math.min(latestFound, END - rint(1, 40) * HOUR - totalMs)
      : START + Math.floor(rng() * Math.max(DAY, latestFound - START));
    p.foundAtMs = Math.max(START, Math.min(p.foundAtMs, latestFound));
    p.foundAt = fmt(p.foundAtMs);
    for (const s of st) at(p.foundAtMs + s.rel * MIN, s.run);

    // paired lost report (ground truth for matching evaluation): only for untouched REGISTERED items
    if (stage === 'REGISTERED' && !rejectFirst && pairBudget > 0 && chance(.45)) {
      pairBudget--;
      const owner = pick(normal.filter(u => u !== finder));
      const sameLoc = chance(.6);
      const lostLoc = sameLoc ? p.loc : pick(locs.filter(l => l !== p.loc));
      const withBrand = chance(.55), withColor = chance(.75);
      const wrongCat = chance(.05) ? cats[pick(D.catWeights)] : cats[catName];
      const lostAtMs = p.foundAtMs - rint(1, 60) * HOUR;
      const rep = { itemP: p, reportId: null };
      pairs.push(rep);
      at(Math.min(END - HOUR, Math.max(START, lostAtMs + rint(1, 30) * HOUR)), async () => {
        rep.reportId = (await call('sp_submit_lost_report(?,?,?,?,?,?,?,?)', [owner, lostTitle(pr, withBrand, withColor), lostDesc(pr), wrongCat,
          withColor ? (chance(.08) ? pick(pr.T.colors) : pr.color) : null, withBrand ? pr.brand : null, lostLoc.location_id, fmt(lostAtMs)])).report_id;
      });
    }
    plans.push(p);
  }

  // noise lost reports (items that were never found)
  for (let i = 0; i < N_NOISE_REPORTS; i++) {
    const catName = pick(D.catWeights), pr = makeProfile(catName), owner = pick(normal), loc = pick(locs);
    const lostAtMs = START + Math.floor(rng() * (END - START - 2 * DAY));
    at(lostAtMs + rint(1, 40) * HOUR, async () => { await call('sp_submit_lost_report(?,?,?,?,?,?,?,?)', [owner, lostTitle(pr, chance(.5), chance(.8)), lostDesc(pr), cats[catName], pr.color, chance(.5) ? pr.brand : null, loc.location_id, fmt(lostAtMs)]); });
  }

  // fraud scenarios: each fraudster hits 4 items within ~14 hours with wrong answers
  fraudsters.forEach((fr, k) => {
    const base = END - (20 + k * 25) * DAY;
    const fitems = [];
    for (let j = 0; j < 4; j++) {
      const catName = pick(['Phone', 'Wallet', 'Laptop', 'Watch']), pr = makeProfile(catName), loc = pick(locs), finder = pick(normal), s = pick(staff);
      const fp = { itemId: null };
      fitems.push(fp);
      const ft = base - (2 + j) * DAY;
      at(ft, async () => { fp.itemId = (await call('sp_report_found_item(?,?,?,?,?,?,?,?,?,?)', [finder, itemTitle(pr), itemDesc(pr), cats[catName], pr.color, pr.brand, loc.location_id, fmt(ft - HOUR), pr.question, pr.answer])).item_id; });
      at(ft + 2 * HOUR, async () => { await call('sp_register_item(?,?,?)', [fp.itemId, s, 'Accepted at desk']); });
      at(base + j * 3 * HOUR, async () => { fp.claimId = (await call('sp_submit_claim(?,?,?,?,?)', [fp.itemId, fr, null, `That ${pr.nounB} belongs to me, I lost it last week.`, pick(D.wrongAnswers)])).claim_id; });
      at(base + 2 * DAY + j * HOUR, async () => { await call('sp_review_claim(?,?,?,?)', [fp.claimId, s, 0, 'Wrong hidden detail; repeated claims']); });
    }
  });

  // ---------------- replay in chronological order -----------------------
  events.sort((a, b) => a.t - b.t || a.seq - b.seq);
  console.log(`Replaying ${events.length} events through stored procedures ...`);
  let done = 0;
  for (const e of events) {
    await c.query('SET @b2y_now = ?', [fmt(e.t)]);
    try { await e.run(); } catch (err) { console.error('EVENT FAILED at', fmt(e.t), err.message); throw err; }
    if (++done % 500 === 0) console.log(`  ${done}/${events.length}`);
  }

  // resolve about half of the fraud flags (admin work)
  await c.query('SET @b2y_now = ?', [fmt(END)]);
  const flags = await q('SELECT flag_id FROM fraud_flags ORDER BY flag_id');
  for (const [i, f] of flags.entries()) if (i % 2 === 0) await call('sp_resolve_flag(?,?,?)', [f.flag_id, admin, i % 4 === 0 ? 'CONFIRMED' : 'DISMISSED']);
  await c.query('SET @b2y_now = NULL');

  // ground truth for matching evaluation
  const truth = pairs.filter(x => x.reportId && x.itemP.itemId).map(x => ({ report_id: x.reportId, item_id: x.itemP.itemId }));
  fs.writeFileSync(path.join(__dirname, '..', 'tests', 'match_ground_truth.json'), JSON.stringify(truth, null, 1));

  const counts = {};
  for (const t of ['users', 'categories', 'locations', 'items', 'lost_reports', 'claims', 'custody_log', 'handovers', 'verification_attempts', 'fraud_flags', 'audit_log'])
    counts[t] = (await q(`SELECT COUNT(*) n FROM ${t}`))[0].n;
  const total = Object.values(counts).reduce((a, b) => a + b, 0);
  console.table(counts);
  console.log('Total rows:', total);
  console.table(await q('SELECT status, COUNT(*) n FROM items GROUP BY status ORDER BY n DESC'));
  const chain = (await c.query('CALL sp_verify_audit_chain()'))[0][0];
  console.log('Audit chain broken links:', chain.length);
  console.log(`Ground-truth lost/found pairs: ${truth.length} (tests/match_ground_truth.json)`);
  console.log('\nDemo logins:  admin@back2you.dev / Admin@123   staff1@back2you.dev / Staff@123   user1@back2you.dev / User@123');
  await c.end();
})().catch(e => { console.error('SEED FAILED:', e.message); process.exit(1); });

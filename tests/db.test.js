// Database test-suite: lifecycle, illegal transitions, triggers, constraints,
// atomicity, audit chain, fraud rules and CONCURRENCY. Writes docs/test-results.md
const fs = require('fs'), path = require('path');
const mysql = require('mysql2/promise');
const cfg = require('../scripts/env');

const pool = mysql.createPool({ ...cfg, connectionLimit: 60, dateStrings: true });
const RUN = Date.now().toString(36);
const results = [];
let N = 0;

async function call(sql, params = [], c = pool) {
  const [res] = await c.query(`CALL ${sql}`, params);
  return Array.isArray(res[0]) ? res[0] : res;
}
const q = async (sql, p = []) => (await pool.query(sql, p))[0];
async function rejects(p, ...needles) {
  try { await p; } catch (e) {
    if (needles.some(n => e.message.includes(n))) return e.message;
    throw new Error(`rejected with wrong error. wanted ${needles.join('|')}, got: ${e.message}`);
  }
  throw new Error(`expected rejection (${needles.join('|')}) but statement succeeded`);
}
function assert(c, msg) { if (!c) throw new Error('assertion failed: ' + msg); }
async function test(id, name, fn) {
  const t0 = Date.now();
  try { const note = await fn(); results.push({ id, name, ok: true, note: note || '', ms: Date.now() - t0 }); console.log(`PASS ${id} ${name}`); }
  catch (e) { results.push({ id, name, ok: false, note: e.message, ms: Date.now() - t0 }); console.log(`FAIL ${id} ${name}\n     ${e.message}`); }
}

let CAT, LOC, LOC2;
async function mkUser(role = 'user', tag = '') {
  const email = `t${RUN}_${++N}${tag}@test.local`;
  const [r] = await pool.query('INSERT INTO users (full_name,email,phone,password_hash,role) VALUES (?,?,?,?,?)',
    [`Test ${role} ${N}`, email, '9000000000', 'x'.repeat(60), role]);
  return r.insertId;
}
async function mkItem(finder, extra = {}) {
  const rows = await call('sp_report_found_item(?,?,?,?,?,?,?,?,?,?)', [
    finder, extra.title || 'Black leather wallet', extra.desc || 'Black leather wallet with a worn corner and some cards inside',
    extra.cat || CAT, extra.color || 'black', extra.brand || 'Tommy', extra.loc || LOC,
    extra.found_at || new Date(Date.now() - 3600e3).toISOString().slice(0, 19).replace('T', ' '),
    'What is the name printed on the first card?', extra.answer || 'Priya']);
  return rows[0].item_id;
}
const status = async id => (await q('SELECT status FROM items WHERE item_id=?', [id]))[0].status;

(async () => {
  // ---- fixtures ---------------------------------------------------------
  let c = await q('SELECT category_id FROM categories LIMIT 1');
  if (!c.length) { await q("INSERT INTO categories (name) VALUES ('Wallet')"); c = await q('SELECT category_id FROM categories LIMIT 1'); }
  CAT = c[0].category_id;
  let l = await q('SELECT location_id FROM locations LIMIT 2');
  while (l.length < 2) { await q("INSERT INTO locations (name,loc_type,city,latitude,longitude) VALUES (?,?,?,?,?)", [`TestLoc ${RUN}${l.length}`, 'public', 'Bengaluru', 12.97 + l.length, 77.59]); l = await q('SELECT location_id FROM locations LIMIT 2'); }
  LOC = l[0].location_id; LOC2 = l[1].location_id;
  const staff = await mkUser('staff'), staff2 = await mkUser('staff'), finder = await mkUser(), owner = await mkUser(), owner2 = await mkUser();
  let admin = (await q("SELECT user_id FROM users WHERE role='admin' AND is_active=1 LIMIT 1"))[0]?.user_id;
  if (!admin) admin = await mkUser('admin');
  const mkVerified = async (answer = 'Priya') => {
    const item = await mkItem(finder, { answer });
    await call('sp_register_item(?,?,?)', [item, staff, 'desk']);
    const cl = (await call('sp_submit_claim(?,?,?,?,?)', [item, owner, null, 'This is my wallet, lost in the cab', answer]))[0].claim_id;
    await call('sp_review_claim(?,?,?,?)', [cl, staff, 1, 'ID checked']);
    return { item, cl };
  };

  // ======================= 1. LIFECYCLE ==================================
  await test('T01', 'Full lifecycle FOUND→REGISTERED→CLAIMED→VERIFIED→HANDED_OVER→RETURNED', async () => {
    const item = await mkItem(finder);
    assert(await status(item) === 'FOUND', 'starts FOUND');
    await call('sp_register_item(?,?,?)', [item, staff, 'Accepted at help desk']);
    assert(await status(item) === 'REGISTERED', 'REGISTERED');
    const cl = (await call('sp_submit_claim(?,?,?,?,?)', [item, owner, null, 'My wallet, has my college ID inside', ' priya ']))[0];
    assert(cl.answer_match == 1, 'answer normalised (case/space)');
    assert(await status(item) === 'CLAIMED', 'CLAIMED');
    await call('sp_review_claim(?,?,?,?)', [cl.claim_id, staff, 1, 'Verified with ID card']);
    assert(await status(item) === 'VERIFIED', 'VERIFIED');
    await call('sp_perform_handover(?,?,?,?,?)', [item, staff, 'ID_CARD', 'KSIT-2022-114', 'handed at desk']);
    assert(await status(item) === 'HANDED_OVER', 'HANDED_OVER');
    await call('sp_confirm_return(?,?)', [item, owner]);
    assert(await status(item) === 'RETURNED', 'RETURNED');
    const cust = await q('SELECT event, end_at FROM custody_log WHERE item_id=? ORDER BY custody_id', [item]);
    assert(cust.map(x => x.event).join() === 'FOUND_BY_FINDER,ACCEPTED_BY_STAFF,HANDED_TO_OWNER', 'custody chain: ' + cust.map(x => x.event));
    assert(cust.every(x => x.end_at), 'all custody rows closed');
    const ho = await q('SELECT given_by, received_by FROM handovers WHERE item_id=?', [item]);
    assert(ho.length === 1 && ho[0].given_by === staff && ho[0].received_by === owner, 'handover who/whom');
    const tl = await q('SELECT event_type FROM v_item_timeline WHERE item_id=? ORDER BY event_time, event_type', [item]);
    assert(tl.length >= 7, 'timeline has events: ' + tl.length);
    return `custody chain = ${cust.map(x => x.event).join(' → ')}; ${tl.length} timeline events`;
  });

  // ======================= 2. STATE MACHINE ==============================
  await test('T02', 'Illegal status jumps are rejected by the trigger (7 cases)', async () => {
    const a = await mkItem(finder);                                   // FOUND
    const cases = [
      [a, 'CLAIMED'], [a, 'VERIFIED'], [a, 'HANDED_OVER'], [a, 'RETURNED'],
    ];
    for (const [id, st] of cases) await rejects(q('UPDATE items SET status=? WHERE item_id=?', [st, id]), 'B2Y-E012');
    await call('sp_register_item(?,?,?)', [a, staff, 'x']);            // REGISTERED
    await rejects(q("UPDATE items SET status='VERIFIED' WHERE item_id=?", [a]), 'B2Y-E012');
    await rejects(q("UPDATE items SET status='HANDED_OVER' WHERE item_id=?", [a]), 'B2Y-E012');
    await rejects(q("UPDATE items SET status='FOUND' WHERE item_id=?", [a]), 'B2Y-E012');   // no going back
    return '7 illegal transitions → B2Y-E012';
  });

  await test('T03', 'RETURNED items are locked against any change', async () => {
    const { item } = await mkVerified();
    await call('sp_perform_handover(?,?,?,?,?)', [item, staff, 'OTP', '482913', null]);
    await call('sp_confirm_return(?,?)', [item, owner]);
    await rejects(q("UPDATE items SET title='Hacked title' WHERE item_id=?", [item]), 'B2Y-E010');
    await rejects(q("UPDATE items SET status='FOUND' WHERE item_id=?", [item]), 'B2Y-E010');
    await rejects(q('DELETE FROM items WHERE item_id=?', [item]), 'B2Y-E019');
  });

  await test('T04', 'No VERIFIED status without a verified claim; no handover without verification', async () => {
    const item = await mkItem(finder);
    await call('sp_register_item(?,?,?)', [item, staff, 'x']);
    await call('sp_submit_claim(?,?,?,?,?)', [item, owner, null, 'It is mine, black wallet from the cab', 'Priya']);
    await rejects(q("UPDATE items SET status='VERIFIED' WHERE item_id=?", [item]), 'B2Y-E016');
    await rejects(call('sp_perform_handover(?,?,?,?,?)', [item, staff, 'OTP', '123456', null]), 'B2Y-E171');
    await rejects(q(`INSERT INTO handovers (item_id,claim_id,given_by,received_by,handed_at,proof_type,proof_ref)
                     SELECT ?, claim_id, ?, ?, NOW(), 'OTP', '123456' FROM claims WHERE item_id=?`, [item, staff, owner, item]), 'B2Y-E040');
  });

  await test('T05', 'A claim with a wrong hidden-detail answer can never be verified', async () => {
    const item = await mkItem(finder);
    await call('sp_register_item(?,?,?)', [item, staff, 'x']);
    const cl = (await call('sp_submit_claim(?,?,?,?,?)', [item, owner, null, 'I think this is my wallet maybe', 'Rahul']))[0];
    assert(cl.answer_match == 0, 'wrong answer not matched');
    await rejects(call('sp_review_claim(?,?,?,?)', [cl.claim_id, staff, 1, 'trust me']), 'B2Y-E034');
    assert(await status(item) === 'CLAIMED', 'item unchanged after rolled-back review');
  });

  await test('T06', 'Retry answer: max 3 attempts, success flips answer_match', async () => {
    const item = await mkItem(finder);
    await call('sp_register_item(?,?,?)', [item, staff, 'x']);
    const cl = (await call('sp_submit_claim(?,?,?,?,?)', [item, owner, null, 'Black leather wallet lost yesterday', 'wrong1']))[0].claim_id;
    await call('sp_retry_answer(?,?,?)', [cl, owner, 'wrong2']);
    const r = (await call('sp_retry_answer(?,?,?)', [cl, owner, 'priya']))[0];
    assert(r.answer_match == 1 && r.attempts_used == 3, 'third attempt matches');
    const item2 = await mkItem(finder);
    await call('sp_register_item(?,?,?)', [item2, staff, 'x']);
    const cl2 = (await call('sp_submit_claim(?,?,?,?,?)', [item2, owner, null, 'Black leather wallet lost yesterday', 'a1']))[0].claim_id;
    await call('sp_retry_answer(?,?,?)', [cl2, owner, 'a2']); await call('sp_retry_answer(?,?,?)', [cl2, owner, 'a3']);
    await rejects(call('sp_retry_answer(?,?,?)', [cl2, owner, 'Priya']), 'B2Y-E143');
  });

  // ======================= 3. BUSINESS RULES =============================
  await test('T07', 'Claim rules: not on FOUND items, finder cannot claim, no duplicate claim', async () => {
    const item = await mkItem(finder);
    await rejects(call('sp_submit_claim(?,?,?,?,?)', [item, owner, null, 'Black leather wallet is mine', 'Priya']), 'B2Y-E021');
    await call('sp_register_item(?,?,?)', [item, staff, 'x']);
    await rejects(call('sp_submit_claim(?,?,?,?,?)', [item, finder, null, 'Black leather wallet is mine', 'Priya']), 'B2Y-E022');
    await call('sp_submit_claim(?,?,?,?,?)', [item, owner, null, 'Black leather wallet is mine', 'Priya']);
    await rejects(call('sp_submit_claim(?,?,?,?,?)', [item, owner, null, 'Black leather wallet is mine', 'Priya']), 'Duplicate', 'uq_claims_item_claimant');
  });

  await test('T08', 'Role enforcement inside the database (user cannot register/review; only admin administers)', async () => {
    const item = await mkItem(finder);
    await rejects(call('sp_register_item(?,?,?)', [item, owner, 'x']), 'B2Y-E102');
    await call('sp_register_item(?,?,?)', [item, staff, 'x']);
    const cl = (await call('sp_submit_claim(?,?,?,?,?)', [item, owner, null, 'Black leather wallet is mine', 'Priya']))[0].claim_id;
    await rejects(call('sp_review_claim(?,?,?,?)', [cl, owner2, 1, 'x']), 'B2Y-E161');
    await rejects(call('sp_set_user_role(?,?,?)', [staff, owner, 'admin']), 'B2Y-E193');
    await rejects(call('sp_delete_spam_item(?,?)', [staff, item]), 'B2Y-E194');
  });

  await test('T09', 'Handover only by the current custodian; custody transfer then handover works', async () => {
    const { item } = await mkVerified();
    await rejects(call('sp_perform_handover(?,?,?,?,?)', [item, staff2, 'OTP', '111222', null]), 'B2Y-E172');
    await call('sp_transfer_custody(?,?,?,?)', [item, staff, staff2, 'moved to evidence room']);
    await rejects(call('sp_perform_handover(?,?,?,?,?)', [item, staff, 'OTP', '111222', null]), 'B2Y-E172');
    await call('sp_perform_handover(?,?,?,?,?)', [item, staff2, 'SIGNATURE', 'sig-8812', null]);
    assert(await status(item) === 'HANDED_OVER', 'handed over by new custodian');
  });

  await test('T10', 'Competing claims: verifying one auto-rejects the others; item reopens when all rejected', async () => {
    const item = await mkItem(finder);
    await call('sp_register_item(?,?,?)', [item, staff, 'x']);
    const c1 = (await call('sp_submit_claim(?,?,?,?,?)', [item, owner, null, 'Black leather wallet is mine', 'Priya']))[0].claim_id;
    const c2 = (await call('sp_submit_claim(?,?,?,?,?)', [item, owner2, null, 'Black leather wallet is mine too', 'priya']))[0].claim_id;
    await call('sp_review_claim(?,?,?,?)', [c1, staff, 1, 'ok']);
    const s = await q('SELECT claim_id,status FROM claims WHERE item_id=?', [item]);
    assert(s.find(x => x.claim_id === c2).status === 'REJECTED', 'competitor auto-rejected');
    const item2 = await mkItem(finder);
    await call('sp_register_item(?,?,?)', [item2, staff, 'x']);
    const d1 = (await call('sp_submit_claim(?,?,?,?,?)', [item2, owner, null, 'Black leather wallet is mine', 'nope']))[0].claim_id;
    await call('sp_review_claim(?,?,?,?)', [d1, staff, 0, 'wrong detail']);
    assert(await status(item2) === 'REGISTERED', 'item back to REGISTERED');
  });

  await test('T11', 'Fraud flags: MULTIPLE_CLAIMANTS, MANY_CLAIMS, REPEATED_WRONG_ANSWER', async () => {
    const fraudster = await mkUser();
    const items = [];
    for (let i = 0; i < 3; i++) { const it = await mkItem(finder); await call('sp_register_item(?,?,?)', [it, staff, 'x']); items.push(it); }
    for (const it of items) await call('sp_submit_claim(?,?,?,?,?)', [it, fraudster, null, 'Definitely my black wallet honest', 'guess' + it]);
    const f = await q('SELECT flag_type FROM fraud_flags WHERE user_id=?', [fraudster]);
    const types = f.map(x => x.flag_type);
    assert(types.includes('MANY_CLAIMS'), 'MANY_CLAIMS raised: ' + types);
    assert(types.includes('REPEATED_WRONG_ANSWER'), 'REPEATED_WRONG_ANSWER raised: ' + types);
    await call('sp_submit_claim(?,?,?,?,?)', [items[0], owner, null, 'Black leather wallet is mine', 'Priya']);
    const mc = await q("SELECT COUNT(*) n FROM fraud_flags WHERE item_id=? AND flag_type='MULTIPLE_CLAIMANTS'", [items[0]]);
    assert(mc[0].n === 1, 'MULTIPLE_CLAIMANTS raised exactly once');
    await call('sp_resolve_flag(?,?,?)', [(await q('SELECT flag_id FROM fraud_flags WHERE user_id=? LIMIT 1', [fraudster]))[0].flag_id, admin, 'CONFIRMED']);
    return 'flags: ' + types.join(', ') + ', MULTIPLE_CLAIMANTS';
  });

  await test('T12', 'Admin DELETE: only FOUND items deletable, deletion is audited', async () => {
    const item = await mkItem(finder, { title: 'Spam listing xx' });
    const r = (await call('sp_delete_spam_item(?,?)', [admin, item]))[0];
    assert(r.deleted === 1, 'deleted');
    const a = await q("SELECT action FROM audit_log WHERE table_name='items' AND record_id=? ORDER BY audit_id", [item]);
    assert(a.map(x => x.action).join() === 'INSERT,DELETE', 'audit shows INSERT,DELETE: ' + a.map(x => x.action));
    const reg = await mkItem(finder); await call('sp_register_item(?,?,?)', [reg, staff, 'x']);
    await rejects(call('sp_delete_spam_item(?,?)', [admin, reg]), 'B2Y-E019');
  });

  // ======================= 4. INTEGRITY ==================================
  await test('T13', 'One active custody holder per item (UNIQUE on generated column)', async () => {
    const item = await mkItem(finder);
    await rejects(q("INSERT INTO custody_log (item_id,holder_id,event,start_at) VALUES (?,?, 'TRANSFERRED', NOW())", [item, staff]), 'Duplicate', 'uq_cust_one_active');
  });

  await test('T14', 'Custody history & handover records are immutable', async () => {
    const { item } = await mkVerified();
    await call('sp_perform_handover(?,?,?,?,?)', [item, staff, 'PHOTO', 'img-4431', null]);
    await rejects(q("UPDATE custody_log SET start_at='2020-01-01' WHERE item_id=?", [item]), 'B2Y-E052');
    await rejects(q('DELETE FROM custody_log WHERE item_id=?', [item]), 'B2Y-E053');
    await rejects(q("UPDATE handovers SET proof_ref='forged' WHERE item_id=?", [item]), 'B2Y-E045');
    await rejects(q('DELETE FROM handovers WHERE item_id=?', [item]), 'B2Y-E045');
    await rejects(q('DELETE FROM claims WHERE item_id=?', [item]), 'B2Y-E035');
    await rejects(q("UPDATE claims SET status='REJECTED' WHERE item_id=?", [item]), 'B2Y-E031');
  });

  await test('T15', 'CHECK / validation constraints reject bad data (8 cases)', async () => {
    const u = await mkUser();
    await rejects(q("INSERT INTO users (full_name,email,password_hash) VALUES ('Bad Mail','not-an-email','x')"), 'ck_users_email');
    await rejects(q("INSERT INTO users (full_name,email,password_hash,phone) VALUES ('Bad Phone','p@x.com','x','abc')"), 'ck_users_phone');
    await rejects(q("INSERT INTO locations (name,loc_type,city,latitude,longitude) VALUES ('Nowhere','public','X',95,10)"), 'ck_locations_lat');
    await rejects(call('sp_report_found_item(?,?,?,?,?,?,?,?,?,?)', [u, 'ab', 'long enough description here', CAT, null, null, LOC, '2026-01-01 10:00:00', 'question here?', 'a']), 'ck_items_title');
    await rejects(call('sp_report_found_item(?,?,?,?,?,?,?,?,?,?)', [u, 'Valid title', 'short', CAT, null, null, LOC, '2026-01-01 10:00:00', 'question here?', 'a']), 'ck_items_desc');
    await rejects(call('sp_report_found_item(?,?,?,?,?,?,?,?,?,?)', [u, 'Valid title', 'long enough description here', CAT, null, null, LOC, '2099-01-01 10:00:00', 'question here?', 'a']), 'B2Y-E002');
    await rejects(call('sp_report_found_item(?,?,?,?,?,?,?,?,?,?)', [u, 'Valid title', 'long enough description here', 999999, null, null, LOC, '2026-01-01 10:00:00', 'question here?', 'a']), 'foreign key', 'FOREIGN KEY', 'fk_items_category');
    await rejects(call('sp_submit_lost_report(?,?,?,?,?,?,?,?)', [u, 'Lost thing', 'long enough description', CAT, null, null, LOC, '2099-01-01 10:00:00']), 'B2Y-E121');
  });

  await test('T16', 'Last active admin cannot be demoted; users cannot be deleted', async () => {
    const admins = await q("SELECT user_id FROM users WHERE role='admin' AND is_active=1");
    if (admins.length === 1) await rejects(call('sp_set_user_role(?,?,?)', [admins[0].user_id, admins[0].user_id, 'user']), 'B2Y-E060');
    await rejects(q('DELETE FROM users WHERE user_id=?', [owner]), 'B2Y-E061');
    return admins.length === 1 ? 'guard exercised' : 'multiple admins present: guard branch skipped, delete rule exercised';
  });

  // ======================= 5. ATOMICITY ==================================
  await test('T17', 'Handover is atomic: failure on the LAST write rolls back everything', async () => {
    const { item, cl } = await mkVerified();
    await q(`CREATE TRIGGER trg_zz_fail BEFORE INSERT ON custody_log FOR EACH ROW
             BEGIN IF NEW.note = 'Proof: PHOTO' AND NEW.item_id = ${item} THEN
               SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'injected failure'; END IF; END`);
    try {
      await rejects(call('sp_perform_handover(?,?,?,?,?)', [item, staff, 'PHOTO', 'img-9', null]), 'injected failure');
    } finally { await q('DROP TRIGGER IF EXISTS trg_zz_fail'); }
    assert(await status(item) === 'VERIFIED', 'item still VERIFIED');
    assert((await q('SELECT COUNT(*) n FROM handovers WHERE item_id=?', [item]))[0].n === 0, 'handover row rolled back');
    const act = await q('SELECT holder_id FROM custody_log WHERE item_id=? AND end_at IS NULL', [item]);
    assert(act.length === 1 && act[0].holder_id === staff, 'custody unchanged (still with staff, still open)');
    await call('sp_perform_handover(?,?,?,?,?)', [item, staff, 'PHOTO', 'img-9', null]);   // and it works afterwards
    return '3 writes (handover insert, custody close, custody insert) fully rolled back';
  });

  // ======================= 6. AUDIT TRAIL ================================
  await test('T18', 'Audit log is append-only, hash-chained, and never stores passwords', async () => {
    await rejects(q("UPDATE audit_log SET changed_by=1 WHERE audit_id=(SELECT m FROM (SELECT MAX(audit_id) m FROM audit_log) x)"), 'B2Y-E070');
    await rejects(q('DELETE FROM audit_log LIMIT 1'), 'B2Y-E070');
    const broken = await call('sp_verify_audit_chain()');
    assert(broken.length === 0, 'chain intact, broken links: ' + JSON.stringify(broken.slice(0, 3)));
    const leak = await q("SELECT COUNT(*) n FROM audit_log WHERE new_values LIKE '%password%' OR new_values LIKE '%$2%'");
    assert(leak[0].n === 0, 'no password material in audit');
    const rows = (await q('SELECT COUNT(*) n FROM audit_log'))[0].n;
    return `${rows} audit rows, chain verified, 0 broken links`;
  });

  await test('T19', 'Tampering with history (trigger bypassed by a DBA) is DETECTED by the hash chain', async () => {
    const [[row]] = await pool.query("SELECT audit_id, new_values FROM audit_log WHERE new_values IS NOT NULL ORDER BY audit_id DESC LIMIT 1 OFFSET 5");
    const [[trg]] = await pool.query('SHOW CREATE TRIGGER trg_audit_bu');
    const ddl = trg['SQL Original Statement'];
    const conn = await pool.getConnection();
    try {
      await conn.query('DROP TRIGGER trg_audit_bu');
      await conn.query("UPDATE audit_log SET new_values = JSON_OBJECT('forged', 1) WHERE audit_id = ?", [row.audit_id]);
      const [res] = await conn.query('CALL sp_verify_audit_chain()');
      const bad = res[0];
      assert(bad.some(b => b.audit_id === row.audit_id), 'forged row detected');
      await conn.query('UPDATE audit_log SET new_values = ? WHERE audit_id = ?', [row.new_values, row.audit_id]);
      const clean = (await conn.query('CALL sp_verify_audit_chain()'))[0][0];
      assert(clean.length === 0, 'chain clean after restoring the row');
      return `forged row #${row.audit_id} flagged: "${bad[0].problem}"`;
    } finally {
      await conn.query('DROP TRIGGER IF EXISTS trg_audit_bu');
      await conn.query(ddl);
      conn.release();
    }
  });

  // ======================= 7. MATCHING FUNCTION ==========================
  await test('T20', 'fn_match_score: weights category/colour/brand/location/time; sp_candidates ranks the right item first', async () => {
    const owner3 = await mkUser();
    const item = await mkItem(finder, { title: 'Silver Casio digital watch', desc: 'Silver Casio digital watch with a scratched strap', color: 'silver', brand: 'Casio' });
    await call('sp_register_item(?,?,?)', [item, staff, 'x']);
    const lost = new Date(Date.now() - 6 * 3600e3).toISOString().slice(0, 19).replace('T', ' ');
    const rid = (await call('sp_submit_lost_report(?,?,?,?,?,?,?,?)', [owner3, 'Lost silver Casio watch', 'Silver Casio digital watch scratched strap lost on my way', CAT, 'silver', 'Casio', LOC, lost]))[0].report_id;
    const good = (await q('SELECT fn_match_score(?,?) s', [item, rid]))[0].s;
    const rid2 = (await call('sp_submit_lost_report(?,?,?,?,?,?,?,?)', [owner3, 'Lost blue umbrella', 'Blue umbrella with wooden handle lost yesterday', CAT, 'blue', 'Fiber', LOC2, '2020-01-01 10:00:00']))[0].report_id;
    const bad = (await q('SELECT fn_match_score(?,?) s', [item, rid2]))[0].s;
    assert(Number(good) > 0.9 && Number(bad) < Number(good), `good=${good} bad=${bad}`);
    const cand = await call('sp_candidates(?,?)', [rid, 5]);
    assert(cand[0].item_id === item, 'best candidate first');
    return `structured score matching item = ${good}, unrelated report = ${bad}`;
  });

  await test('T21', 'View v_item_public never exposes the verification answer hash', async () => {
    const cols = (await q("SELECT column_name c FROM information_schema.columns WHERE table_schema=DATABASE() AND table_name='v_item_public'")).map(x => x.c.toLowerCase());
    assert(!cols.some(c => c.includes('hash')), 'no hash column; columns=' + cols.length);
  });

  // ======================= 8. CONCURRENCY ================================
  await test('T22', 'Concurrency: 25 users claim the same item at once → all recorded, one MULTIPLE_CLAIMANTS flag, no deadlock', async () => {
    const item = await mkItem(finder); await call('sp_register_item(?,?,?)', [item, staff, 'x']);
    const users = []; for (let i = 0; i < 25; i++) users.push(await mkUser());
    const out = await Promise.allSettled(users.map(u => call('sp_submit_claim(?,?,?,?,?)', [item, u, null, 'Black leather wallet is mine, parallel test', 'Priya'])));
    const ok = out.filter(o => o.status === 'fulfilled').length;
    const errs = out.filter(o => o.status === 'rejected').map(o => o.reason.message);
    assert(ok === 25, `expected 25 successes, got ${ok}; errors: ${[...new Set(errs)].join(' | ')}`);
    assert(await status(item) === 'CLAIMED', 'CLAIMED once');
    const fl = (await q("SELECT COUNT(*) n FROM fraud_flags WHERE item_id=? AND flag_type='MULTIPLE_CLAIMANTS'", [item]))[0].n;
    assert(fl === 1, 'exactly one flag, got ' + fl);
    return '25/25 claims committed, status CLAIMED, 1 flag';
  });

  await test('T23', 'Concurrency: 2 staff approve 2 different claims simultaneously → exactly ONE verified', async () => {
    const item = await mkItem(finder); await call('sp_register_item(?,?,?)', [item, staff, 'x']);
    const c1 = (await call('sp_submit_claim(?,?,?,?,?)', [item, owner, null, 'Black leather wallet is mine', 'Priya']))[0].claim_id;
    const c2 = (await call('sp_submit_claim(?,?,?,?,?)', [item, owner2, null, 'Black leather wallet is mine', 'Priya']))[0].claim_id;
    const out = await Promise.allSettled([call('sp_review_claim(?,?,?,?)', [c1, staff, 1, 'a']), call('sp_review_claim(?,?,?,?)', [c2, staff2, 1, 'b'])]);
    assert(out.filter(o => o.status === 'fulfilled').length === 1, 'exactly one approval succeeded');
    const v = (await q("SELECT COUNT(*) n FROM claims WHERE item_id=? AND status='VERIFIED'", [item]))[0].n;
    assert(v === 1, 'one verified claim, got ' + v);
  });

  await test('T24', 'Concurrency: 20 simultaneous handover attempts → exactly one handover, one active custody row', async () => {
    const { item } = await mkVerified();
    const out = await Promise.allSettled(Array.from({ length: 20 }, (_, i) => call('sp_perform_handover(?,?,?,?,?)', [item, staff, 'OTP', 'otp-' + i, null])));
    const ok = out.filter(o => o.status === 'fulfilled').length;
    const msgs = [...new Set(out.filter(o => o.status === 'rejected').map(o => o.reason.message.slice(0, 40)))];
    assert(ok === 1, `exactly 1 success, got ${ok}; other errors: ${msgs.join(' | ')}`);
    assert((await q('SELECT COUNT(*) n FROM handovers WHERE item_id=?', [item]))[0].n === 1, 'one handover row');
    assert((await q('SELECT COUNT(*) n FROM custody_log WHERE item_id=? AND end_at IS NULL', [item]))[0].n === 1, 'one open custody row');
    return `1 success, 19 rejected (${msgs.join('; ')})`;
  });

  await test('T25', 'Audit chain remains intact after all concurrent activity', async () => {
    const broken = await call('sp_verify_audit_chain()');
    assert(broken.length === 0, 'broken links: ' + JSON.stringify(broken.slice(0, 3)));
    return (await q('SELECT COUNT(*) n FROM audit_log'))[0].n + ' audit rows verified';
  });

  // ---- report ------------------------------------------------------------
  const passed = results.filter(r => r.ok).length;
  const md = [`# Database Test Results`, ``, `Run: ${new Date().toISOString()}  |  Server: ${(await q('SELECT VERSION() v'))[0].v}`, ``,
    `**${passed} / ${results.length} tests passed**`, ``, `| ID | Test | Result | Evidence |`, `|---|---|---|---|`,
    ...results.map(r => `| ${r.id} | ${r.name} | ${r.ok ? 'PASS' : 'FAIL'} | ${String(r.note).replace(/\|/g, '/').replace(/\n/g, ' ')} |`), ''].join('\n');
  fs.mkdirSync(path.join(__dirname, '..', 'docs'), { recursive: true });
  fs.writeFileSync(path.join(__dirname, '..', 'docs', 'test-results.md'), md);
  console.log(`\n${passed}/${results.length} passed`);
  await pool.end();
  process.exit(passed === results.length ? 0 : 1);
})();

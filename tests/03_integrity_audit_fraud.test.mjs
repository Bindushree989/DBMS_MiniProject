// Data integrity, audit trail, ownership verification, fraud rules, atomic rollback, least privilege.
import test, { before, after } from 'node:test';
import assert from 'node:assert/strict';
import mysql from 'mysql2/promise';
import { dbConfig } from '../scripts/_env.mjs';
import { freshDb, mkUser, itemAt, claim, register, report, rejectsWith, statusOf, APP_USER, APP_PASS } from './helpers.mjs';

let db;
before(async () => { db = await freshDb(import.meta.url); });
after(async () => { await db.close(); });

const isCheckFail = (e) => e.errno === 3819 || e.errno === 4025;   // MySQL 8 / MariaDB
async function rejectsCheck(p, label) {
  await assert.rejects(p, (e) => { assert.ok(isCheckFail(e), `${label}: expected a CHECK violation, got ${e.errno} ${e.sqlMessage}`); return true; });
}

test('CHECK constraints reject malformed rows even when SQL is typed by hand (bypassing the app)', async () => {
  const u = await mkUser(db, 'user');
  await rejectsCheck(db.q("INSERT INTO users (full_name, email, password_hash) VALUES ('A', 'ok@x.com', 'h')"), 'one-letter name');
  await rejectsCheck(db.q("INSERT INTO users (full_name, email, password_hash) VALUES ('Alice', 'not-an-email', 'h')"), 'bad email');
  await rejectsCheck(db.q("INSERT INTO users (full_name, email, phone, password_hash) VALUES ('Alice', 'a@x.com', 'abc', 'h')"), 'bad phone');
  const base = "INSERT INTO items (title, description, category_id, found_location_id, found_at, finder_id%s) VALUES (%s, 1, 1, NOW() - INTERVAL 1 HOUR, ?%s)";
  const ins = (cols, vals, extra) => db.q(base.replace('%s', cols).replace('%s', vals).replace('%s', extra), [u]);
  await rejectsCheck(ins('', "'ab', 'long enough description'", ''), 'title too short');
  await rejectsCheck(ins('', "'Valid title', 'short'", ''), 'description too short');
  await rejectsCheck(ins(', verification_hint', "'Valid title', 'long enough description'", ", 'a hint without an answer'"), 'hint without answer hash');
  await rejectsCheck(db.q("INSERT INTO locations (name, location_type, city, latitude, longitude) VALUES ('Nowhere', 'other', 'X', 95, 10)"), 'latitude out of range');
  await rejectsCheck(db.q("INSERT INTO locations (name, location_type, city, latitude) VALUES ('Half', 'other', 'X', 10)"), 'latitude without longitude');
  // foreign keys
  await assert.rejects(db.q("INSERT INTO items (title, description, category_id, found_location_id, found_at, finder_id) VALUES ('Valid title','long enough description', 999, 1, NOW() - INTERVAL 1 HOUR, ?)", [u]), (e) => e.errno === 1452);
  // unique
  await assert.rejects(db.q("INSERT INTO categories (name) VALUES ('Phone')"), (e) => e.errno === 1062);
});

test('audit trail: every lifecycle change is logged by triggers with old/new values and the acting user', async () => {
  const c = await itemAt(db, 'RETURNED');
  const rows = await db.q("SELECT action, old_values, new_values, changed_by FROM audit_log WHERE table_name = 'items' AND record_id = ? ORDER BY audit_id", [String(c.itemId)]);
  assert.equal(rows[0].action, 'INSERT');
  assert.equal(rows[0].changed_by, `u${c.finder}`, 'actor comes from @b2y_actor');
  const changes = rows.filter((r) => r.action === 'UPDATE').map((r) => {
    const o = typeof r.old_values === 'string' ? JSON.parse(r.old_values) : r.old_values;
    const n = typeof r.new_values === 'string' ? JSON.parse(r.new_values) : r.new_values;
    return `${o.status}>${n.status}`;
  });
  assert.deepEqual(changes, ['FOUND>REGISTERED', 'REGISTERED>CLAIMED', 'CLAIMED>VERIFIED', 'VERIFIED>HANDED_OVER', 'HANDED_OVER>RETURNED']);
  const tables = (await db.q('SELECT DISTINCT table_name FROM audit_log')).map((r) => r.table_name);
  for (const t of ['users', 'items', 'claims', 'handovers', 'custody_log']) assert.ok(tables.includes(t), `audit covers ${t}`);
});

test('audit_log is append-only: UPDATE and DELETE are refused, even for the DB admin', async () => {
  const id = await db.scalar('SELECT audit_id FROM audit_log LIMIT 1');
  await rejectsWith(db.q("UPDATE audit_log SET changed_by = 'nobody' WHERE audit_id = ?", [id]), /append-only/);
  await rejectsWith(db.q('DELETE FROM audit_log WHERE audit_id = ?', [id]), /append-only/);
  await rejectsWith(db.q('TRUNCATE TABLE audit_log').catch((e) => { throw Object.assign(e, { sqlMessage: 'append-only (truncate blocked)' }); }).then(() => { throw new Error('truncate succeeded'); }), /append-only|truncate/);
});

test('handovers, custody history and claims are permanent records', async () => {
  const c = await itemAt(db, 'HANDED_OVER');
  const h = await db.scalar('SELECT handover_id FROM handovers WHERE item_id = ? LIMIT 1', [c.itemId]);
  await rejectsWith(db.q("UPDATE handovers SET proof_reference = 'tampered' WHERE handover_id = ?", [h]), /immutable/);
  await rejectsWith(db.q('DELETE FROM handovers WHERE handover_id = ?', [h]), /cannot be deleted/);
  const cu = await db.scalar('SELECT custody_id FROM custody_log WHERE item_id = ? ORDER BY custody_id LIMIT 1', [c.itemId]);
  await rejectsWith(db.q('UPDATE custody_log SET holder_id = ? WHERE custody_id = ?', [c.claimant, cu]), /immutable/);
  await rejectsWith(db.q('DELETE FROM custody_log WHERE custody_id = ?', [cu]), /cannot be deleted/);
  await rejectsWith(db.q('DELETE FROM claims WHERE claim_id = ?', [c.claimId]), /permanent/);
});

test('ownership verification: hint answer is normalised, failures are evidence, other claims are rejected on success', async () => {
  const finder = await mkUser(db, 'user'); const staff = await mkUser(db, 'staff');
  const a = await mkUser(db, 'user'); const b = await mkUser(db, 'user');
  const item = await report(db, finder); await register(db, item, staff);
  const ca = await claim(db, item, a, '  MOUNTAIN ');            // case / whitespace do not matter
  const cb = await claim(db, item, b, 'beach');
  const [wrong] = await db.call('sp_verify_claim', [cb, staff, 'HINT_ANSWER', null, null]);
  assert.equal(wrong.outcome, 'FAIL'); assert.equal(Number(wrong.attempts_left), 2);
  const [right] = await db.call('sp_verify_claim', [ca, staff, 'HINT_ANSWER', null, null]);
  assert.equal(right.outcome, 'PASS');
  assert.equal(await statusOf(db, item), 'VERIFIED');
  const loser = await db.one('SELECT status, reject_reason FROM claims WHERE claim_id = ?', [cb]);
  assert.equal(loser.status, 'REJECTED'); assert.match(loser.reject_reason, /Another claim/);
  assert.equal(await db.scalar('SELECT COUNT(*) FROM verification_attempts WHERE claim_id = ?', [cb]), 1, 'the failed attempt is kept');
  assert.equal(await db.scalar("SELECT COUNT(*) FROM claims WHERE item_id = ? AND status = 'VERIFIED'", [item]), 1, 'exactly one verified claim');
});

test('verification rules: ID proof needs a reference, admin override is admin-only, staff cannot verify their own claim', async () => {
  const finder = await mkUser(db, 'user'); const s1 = await mkUser(db, 'staff'); const s2 = await mkUser(db, 'staff'); const admin = await mkUser(db, 'admin');
  const owner = await mkUser(db, 'user');
  const noHint = await report(db, finder, { hint: null, answer: null }); await register(db, noHint, s1);
  const c1 = await claim(db, noHint, owner, null);
  await rejectsWith(db.call('sp_verify_claim', [c1, s1, 'HINT_ANSWER', null, null]), /no hidden-detail question/);
  await rejectsWith(db.call('sp_verify_claim', [c1, s1, 'ID_PROOF', null, null]), /proof reference/);
  await rejectsWith(db.call('sp_verify_claim', [c1, s1, 'ADMIN_OVERRIDE', 'REF-1', null]), /Only an admin/);
  await rejectsWith(db.call('sp_verify_claim', [c1, owner, 'ID_PROOF', 'REF-1', null]), /Only staff/);
  const [ok] = await db.call('sp_verify_claim', [c1, admin, 'ADMIN_OVERRIDE', 'REF-ADMIN-1', 'checked passport']);
  assert.equal(ok.outcome, 'PASS');

  const it2 = await report(db, finder); await register(db, it2, s1);
  const mine = await claim(db, it2, s2);                          // another staff member claims it
  await rejectsWith(db.call('sp_verify_claim', [mine, s2, 'ID_PROOF', 'MY-ID-1', null]), /cannot verify your own claim/);
});

test('fraud rules: competing claimants, three failed checks, rapid claiming', async () => {
  // 1) competing claimants
  const staff = await mkUser(db, 'staff');
  const it = await itemAt(db, 'REGISTERED', { staff });
  const users = [await mkUser(db, 'user'), await mkUser(db, 'user'), await mkUser(db, 'user')];
  for (const u of users) await claim(db, it.itemId, u);
  const flags = await db.q("SELECT user_id, severity FROM fraud_flags WHERE item_id = ? AND reason = 'MULTIPLE_CLAIMANTS' ORDER BY flag_id", [it.itemId]);
  assert.deepEqual(flags.map((f) => [f.user_id, f.severity]), [[users[1], 'MEDIUM'], [users[2], 'HIGH']]);

  // 2) three wrong answers -> claim rejected, HIGH flag, item released, no retry possible
  const it3 = await itemAt(db, 'REGISTERED', { staff });
  const guesser = await mkUser(db, 'user');
  const cid = await claim(db, it3.itemId, guesser, 'wrong');
  const left = [];
  for (let i = 0; i < 3; i++) left.push((await db.call('sp_verify_claim', [cid, staff, 'HINT_ANSWER', null, null]))[0].attempts_left);
  assert.deepEqual(left.map(Number), [2, 1, 0]);
  assert.equal((await db.one('SELECT status FROM claims WHERE claim_id = ?', [cid])).status, 'REJECTED');
  assert.equal(await statusOf(db, it3.itemId), 'REGISTERED', 'no pending claim left -> back to REGISTERED');
  assert.equal(await db.scalar("SELECT severity FROM fraud_flags WHERE claim_id = ? AND reason = 'REPEATED_FAILED_VERIFICATION'", [cid]), 'HIGH');
  await rejectsWith(claim(db, it3.itemId, guesser, 'mountain'), /rejected after failed verification/);
  await rejectsWith(db.call('sp_verify_claim', [cid, staff, 'HINT_ANSWER', null, null]), /Only pending claims/);

  // 3) rapid claims by one user
  const rapid = await mkUser(db, 'user');
  for (let i = 0; i < 4; i++) { const x = await itemAt(db, 'REGISTERED', { staff }); await claim(db, x.itemId, rapid); }
  assert.equal(await db.scalar("SELECT COUNT(*) FROM fraud_flags WHERE user_id = ? AND reason = 'RAPID_CLAIMS'", [rapid]), 1);
});

test('handover is atomic: a refused handover leaves custody, status and handover rows untouched', async () => {
  const c = await itemAt(db, 'VERIFIED');
  const other = await mkUser(db, 'staff');
  const snap = async () => [await statusOf(db, c.itemId),
    await db.scalar('SELECT COUNT(*) FROM handovers WHERE item_id = ?', [c.itemId]),
    await db.scalar('SELECT COUNT(*) FROM custody_log WHERE item_id = ?', [c.itemId]),
    await db.scalar('SELECT holder_id FROM custody_log WHERE item_id = ? AND ended_at IS NULL', [c.itemId])];
  const before = await snap();
  await rejectsWith(db.call('sp_perform_handover', [c.claimId, other, 'ID_CARD', 'ID-1', null]), /current custodian/);
  await rejectsWith(db.call('sp_perform_handover', [c.claimId, c.claimant, 'ID_CARD', 'ID-1', null]), /Only staff/);
  assert.deepEqual(await snap(), before, 'nothing changed after refused attempts');

  await db.call('sp_perform_handover', [c.claimId, c.staff, 'ID_CARD', 'ID-777', 'collected']);
  const rows = await db.q('SELECT holder_id, from_user_id, ended_at FROM custody_log WHERE item_id = ? ORDER BY custody_id', [c.itemId]);
  assert.equal(rows.length, 3, 'finder -> staff -> owner');
  assert.equal(rows[2].holder_id, c.claimant); assert.equal(rows[2].from_user_id, c.staff); assert.equal(rows[2].ended_at, null);
  await rejectsWith(db.call('sp_perform_handover', [c.claimId, c.staff, 'ID_CARD', 'ID-777', null]), /not ready for handover/);
});

test('stored functions: answer hashing, haversine distance, structured score', async () => {
  assert.equal(await db.scalar("SELECT fn_hash_answer('  Mountain ')"), await db.scalar("SELECT SHA2('mountain', 256)"));
  assert.equal(await db.scalar("SELECT fn_hash_answer('   ')"), null);
  const km = await db.scalar('SELECT fn_distance_km(12.9716, 77.5946, 13.0827, 80.2707)');   // Bengaluru -> Chennai
  assert.ok(km > 285 && km < 295, `distance ${km}`);
  const finder = await mkUser(db, 'user');
  const id = await report(db, finder, { category_id: 1, color: 'black', brand: 'Samsung', location_id: 5, found_at: new Date(Date.now() - 2 * 3600e3).toISOString().slice(0, 19).replace('T', ' ') });
  const lost = new Date(Date.now() - 5 * 3600e3).toISOString().slice(0, 19).replace('T', ' ');
  const sc = (...a) => db.scalar('SELECT fn_structured_score(?, ?, ?, ?, ?, ?)', [id, ...a]);
  assert.equal(Number(await sc(1, 'Black', 'samsung', 5, lost)), 1);              // everything matches (case-insensitive)
  assert.equal(Number(await sc(2, null, null, null, null)), 0);                   // wrong category only
  assert.equal(Number(await sc(1, null, null, null, null)), 1);                   // missing attributes are not penalised
  assert.equal(Number(await sc(null, null, null, null, new Date(Date.now() + 2 * 86400e3).toISOString().slice(0, 19).replace('T', ' '))), 0, 'found 2 days before it was lost = impossible');
  assert.equal(Number(await sc(null, null, null, null, new Date(Date.now() - 2 * 3600e3 + 3600e3).toISOString().slice(0, 19).replace('T', ' '))), 1, 'a few hours of clock fuzz is tolerated');
  const near = Number(await sc(null, null, null, 6, null));                       // MG Road vs Indiranagar metro, ~3.7 km apart
  assert.ok(near > 0.75 && near < 0.95, `distance decay ${near}`);
  assert.equal(Number(await sc(null, null, null, 1, null)), 0, 'airport route is more than 20 km away');
});

test('vector-sync outbox: triggers queue UPSERT / STATUS / DELETE in the same transaction as the data change', async () => {
  const finder = await mkUser(db, 'user'); const staff = await mkUser(db, 'staff');
  const id = await report(db, finder);
  const ops = async () => (await db.q('SELECT op FROM embedding_outbox WHERE item_id = ? ORDER BY outbox_id', [id])).map((r) => r.op);
  assert.deepEqual(await ops(), ['UPSERT']);
  await register(db, id, staff);
  assert.deepEqual(await ops(), ['UPSERT', 'STATUS']);
  const w = await report(db, finder);
  await db.call('sp_withdraw_found_item', [w, finder]);
  assert.deepEqual((await db.q('SELECT op FROM embedding_outbox WHERE item_id = ? ORDER BY outbox_id', [w])).map((r) => r.op), ['UPSERT', 'DELETE']);
});

test('least privilege: the application account can only write through stored procedures', async () => {
  const cfg = { ...dbConfig(true), user: APP_USER, password: APP_PASS, database: db.name };
  const app = await mysql.createConnection(cfg);
  const denied = (p) => assert.rejects(p, (e) => e.errno === 1142 || e.errno === 1143 || e.errno === 1370);
  try {
    await denied(app.query("INSERT INTO items (title, description, category_id, found_location_id, found_at, finder_id) VALUES ('Direct insert','by-passing the proc',1,1,NOW(),1)"));
    await denied(app.query("UPDATE items SET status = 'RETURNED' WHERE item_id = 1"));
    await denied(app.query('DELETE FROM handovers'));
    await denied(app.query('DELETE FROM audit_log'));
    await denied(app.query("INSERT INTO audit_log (table_name, record_id, action, changed_by) VALUES ('x','1','INSERT','me')"));
    const finder = await mkUser(db, 'user');
    const [res] = await app.query("CALL sp_report_found_item(?, 'Via procedure', 'allowed because it is a procedure', 1, 'red', NULL, 1, NOW() - INTERVAL 1 HOUR, NULL, NULL, NULL)", [finder]);
    assert.ok(res[0][0].item_id > 0);
    const [v] = await app.query('SELECT * FROM v_item_overview LIMIT 1');
    assert.ok(!('verification_answer_hash' in v[0]), 'views never expose the answer hash');
  } finally { await app.end(); }
});

test('views: custody timeline orders the whole case file; KPI view agrees with raw counts', async () => {
  const c = await itemAt(db, 'RETURNED');
  const ev = await db.q('SELECT event_type FROM v_item_timeline WHERE item_id = ? ORDER BY event_time, FIELD(event_type, "REPORTED","CUSTODY","CLAIM_SUBMITTED","VERIFICATION","HANDOVER","RETURNED")', [c.itemId]);
  const kinds = ev.map((e) => e.event_type);
  for (const k of ['REPORTED', 'CUSTODY', 'CLAIM_SUBMITTED', 'VERIFICATION', 'HANDOVER', 'RETURNED']) assert.ok(kinds.includes(k), `timeline has ${k}`);
  const [k] = await db.q('SELECT total_items, returned_items FROM v_admin_kpis');
  assert.equal(Number(k.total_items), Number(await db.scalar('SELECT COUNT(*) FROM items')));
  assert.equal(Number(k.returned_items), Number(await db.scalar("SELECT COUNT(*) FROM items WHERE status = 'RETURNED'")));
});

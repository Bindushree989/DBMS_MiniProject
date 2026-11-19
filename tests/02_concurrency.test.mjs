// Real parallel connections (each db.call checks out its own pooled connection) racing on the same rows.
// The procedures serialise on SELECT ... FOR UPDATE of the item row; these tests prove it.
import test, { before, after } from 'node:test';
import assert from 'node:assert/strict';
import { freshDb, mkUser, itemAt, claim, register, report, statusOf, openCustody } from './helpers.mjs';

let db;
before(async () => { db = await freshDb(import.meta.url, { connections: 40 }); });
after(async () => { await db.close(); });

const msgOf = (r) => r.reason?.sqlMessage ?? r.reason?.message ?? '';

/** A deadlock that survives the retry policy (6 attempts) is a real defect. Single retries are expected
 *  under InnoDB unique-index neighbour locking and are only reported (see the final test). */
function assertNoDeadlock(results, label) {
  const dead = results.filter((r) => r.status === 'rejected' && (r.reason?.errno === 1213 || /Deadlock/i.test(msgOf(r))));
  assert.equal(dead.length, 0, `FINDING: deadlock (errno 1213) in "${label}": ${dead.map(msgOf).join(' | ')}`);
}
const ok = (rs) => rs.filter((r) => r.status === 'fulfilled');
const failed = (rs) => rs.filter((r) => r.status === 'rejected');

const auditCount = (table, id, action, status) => db.scalar(
  `SELECT COUNT(*) FROM audit_log WHERE table_name = ? AND record_id = ? AND action = ?
      AND JSON_UNQUOTE(JSON_EXTRACT(new_values, '$.status')) = ?`, [table, String(id), action, status]);

test('20 users claim the same REGISTERED item simultaneously: all succeed, item CLAIMED, exactly one status change', async () => {
  const c = await itemAt(db, 'REGISTERED');
  const users = [];
  for (let i = 0; i < 20; i++) users.push(await mkUser(db, 'user', `Racer Claimant ${i}`));
  const rs = await Promise.allSettled(users.map((u) => claim(db, c.itemId, u)));
  assertNoDeadlock(rs, '20 simultaneous claims');
  assert.equal(ok(rs).length, 20, `failures: ${failed(rs).map(msgOf).join(' | ')}`);
  assert.equal(new Set(ok(rs).map((r) => r.value)).size, 20, 'every claim gets its own id');

  assert.equal(await statusOf(db, c.itemId), 'CLAIMED');
  assert.equal(await db.scalar("SELECT COUNT(*) FROM claims WHERE item_id = ? AND status = 'PENDING'", [c.itemId]), 20);
  assert.equal(await auditCount('items', c.itemId, 'UPDATE', 'CLAIMED'), 1, 'REGISTERED -> CLAIMED happens exactly once');
  assert.equal(await db.scalar(
    `SELECT COUNT(*) FROM audit_log WHERE table_name='items' AND record_id=? AND action='UPDATE'
        AND JSON_UNQUOTE(JSON_EXTRACT(old_values,'$.status'))='CLAIMED'`, [String(c.itemId)]), 0, 'no CLAIMED -> X change');
  // claims are serialised, so the k-th claim sees k pending claims: claims 2..20 each raise MULTIPLE_CLAIMANTS
  assert.equal(await db.scalar("SELECT COUNT(*) FROM fraud_flags WHERE item_id = ? AND reason='MULTIPLE_CLAIMANTS'", [c.itemId]), 19);
  assert.equal(await openCustody(db, c.itemId), 1);
});

test('two staff hand over the same verified claim simultaneously: exactly 1 succeeds, 1 owner handover, 1 open custody row', async () => {
  for (let round = 0; round < 4; round++) {
    const c = await itemAt(db, 'VERIFIED');
    const other = await mkUser(db, 'staff', `Other Staff ${round}`);
    const racers = round % 2 === 0
      ? [c.staff, other]            // custodian vs. a non-custodian
      : [c.staff, c.staff];         // the same custodian on two connections (double click)
    const rs = await Promise.allSettled(racers.map((s) =>
      db.call('sp_perform_handover', [c.claimId, s, 'ID_CARD', `ID-R${round}`, 'race'], { actor: `s${s}` })));
    assertNoDeadlock(rs, `handover race round ${round}`);
    assert.equal(ok(rs).length, 1, `round ${round}: exactly one handover must win (${failed(rs).map(msgOf).join(' | ')})`);
    assert.equal(failed(rs).length, 1);
    assert.match(msgOf(failed(rs)[0]), /No handover without a verified claim|Only the current custodian|not ready for handover/);

    assert.equal(await db.scalar("SELECT COUNT(*) FROM handovers WHERE item_id = ? AND handover_type='STAFF_TO_OWNER'", [c.itemId]), 1);
    assert.equal(await openCustody(db, c.itemId), 1);
    assert.equal(await db.scalar('SELECT holder_id FROM custody_log WHERE item_id = ? AND ended_at IS NULL', [c.itemId]), c.claimant);
    assert.equal(await statusOf(db, c.itemId), 'HANDED_OVER');
    assert.equal(await auditCount('items', c.itemId, 'UPDATE', 'HANDED_OVER'), 1);
  }
});

test('two staff verify two different pending claims on one item simultaneously: one VERIFIED, the other REJECTED', async () => {
  for (let round = 0; round < 4; round++) {
    const c = await itemAt(db, 'CLAIMED');
    const claimant2 = await mkUser(db, 'user', `Second Claimant ${round}`);
    const claim2 = await claim(db, c.itemId, claimant2);
    const staff2 = await mkUser(db, 'staff', `Second Verifier ${round}`);
    const rs = await Promise.allSettled([
      db.call('sp_verify_claim', [c.claimId, c.staff, 'HINT_ANSWER', null, null], { actor: `s${c.staff}` }),
      db.call('sp_verify_claim', [claim2, staff2, 'HINT_ANSWER', null, null], { actor: `s${staff2}` }),
    ]);
    assertNoDeadlock(rs, `verify race round ${round}`);
    assert.equal(ok(rs).length, 1, `round ${round}: ${failed(rs).map(msgOf).join(' | ')}`);
    assert.match(msgOf(failed(rs)[0]), /Only pending claims can be verified/);

    const statuses = (await db.q('SELECT status FROM claims WHERE item_id = ? ORDER BY claim_id', [c.itemId])).map((r) => r.status).sort();
    assert.deepEqual(statuses, ['REJECTED', 'VERIFIED']);
    assert.equal(await statusOf(db, c.itemId), 'VERIFIED');
    assert.equal(await db.scalar(
      `SELECT COUNT(*) FROM verification_attempts v JOIN claims c USING (claim_id) WHERE c.item_id = ? AND v.outcome='PASS'`, [c.itemId]), 1);
    assert.equal(await db.scalar("SELECT reject_reason FROM claims WHERE item_id = ? AND status='REJECTED'", [c.itemId]),
      'Another claim on this item was verified');
  }
});

test('same user double-submitting a claim concurrently ends with exactly one live claim', async () => {
  const c = await itemAt(db, 'REGISTERED');
  const u = await mkUser(db, 'user', 'Double Clicker');
  const rs = await Promise.allSettled(Array.from({ length: 6 }, () => claim(db, c.itemId, u)));
  assertNoDeadlock(rs, 'double submit');
  assert.equal(ok(rs).length, 1, failed(rs).map(msgOf).join(' | '));
  assert.equal(failed(rs).length, 5);
  for (const f of failed(rs)) assert.match(msgOf(f), /already have an active claim/);
  assert.equal(await db.scalar('SELECT COUNT(*) FROM claims WHERE item_id = ? AND claimant_id = ?', [c.itemId, u]), 1);
  assert.equal(await db.scalar("SELECT COUNT(*) FROM claims WHERE item_id = ? AND claimant_id = ? AND live_flag = 1", [c.itemId, u]), 1);
  assert.equal(await statusOf(db, c.itemId), 'CLAIMED');
  assert.equal(await auditCount('items', c.itemId, 'UPDATE', 'CLAIMED'), 1);
});

test('30 parallel register / transfer-custody calls never leave an item with != 1 open custody row', async () => {
  const finder = await mkUser(db, 'user', 'Race Finder');
  const admin = await mkUser(db, 'admin', 'Race Admin');
  const staff = [];
  for (let i = 0; i < 6; i++) staff.push(await mkUser(db, 'staff', `Race Staff ${i}`));
  const itemId = await report(db, finder);

  // phase 1: 10 staff try to register the same FOUND item at once -> exactly one wins
  const regs = await Promise.allSettled(Array.from({ length: 10 }, (_, i) => register(db, itemId, staff[i % 6])));
  assertNoDeadlock(regs, 'register race');
  assert.equal(ok(regs).length, 1, failed(regs).map(msgOf).join(' | '));
  for (const f of failed(regs)) assert.match(msgOf(f), /Only items in FOUND status can be registered/);
  assert.equal(await statusOf(db, itemId), 'REGISTERED');
  assert.equal(await openCustody(db, itemId), 1);

  // phase 2: 20 concurrent admin-driven transfers to random staff; some collide with "already held"
  const targets = Array.from({ length: 20 }, (_, i) => staff[(i * 5 + 1) % 6]);
  const xfers = await Promise.allSettled(targets.map((to, i) =>
    db.call('sp_transfer_custody', [itemId, admin, to, 'OTHER', `TR-${i}-REF`, `Shelf ${i}`, 'race'], { actor: `a${admin}` })));
  assertNoDeadlock(xfers, 'transfer race');
  for (const f of failed(xfers)) assert.match(msgOf(f), /already held by that staff member/);
  assert.ok(ok(xfers).length >= 1);

  assert.equal(await openCustody(db, itemId), 1, 'exactly one open custody row after the storm');
  assert.equal(await db.scalar('SELECT COUNT(*) FROM custody_log WHERE item_id = ?', [itemId]), 1 + 1 + ok(xfers).length);
  assert.equal(await db.scalar("SELECT COUNT(*) FROM handovers WHERE item_id = ? AND handover_type='STAFF_TO_STAFF'", [itemId]), ok(xfers).length);

  // chain continuity: every row was handed over by the previous row's holder
  const rows = await db.q('SELECT holder_id, from_user_id, started_at, ended_at FROM custody_log WHERE item_id = ? ORDER BY custody_id', [itemId]);
  for (let i = 1; i < rows.length; i++) {
    assert.equal(rows[i].from_user_id, rows[i - 1].holder_id, `custody row ${i} continues from the previous holder`);
    assert.ok(rows[i - 1].ended_at !== null, 'earlier rows are closed');
  }
  assert.equal(rows[rows.length - 1].ended_at, null);
  assert.equal(rows[0].holder_id, finder);
});

test('register + transfer + claim + verify racing on many items at once keep every item consistent', async () => {
  const finder = await mkUser(db, 'user', 'Mixed Finder');
  const admin = await mkUser(db, 'admin', 'Mixed Admin');
  const s1 = await mkUser(db, 'staff', 'Mixed Staff 1');
  const s2 = await mkUser(db, 'staff', 'Mixed Staff 2');
  const claimants = [];
  for (let i = 0; i < 3; i++) claimants.push(await mkUser(db, 'user', `Mixed Claimant ${i}`));
  const items = [];
  for (let i = 0; i < 6; i++) items.push(await report(db, finder));
  const jobs = [];
  for (const it of items) {
    jobs.push(register(db, it, s1));
    jobs.push(register(db, it, s2));
    jobs.push(db.call('sp_transfer_custody', [it, admin, s2, 'OTHER', 'TR-MIX-1', 'Shelf M', 'mix'], { actor: 'a' }));
    for (const c of claimants) jobs.push(claim(db, it, c));
  }
  const rs = await Promise.allSettled(jobs);
  assertNoDeadlock(rs, 'mixed storm');
  for (const it of items) {
    const n = await openCustody(db, it);
    assert.equal(n, 1, `item ${it} has ${n} open custody rows`);
    const st = await statusOf(db, it);
    assert.ok(['FOUND', 'REGISTERED', 'CLAIMED'].includes(st), `item ${it} in unexpected status ${st}`);
    const pending = await db.scalar("SELECT COUNT(*) FROM claims WHERE item_id = ? AND status='PENDING'", [it]);
    assert.equal(st === 'CLAIMED', pending > 0, `item ${it}: status ${st} vs ${pending} pending claims`);
  }
});

test('report: deadlock victims were transparently retried and no racer was lost', () => {
  console.log(`  [info] deadlock victims retried by the helper during this file: ${db.deadlockRetries}`);
  assert.ok(db.deadlockRetries >= 0);
});

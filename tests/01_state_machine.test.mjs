// The item / claim lifecycle is enforced by triggers, not by the UI.
import test, { before, after } from 'node:test';
import assert from 'node:assert/strict';
import { freshDb, mkUser, report, itemAt, rejectsWith, statusOf } from './helpers.mjs';

let db;
before(async () => { db = await freshDb(import.meta.url); });
after(async () => { await db.close(); });

const STATES = ['FOUND', 'REGISTERED', 'CLAIMED', 'VERIFIED', 'HANDED_OVER', 'RETURNED'];

test('happy path: Found -> Registered -> Claimed -> Verified -> Handed Over -> Returned', async () => {
  const c = await itemAt(db, 'FOUND');
  assert.equal(await statusOf(db, c.itemId), 'FOUND');

  await db.call('sp_register_item', [c.itemId, c.staff, 'ID_CARD', 'ID-1', 'Shelf B']);
  assert.equal(await statusOf(db, c.itemId), 'REGISTERED');

  const [cl] = await db.call('sp_submit_claim', [c.itemId, c.claimant, 'It is my phone with a cracked guard', 'mountain']);
  assert.equal(await statusOf(db, c.itemId), 'CLAIMED');

  const [v] = await db.call('sp_verify_claim', [cl.claim_id, c.staff, 'HINT_ANSWER', null, null]);
  assert.equal(v.outcome, 'PASS');
  assert.equal(await statusOf(db, c.itemId), 'VERIFIED');

  await db.call('sp_perform_handover', [cl.claim_id, c.staff, 'SIGNATURE', 'SIG-9', 'at desk']);
  assert.equal(await statusOf(db, c.itemId), 'HANDED_OVER');

  const [done] = await db.call('sp_confirm_return', [cl.claim_id, c.claimant]);
  assert.equal(done.status, 'RETURNED');
  const item = await db.one('SELECT status, returned_at, registered_at FROM items WHERE item_id = ?', [c.itemId]);
  assert.equal(item.status, 'RETURNED');
  assert.ok(item.returned_at && item.registered_at);
  assert.equal(await db.scalar('SELECT status FROM claims WHERE claim_id = ?', [cl.claim_id]), 'FULFILLED');
});

test('every status change that is not in status_transitions is rejected (all 23 illegal pairs, real items)', async () => {
  const legal = new Set((await db.q('SELECT from_status, to_status FROM status_transitions')).map((r) => `${r.from_status}>${r.to_status}`));
  assert.equal(legal.size, 7);
  let attempted = 0;
  for (const from of STATES) {
    const c = await itemAt(db, from);
    for (const to of STATES) {
      if (to === from || legal.has(`${from}>${to}`)) continue;
      attempted++;
      await rejectsWith(db.q('UPDATE items SET status = ? WHERE item_id = ?', [to, c.itemId]),
        from === 'RETURNED' ? /closed and cannot be modified/ : /Illegal status transition/);
      assert.equal(await statusOf(db, c.itemId), from, `${from} must be unchanged after a rejected jump to ${to}`);
    }
  }
  assert.equal(attempted, 23); // 6 x 5 = 30 pairs, minus 7 legal ones
});

test('legal transitions still need their pre-conditions (no shortcuts through a legal arrow)', async () => {
  const found = await itemAt(db, 'FOUND');
  await rejectsWith(db.q("UPDATE items SET status='REGISTERED' WHERE item_id=?", [found.itemId]), /staff custody/);

  const reg = await itemAt(db, 'REGISTERED');
  await rejectsWith(db.q("UPDATE items SET status='CLAIMED' WHERE item_id=?", [reg.itemId]), /without a pending claim/);

  const claimed = await itemAt(db, 'CLAIMED');
  await rejectsWith(db.q("UPDATE items SET status='VERIFIED' WHERE item_id=?", [claimed.itemId]), /without a verified claim/);

  const verified = await itemAt(db, 'VERIFIED');
  await rejectsWith(db.q("UPDATE items SET status='HANDED_OVER' WHERE item_id=?", [verified.itemId]), /without a recorded owner handover/);
  await rejectsWith(db.q("UPDATE items SET status='REGISTERED' WHERE item_id=?", [verified.itemId]), /Revoke the verified claim/);

  const handed = await itemAt(db, 'HANDED_OVER');
  await rejectsWith(db.q("UPDATE items SET status='RETURNED' WHERE item_id=?", [handed.itemId]), /before the owner confirms receipt/);
});

test('new items must start as FOUND; finder_id / found_at are immutable; RETURNED items are frozen', async () => {
  const u = await mkUser(db);
  await rejectsWith(db.q(
    `INSERT INTO items (title, description, category_id, found_location_id, found_at, finder_id, status)
     VALUES ('Sneaky', 'Trying to start as registered', 1, 1, NOW() - INTERVAL 1 HOUR, ?, 'REGISTERED')`, [u]),
  /must start in FOUND/);

  const c = await itemAt(db, 'FOUND');
  const other = await mkUser(db);
  await rejectsWith(db.q('UPDATE items SET finder_id = ? WHERE item_id = ?', [other, c.itemId]), /immutable/);
  await rejectsWith(db.q('UPDATE items SET found_at = found_at - INTERVAL 1 DAY WHERE item_id = ?', [c.itemId]), /immutable/);

  const done = await itemAt(db, 'RETURNED');
  await rejectsWith(db.q("UPDATE items SET description = 'edited after the case closed' WHERE item_id = ?", [done.itemId]), /closed and cannot be modified/);
});

test('only FOUND items can be deleted; the withdraw procedure is owner-only', async () => {
  const c = await itemAt(db, 'FOUND');
  const stranger = await mkUser(db);
  await rejectsWith(db.call('sp_withdraw_found_item', [c.itemId, stranger]), /Only the finder/);
  await db.call('sp_withdraw_found_item', [c.itemId, c.finder]);
  assert.equal(await db.scalar('SELECT COUNT(*) FROM items WHERE item_id = ?', [c.itemId]), 0);

  const reg = await itemAt(db, 'REGISTERED');
  await rejectsWith(db.q('DELETE FROM items WHERE item_id = ?', [reg.itemId]), /Only items still in FOUND/);
});

test('claim status machine: illegal jumps are rejected', async () => {
  const c = await itemAt(db, 'CLAIMED');
  await rejectsWith(db.q("UPDATE claims SET status='FULFILLED' WHERE claim_id=?", [c.claimId]), /Illegal claim status transition: PENDING -> FULFILLED/);
  await rejectsWith(db.q("UPDATE claims SET status='VERIFIED' WHERE claim_id=?", [c.claimId]), /without a passing verification attempt/);
  await db.call('sp_cancel_claim', [c.claimId, c.claimant]);
  await rejectsWith(db.q("UPDATE claims SET status='VERIFIED' WHERE claim_id=?", [c.claimId]), /Illegal claim status transition: CANCELLED -> VERIFIED/);
  await rejectsWith(db.q("UPDATE claims SET status='PENDING' WHERE claim_id=?", [c.claimId]), /Illegal claim status transition/);
  await rejectsWith(db.q('UPDATE claims SET claimant_id = claimant_id + 1 WHERE claim_id = ?', [c.claimId]), /immutable/);
  await rejectsWith(db.q('DELETE FROM claims WHERE claim_id = ?', [c.claimId]), /permanent records/);
  // cancelling the only pending claim reopens the item
  assert.equal(await statusOf(db, c.itemId), 'REGISTERED');
});

test('items can only be claimed while REGISTERED or CLAIMED', async () => {
  const found = await itemAt(db, 'FOUND');
  const u = await mkUser(db);
  await rejectsWith(db.call('sp_submit_claim', [found.itemId, u, 'I think this is my phone, please check', 'mountain']), /not open for claims/);
  await rejectsWith(db.q(`INSERT INTO claims (item_id, claimant_id, description) VALUES (?, ?, 'Direct insert bypassing the procedure')`, [found.itemId, u]), /not open for claims/);
  const verified = await itemAt(db, 'VERIFIED');
  await rejectsWith(db.call('sp_submit_claim', [verified.itemId, u, 'Late claim after verification happened', 'x']), /not open for claims/);
});

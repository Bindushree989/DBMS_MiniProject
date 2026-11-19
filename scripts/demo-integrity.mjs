// Viva demo: tries to break the rules - directly in SQL, as the all-powerful admin account, bypassing the
// application - and shows that the database refuses. Every attempt runs inside a transaction that is rolled back.
//   npm run demo:integrity
import mysql from 'mysql2/promise';
import { dbConfig } from './_env.mjs';

const conn = await mysql.createConnection({ ...dbConfig(true), decimalNumbers: true });
await conn.query("SET time_zone = '+00:00'");
const one = async (sql, p = []) => (await conn.query(sql, p))[0][0];

const ok = await one(`SELECT
  (SELECT item_id FROM items WHERE status='REGISTERED' LIMIT 1) AS registered,
  (SELECT item_id FROM items WHERE status='FOUND' LIMIT 1) AS found,
  (SELECT item_id FROM items WHERE status='RETURNED' LIMIT 1) AS returned,
  (SELECT claim_id FROM claims WHERE status='PENDING' LIMIT 1) AS pending_claim,
  (SELECT item_id FROM claims WHERE status='PENDING' LIMIT 1) AS pending_item,
  (SELECT user_id FROM users WHERE role='user' LIMIT 1) AS a_user,
  (SELECT user_id FROM users WHERE role='staff' LIMIT 1) AS a_staff,
  (SELECT cl.holder_id FROM custody_log cl WHERE cl.item_id = (SELECT item_id FROM claims WHERE status='PENDING' LIMIT 1) AND cl.ended_at IS NULL) AS pending_custodian`);
const hand = await one(`SELECT handover_id FROM handovers LIMIT 1`);
const audit = await one(`SELECT audit_id FROM audit_log LIMIT 1`);

const attempts = [
  ['Skip the workflow: REGISTERED -> RETURNED', `UPDATE items SET status='RETURNED' WHERE item_id=${ok.registered}`],
  ['Verify an item that has no verified claim', `UPDATE items SET status='VERIFIED' WHERE item_id=${ok.registered}`],
  ['Re-open a closed (RETURNED) item', `UPDATE items SET title='Edited after return' WHERE item_id=${ok.returned}`],
  ['Claim a verified status without a passing check', `UPDATE claims SET status='VERIFIED' WHERE claim_id=${ok.pending_claim}`],
  ['Hand an item to someone with no verified claim', `INSERT INTO handovers (item_id, claim_id, handover_type, from_user_id, to_user_id, proof_type, proof_reference)
     VALUES (${ok.pending_item}, ${ok.pending_claim}, 'STAFF_TO_OWNER', ${ok.pending_custodian}, ${ok.a_user}, 'OTP', 'FAKE-123')`],
  ['Edit a handover record', `UPDATE handovers SET proof_reference='tampered' WHERE handover_id=${hand.handover_id}`],
  ['Delete a handover record', `DELETE FROM handovers WHERE handover_id=${hand.handover_id}`],
  ['Rewrite the audit trail', `UPDATE audit_log SET changed_by='nobody' WHERE audit_id=${audit.audit_id}`],
  ['Erase the audit trail', `DELETE FROM audit_log WHERE audit_id=${audit.audit_id}`],
  ['Give an item two active custodians', `INSERT INTO custody_log (item_id, holder_id, started_at) VALUES (${ok.registered}, ${ok.a_staff}, NOW())`],
  ['Insert an item with a future found_at', `INSERT INTO items (title, description, category_id, found_location_id, found_at, finder_id)
     VALUES ('Future item', 'Found tomorrow, apparently', 1, 1, NOW() + INTERVAL 2 DAY, ${ok.a_user})`],
  ['Register a user with a malformed e-mail', `INSERT INTO users (full_name, email, password_hash) VALUES ('Bad Mail', 'not-an-email', 'x')`],
  ['Delete an item that is already registered', `DELETE FROM items WHERE item_id=${ok.registered}`],
];

let blocked = 0;
const rows = [];
for (const [label, sql] of attempts) {
  await conn.query('START TRANSACTION');
  let result;
  try {
    await conn.query(sql);
    result = 'ALLOWED  <-- rule is missing!';
  } catch (e) {
    blocked++;
    result = `REJECTED: ${e.sqlMessage}`;
  }
  await conn.query('ROLLBACK');
  rows.push({ attempt: label, result: result.length > 95 ? `${result.slice(0, 92)}...` : result });
}
console.table(rows);
console.log(`${blocked}/${attempts.length} illegal operations were rejected by the database itself.`);
await conn.end();
process.exit(blocked === attempts.length ? 0 : 1);

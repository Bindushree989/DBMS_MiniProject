// Test helpers. Every test file gets its OWN freshly built database (name derived from the file),
// so files can run in parallel and never touch the real `back2you` data.
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';
import mysql from 'mysql2/promise';
import { dbConfig } from '../scripts/_env.mjs';
import { rebuildDatabase, grantAppUser } from '../scripts/_schema.mjs';
import { retryDeadlock } from '../src/lib/db.js';

export const APP_USER = 'b2y_test_app';
export const APP_PASS = 'test_app_password';

export class Db {
  constructor(pool, name) { this.pool = pool; this.name = name; this.deadlockRetries = 0; }

  /** CALL a stored procedure on its own connection. Options: actor (@b2y_actor), now (simulated clock). */
  async call(name, args = [], opts = {}) {
    // Same policy as the application (src/lib/db.js callProc): a deadlock victim was rolled back
    // atomically, so it is re-run. Retries are counted and reported by the concurrency tests.
    return retryDeadlock(() => this.#callOnce(name, args, opts), { onRetry: () => { this.deadlockRetries++; } });
  }

  async #callOnce(name, args, { actor = 'test', now = null } = {}) {
    const conn = await this.pool.getConnection();
    try {
      await conn.query('SET @b2y_actor = ?, @b2y_now = ?', [actor, now]);
      const [res] = await conn.query(`CALL ${name}(${args.map(() => '?').join(', ')})`, args);
      return Array.isArray(res) && Array.isArray(res[0]) ? res[0] : [];
    } finally {
      try { await conn.query('SET @b2y_actor = NULL, @b2y_now = NULL'); } catch { /* ignore */ }
      conn.release();
    }
  }
  async q(sql, params = []) { return (await this.pool.query(sql, params))[0]; }
  async one(sql, params = []) { return (await this.q(sql, params))[0]; }
  async scalar(sql, params = []) { const r = await this.one(sql, params); return r ? Object.values(r)[0] : undefined; }
  async close() {
    await this.pool.end();
    const admin = dbConfig(true);
    const c = await mysql.createConnection({ ...admin, database: undefined });
    await c.query('DROP DATABASE IF EXISTS ??', [this.name]);
    await c.end();
  }
}

/** Build a fresh database for the calling test file and return a Db handle (admin rights). */
export async function freshDb(importMetaUrl, { connections = 12 } = {}) {
  const file = path.basename(fileURLToPath(importMetaUrl), '.test.mjs').replace(/[^a-z0-9]/gi, '_');
  const name = `${process.env.DB_NAME || 'back2you'}_t_${file}`.slice(0, 60);
  const admin = dbConfig(true);
  const c = await mysql.createConnection({ ...admin, database: undefined });
  await rebuildDatabase(c, name);
  await grantAppUser(c, name, APP_USER, APP_PASS);
  await c.end();
  const pool = mysql.createPool({ ...admin, database: name, connectionLimit: connections, decimalNumbers: true, multipleStatements: false });
  pool.pool.on('connection', (k) => k.query("SET time_zone = '+00:00'"));
  return new Db(pool, name);
}

/** Point the application library (src/lib/*) at a test database, as the least-privilege app user. */
export function useAppAccount(db) {
  process.env.DB_NAME = db.name;
  process.env.DB_USER = APP_USER;
  process.env.DB_PASSWORD = APP_PASS;
  process.env.DB_HOST = dbConfig(true).host;
  process.env.DB_PORT = String(dbConfig(true).port);
}

let counter = 0;
export async function mkUser(db, role = 'user', name) {
  const n = ++counter;
  const r = await db.q('INSERT INTO users (full_name, email, password_hash, role) VALUES (?,?,?,?)',
    [name || `${role} number ${n}`, `${role}${n}@test.dev`, 'x'.repeat(60), role]);
  return r.insertId;
}

export const hoursAgo = (h) => new Date(Date.now() - h * 3600e3).toISOString().slice(0, 19).replace('T', ' ');

export async function report(db, finderId, o = {}) {
  const [r] = await db.call('sp_report_found_item', [
    finderId, o.title ?? 'Black Samsung phone', o.description ?? 'Black Samsung phone with a cracked screen guard, found on a seat.',
    o.category_id ?? 1, o.color ?? 'black', o.brand ?? 'Samsung', o.location_id ?? 1, o.found_at ?? hoursAgo(2),
    'hint' in o ? o.hint : 'What is the lock screen picture?', 'answer' in o ? o.answer : 'mountain', o.storage ?? 'With finder',
  ], { actor: `u${finderId}`, now: o.now ?? null });
  return r.item_id;
}

export async function register(db, itemId, staffId) {
  return db.call('sp_register_item', [itemId, staffId, 'ID_CARD', 'ID-12345', 'Shelf A'], { actor: `s${staffId}` });
}

export async function claim(db, itemId, userId, answer = 'mountain', o = {}) {
  const [r] = await db.call('sp_submit_claim', [itemId, userId, o.description ?? 'This phone is mine, it has a cracked screen guard.', answer],
    { actor: `u${userId}`, now: o.now ?? null });
  return r.claim_id;
}

const ORDER = ['FOUND', 'REGISTERED', 'CLAIMED', 'VERIFIED', 'HANDED_OVER', 'RETURNED'];

/** Drive a brand-new item through the real procedures until it reaches `state`. */
export async function itemAt(db, state, o = {}) {
  const finder = o.finder ?? await mkUser(db, 'user', 'Finder Fiona');
  const staff = o.staff ?? await mkUser(db, 'staff', 'Staff Sam');
  const claimant = o.claimant ?? await mkUser(db, 'user', 'Owner Olive');
  const ctx = { finder, staff, claimant, itemId: await report(db, finder, o.report), claimId: null };
  const at = ORDER.indexOf(state);
  if (at >= 1) await register(db, ctx.itemId, staff);
  if (at >= 2) ctx.claimId = await claim(db, ctx.itemId, claimant);
  if (at >= 3) await db.call('sp_verify_claim', [ctx.claimId, staff, 'HINT_ANSWER', null, null], { actor: `s${staff}` });
  if (at >= 4) await db.call('sp_perform_handover', [ctx.claimId, staff, 'ID_CARD', 'ID-777', 'at desk'], { actor: `s${staff}` });
  if (at >= 5) await db.call('sp_confirm_return', [ctx.claimId, claimant], { actor: `u${claimant}` });
  return ctx;
}

export async function rejectsWith(promise, pattern) {
  await assert.rejects(promise, (e) => {
    const msg = e.sqlMessage ?? e.message ?? '';
    assert.match(msg, pattern, `unexpected error message: ${msg}`);
    return true;
  });
}

export const statusOf = (db, itemId) => db.scalar('SELECT status FROM items WHERE item_id = ?', [itemId]);
export const openCustody = (db, itemId) => db.scalar('SELECT COUNT(*) FROM custody_log WHERE item_id = ? AND ended_at IS NULL', [itemId]);

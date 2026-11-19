// Shared by `npm run db:reset` and the test-suite: (re)creates a database and
// applies every db/NN_*.sql file in order.
import fs from 'node:fs';
import path from 'node:path';
import { ROOT } from './_env.mjs';
import { splitSql } from './_sql.mjs';

export async function rebuildDatabase(conn, dbName, { log = () => {} } = {}) {
  await conn.query(`DROP DATABASE IF EXISTS ??`, [dbName]);
  await conn.query(`CREATE DATABASE ?? CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`, [dbName]);
  await conn.query(`USE ??`, [dbName]);
  log(`Database ${dbName} recreated`);

  const dir = path.join(ROOT, 'db');
  const files = fs.readdirSync(dir).filter((f) => /^\d+_.*\.sql$/.test(f)).sort();
  for (const f of files) {
    const stmts = splitSql(fs.readFileSync(path.join(dir, f), 'utf8'));
    for (const s of stmts) {
      try {
        await conn.query(s);
      } catch (e) {
        throw new Error(`Failed in ${f}:\n${s.slice(0, 400)}\n\n${e.message}`);
      }
    }
    log(`  applied ${f} (${stmts.length} statements)`);
  }
}

// Least-privilege application account (see migrate.mjs for the rationale).
export async function grantAppUser(conn, dbName, appUser, appPass) {
  const host = '%';
  await conn.query(`CREATE USER IF NOT EXISTS ?@? IDENTIFIED BY ?`, [appUser, host, appPass]);
  await conn.query(`ALTER USER ?@? IDENTIFIED BY ?`, [appUser, host, appPass]);
  await conn.query(`GRANT SELECT, EXECUTE ON ??.* TO ?@?`, [dbName, appUser, host]);
  await conn.query(`GRANT INSERT, UPDATE ON ??.users TO ?@?`, [dbName, appUser, host]);
  await conn.query(`GRANT UPDATE ON ??.fraud_flags TO ?@?`, [dbName, appUser, host]);
  await conn.query(`GRANT UPDATE ON ??.embedding_outbox TO ?@?`, [dbName, appUser, host]);
  await conn.query(`FLUSH PRIVILEGES`);
}

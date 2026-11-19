// Runs every query in db/queries.sql and prints the results (for the viva / demonstration).
//   npm run demo:queries
import fs from 'node:fs';
import path from 'node:path';
import mysql from 'mysql2/promise';
import { ROOT, dbConfig } from './_env.mjs';

const text = fs.readFileSync(path.join(ROOT, 'db', 'queries.sql'), 'utf8');
const blocks = text.split(/^-- @title /m).slice(1).map((b) => {
  const nl = b.indexOf('\n');
  return { title: b.slice(0, nl).trim(), sql: b.slice(nl + 1).trim().replace(/;\s*$/, '') };
});
const conn = await mysql.createConnection({ ...dbConfig(false), decimalNumbers: true });
await conn.query("SET time_zone = '+00:00'");
for (const { title, sql } of blocks) {
  console.log(`\n=== ${title}`);
  console.log(sql.split('\n').map((l) => `    ${l}`).join('\n'));
  try {
    const t0 = process.hrtime.bigint();
    const [rows] = await conn.query(sql);
    const ms = Number(process.hrtime.bigint() - t0) / 1e6;
    console.log(`  -> ${rows.length} row(s) in ${ms.toFixed(1)} ms`);
    if (rows.length) console.table(rows.slice(0, 10).map((r) => Object.fromEntries(Object.entries(r).map(([k, v]) => [k, typeof v === 'string' && v.length > 60 ? `${v.slice(0, 57)}...` : v]))));
  } catch (e) { console.log(`  !! ${e.message}`); }
}
await conn.end();

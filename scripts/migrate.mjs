// Drops and recreates the database, applies every db/*.sql file in order,
// then creates the least-privilege application account.
//   npm run db:reset
import mysql from 'mysql2/promise';
import { dbConfig, requireEnv } from './_env.mjs';
import { rebuildDatabase, grantAppUser } from './_schema.mjs';

const admin = dbConfig(true);
const appUser = requireEnv('DB_USER');
const appPass = process.env.DB_PASSWORD ?? '';

const conn = await mysql.createConnection({ ...admin, database: undefined });
console.log(`Connected to MySQL at ${admin.host}:${admin.port} as ${admin.user}`);

try {
  await rebuildDatabase(conn, admin.database, { log: console.log });
} catch (e) {
  console.error(`\n${e.message}`);
  process.exit(1);
}

// ---- least-privilege application account -----------------------------------
// The app can read everything but may only WRITE through stored procedures
// (EXECUTE), plus register users, change roles and review fraud flags.
// Triggers/procedures run with the definer's rights, so the app account needs
// no direct INSERT on audit_log, items, claims, handovers or custody_log.
if (appUser !== admin.user) {
  await grantAppUser(conn, admin.database, appUser, appPass);
  console.log(`Application user '${appUser}' created with least-privilege grants`);
} else {
  console.log('DB_USER equals DB_ADMIN_USER: skipping least-privilege user creation');
}

await conn.end();
console.log('\nSchema ready. Next: npm run db:seed');

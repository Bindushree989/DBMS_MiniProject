// Creates the database: schema -> functions -> triggers -> procedures -> migration -> indexes -> views
const path = require('path');
const mysql = require('mysql2/promise');
const cfg = require('./env');
const runFile = require('./run_sql');

const FILES = ['01_schema', '02_functions', '03_triggers', '04_procedures',
               '05_migration_alter_drop', '06_indexes', '07_views'];

(async () => {
  if (!cfg.user) { console.error('Set DB_USER / DB_PASSWORD in .env first'); process.exit(1); }
  const conn = await mysql.createConnection({ host: cfg.host, port: cfg.port, user: cfg.user, password: cfg.password });
  for (const f of FILES) {
    const n = await runFile(conn, path.join(__dirname, '..', 'db', f + '.sql'));
    console.log(`  ran ${f}.sql (${n} statements)`);
  }
  // seed reference data
  await conn.query('USE back2you');
  if (process.env.DB_APP_USER && process.env.DB_APP_PASSWORD) {
    const u = conn.escape(process.env.DB_APP_USER), p = conn.escape(process.env.DB_APP_PASSWORD);
    await conn.query(`CREATE USER IF NOT EXISTS ${u}@'%' IDENTIFIED BY ${p}`);
    // no DROP / ALTER / TRUNCATE => audit_log cannot be truncated by the app
    await conn.query(`GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON back2you.* TO ${u}@'%'`);
    console.log(`  created least-privilege user ${process.env.DB_APP_USER}`);
  }
  await conn.end();
  console.log('Database ready. Next: npm run db:seed');
})().catch(e => { console.error('SETUP FAILED:', e.message); process.exit(1); });

// MySQL access layer. Credentials come ONLY from environment variables.
const mysql = require('mysql2/promise');

const g = globalThis;
function pool() {
  if (!g.__b2yPool) {
    if (!(process.env.DB_APP_USER || process.env.DB_USER)) throw new Error('DB_USER / DB_PASSWORD are not set (see .env.example)');
    g.__b2yPool = mysql.createPool({
      host: process.env.DB_HOST || '127.0.0.1',
      port: Number(process.env.DB_PORT || 3306),
      user: process.env.DB_APP_USER || process.env.DB_USER,
      password: process.env.DB_APP_USER ? process.env.DB_APP_PASSWORD : process.env.DB_PASSWORD,
      database: process.env.DB_NAME || 'back2you',
      connectionLimit: 20,
      dateStrings: true,
      decimalNumbers: true,
    });
  }
  return g.__b2yPool;
}

async function query(sql, params = []) {
  const [rows] = await pool().query(sql, params);
  return rows;
}

// CALL a stored procedure. Retries on deadlock / lock-wait (InnoDB rolled the txn back for us).
async function call(proc, params = []) {
  const marks = params.map(() => '?').join(',');
  for (let attempt = 0; ; attempt++) {
    try {
      const [res] = await pool().query(`CALL ${proc}(${marks})`, params);
      const rows = Array.isArray(res[0]) ? res[0] : res;
      return rows;
    } catch (e) {
      if ((e.errno === 1213 || e.errno === 1205) && attempt < 3) { await new Promise(r => setTimeout(r, 40 * (attempt + 1))); continue; }
      throw e;
    }
  }
}

// Turn a trigger/procedure error (B2Y-Exxx: message) into an HTTP-friendly shape.
function toApiError(e) {
  const m = /B2Y-E(\d{3}):\s*(.*)$/.exec(e.message || '');
  if (m) {
    const code = Number(m[1]);
    const forbidden = [102, 161, 191, 193, 194, 141, 151, 182].includes(code);
    return { status: forbidden ? 403 : 409, code: 'E' + m[1], message: m[2] };
  }
  if (e.code === 'ER_DUP_ENTRY' || e.errno === 1062) return { status: 409, code: 'DUPLICATE', message: 'That record already exists (duplicate).' };
  if (e.errno === 4025 || e.errno === 3819 || /CONSTRAINT|constraint/.test(e.message || '')) {
    const c = /(ck_\w+)/.exec(e.message || '');
    return { status: 422, code: 'VALIDATION', message: 'Rejected by database validation' + (c ? ` (${c[1]})` : '') + '.' };
  }
  if (e.errno === 1452) return { status: 422, code: 'REFERENCE', message: 'Referenced record does not exist.' };
  return null;
}

module.exports = { pool, query, call, toApiError };

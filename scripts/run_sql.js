// Minimal runner that understands DELIMITER (so no mysql CLI is required)
const fs = require('fs'), path = require('path');
module.exports = async function runFile(conn, file) {
  const lines = fs.readFileSync(file, 'utf8').split(/\r?\n/);
  let delim = ';', buf = '';
  const out = [];
  for (const line of lines) {
    const m = line.match(/^\s*DELIMITER\s+(\S+)\s*$/i);
    if (m) { delim = m[1]; continue; }
    if (/^\s*--/.test(line) && !buf.trim()) continue;
    buf += line + '\n';
    if (buf.trimEnd().endsWith(delim)) {
      const stmt = buf.trimEnd().slice(0, -delim.length).trim();
      buf = '';
      if (stmt) out.push(stmt);
    }
  }
  if (buf.trim()) out.push(buf.trim());
  for (const s of out) await conn.query(s);
  return out.length;
};

// Minimal SQL script splitter that understands `DELIMITER` lines, quotes and comments,
// so stored-program bodies (which contain ';') are sent as single statements.
export function splitSql(text) {
  const out = [];
  let delim = ';';
  let buf = '';
  let i = 0;
  const n = text.length;
  const flush = () => { const s = buf.trim(); if (s) out.push(s); buf = ''; };

  while (i < n) {
    // DELIMITER directive (only at the start of a line, when buffer is empty)
    if (buf.trim() === '' && /^[ \t]*DELIMITER[ \t]+\S+/i.test(text.slice(i, i + 80))) {
      const m = /^[ \t]*DELIMITER[ \t]+(\S+)[^\n]*/i.exec(text.slice(i));
      delim = m[1];
      i += m[0].length;
      buf = '';
      continue;
    }
    const c = text[i];
    const c2 = text.slice(i, i + 2);
    if (c2 === '--' && /[\s]/.test(text[i + 2] ?? '\n')) {            // line comment
      while (i < n && text[i] !== '\n') i++;
      continue;
    }
    if (c === '#') { while (i < n && text[i] !== '\n') i++; continue; }
    if (c2 === '/*') {                                                  // block comment
      const end = text.indexOf('*/', i + 2);
      i = end === -1 ? n : end + 2;
      continue;
    }
    if (c === "'" || c === '"' || c === '`') {                          // quoted
      const q = c;
      buf += c; i++;
      while (i < n) {
        if (text[i] === '\\' && q !== '`') { buf += text[i] + (text[i + 1] ?? ''); i += 2; continue; }
        if (text[i] === q) {
          if (text[i + 1] === q) { buf += q + q; i += 2; continue; }    // doubled quote
          buf += q; i++; break;
        }
        buf += text[i]; i++;
      }
      continue;
    }
    if (text.startsWith(delim, i)) { flush(); i += delim.length; continue; }
    buf += c; i++;
  }
  flush();
  return out;
}

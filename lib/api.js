// Route-handler helpers: uniform JSON + error mapping
const { NextResponse } = require('next/server');
const { HttpError } = require('./auth');
const { toApiError } = require('./db');

const json = (data, status = 200) => NextResponse.json(data, { status });
function handle(fn) {
  return async (req, ctx) => {
    try { return await fn(req, ctx); }
    catch (e) {
      if (e instanceof HttpError) return json({ error: e.message, code: e.code }, e.status);
      const m = toApiError(e);
      if (m) return json({ error: m.message, code: m.code }, m.status);
      console.error('[api]', e);
      return json({ error: 'Internal error' }, 500);
    }
  };
}
const body = async req => { try { return await req.json(); } catch { throw new HttpError(400, 'Invalid JSON body', 'BAD_JSON'); } };
const need = (o, ...keys) => { for (const k of keys) if (o[k] === undefined || o[k] === null || o[k] === '') throw new HttpError(400, `Missing field: ${k}`, 'MISSING'); };
const int = (v, name) => { const n = Number(v); if (!Number.isInteger(n) || n <= 0) throw new HttpError(400, `Invalid ${name}`, 'BAD_ID'); return n; };
const dt = (v, name) => { const s = String(v || '').replace('T', ' ').slice(0, 19); if (!/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}(:\d{2})?$/.test(s)) throw new HttpError(400, `Invalid ${name}`, 'BAD_DATE'); return s.length === 16 ? s + ':00' : s; };

module.exports = { json, handle, body, need, int, dt };

// End-to-end over HTTP: boots the real Next.js server (built output) against an isolated database and
// drives the whole journey with real sessions for each role.   npm run test:e2e   (needs `npm run build` first)
import test, { before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import path from 'node:path';
import fs from 'node:fs';
import bcrypt from 'bcryptjs';
import { freshDb, APP_USER, APP_PASS } from '../helpers.mjs';
import { dbConfig, ROOT } from '../../scripts/_env.mjs';

const PORT = 3199;
const BASE = `http://127.0.0.1:${PORT}`;
const PASSWORD = 'Str0ng&Secret!';
let db, server, serverLog = '';

/** Minimal HTTP client with a cookie jar (one per signed-in actor). */
class Client {
  constructor(name) { this.name = name; this.cookie = ''; }
  async req(method, url, body) {
    const res = await fetch(BASE + url, {
      method, redirect: 'manual',
      headers: { 'content-type': 'application/json', ...(this.cookie ? { cookie: this.cookie } : {}) },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const set = res.headers.getSetCookie?.() ?? [];
    for (const c of set) { const [kv] = c.split(';'); this.cookie = /=;?$|=$/.test(kv) ? '' : kv; }
    const data = await res.json().catch(() => ({}));
    return { status: res.status, data };
  }
  get(u) { return this.req('GET', u); }
  post(u, b = {}) { return this.req('POST', u, b); }
  patch(u, b) { return this.req('PATCH', u, b); }
  async login(email, password = PASSWORD) { const r = await this.post('/api/auth/login', { email, password }); assert.equal(r.status, 200, JSON.stringify(r.data)); return r.data.user; }
}

before(async () => {
  db = await freshDb(import.meta.url);
  // bootstrap admin (public sign-up can only ever create ordinary users)
  await db.q("INSERT INTO users (full_name, email, password_hash, role) VALUES ('Root Admin', 'admin@e2e.test', ?, 'admin')", [await bcrypt.hash(PASSWORD, 4)]);
  const admin = dbConfig(true);
  server = spawn(path.join(ROOT, 'node_modules/.bin/next'), ['start', '-p', String(PORT)], {
    cwd: ROOT,
    env: { ...process.env, DB_HOST: admin.host, DB_PORT: String(admin.port), DB_NAME: db.name, DB_USER: APP_USER, DB_PASSWORD: APP_PASS,
      JWT_SECRET: 'e2e_secret_e2e_secret_e2e_secret_1234567890', COOKIE_SECURE: 'false', VECTOR_STORE: 'memory', EMBEDDING_PROVIDER: 'hash', NODE_ENV: 'production' },
  });
  server.stdout.on('data', (d) => { serverLog += d; }); server.stderr.on('data', (d) => { serverLog += d; });
  for (let i = 0; i < 80; i++) {
    try { const r = await fetch(`${BASE}/api/health`); if (r.ok) return; } catch { /* not up yet */ }
    await new Promise((r) => setTimeout(r, 250));
  }
  throw new Error(`server did not start:\n${serverLog}`);
});
after(async () => { server?.kill('SIGTERM'); await db?.close(); });

const S = {};   // shared story state

test('sign-up creates ordinary users only; duplicates and weak input are refused', async () => {
  const mk = (name, email) => ({ full_name: name, email, password: PASSWORD, role: 'admin' /* must be ignored */ });
  for (const [k, name, email] of [['fay', 'Fay Finder', 'fay@e2e.test'], ['olive', 'Olive Owner', 'olive@e2e.test'], ['rex', 'Rex Rival', 'rex@e2e.test'], ['stan', 'Stan Staff', 'stan@e2e.test'], ['sue', 'Sue Staff', 'sue@e2e.test'], ['nobody', 'Nobody Nolan', 'nobody@e2e.test']]) {
    S[k] = new Client(k);
    const r = await S[k].post('/api/auth/register', mk(name, email));
    assert.equal(r.status, 201, JSON.stringify(r.data));
    assert.equal(r.data.user.role, 'user', 'role in the payload is ignored');
  }
  assert.equal((await new Client().post('/api/auth/register', mk('Dup', 'fay@e2e.test'))).status, 409);
  assert.equal((await new Client().post('/api/auth/register', { full_name: 'X', email: 'bad', password: '1' })).status, 422);
  assert.equal((await S.fay.get('/api/auth/me')).data.user.email, 'fay@e2e.test');
});

test('authentication: wrong password, deactivated account, brute-force throttle', async () => {
  const c = new Client();
  const bad = await c.post('/api/auth/login', { email: 'fay@e2e.test', password: 'wrong-password' });
  assert.equal(bad.status, 401); assert.equal(bad.data.error, 'Incorrect email or password');
  assert.equal((await c.post('/api/auth/login', { email: 'nobody-here@e2e.test', password: 'whatever12' })).data.error, 'Incorrect email or password', 'unknown e-mail looks identical');
  let last;
  for (let i = 0; i < 12; i++) last = await c.post('/api/auth/login', { email: 'brute@e2e.test', password: `guess-${i}` });
  assert.equal(last.status, 429);
});

test('role-based access is enforced by the API (anonymous < user < staff < admin)', async () => {
  const anon = new Client();
  assert.equal((await anon.get('/api/staff/queue')).status, 401);
  assert.equal((await anon.post('/api/items', {})).status, 401);
  assert.equal((await anon.get('/api/claims')).status, 401);
  assert.equal((await S.fay.get('/api/staff/queue')).status, 403);
  assert.equal((await S.fay.get('/api/admin/stats')).status, 403);
  assert.equal((await S.fay.patch('/api/admin/users/1', { role: 'admin' })).status, 403, 'users cannot promote themselves');
  assert.equal((await S.fay.post('/api/items/1/register', { proof_type: 'ID_CARD', proof_reference: 'abc' })).status, 403);

  // admin promotes two users to staff
  S.admin = new Client('admin'); await S.admin.login('admin@e2e.test');
  const users = (await S.admin.get('/api/admin/users')).data.users;
  const id = (email) => users.find((u) => u.email === email).user_id;
  S.ids = { fay: id('fay@e2e.test'), olive: id('olive@e2e.test'), rex: id('rex@e2e.test'), stan: id('stan@e2e.test'), sue: id('sue@e2e.test'), admin: id('admin@e2e.test'), nobody: id('nobody@e2e.test') };
  assert.equal((await S.admin.patch(`/api/admin/users/${S.ids.stan}`, { role: 'staff' })).status, 200);
  assert.equal((await S.admin.patch(`/api/admin/users/${S.ids.sue}`, { role: 'staff' })).status, 200);
  assert.equal((await S.stan.get('/api/staff/queue')).status, 200, 'role change applies immediately, no re-login needed');
  assert.equal((await S.admin.patch(`/api/admin/users/${S.ids.admin}`, { role: 'user' })).status, 409, 'an admin cannot demote themselves');
});

test('validation: API schema + database triggers both reject bad reports', async () => {
  const meta = (await S.fay.get('/api/meta')).data;
  assert.ok(meta.categories.length >= 10 && meta.locations.length >= 10 && meta.staff.length === 0, 'staff directory is hidden from ordinary users');
  const ok = { title: 'Black leather wallet', description: 'Black leather bifold wallet with a metro card and some cash', category_id: 2, color: 'black', brand: 'Fossil', location_id: 5, found_at: new Date(Date.now() - 3600e3).toISOString(), hint: 'Which metro card name is printed on the card?', answer: 'Aarav Sharma' };
  assert.equal((await S.fay.post('/api/items', { ...ok, title: 'ab' })).status, 422);
  assert.equal((await S.fay.post('/api/items', { ...ok, answer: '' })).status, 422, 'hint without answer');
  const future = await S.fay.post('/api/items', { ...ok, found_at: new Date(Date.now() + 86400e3).toISOString() });
  assert.equal(future.status, 409); assert.match(future.data.error, /future/);   // refused by trg_items_bi, not by the API
  assert.equal((await S.fay.post('/api/items', { ...ok, category_id: 9999 })).status, 422, 'foreign key');
  const r = await S.fay.post('/api/items', ok);
  assert.equal(r.status, 201); S.item = r.data.item_id;
  assert.equal(r.data.status, 'FOUND');
});

test('visibility: a FOUND item is private; REGISTERED items are public without finder identity or answer hash', async () => {
  assert.equal((await S.olive.get(`/api/items/${S.item}`)).status, 404);
  assert.ok(!(await S.olive.get('/api/items?q=wallet')).data.items.some((i) => i.item_id === S.item));
  assert.equal((await S.fay.get(`/api/items/${S.item}`)).status, 200, 'the finder can see their own report');

  S.stan = Object.assign(S.stan, {}); await S.stan.login('stan@e2e.test');   // fresh token with the staff role
  const reg = await S.stan.post(`/api/items/${S.item}/register`, { proof_type: 'ID_CARD', proof_reference: 'FAY-ID-4821', storage_place: 'Shelf A-2' });
  assert.equal(reg.status, 200, JSON.stringify(reg.data)); assert.equal(reg.data.status, 'REGISTERED');
  assert.equal((await S.stan.post(`/api/items/${S.item}/register`, { proof_type: 'ID_CARD', proof_reference: 'FAY-ID-4821' })).status, 409, 'cannot register twice');

  const pub = (await S.olive.get(`/api/items/${S.item}`)).data;
  assert.equal(pub.item.status, 'REGISTERED');
  for (const k of ['finder_name', 'finder_id', 'holder_name', 'storage_place', 'verification_answer_hash']) assert.ok(!(k in pub.item), `${k} must not be exposed`);
  assert.ok(pub.item.has_hidden_detail);
  const found = await S.olive.get('/api/items?q=leather+wallet');                  // MySQL FULLTEXT, boolean mode
  assert.ok(found.data.items.some((i) => i.item_id === S.item));
});

test('search input cannot inject SQL or break FULLTEXT syntax', async () => {
  for (const q of ["' OR 1=1 --", '+-*()<>~"@', "wallet'; DROP TABLE items; --", '%00', 'a'.repeat(500)]) {
    const r = await S.olive.get(`/api/items?q=${encodeURIComponent(q)}&category=1%20OR%201=1&sort=oldest;DROP`);
    assert.equal(r.status, 200, `q=${q.slice(0, 20)} -> ${r.status} ${JSON.stringify(r.data).slice(0, 100)}`);
  }
  assert.ok((await S.admin.get('/api/admin/stats')).data.kpis.total_items >= 1, 'tables are intact');
});

test('hybrid match (vector + attributes) surfaces the registered item', async () => {
  const r = await S.olive.post('/api/match', { description: 'I lost my black leather wallet with a metro card', category_id: 2, color: 'black', mode: 'hybrid' });
  assert.equal(r.status, 200, JSON.stringify(r.data));
  assert.equal(r.data.results[0].item_id, S.item);
  assert.ok(r.data.results[0].final_score > 0.5);
  assert.ok(!('finder_name' in r.data.results[0]));
  assert.equal((await new Client().post('/api/match', { description: 'wallet please' })).status, 401);
  assert.equal((await S.olive.post('/api/match', { description: 'hi' })).status, 422);
});

test('claims: finder cannot claim; rival claim is flagged; duplicate claim refused', async () => {
  assert.equal((await S.fay.post(`/api/items/${S.item}/claims`, { description: 'I found it but I want it anyway', answer: 'x' })).status, 409, 'finder cannot claim their own report');
  const o = await S.olive.post(`/api/items/${S.item}/claims`, { description: 'Black Fossil wallet, lost on the metro yesterday', answer: ' aarav sharma ' });
  assert.equal(o.status, 201); S.claimOlive = o.data.claim_id;
  const x = await S.rex.post(`/api/items/${S.item}/claims`, { description: 'It is my wallet, I lost it on the metro too', answer: 'Raj Kumar' });
  assert.equal(x.status, 201); S.claimRex = x.data.claim_id;
  assert.equal((await S.olive.post(`/api/items/${S.item}/claims`, { description: 'Claiming a second time now', answer: 'a' })).status, 409);
  const flags = (await S.admin.get('/api/admin/fraud')).data.flags;
  assert.ok(flags.some((f) => f.reason === 'MULTIPLE_CLAIMANTS' && f.user_id === S.ids.rex), 'competing claimant flagged for the admin');
  assert.equal((await S.olive.get('/api/claims')).data.claims.length, 1);
  assert.equal((await S.olive.get(`/api/items/${S.item}`)).data.claims.length, 1, 'a claimant only sees their own claim');
});

test('verification: wrong answer = FAIL (recorded), right answer = PASS and the rival claim is closed', async () => {
  S.sue = Object.assign(S.sue, {}); await S.sue.login('sue@e2e.test');
  assert.equal((await S.olive.post(`/api/claims/${S.claimOlive}/verify`, { method: 'HINT_ANSWER' })).status, 403, 'owners cannot verify');
  const bad = await S.stan.post(`/api/claims/${S.claimRex}/verify`, { method: 'HINT_ANSWER' });
  assert.equal(bad.status, 200); assert.equal(bad.data.outcome, 'FAIL'); assert.equal(Number(bad.data.attempts_left), 2);
  assert.equal((await S.stan.post(`/api/claims/${S.claimOlive}/verify`, { method: 'ADMIN_OVERRIDE', proof_ref: 'XX-1' })).status, 403, 'override is admin-only');
  const good = await S.stan.post(`/api/claims/${S.claimOlive}/verify`, { method: 'HINT_ANSWER' });
  assert.equal(good.data.outcome, 'PASS');
  const rex = (await S.rex.get('/api/claims')).data.claims[0];
  assert.equal(rex.status, 'REJECTED'); assert.match(rex.reject_reason, /Another claim/);
  assert.equal((await S.olive.get(`/api/items/${S.item}`)).data.item.status, 'VERIFIED');
});

test('handover: only the current custodian may hand over; custody transfer comes first; then the owner confirms', async () => {
  const wrong = await S.sue.post(`/api/claims/${S.claimOlive}/handover`, { proof_type: 'ID_CARD', proof_reference: 'OLIVE-ID-1' });
  assert.equal(wrong.status, 403); assert.match(wrong.data.error, /current custodian/);
  const tr = await S.stan.post(`/api/items/${S.item}/transfer`, { to_staff_id: S.ids.sue, proof_type: 'SIGNATURE', proof_reference: 'SIG-STAN-SUE', storage_place: 'Counter 1' });
  assert.equal(tr.status, 200, JSON.stringify(tr.data));
  assert.equal((await S.stan.post(`/api/claims/${S.claimOlive}/handover`, { proof_type: 'ID_CARD', proof_reference: 'OLIVE-ID-1' })).status, 403, 'stan no longer holds it');
  assert.equal((await S.sue.post(`/api/claims/${S.claimOlive}/handover`, { proof_type: 'ID_CARD' })).status, 422, 'proof reference is mandatory');
  const ho = await S.sue.post(`/api/claims/${S.claimOlive}/handover`, { proof_type: 'ID_CARD', proof_reference: 'OLIVE-ID-1', notes: 'collected in person' });
  assert.equal(ho.status, 200, JSON.stringify(ho.data)); assert.equal(ho.data.status, 'HANDED_OVER');
  assert.equal((await S.sue.post(`/api/claims/${S.claimOlive}/handover`, { proof_type: 'ID_CARD', proof_reference: 'OLIVE-ID-1' })).status, 409, 'cannot hand over twice');
  assert.equal((await S.rex.post(`/api/claims/${S.claimOlive}/confirm`)).status, 403, 'only the owner or staff can confirm');
  const done = await S.olive.post(`/api/claims/${S.claimOlive}/confirm`);
  assert.equal(done.status, 200); assert.equal(done.data.status, 'RETURNED');
  assert.equal((await S.olive.post(`/api/claims/${S.claimOlive}/confirm`)).status, 409);
});

test('case file: timeline + custody chain for involved people only', async () => {
  const t = await S.olive.get(`/api/items/${S.item}/timeline`);
  assert.equal(t.status, 200);
  const kinds = new Set(t.data.events.map((e) => e.event_type));
  for (const k of ['REPORTED', 'CUSTODY', 'CLAIM_SUBMITTED', 'VERIFICATION', 'HANDOVER', 'RETURNED']) assert.ok(kinds.has(k), k);
  assert.deepEqual(t.data.custody.map((c) => c.holder), ['Fay Finder', 'Stan Staff', 'Sue Staff', 'Olive Owner']);
  assert.equal(t.data.custody.filter((c) => !c.ended_at).length, 0, 'case closed: nobody holds it any more');
  assert.equal((await S.fay.get(`/api/items/${S.item}/timeline`)).status, 200);
  assert.equal((await S.nobody.get(`/api/items/${S.item}/timeline`)).status, 403);
  assert.equal((await new Client().get(`/api/items/${S.item}/timeline`)).status, 401);
});

test('admin: audit trail names the real actor; dashboard numbers; fraud review; staff queue', async () => {
  const a = await S.admin.get(`/api/admin/audit?table=items&record=${S.item}`);
  assert.equal(a.status, 200);
  const actors = new Set(a.data.rows.map((r) => r.changed_by));
  assert.ok([...actors].some((x) => x === `app:user#${S.ids.fay}`), 'finder recorded');
  assert.ok([...actors].some((x) => x === `app:staff#${S.ids.stan}`), 'staff recorded');
  assert.ok(a.data.rows.filter((r) => r.action === 'UPDATE').length >= 5, 'every lifecycle step audited');

  const st = (await S.admin.get('/api/admin/stats')).data;
  assert.equal(Number(st.kpis.returned_items), 1); assert.equal(Number(st.kpis.return_rate_pct), 100);
  assert.ok(st.statuses.some((s) => s.status === 'RETURNED'));

  const flag = (await S.admin.get('/api/admin/fraud')).data.flags[0];
  assert.equal((await S.admin.patch(`/api/admin/fraud/${flag.flag_id}`, { status: 'REVIEWED' })).status, 200);
  assert.equal((await S.admin.patch(`/api/admin/fraud/${flag.flag_id}`, { status: 'REVIEWED' })).status, 404, 'already reviewed');
  const q = (await S.sue.get('/api/staff/queue')).data;
  assert.deepEqual(Object.keys(q).sort(), ['delivered', 'intake', 'mine', 'pending', 'verified']);
  assert.equal((await S.sue.get('/api/admin/audit')).status, 403, 'staff cannot read the audit log');
});

test('deactivated accounts lose access immediately; logout clears the session', async () => {
  assert.equal((await S.admin.patch(`/api/admin/users/${S.ids.rex}`, { is_active: false })).status, 200);
  assert.equal((await S.rex.get('/api/claims')).status, 401, 'old token no longer works');
  assert.equal((await new Client().post('/api/auth/login', { email: 'rex@e2e.test', password: PASSWORD })).status, 403);
  await S.olive.post('/api/auth/logout');
  assert.equal((await S.olive.get('/api/auth/me')).data.user, null);
});

test('no credentials in the source tree: configuration only comes from the environment', () => {
  const walk = (d) => fs.readdirSync(d, { withFileTypes: true }).flatMap((e) => e.isDirectory() ? (['node_modules', '.next', '.git', 'data'].includes(e.name) ? [] : walk(path.join(d, e.name))) : [path.join(d, e.name)]);
  const files = walk(path.join(ROOT, 'src')).filter((f) => /\.(js|mjs)$/.test(f));
  for (const f of files) {
    const text = fs.readFileSync(f, 'utf8');
    assert.ok(!/password\s*[:=]\s*['"][^'"]{3,}['"]/i.test(text.replace(/password:\s*z\./g, '')), `hard-coded password in ${f}`);
    assert.ok(!/mysql:\/\/[^'"\s]*:[^'"\s]*@/.test(text), `connection string with credentials in ${f}`);
  }
});

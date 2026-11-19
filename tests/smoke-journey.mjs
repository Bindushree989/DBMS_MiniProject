// HTTP smoke test of the whole lifecycle against a running server (BASE_URL, default http://localhost:3000).
//   npm run build && npm start   (in another terminal)   then   node tests/smoke-journey.mjs
import assert from 'node:assert/strict';
const BASE = process.env.BASE_URL || 'http://localhost:3000';
const U = process.env.SMOKE_USER || 'user1@back2you.dev', U2 = process.env.SMOKE_USER2 || 'user2@back2you.dev';
const S = process.env.SMOKE_STAFF || 'staff1@back2you.dev', A = process.env.SMOKE_ADMIN || 'admin@back2you.dev';
const PW = { user: 'User@123', staff: 'Staff@123', admin: 'Admin@123' };

async function login(email, pw) {
  const r = await fetch(BASE + '/api/auth/login', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password: pw }) });
  assert.equal(r.status, 200, `login ${email}`);
  const cookie = r.headers.get('set-cookie').split(';')[0];
  return async (path, method = 'GET', body) => {
    const x = await fetch(BASE + path, { method, headers: { 'Content-Type': 'application/json', cookie }, body: body ? JSON.stringify(body) : undefined });
    return { status: x.status, json: await x.json().catch(() => ({})) };
  };
}
const results = [];
const step = async (name, fn) => { try { await fn(); results.push([name, 'PASS']); console.log('PASS', name); } catch (e) { results.push([name, 'FAIL']); console.log('FAIL', name, '-', e.message); } };

const user = await login(U, PW.user), owner = await login(U2, PW.user), staff = await login(S, PW.staff), admin = await login(A, PW.admin);
let item, claim, meta;
const stamp = Date.now().toString(36);

await step('anonymous request is rejected (401)', async () => assert.equal((await fetch(BASE + '/api/items')).status, 401));
await step('role checks: user cannot reach staff/admin APIs (403)', async () => {
  assert.equal((await user('/api/staff/queue')).status, 403); assert.equal((await user('/api/admin/dashboard')).status, 403);
  assert.equal((await staff('/api/admin/dashboard')).status, 403);
});
await step('finder reports an item (FOUND)', async () => {
  meta = (await user('/api/meta')).json;
  const r = await user('/api/items', 'POST', { title: `Maroon leather wallet ${stamp}`, description: 'Maroon leather wallet with a metro card and two bank cards inside',
    category_id: meta.categories.find((c) => c.name === 'Wallet').category_id, color: 'Maroon', brand: 'Hidesign', location_id: meta.locations[0].location_id,
    verification_question: 'Which card is inside?', verification_answer: 'Metro Card' });
  assert.equal(r.status, 201, JSON.stringify(r.json)); item = r.json.item_id;
  assert.equal((await user(`/api/items/${item}`)).json.item.status, 'FOUND');
});
await step('staff registers it (REGISTERED, custody to staff)', async () => {
  assert.equal((await staff(`/api/items/${item}/register`, 'POST', { note: 'Shelf Z1' })).status, 200);
  const d = (await staff(`/api/items/${item}`)).json; assert.equal(d.item.status, 'REGISTERED'); assert.ok(d.timeline.length >= 2);
});
await step('owner files a lost report and the matcher ranks the item', async () => {
  const r = await owner('/api/lost-reports', 'POST', { title: 'Lost maroon wallet', description: 'Leather billfold, maroon, has my metro card and bank cards', category_id: meta.categories.find((c) => c.name === 'Wallet').category_id,
    color: 'Maroon', brand: 'Hidesign', location_id: meta.locations[0].location_id, lost_at: new Date(Date.now() - 3600e3 * 5).toISOString().slice(0, 16) });
  assert.equal(r.status, 201, JSON.stringify(r.json));
  const list = (await owner('/api/lost-reports')).json.reports; const rid = list[0].report_id;
  const m = (await owner(`/api/lost-reports/${rid}/matches`)).json;
  const rank = m.matches.findIndex((x) => x.item_id === item);
  console.log(`   engine=${m.engine}  rank of the true item = ${rank + 1} of ${m.matches.length}`);
  assert.ok(rank >= 0 && rank < 3, 'true item should be in the top 3');
});
await step('wrong answer does not verify; correct answer does', async () => {
  const c = await owner(`/api/items/${item}/claims`, 'POST', { description: 'My maroon wallet', answer: 'Library card' });
  assert.equal(c.status, 201, JSON.stringify(c.json)); claim = c.json.claim_id;
  assert.equal((await owner('/api/claims/mine')).json.claims.find((x) => x.claim_id === claim).answer_match, 0);
  await owner(`/api/claims/${claim}/retry`, 'POST', { answer: '  metro CARD ' });
  assert.equal((await owner('/api/claims/mine')).json.claims.find((x) => x.claim_id === claim).answer_match, 1);
});
await step('finder cannot claim their own item', async () => assert.equal((await user(`/api/items/${item}/claims`, 'POST', { description: 'mine', answer: 'x' })).status >= 400, true));
await step('staff approves, hands over; owner confirms (RETURNED)', async () => {
  assert.equal((await staff(`/api/claims/${claim}/review`, 'POST', { approve: true, notes: 'answer verified' })).status, 200);
  assert.equal((await staff(`/api/items/${item}/handover`, 'POST', { proof_type: 'ID_CARD', proof_ref: 'College ID 4MH21CS777' })).status, 200);
  assert.equal((await owner(`/api/items/${item}/confirm`, 'POST')).status, 200);
  assert.equal((await owner(`/api/items/${item}`)).json.item.status, 'RETURNED');
});
await step('handover again is refused (state machine)', async () => assert.ok((await staff(`/api/items/${item}/handover`, 'POST', { proof_type: 'OTP', proof_ref: 'otp-1' })).status >= 400));
await step('admin dashboard + audit chain verification', async () => {
  const d = await admin('/api/admin/dashboard'); assert.equal(d.status, 200); assert.ok(d.json.kpis.total_items > 0);
  const v = (await admin('/api/admin/audit/verify')).json; assert.equal(v.intact, true); console.log(`   audit chain: ${v.checked} entries verified`);
});
const pass = results.filter((r) => r[1] === 'PASS').length;
console.log(`\n${pass}/${results.length} passed`); process.exit(pass === results.length ? 0 : 1);

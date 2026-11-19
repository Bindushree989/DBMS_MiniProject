// Hybrid matching + vector index consistency, using the real application library
// (hash embeddings + in-memory vector store so the test needs no model download and no Qdrant).
import test, { before, after } from 'node:test';
import assert from 'node:assert/strict';
import { freshDb, mkUser, register, claim, useAppAccount } from './helpers.mjs';

process.env.VECTOR_STORE = 'memory';
process.env.EMBEDDING_PROVIDER = 'hash';

let db, M, S, V, staff, finder;
const ids = {};
before(async () => {
  db = await freshDb(import.meta.url);
  useAppAccount(db);
  M = await import('../src/lib/matching.js');
  S = await import('../src/lib/sync.js');
  V = await import('../src/lib/vectorstore.js');
  staff = await mkUser(db, 'staff', 'Match Staff'); finder = await mkUser(db, 'user', 'Match Finder');
  const mk = async (key, title, description, cat, color, brand, loc, hoursAgo = 3) => {
    const [r] = await db.call('sp_report_found_item', [finder, title, description, cat, color, brand, loc,
      new Date(Date.now() - hoursAgo * 3600e3).toISOString().slice(0, 19).replace('T', ' '), null, null, null]);
    ids[key] = r.item_id; await register(db, r.item_id, staff);
  };
  await mk('wallet', 'Black leather wallet', 'Black leather bifold wallet with several cards and some cash inside', 2, 'black', 'Fossil', 5);
  await mk('backpack', 'Blue backpack', 'Blue Nike backpack with a broken zip and a laptop sleeve', 3, 'blue', 'Nike', 8);
  await mk('keys', 'Keys with red keychain', 'Bunch of three keys on a red keychain with a small bell', 4, 'red', null, 9);
  await mk('phone', 'White iPhone', 'White Apple iPhone with a cracked screen protector and a clear case', 1, 'white', 'Apple', 1);
  await mk('earbuds', 'Wireless earbuds', 'White wireless earbuds in a charging case, left bud scratched', 6, 'white', 'Boat', 10);
  await S.rebuildIndex();
});
after(async () => { await (await import('../src/lib/db.js')).pool().end(); await db.close(); });

const top = async (input, mode = 'hybrid') => (await M.hybridMatch(input, { mode, limit: 5, skipSync: true }))[0]?.item_id;

test('a paraphrased description finds the right item in every mode (synonyms: rucksack~backpack, navy~blue)', async () => {
  const q = { description: 'navy rucksack with a damaged zip and a laptop sleeve' };
  assert.equal(await top(q, 'vector'), ids.backpack);
  assert.equal(await top({ ...q, category_id: 3 }, 'hybrid'), ids.backpack);
  assert.equal(await top({ description: 'cracked iphone with transparent cover' }), ids.phone);
  assert.equal(await top({ description: 'my house keys with a red bell keychain' }), ids.keys);
});

test('hybrid fuses both signals: scores are in [0,1] and final = alpha*vector + (1-alpha)*structured', async () => {
  const input = { description: 'black wallet with cards and cash', category_id: 2, color: 'black', brand: 'Fossil', location_id: 5, lost_at: new Date(Date.now() - 6 * 3600e3).toISOString() };
  const r = await M.hybridMatch(input, { mode: 'hybrid', limit: 5, skipSync: true });
  assert.equal(r[0].item_id, ids.wallet);
  const a = M.alpha();
  for (const x of r) {
    assert.ok(x.vector_score >= 0 && x.vector_score <= 1 && x.structured_score >= 0 && x.structured_score <= 1);
    assert.ok(Math.abs(x.final_score - (a * x.vector_score + (1 - a) * x.structured_score)) < 1e-3);
  }
  assert.equal(r[0].structured_score, 1, 'every supplied attribute matches');
  for (let i = 1; i < r.length; i++) assert.ok(r[i - 1].final_score >= r[i].final_score, 'sorted best first');
});

test('structured signal rescues a poorly worded query; vector signal rescues a query without attributes', async () => {
  // all attributes agree on the keys, but the words describe nothing in the catalogue
  assert.equal(await top({ description: 'thing', category_id: 4, color: 'red', location_id: 9 }, 'structured'), ids.keys);
  // no attributes at all: ranking comes purely from text similarity
  const r = await M.hybridMatch({ description: 'white wireless earbuds charging case scratched' }, { mode: 'hybrid', limit: 3, skipSync: true });
  assert.equal(r[0].item_id, ids.earbuds); assert.equal(r[0].structured_score, 0);
});

test('vector index follows MySQL: status changes leave the index, new items arrive, withdrawn items vanish', async () => {
  const input = { description: 'black leather bifold wallet with cards' };
  assert.equal(await top(input), ids.wallet);

  // wallet gets claimed -> verified -> no longer searchable (not REGISTERED / CLAIMED)
  const owner = await mkUser(db, 'user');
  const [cl] = await db.call('sp_submit_claim', [ids.wallet, owner, 'My wallet, black leather bifold with cards', null]);
  await db.call('sp_verify_claim', [cl.claim_id, staff, 'ID_PROOF', 'ID-4455', null]);
  assert.ok((await db.scalar('SELECT COUNT(*) FROM embedding_outbox WHERE processed_at IS NULL')) > 0, 'outbox has pending work');
  const drained = await S.drainOutbox();
  assert.ok(drained.processed > 0);
  const after = await M.hybridMatch(input, { mode: 'hybrid', limit: 10, skipSync: true });
  assert.ok(!after.some((r) => r.item_id === ids.wallet), 'verified item is not offered as a match');

  // a new item shows up after the outbox is applied
  const [n] = await db.call('sp_report_found_item', [finder, 'Brown leather wallet', 'Brown leather wallet with metro card', 2, 'brown', null, 5, new Date(Date.now() - 3600e3).toISOString().slice(0, 19).replace('T', ' '), null, null, null]);
  await register(db, n.item_id, staff);
  await S.drainOutbox();
  assert.equal(await top({ description: 'brown wallet with a metro card' }), n.item_id);

  // withdrawing a FOUND report removes its vector
  const [w] = await db.call('sp_report_found_item', [finder, 'Temporary item', 'To be withdrawn again very soon', 14, null, null, 5, new Date(Date.now() - 3600e3).toISOString().slice(0, 19).replace('T', ' '), null, null, null]);
  await S.drainOutbox();
  const before = await V.getStore().count();
  await db.call('sp_withdraw_found_item', [w.item_id, finder]);
  await S.drainOutbox();
  assert.equal(await V.getStore().count(), before - 1);
});

test('ensureIndexed self-heals an empty index and reports status', async () => {
  await V.getStore().reset();
  const r = await S.ensureIndexed();
  assert.equal(r.rebuilt, true);
  const st = await S.vectorStatus();
  assert.equal(st.points, st.items);
  assert.equal(st.error, null);
});

test('cosine similarity of embeddings: identical text = 1, unrelated text is clearly lower, vectors are unit length', async () => {
  const E = await import('../src/lib/embeddings.js');
  const [a, b, c] = await E.embed(['black leather wallet', 'black leather wallet', 'blue umbrella with wooden handle']);
  assert.equal(a.length, E.DIM);
  assert.ok(Math.abs(Math.hypot(...a) - 1) < 1e-6);
  assert.ok(Math.abs(E.cosine(a, b) - 1) < 1e-6);
  assert.ok(E.cosine(a, c) < 0.3);
});

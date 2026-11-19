// Minimal Qdrant REST client (no SDK needed). Collection: found_items, 384-d, cosine.
const DIM = 384;
const base = () => (process.env.QDRANT_URL || 'http://localhost:6333').replace(/\/$/, '');
const coll = () => process.env.QDRANT_COLLECTION || 'found_items';

async function req(method, path, body, timeout = 5000) {
  const headers = { 'content-type': 'application/json' };
  if (process.env.QDRANT_API_KEY) headers['api-key'] = process.env.QDRANT_API_KEY;
  const res = await fetch(base() + path, { method, headers, body: body ? JSON.stringify(body) : undefined, signal: AbortSignal.timeout(timeout) });
  const txt = await res.text();
  let json; try { json = txt ? JSON.parse(txt) : {}; } catch { json = { raw: txt }; }
  if (!res.ok) { const e = new Error(`Qdrant ${method} ${path} -> ${res.status} ${txt.slice(0, 200)}`); e.status = res.status; throw e; }
  return json;
}

async function isUp() { try { await req('GET', '/collections', null, 1500); return true; } catch { return false; } }

async function ensureCollection() {
  try { await req('GET', `/collections/${coll()}`); }
  catch (e) {
    if (e.status !== 404) throw e;
    await req('PUT', `/collections/${coll()}`, { vectors: { size: DIM, distance: 'Cosine' } });
  }
  // payload indexes make the metadata filter fast
  for (const [f, t] of [['status', 'keyword'], ['category_id', 'integer'], ['location_id', 'integer']]) {
    try { await req('PUT', `/collections/${coll()}/index?wait=true`, { field_name: f, field_schema: t }); } catch { /* already exists */ }
  }
}

const toPoint = (item, vector) => ({
  id: item.item_id, vector,
  payload: { item_id: item.item_id, status: item.status, category_id: item.category_id, location_id: item.location_id,
             found_at: Math.floor(Date.parse(String(item.found_at).replace(' ', 'T') + 'Z') / 1000) },
});
async function upsertPoints(points) { return req('PUT', `/collections/${coll()}/points?wait=true`, { points }, 30000); }
async function setStatus(itemId, status) { return req('POST', `/collections/${coll()}/points/payload?wait=true`, { payload: { status }, points: [itemId] }); }
async function deletePoint(itemId) { return req('POST', `/collections/${coll()}/points/delete?wait=true`, { points: [itemId] }); }

// cosine top-K with a metadata pre-filter
async function search(vector, { limit = 30, statuses = ['REGISTERED', 'CLAIMED'], categoryId } = {}) {
  const must = [{ key: 'status', match: { any: statuses } }];
  if (categoryId) must.push({ key: 'category_id', match: { value: categoryId } });
  const r = await req('POST', `/collections/${coll()}/points/search`, { vector, limit, filter: { must }, with_payload: true });
  return (r.result || []).map(p => ({ item_id: p.id, score: p.score }));
}
async function count() { const r = await req('POST', `/collections/${coll()}/points/count`, { exact: true }); return r.result?.count ?? 0; }

module.exports = { isUp, ensureCollection, toPoint, upsertPoints, setStatus, deletePoint, search, count, DIM };

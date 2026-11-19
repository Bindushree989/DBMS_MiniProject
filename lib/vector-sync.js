// Best-effort: keep Qdrant in step with MySQL. MySQL stays the source of truth;
// a failure here never breaks a business transaction (scripts/vector-index.js can rebuild).
const { query } = require('./db');
const { embed, itemText } = require('./embeddings');
const qdrant = require('./qdrant');

async function loadItem(id) {
  const r = await query(`SELECT i.item_id, i.title, i.description, i.color, i.brand, i.status, i.category_id, i.location_id, i.found_at, c.name AS category
                         FROM items i JOIN categories c ON c.category_id = i.category_id WHERE i.item_id = ?`, [id]);
  return r[0];
}
async function syncItem(itemId) {
  try {
    const it = await loadItem(itemId);
    if (!it) return await qdrant.deletePoint(itemId);
    await qdrant.ensureCollection();
    await qdrant.upsertPoints([qdrant.toPoint(it, await embed(itemText(it)))]);
  } catch (e) { console.warn('[vector-sync] skipped:', String(e.message).slice(0, 120)); }
}
async function removeItem(itemId) { try { await qdrant.deletePoint(itemId); } catch (e) { /* ignore */ } }
module.exports = { syncItem, removeItem, loadItem };

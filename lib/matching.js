// Hybrid matcher:  final = ALPHA * structured(SQL fn_match_score) + (1-ALPHA) * semantic
//  semantic = cosine similarity from Qdrant (top-K, status pre-filter).
//  If Qdrant is down we degrade gracefully to MySQL FULLTEXT relevance.
const { query, call } = require('./db');
const { embed, reportText } = require('./embeddings');
const qdrant = require('./qdrant');

const ALPHA = Number(process.env.MATCH_ALPHA || 0.5);

async function loadReport(reportId) {
  const r = await query(`SELECT r.*, c.name AS category FROM lost_reports r JOIN categories c ON c.category_id = r.category_id WHERE r.report_id = ?`, [reportId]);
  return r[0] || null;
}

async function hybridMatches(reportId, { limit = 10, alpha = ALPHA } = {}) {
  const report = await loadReport(reportId);
  if (!report) return null;
  const structured = await call('sp_candidates', [reportId, 60]);       // structured + fulltext (MySQL)
  const byId = new Map(structured.map(s => [s.item_id, { ...s, cosine: null }]));
  let engine = 'qdrant+mysql';
  let vec = [];
  try {
    vec = await qdrant.search(await embed(reportText(report)), { limit: 40 });
  } catch (e) { engine = 'mysql-fulltext (vector service unavailable)'; }

  // pull structured scores for vector hits that SQL did not rank in its top 60
  const missing = vec.filter(v => !byId.has(v.item_id)).map(v => v.item_id);
  if (missing.length) {
    const extra = await query(`SELECT i.item_id, i.title, i.color, i.brand, i.status, i.found_at, c.name AS category, l.name AS location,
        fn_match_score(i.item_id, ?) AS structured_score, 0 AS text_score
      FROM items i JOIN categories c ON c.category_id = i.category_id JOIN locations l ON l.location_id = i.location_id
      WHERE i.item_id IN (?) AND i.status IN ('REGISTERED','CLAIMED')`, [reportId, missing]);
    for (const e of extra) byId.set(e.item_id, { ...e, cosine: null });
  }
  for (const v of vec) { const row = byId.get(v.item_id); if (row) row.cosine = v.score; }

  const maxText = Math.max(1e-9, ...[...byId.values()].map(r => Number(r.text_score) || 0));
  const out = [...byId.values()].map(r => {
    const semantic = engine.startsWith('qdrant') ? Math.max(0, r.cosine ?? 0) : (Number(r.text_score) || 0) / maxText;
    const final = alpha * Number(r.structured_score) + (1 - alpha) * semantic;
    return { item_id: r.item_id, title: r.title, category: r.category, color: r.color, brand: r.brand, location: r.location,
             status: r.status, found_at: r.found_at, structured: Number(r.structured_score), semantic: Number(semantic.toFixed(4)),
             score: Number(final.toFixed(4)) };
  }).sort((a, b) => b.score - a.score).slice(0, limit);
  return { report, engine, alpha, matches: out };
}

module.exports = { hybridMatches, ALPHA };

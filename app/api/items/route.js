import { handle, json, body, need, int, dt } from '@/lib/api';
import { query, call } from '@/lib/db';
import { requireUser } from '@/lib/auth';
import { syncItem } from '@/lib/vector-sync';

export const GET = handle(async (req) => {
  const u = await requireUser();
  const sp = new URL(req.url).searchParams;
  const q = (sp.get('q') || '').trim(), page = Math.max(1, Number(sp.get('page') || 1)), size = 12;
  const where = [], params = [];
  const staff = u.role !== 'user';
  const mine = sp.get('mine') === '1';
  if (mine) { where.push('i.finder_id = ?'); params.push(u.user_id); }
  else if (!staff) where.push("i.status IN ('REGISTERED','CLAIMED')");        // public pool = items physically at a desk
  if (sp.get('category')) { where.push('i.category_id = ?'); params.push(int(sp.get('category'), 'category')); }
  if (sp.get('location')) { where.push('i.location_id = ?'); params.push(int(sp.get('location'), 'location')); }
  if (sp.get('status') && staff) { where.push('i.status = ?'); params.push(sp.get('status')); }
  let rel = '0', relParams = [], order = 'i.found_at DESC';
  if (q.length >= 3) {
    where.push('MATCH(i.title, i.description) AGAINST (? IN NATURAL LANGUAGE MODE)'); params.push(q);
    rel = 'MATCH(i.title, i.description) AGAINST (? IN NATURAL LANGUAGE MODE)'; relParams = [q]; order = 'relevance DESC, i.found_at DESC';
  } else if (q.length) { where.push('(i.title LIKE ? OR i.description LIKE ?)'); params.push(`%${q}%`, `%${q}%`); }
  const W = where.length ? 'WHERE ' + where.join(' AND ') : '';
  const base = `FROM items i JOIN categories c ON c.category_id = i.category_id JOIN locations l ON l.location_id = i.location_id ${W}`;
  const [{ n }] = await query(`SELECT COUNT(*) n ${base}`, params);
  const items = await query(`SELECT i.item_id, i.title, i.color, i.brand, i.status, i.found_at, c.name AS category, c.is_high_value, l.name AS location, l.loc_type,
                                    ${rel} AS relevance ${base} ORDER BY ${order} LIMIT ? OFFSET ?`, [...relParams, ...params, size, (page - 1) * size]);
  return json({ items, total: n, page, pages: Math.ceil(n / size) });
});

export const POST = handle(async (req) => {
  const u = await requireUser();
  const b = await body(req);
  need(b, 'title', 'description', 'category_id', 'location_id', 'verification_question', 'verification_answer');
  const found = b.found_at ? dt(b.found_at, 'found_at') : new Date().toISOString().slice(0, 19).replace('T', ' ');
  const r = await call('sp_report_found_item', [u.user_id, b.title, b.description, int(b.category_id, 'category'), b.color || null, b.brand || null,
    int(b.location_id, 'location'), found, b.verification_question, String(b.verification_answer)]);
  await syncItem(r[0].item_id);
  return json({ item_id: r[0].item_id }, 201);
});

import { handle, json, body, need, int, dt } from '@/lib/api';
import { query, call } from '@/lib/db';
import { requireUser } from '@/lib/auth';
export const GET = handle(async () => {
  const u = await requireUser();
  return json({ reports: await query(`SELECT r.report_id, r.title, r.description, r.color, r.brand, r.lost_at, r.status, c.name AS category, l.name AS location
      FROM lost_reports r JOIN categories c ON c.category_id = r.category_id JOIN locations l ON l.location_id = r.lost_location_id
      WHERE r.owner_id = ? ORDER BY r.created_at DESC`, [u.user_id]) });
});
export const POST = handle(async (req) => {
  const u = await requireUser();
  const b = await body(req); need(b, 'title', 'description', 'category_id', 'location_id', 'lost_at');
  const r = await call('sp_submit_lost_report', [u.user_id, b.title, b.description, int(b.category_id, 'category'), b.color || null, b.brand || null, int(b.location_id, 'location'), dt(b.lost_at, 'lost_at')]);
  return json(r[0], 201);
});

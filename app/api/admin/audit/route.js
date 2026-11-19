import { handle, json } from '@/lib/api';
import { query } from '@/lib/db';
import { requireUser } from '@/lib/auth';
export const GET = handle(async (req) => {
  await requireUser('admin');
  const sp = new URL(req.url).searchParams;
  const page = Math.max(1, Number(sp.get('page') || 1)), size = 25;
  const where = [], params = [];
  if (sp.get('table')) { where.push('a.table_name = ?'); params.push(sp.get('table')); }
  if (sp.get('record')) { where.push('a.record_id = ?'); params.push(Number(sp.get('record'))); }
  const W = where.length ? 'WHERE ' + where.join(' AND ') : '';
  const [{ n }] = await query(`SELECT COUNT(*) n FROM audit_log a ${W}`, params);
  const rows = await query(`SELECT a.audit_id, a.table_name, a.record_id, a.action, a.old_values, a.new_values, a.changed_at, u.full_name AS actor, LEFT(a.row_hash, 12) AS hash
      FROM audit_log a LEFT JOIN users u ON u.user_id = a.changed_by ${W} ORDER BY a.audit_id DESC LIMIT ? OFFSET ?`, [...params, size, (page - 1) * size]);
  return json({ rows, total: n, page, pages: Math.ceil(n / size) });
});

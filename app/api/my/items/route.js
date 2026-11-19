import { handle, json } from '@/lib/api';
import { query } from '@/lib/db';
import { requireUser } from '@/lib/auth';
export const GET = handle(async () => {
  const u = await requireUser();
  return json({ items: await query(`SELECT i.item_id, i.title, i.status, i.found_at, l.name AS location, h.full_name AS holder
      FROM items i JOIN locations l ON l.location_id = i.location_id LEFT JOIN users h ON h.user_id = i.current_holder_id
      WHERE i.finder_id = ? ORDER BY i.found_at DESC LIMIT 100`, [u.user_id]) });
});

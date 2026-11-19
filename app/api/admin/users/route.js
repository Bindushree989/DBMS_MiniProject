import { handle, json } from '@/lib/api';
import { query } from '@/lib/db';
import { requireUser } from '@/lib/auth';
export const GET = handle(async () => {
  await requireUser('admin');
  return json({ users: await query(`SELECT u.user_id, u.full_name, u.email, u.role, u.is_active, u.created_at,
      (SELECT COUNT(*) FROM items i WHERE i.finder_id = u.user_id) AS items_found,
      (SELECT COUNT(*) FROM claims c WHERE c.claimant_id = u.user_id) AS claims FROM users u ORDER BY FIELD(u.role,'admin','staff','user'), u.full_name LIMIT 200`) });
});

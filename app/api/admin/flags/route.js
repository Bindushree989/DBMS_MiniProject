import { handle, json } from '@/lib/api';
import { query } from '@/lib/db';
import { requireUser } from '@/lib/auth';
export const GET = handle(async () => {
  await requireUser('admin');
  const flags = await query(`SELECT f.flag_id, f.flag_type, f.details, f.status, f.created_at, u.full_name AS user, u.user_id, f.item_id, i.title AS item
      FROM fraud_flags f JOIN users u ON u.user_id = f.user_id LEFT JOIN items i ON i.item_id = f.item_id ORDER BY f.status = 'OPEN' DESC, f.created_at DESC LIMIT 100`);
  const suspicious = await query('SELECT * FROM v_suspicious_users ORDER BY open_flags DESC, flags DESC LIMIT 10');
  return json({ flags, suspicious });
});

import { handle, json } from '@/lib/api';
import { query } from '@/lib/db';
export const GET = handle(async () => {
  const [k] = await query('SELECT total_items, returned_items, return_rate_pct, avg_hours_to_return, open_items FROM v_admin_kpis');
  return json(k);
});

import { handle, json } from '@/lib/api';
import { query } from '@/lib/db';
import { requireUser } from '@/lib/auth';
export const GET = handle(async () => {
  await requireUser('admin');
  const [kpis] = await query('SELECT * FROM v_admin_kpis');
  const byStatus = await query("SELECT status, COUNT(*) AS n FROM items GROUP BY status ORDER BY FIELD(status,'FOUND','REGISTERED','CLAIMED','VERIFIED','HANDED_OVER','RETURNED')");
  const monthly = await query('SELECT * FROM (SELECT * FROM v_monthly_returns ORDER BY month DESC LIMIT 8) m ORDER BY month');
  const unclaimed = await query('SELECT * FROM v_unclaimed_by_location ORDER BY unclaimed_items DESC LIMIT 8');
  const workload = await query('SELECT * FROM v_staff_workload ORDER BY items_in_custody DESC');
  const byCategory = await query(`SELECT c.name AS category, COUNT(*) AS found, SUM(i.status='RETURNED') AS returned,
      ROUND(100*SUM(i.status='RETURNED')/COUNT(*),1) AS return_rate_pct
    FROM items i JOIN categories c ON c.category_id = i.category_id GROUP BY c.category_id, c.name HAVING COUNT(*) >= 5 ORDER BY found DESC`);
  const byType = await query(`SELECT l.loc_type, COUNT(*) AS found, ROUND(AVG(CASE WHEN i.status='RETURNED' THEN TIMESTAMPDIFF(HOUR,i.found_at,i.returned_at) END),1) AS avg_hours_to_return
    FROM items i JOIN locations l ON l.location_id = i.location_id GROUP BY l.loc_type ORDER BY found DESC`);
  return json({ kpis, byStatus, monthly, unclaimed, workload, byCategory, byType });
});

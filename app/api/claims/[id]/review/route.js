import { handle, json, body, int } from '@/lib/api';
import { call, query } from '@/lib/db';
import { requireUser } from '@/lib/auth';
import { syncItem } from '@/lib/vector-sync';
export const POST = handle(async (req, { params }) => {
  const u = await requireUser('staff', 'admin');
  const id = int((await params).id, 'claim id'); const b = await body(req);
  const [c] = await query('SELECT item_id FROM claims WHERE claim_id = ?', [id]);
  const r = await call('sp_review_claim', [id, u.user_id, b.approve ? 1 : 0, b.notes || null]);
  if (c) await syncItem(c.item_id);
  return json(r[0]);
});

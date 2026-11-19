import { handle, json, body, need, int } from '@/lib/api';
import { call } from '@/lib/db';
import { requireUser } from '@/lib/auth';
export const POST = handle(async (req, { params }) => {
  const u = await requireUser('staff', 'admin');
  const id = int((await params).id, 'item id'); const b = await body(req); need(b, 'to');
  return json((await call('sp_transfer_custody', [id, u.user_id, int(b.to, 'recipient'), b.note || null]))[0]);
});

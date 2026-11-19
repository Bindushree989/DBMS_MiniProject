import { handle, json, body, int } from '@/lib/api';
import { call } from '@/lib/db';
import { requireUser } from '@/lib/auth';
import { syncItem } from '@/lib/vector-sync';
export const POST = handle(async (req, { params }) => {
  const u = await requireUser('staff', 'admin');
  const id = int((await params).id, 'item id'); const b = await body(req).catch(() => ({}));
  const r = await call('sp_register_item', [id, u.user_id, b.note || 'Accepted at desk']);
  await syncItem(id);
  return json(r[0]);
});

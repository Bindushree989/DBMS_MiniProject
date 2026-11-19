import { handle, json, int } from '@/lib/api';
import { call } from '@/lib/db';
import { requireUser } from '@/lib/auth';
import { syncItem } from '@/lib/vector-sync';
export const POST = handle(async (req, { params }) => {
  const u = await requireUser();
  const id = int((await params).id, 'item id');
  const r = await call('sp_confirm_return', [id, u.user_id]);
  await syncItem(id);
  return json(r[0]);
});

import { handle, json, body, need, int } from '@/lib/api';
import { call } from '@/lib/db';
import { requireUser } from '@/lib/auth';
export const POST = handle(async (req, { params }) => {
  const u = await requireUser('admin');
  const b = await body(req); need(b, 'status');
  return json((await call('sp_resolve_flag', [int((await params).id, 'flag id'), u.user_id, b.status]))[0]);
});

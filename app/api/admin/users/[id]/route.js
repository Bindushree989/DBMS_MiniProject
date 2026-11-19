import { handle, json, body, need, int } from '@/lib/api';
import { call } from '@/lib/db';
import { requireUser, HttpError } from '@/lib/auth';
export const POST = handle(async (req, { params }) => {
  const u = await requireUser('admin');
  const b = await body(req); need(b, 'role');
  if (!['user', 'staff', 'admin'].includes(b.role)) throw new HttpError(422, 'Invalid role', 'VALIDATION');
  return json((await call('sp_set_user_role', [u.user_id, int((await params).id, 'user id'), b.role]))[0]);
});

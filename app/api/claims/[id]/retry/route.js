import { handle, json, body, need, int } from '@/lib/api';
import { call } from '@/lib/db';
import { requireUser } from '@/lib/auth';
export const POST = handle(async (req, { params }) => {
  const u = await requireUser();
  const b = await body(req); need(b, 'answer');
  return json((await call('sp_retry_answer', [int((await params).id, 'claim id'), u.user_id, String(b.answer)]))[0]);
});

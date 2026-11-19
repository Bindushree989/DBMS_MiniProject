import { handle, json, body, need, int } from '@/lib/api';
import { call } from '@/lib/db';
import { requireUser } from '@/lib/auth';
import { syncItem } from '@/lib/vector-sync';
export const POST = handle(async (req, { params }) => {
  const u = await requireUser();
  const id = int((await params).id, 'item id'); const b = await body(req); need(b, 'description', 'answer');
  const r = await call('sp_submit_claim', [id, u.user_id, b.report_id ? int(b.report_id, 'report') : null, b.description, String(b.answer)]);
  await syncItem(id);
  return json(r[0], 201);
});

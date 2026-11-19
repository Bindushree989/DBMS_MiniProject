import { handle, json, body, need, int } from '@/lib/api';
import { call } from '@/lib/db';
import { requireUser, HttpError } from '@/lib/auth';
import { syncItem } from '@/lib/vector-sync';
export const POST = handle(async (req, { params }) => {
  const u = await requireUser('staff', 'admin');
  const id = int((await params).id, 'item id'); const b = await body(req); need(b, 'proof_type', 'proof_ref');
  if (!['ID_CARD', 'OTP', 'SIGNATURE', 'PHOTO'].includes(b.proof_type)) throw new HttpError(422, 'Invalid proof type', 'VALIDATION');
  const r = await call('sp_perform_handover', [id, u.user_id, b.proof_type, String(b.proof_ref), b.notes || null]);
  await syncItem(id);
  return json(r[0]);
});

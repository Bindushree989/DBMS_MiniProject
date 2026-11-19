import { handle, json, int } from '@/lib/api';
import { query, call } from '@/lib/db';
import { requireUser, HttpError } from '@/lib/auth';
import { removeItem } from '@/lib/vector-sync';

export const GET = handle(async (req, { params }) => {
  const u = await requireUser();
  const id = int((await params).id, 'item id');
  const [it] = await query('SELECT * FROM v_item_public WHERE item_id = ?', [id]);
  if (!it) throw new HttpError(404, 'Item not found', 'NOT_FOUND');
  const staff = u.role !== 'user';
  const myClaims = await query(`SELECT claim_id, status, answer_match, match_score, created_at, review_notes,
      (SELECT COUNT(*) FROM verification_attempts v WHERE v.claim_id = claims.claim_id) AS attempts
      FROM claims WHERE item_id = ? AND claimant_id = ?`, [id, u.user_id]);
  const isFinder = it.finder_id === u.user_id;
  const participant = staff || isFinder || myClaims.length > 0 || it.current_holder_id === u.user_id;
  if (!participant && !['REGISTERED', 'CLAIMED'].includes(it.status)) throw new HttpError(404, 'Item not found', 'NOT_FOUND');
  const out = { item: { ...it }, myClaims, can: {} };
  if (!participant) { delete out.item.finder_name; delete out.item.holder_name; delete out.item.finder_id; delete out.item.current_holder_id; }
  if (participant) out.timeline = await query('SELECT event_time, event_type, actor, detail FROM v_item_timeline WHERE item_id = ? ORDER BY event_time, event_type', [id]);
  if (staff) out.claims = await query(`SELECT c.claim_id, c.status, c.answer_match, c.match_score, c.description, c.created_at, c.review_notes,
        u.user_id AS claimant_id, u.full_name AS claimant, (SELECT COUNT(*) FROM fraud_flags f WHERE f.user_id = u.user_id AND f.status = 'OPEN') AS open_flags
      FROM claims c JOIN users u ON u.user_id = c.claimant_id WHERE c.item_id = ? ORDER BY c.created_at`, [id]);
  if (staff) out.staffList = await query("SELECT user_id, full_name FROM users WHERE role IN ('staff','admin') AND is_active = 1 ORDER BY full_name");
  const claimable = ['REGISTERED', 'CLAIMED'].includes(it.status) && !isFinder && it.current_holder_id !== u.user_id && myClaims.length === 0;
  out.can = {
    claim: claimable,
    register: staff && it.status === 'FOUND',
    transfer: staff && it.current_holder_id === u.user_id && ['REGISTERED', 'CLAIMED', 'VERIFIED'].includes(it.status),
    handover: staff && it.current_holder_id === u.user_id && it.status === 'VERIFIED',
    confirm: it.status === 'HANDED_OVER' && (it.current_holder_id === u.user_id || staff),
    delete: u.role === 'admin' && it.status === 'FOUND',
    review: staff && ['CLAIMED'].includes(it.status),
  };
  return json(out);
});

export const DELETE = handle(async (req, { params }) => {
  const u = await requireUser('admin');
  const id = int((await params).id, 'item id');
  await call('sp_delete_spam_item', [u.user_id, id]);
  await removeItem(id);
  return json({ ok: true });
});

import { handle, json } from '@/lib/api';
import { query } from '@/lib/db';
import { requireUser } from '@/lib/auth';
export const GET = handle(async () => {
  const u = await requireUser();
  return json({ claims: await query(`SELECT c.claim_id, c.item_id, i.title, i.status AS item_status, i.verification_question, c.status, c.answer_match, c.match_score,
      c.created_at, c.review_notes, (SELECT COUNT(*) FROM verification_attempts v WHERE v.claim_id = c.claim_id) AS attempts
    FROM claims c JOIN items i ON i.item_id = c.item_id WHERE c.claimant_id = ? ORDER BY c.created_at DESC`, [u.user_id]) });
});

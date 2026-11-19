import { handle, json } from '@/lib/api';
import { query } from '@/lib/db';
import { requireUser } from '@/lib/auth';
export const GET = handle(async () => {
  const u = await requireUser('staff', 'admin');
  const toRegister = await query(`SELECT i.item_id, i.title, i.found_at, l.name AS location, f.full_name AS finder
      FROM items i JOIN locations l ON l.location_id = i.location_id JOIN users f ON f.user_id = i.finder_id
      WHERE i.status = 'FOUND' ORDER BY i.found_at LIMIT 50`);
  const pendingClaims = await query(`SELECT c.claim_id, c.item_id, i.title, c.answer_match, c.match_score, c.created_at, c.description, u.full_name AS claimant,
        (SELECT COUNT(*) FROM fraud_flags f WHERE f.user_id = u.user_id AND f.status = 'OPEN') AS open_flags,
        (SELECT COUNT(*) FROM claims c2 WHERE c2.item_id = c.item_id AND c2.status = 'PENDING') AS competing, i.current_holder_id
      FROM claims c JOIN items i ON i.item_id = c.item_id JOIN users u ON u.user_id = c.claimant_id
      WHERE c.status = 'PENDING' ORDER BY c.answer_match DESC, c.created_at LIMIT 50`);
  const awaitingHandover = await query(`SELECT i.item_id, i.title, h.full_name AS holder, i.current_holder_id,
        (SELECT u.full_name FROM claims c JOIN users u ON u.user_id = c.claimant_id WHERE c.item_id = i.item_id AND c.status = 'VERIFIED') AS owner
      FROM items i JOIN users h ON h.user_id = i.current_holder_id WHERE i.status = 'VERIFIED' ORDER BY i.updated_at LIMIT 50`);
  const mine = await query(`SELECT i.item_id, i.title, i.status FROM items i WHERE i.current_holder_id = ? AND i.status IN ('REGISTERED','CLAIMED','VERIFIED') ORDER BY i.updated_at DESC LIMIT 50`, [u.user_id]);
  return json({ me: u.user_id, toRegister, pendingClaims, awaitingHandover, mine });
});

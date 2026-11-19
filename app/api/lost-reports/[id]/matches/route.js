import { handle, json, int } from '@/lib/api';
import { query } from '@/lib/db';
import { requireUser, HttpError } from '@/lib/auth';
import { hybridMatches } from '@/lib/matching';
export const GET = handle(async (req, { params }) => {
  const u = await requireUser();
  const id = int((await params).id, 'report id');
  const [r] = await query('SELECT owner_id FROM lost_reports WHERE report_id = ?', [id]);
  if (!r || (r.owner_id !== u.user_id && u.role === 'user')) throw new HttpError(404, 'Report not found', 'NOT_FOUND');
  return json(await hybridMatches(id, { limit: 10 }));
});

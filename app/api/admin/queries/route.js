import { handle, json } from '@/lib/api';
import { query } from '@/lib/db';
import { requireUser, HttpError } from '@/lib/auth';
import Q from '@/lib/showcase-queries';
export const GET = handle(async (req) => {
  await requireUser('admin');
  const id = new URL(req.url).searchParams.get('id');
  if (!id) return json({ queries: Q.map(({ id, concept, title }) => ({ id, concept, title })) });
  const q = Q.find(x => x.id === id);
  if (!q) throw new HttpError(404, 'Unknown query', 'NOT_FOUND');
  const t0 = Date.now();
  const rows = await query(q.sql);
  return json({ ...q, rows, ms: Date.now() - t0 });
});

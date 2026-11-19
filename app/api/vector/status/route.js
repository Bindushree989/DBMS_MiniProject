import { handle, json } from '@/lib/api';
import { requireUser } from '@/lib/auth';
import qdrant from '@/lib/qdrant';
import emb from '@/lib/embeddings';
export const GET = handle(async () => {
  await requireUser('staff', 'admin');
  const up = await qdrant.isUp();
  let points = null; try { if (up) points = await qdrant.count(); } catch { /* collection missing */ }
  return json({ up, points, url: process.env.QDRANT_URL || 'http://localhost:6333', collection: process.env.QDRANT_COLLECTION || 'found_items', provider: emb.provider(), dims: 384, metric: 'cosine' });
});

import { handle, json } from '@/lib/api';
import { query } from '@/lib/db';
import { requireUser } from '@/lib/auth';
import { syncItem } from '@/lib/vector-sync';
export const POST = handle(async () => {
  await requireUser('admin');
  const ids = await query('SELECT item_id FROM items');
  for (const r of ids) await syncItem(r.item_id);
  return json({ reindexed: ids.length });
});

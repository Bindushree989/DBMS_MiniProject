// Drains the MySQL embedding_outbox into the vector index (Qdrant by default).
//   npm run vectors:sync              incremental (rebuilds automatically if the index is empty/out of sync)
//   npm run vectors:sync -- --rebuild drop the collection and re-embed every item
import './_env.mjs';
import { rebuildIndex, ensureIndexed, drainOutbox, vectorStatus } from '../src/lib/sync.js';
import { providerName, providerTag } from '../src/lib/embeddings.js';
import { pool } from '../src/lib/db.js';

console.log(`Embedding provider: ${providerName()} (${providerTag()})`);
try {
  const t0 = Date.now();
  if (process.argv.includes('--rebuild')) {
    const n = await rebuildIndex({ onProgress: (k) => k % 256 === 0 && console.log(`  embedded ${k} items ...`) });
    console.log(`Rebuilt index with ${n} items in ${((Date.now() - t0) / 1000).toFixed(1)}s`);
  } else {
    const r = await ensureIndexed();
    if (r.rebuilt) console.log(`Index was empty or out of sync - rebuilt with ${r.items} items`);
    let total = 0;
    for (;;) { const d = await drainOutbox(); if (!d.processed) break; total += d.processed; }
    console.log(`Applied ${total} pending outbox rows`);
  }
  console.table([await vectorStatus()]);
} catch (e) {
  console.error(`\nVector sync failed: ${e.message}`);
  process.exitCode = 1;
}
await pool().end();

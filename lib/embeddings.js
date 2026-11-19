// Embeddings for item/lost-report text.
//  provider "transformers": Xenova/all-MiniLM-L6-v2 (384-d, mean pooled, L2-normalised) via Transformers.js
//  provider "hash":         offline lexical fallback (feature hashing of words + bigrams + char trigrams)
//  provider "auto" (default): try the model, fall back to hash if it cannot be loaded.
const DIM = 384;
const STOP = new Set('a an the and or of in on at to with for is it its was were be been this that these those my our your their i me we you he she they them from by as are has have had not no but if so very just also into near'.split(' '));

let extractorPromise = null;
let active = null; // 'transformers' | 'hash'

function fnv(str, seed = 2166136261) {
  let h = seed >>> 0;
  for (let i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = Math.imul(h, 16777619) >>> 0; }
  return h >>> 0;
}
function hashEmbed(text) {
  const v = new Float32Array(DIM);
  const words = (text.toLowerCase().match(/[a-z0-9]+/g) || []).filter(w => !STOP.has(w));
  const add = (feat, w) => { const h = fnv(feat); v[h % DIM] += ((fnv(feat, 7) & 1) ? 1 : -1) * w; };
  words.forEach((w, i) => {
    add('w:' + w, 1);
    if (i > 0) add('b:' + words[i - 1] + '_' + w, 0.5);
    if (w.length > 3) { const p = `#${w}#`; for (let k = 0; k + 3 <= p.length; k++) add('c:' + p.slice(k, k + 3), 0.3); }
  });
  let n = 0; for (const x of v) n += x * x; n = Math.sqrt(n) || 1;
  return Array.from(v, x => x / n);
}

async function loadModel() {
  if (!extractorPromise) {
    extractorPromise = (async () => {
      const { pipeline } = await import('@huggingface/transformers');
      return pipeline('feature-extraction', 'Xenova/all-MiniLM-L6-v2');
    })();
  }
  return extractorPromise;
}

async function embed(text) {
  const want = (process.env.EMBEDDING_PROVIDER || 'auto').toLowerCase();
  if (want !== 'hash' && active !== 'hash') {
    try {
      const ex = await loadModel();
      const out = await ex(text, { pooling: 'mean', normalize: true });
      active = 'transformers';
      return Array.from(out.data);
    } catch (e) {
      if (want === 'transformers') throw new Error('EMBEDDING_PROVIDER=transformers but the model could not be loaded: ' + e.message);
      active = 'hash';
      console.warn('[embeddings] MiniLM unavailable (' + String(e.message).slice(0, 80) + ') - using offline hashing embedder');
    }
  }
  active = 'hash';
  return hashEmbed(text);
}
const provider = () => active || (process.env.EMBEDDING_PROVIDER || 'auto');

const itemText = it => [it.title, it.category, it.color, it.brand, it.description].filter(Boolean).join('. ');
const reportText = r => [r.title, r.category, r.color, r.brand, r.description].filter(Boolean).join('. ');

module.exports = { embed, DIM, provider, itemText, reportText, hashEmbed };

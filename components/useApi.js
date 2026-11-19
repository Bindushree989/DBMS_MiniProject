'use client';
import { useEffect, useState, useCallback } from 'react';

export function useApi(url) {
  const [s, set] = useState({ data: null, error: null, loading: !!url });
  const load = useCallback(async () => {
    if (!url) return;
    try {
      const r = await fetch(url, { cache: 'no-store' });
      const j = await r.json().catch(() => ({}));
      if (!r.ok) throw Object.assign(new Error(j.error || 'Request failed'), { status: r.status });
      set({ data: j, error: null, loading: false });
    } catch (e) { set({ data: null, error: e, loading: false }); }
  }, [url]);
  useEffect(() => { load(); }, [load]);
  return { ...s, reload: load };
}

export async function send(url, body, method = 'POST') {
  const r = await fetch(url, { method, headers: { 'Content-Type': 'application/json' }, body: method === 'DELETE' ? undefined : JSON.stringify(body || {}) });
  const j = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(j.error || 'Request failed');
  return j;
}

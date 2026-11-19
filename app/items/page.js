'use client';
import { useState } from 'react';
import Link from 'next/link';
import { useApi } from '@/components/useApi';
import { Badge, Err, when } from '@/components/ui';

export default function Items() {
  const [f, setF] = useState({ q: '', category: '', location: '', status: '', page: 1 });
  const qs = new URLSearchParams(Object.entries(f).filter(([, v]) => v !== '' && v !== 1)).toString();
  const { data, error } = useApi('/api/items?' + qs);
  const { data: meta } = useApi('/api/meta');
  const { data: me } = useApi('/api/auth/me');
  const staff = me?.user && me.user.role !== 'user';
  const set = (k) => (e) => setF({ ...f, [k]: e.target.value, page: 1 });
  return (
    <>
      <h1>Found items</h1>
      <div className="card row">
        <label>Search (full-text)<input value={f.q} onChange={set('q')} placeholder="black wallet metro card" /></label>
        <label>Category<select value={f.category} onChange={set('category')}><option value="">All</option>{meta?.categories.map((c) => <option key={c.category_id} value={c.category_id}>{c.name}</option>)}</select></label>
        <label>Location<select value={f.location} onChange={set('location')}><option value="">All</option>{meta?.locations.map((l) => <option key={l.location_id} value={l.location_id}>{l.name}</option>)}</select></label>
        {staff && <label>Status<select value={f.status} onChange={set('status')}><option value="">All</option>{['FOUND', 'REGISTERED', 'CLAIMED', 'VERIFIED', 'HANDED_OVER', 'RETURNED'].map((s) => <option key={s}>{s}</option>)}</select></label>}
      </div>
      <Err error={error} />
      {data && <>
        <p className="muted">{data.total} items</p>
        <table><thead><tr><th>Item</th><th>Category</th><th>Found at</th><th>When</th><th>Status</th></tr></thead><tbody>
          {data.items.map((i) => <tr key={i.item_id}><td><Link href={`/items/${i.item_id}`}>{i.title}</Link></td><td>{i.category}</td><td>{i.location}</td><td>{when(i.found_at)}</td><td><Badge s={i.status} /></td></tr>)}
          {!data.items.length && <tr><td colSpan={5} className="muted">No items match.</td></tr>}</tbody></table>
        <p className="row" style={{ marginTop: '.8rem' }}>
          <button className="alt" disabled={f.page <= 1} onClick={() => setF({ ...f, page: f.page - 1 })}>Previous</button>
          <span className="muted">Page {data.page} of {Math.max(1, data.pages)}</span>
          <button className="alt" disabled={f.page >= data.pages} onClick={() => setF({ ...f, page: f.page + 1 })}>Next</button></p>
      </>}
    </>
  );
}

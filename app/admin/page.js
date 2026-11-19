'use client';
import { useState } from 'react';
import Link from 'next/link';
import { useApi, send } from '@/components/useApi';
import { Err, Form, Act, when } from '@/components/ui';

function Audit() {
  const { data: v } = useApi('/api/admin/audit/verify');
  const { data: a } = useApi('/api/admin/audit');
  return <>
    {v && <p className={v.intact ? 'okmsg' : 'err'}>{v.intact ? `Hash chain intact (${v.checked} entries verified).` : `TAMPERING DETECTED: ${JSON.stringify(v.broken)}`}</p>}
    <table><thead><tr><th>#</th><th>Table</th><th>Record</th><th>Action</th><th>By</th><th>When</th><th>Hash</th></tr></thead><tbody>
      {a?.rows.map((r) => <tr key={r.audit_id}><td>{r.audit_id}</td><td>{r.table_name}</td><td>{r.record_id}</td><td>{r.action}</td><td>{r.actor || 'system'}</td><td>{when(r.changed_at)}</td><td className="muted">{r.hash}</td></tr>)}</tbody></table></>;
}
function Queries() {
  const { data } = useApi('/api/admin/queries');
  const [id, setId] = useState(null);
  const { data: r } = useApi(id ? `/api/admin/queries?id=${id}` : null);
  return <>
    <table><tbody>{data?.queries.map((q) => <tr key={q.id}><td className="muted">{q.concept}</td><td>{q.title}</td><td><button className="alt" onClick={() => setId(q.id)}>Run</button></td></tr>)}</tbody></table>
    {r && <div className="card"><b>{r.title}</b> <span className="muted">({r.rows.length} rows, {r.ms} ms)</span><pre style={{ overflow: 'auto', fontSize: '.8rem' }}>{r.sql}</pre>
      <div style={{ overflow: 'auto' }}><table><thead><tr>{r.rows[0] && Object.keys(r.rows[0]).map((k) => <th key={k}>{k}</th>)}</tr></thead><tbody>
        {r.rows.slice(0, 15).map((row, i) => <tr key={i}>{Object.values(row).map((v, j) => <td key={j}>{String(v ?? '')}</td>)}</tr>)}</tbody></table></div></div>}</>;
}

export default function Admin() {
  const { data, error } = useApi('/api/admin/dashboard');
  const { data: fl, reload: reloadFlags } = useApi('/api/admin/flags');
  const { data: us, reload: reloadUsers } = useApi('/api/admin/users');
  const { data: vec } = useApi('/api/vector/status');
  if (error) return <Err error={error} />;
  if (!data) return <p className="muted">Loading...</p>;
  const k = data.kpis; const max = Math.max(1, ...data.unclaimed.map((u) => Number(u.unclaimed_items)));
  return (<>
    <h1>Admin dashboard</h1>
    <div className="grid">{[['total_items', 'items'], ['return_rate_pct', '% returned'], ['avg_hours_to_return', 'avg hours to return'], ['open_items', 'open items'], ['pending_claims', 'pending claims'], ['open_flags', 'open fraud flags']].map(([f, l]) => <div className="kpi" key={f}><b>{k[f] ?? '-'}</b><span>{l}</span></div>)}</div>
    <h2>Items by status</h2><table><tbody>{data.byStatus.map((s) => <tr key={s.status}><td style={{ width: '30%' }}>{s.status}</td><td><div style={{ background: 'var(--tag)', height: 12, width: `${(s.n / Math.max(...data.byStatus.map((x) => x.n))) * 100}%`, borderRadius: 4 }} /></td><td>{s.n}</td></tr>)}</tbody></table>
    <h2>Unclaimed items by location</h2><table><tbody>{data.unclaimed.map((u) => <tr key={u.location_id}><td style={{ width: '38%' }}>{u.location}</td><td><div style={{ background: 'var(--tag)', height: 12, width: `${(u.unclaimed_items / max) * 100}%`, borderRadius: 4 }} /></td><td>{u.unclaimed_items}</td><td className="muted">avg {u.avg_age_days}d old</td></tr>)}</tbody></table>
    <h2>Return rate by category</h2><table><thead><tr><th>Category</th><th>Found</th><th>Returned</th><th>Rate</th></tr></thead><tbody>{data.byCategory.map((c) => <tr key={c.category}><td>{c.category}</td><td>{c.found}</td><td>{c.returned}</td><td>{c.return_rate_pct}%</td></tr>)}</tbody></table>
    <h2>Staff workload</h2><table><tbody>{data.workload.map((w) => <tr key={w.user_id}><td>{w.full_name}</td><td>{w.items_in_custody} in custody</td><td>{w.awaiting_handover} awaiting handover</td></tr>)}</tbody></table>
    <h2>Fraud flags</h2>
    {fl?.flags.filter((f) => f.status === 'OPEN').slice(0, 10).map((f) => <div className="card" key={f.flag_id}><b>{String(f.flag_type).replaceAll('_', ' ')}</b> · {f.user} · {f.details} {f.item_id && <>· <Link href={`/items/${f.item_id}`}>{f.item}</Link></>}
      <Act url={`/api/admin/flags/${f.flag_id}`} body={{ status: 'DISMISSED' }} label="Dismiss" danger onDone={reloadFlags} /> <Act url={`/api/admin/flags/${f.flag_id}`} body={{ status: 'CONFIRMED' }} label="Confirm fraud" onDone={reloadFlags} /></div>)}
    {fl && fl.flags.filter((f) => f.status === 'OPEN').length > 10 && <p className="muted">Showing 10 of {fl.flags.filter((f) => f.status === 'OPEN').length} open flags.</p>}
    {fl && !fl.flags.some((f) => f.status === 'OPEN') && <p className="muted">No open flags.</p>}
    <h2>Users</h2><div style={{ overflow: 'auto', maxHeight: 320 }}><table><thead><tr><th>Name</th><th>Email</th><th>Role</th><th>Found</th><th>Claims</th><th>Set role</th></tr></thead><tbody>
      {us?.users.slice(0, 40).map((u) => <tr key={u.user_id}><td>{u.full_name}</td><td className="muted">{u.email}</td><td>{u.role}</td><td>{u.items_found}</td><td>{u.claims}</td>
        <td><select defaultValue={u.role} onChange={async (e) => { try { await send(`/api/admin/users/${u.user_id}`, { role: e.target.value }); reloadUsers(); } catch (er) { alert(er.message); reloadUsers(); } }}><option>user</option><option>staff</option><option>admin</option></select></td></tr>)}</tbody></table></div>
    <h2>Vector index</h2>{vec && <p className="muted">Qdrant {vec.up ? 'online' : 'offline (matching falls back to MySQL full-text)'} · points: {vec.points ?? '-'} · embeddings: {vec.provider} · {vec.dims} dims · {vec.metric}</p>}
    {vec && <Act url="/api/vector/reindex" label="Re-index all items" onDone={() => {}} />}
    <h2>Audit trail</h2><Audit />
    <h2>Showcase queries (JOIN / GROUP BY / HAVING / subqueries)</h2><Queries />
  </>);
}

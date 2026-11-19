'use client';
import { useState } from 'react';
import Link from 'next/link';
import { useApi, send } from '@/components/useApi';
import { Form, Err, Badge, when } from '@/components/ui';

function Matches({ id }) {
  const { data, error } = useApi(`/api/lost-reports/${id}/matches`);
  if (error) return <Err error={error} />;
  if (!data) return <p className="muted">Searching...</p>;
  return <>
    <p className="muted">Engine: {data.engine} · weight on structured score α = {data.alpha}</p>
    <table><thead><tr><th>Candidate</th><th>Where</th><th>Structured</th><th>Semantic</th><th>Final</th><th></th></tr></thead><tbody>
      {data.matches.map((m) => <tr key={m.item_id}><td><Link href={`/items/${m.item_id}?report=${id}`}>{m.title}</Link> <Badge s={m.status} /></td><td>{m.location}</td>
        <td>{m.structured.toFixed(2)}</td><td>{m.semantic.toFixed(2)}</td><td><b>{m.score.toFixed(2)}</b></td><td><Link className="btn" href={`/items/${m.item_id}`}>Claim</Link></td></tr>)}
      {!data.matches.length && <tr><td colSpan={6} className="muted">No candidates yet. New found items are matched as they arrive.</td></tr>}</tbody></table></>;
}

export default function Lost() {
  const { data: meta } = useApi('/api/meta');
  const { data, error, reload } = useApi('/api/lost-reports');
  const [open, setOpen] = useState(null);
  return (<>
    <h1>I lost something</h1>
    <p className="muted">Describe what you lost. Back2You ranks found items using attribute scoring (SQL) combined with description similarity (vector search).</p>
    <div className="card" style={{ maxWidth: 640 }}>
      {meta && <Form submit="Save lost report" onDone={reload} onSubmit={(v) => send('/api/lost-reports', v)} fields={[
        { name: 'title', label: 'What did you lose?', required: true, placeholder: 'Black leather wallet' },
        { name: 'description', label: 'Describe it', type: 'textarea', required: true },
        { name: 'category_id', label: 'Category', type: 'select', required: true, options: meta.categories.map((c) => ({ value: c.category_id, label: c.name })) },
        { name: 'color', label: 'Colour' }, { name: 'brand', label: 'Brand' },
        { name: 'location_id', label: 'Where did you lose it?', type: 'select', required: true, options: meta.locations.map((l) => ({ value: l.location_id, label: `${l.name} (${l.city})` })) },
        { name: 'lost_at', label: 'When?', type: 'datetime-local', required: true }]} />}</div>
    <Err error={error} />
    {data?.reports.map((r) => <div className="card" key={r.report_id}><b>{r.title}</b> <span className="muted">{r.category} · {r.location} · {when(r.lost_at)} · {r.status}</span>
      <p>{r.description}</p><button className="alt" onClick={() => setOpen(open === r.report_id ? null : r.report_id)}>{open === r.report_id ? 'Hide matches' : 'Find matches'}</button>
      {open === r.report_id && <Matches id={r.report_id} />}</div>)}
  </>);
}

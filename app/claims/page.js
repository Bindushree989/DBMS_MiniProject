'use client';
import Link from 'next/link';
import { useApi, send } from '@/components/useApi';
import { Badge, Err, Form, Act, when } from '@/components/ui';

export default function Claims() {
  const { data, error, reload } = useApi('/api/claims/mine');
  const { data: mine, reload: reloadMine } = useApi('/api/my/items');
  const all = () => { reload(); reloadMine(); };
  return (<>
    <h1>My claims</h1>
    <Err error={error} />
    {data && !data.claims.length && <p className="muted">No claims yet. <Link href="/items">Browse found items</Link> or <Link href="/lost">report what you lost</Link>.</p>}
    {data?.claims.map((c) => <div className="card" key={c.claim_id}>
      <b><Link href={`/items/${c.item_id}`}>{c.title}</Link></b> <Badge s={c.item_status} /> <span className="muted">claim {c.status} · {when(c.created_at)}</span>
      {c.review_notes && <p className="muted">{c.review_notes}</p>}
      {c.status === 'PENDING' && (c.answer_match ? <p className="okmsg">Answer verified. Waiting for staff approval.</p> :
        <><p><b>Prove it&apos;s yours:</b> {c.verification_question} <span className="muted">(attempts used: {c.attempts})</span></p>
        <Form compact submit="Check answer" onDone={all} onSubmit={(v) => send(`/api/claims/${c.claim_id}/retry`, v)} fields={[{ name: 'answer', label: 'Your answer', required: true }]} /></>)}
      {c.status === 'PENDING' && <Act url={`/api/claims/${c.claim_id}/withdraw`} label="Withdraw claim" danger onDone={all} />}
      {c.status === 'VERIFIED' && c.item_status === 'VERIFIED' && <p className="okmsg">Approved! Visit the desk with your ID to collect it.</p>}
      {c.status === 'VERIFIED' && c.item_status === 'HANDED_OVER' && <Act url={`/api/items/${c.item_id}/confirm`} label="I received my item" onDone={all} />}</div>)}
    <h2>Items I reported</h2>
    <table><tbody>{mine?.items.map((m) => <tr key={m.item_id}><td><Link href={`/items/${m.item_id}`}>{m.title}</Link></td><td className="muted">{m.location}</td><td><Badge s={m.status} /></td></tr>)}</tbody></table>
  </>);
}

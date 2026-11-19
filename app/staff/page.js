'use client';
import Link from 'next/link';
import { useApi } from '@/components/useApi';
import { Badge, Err, when } from '@/components/ui';

export default function Staff() {
  const { data, error } = useApi('/api/staff/queue');
  if (error) return <Err error={error} />;
  if (!data) return <p className="muted">Loading...</p>;
  const L = (id, t) => <Link href={`/items/${id}`}>{t}</Link>;
  return (<>
    <h1>Staff desk</h1>
    <h2>1 · Awaiting registration ({data.toRegister.length})</h2>
    <table><tbody>{data.toRegister.map((r) => <tr key={r.item_id}><td>{L(r.item_id, r.title)}</td><td className="muted">{r.finder} · {r.location} · {when(r.found_at)}</td></tr>)}</tbody></table>
    <h2>2 · Claims to review ({data.pendingClaims.length})</h2>
    <table><thead><tr><th>Item</th><th>Claimant</th><th>Answer</th><th>Rivals</th><th>Flags</th></tr></thead><tbody>
      {data.pendingClaims.map((r) => <tr key={r.claim_id}><td>{L(r.item_id, r.title)}</td><td>{r.claimant}</td><td>{r.answer_match ? <span className="okmsg">correct</span> : <span className="muted">not matched</span>}</td><td>{r.competing}</td><td className={r.open_flags ? 'err' : ''}>{r.open_flags}</td></tr>)}</tbody></table>
    <h2>3 · Ready for handover ({data.awaitingHandover.length})</h2>
    <table><tbody>{data.awaitingHandover.map((r) => <tr key={r.item_id}><td>{L(r.item_id, r.title)}</td><td className="muted">owner: {r.owner} · held by {r.holder}{r.current_holder_id === data.me ? ' (you)' : ''}</td><td><Badge s="VERIFIED" /></td></tr>)}</tbody></table>
    <h2>In my custody ({data.mine.length})</h2>
    <table><tbody>{data.mine.map((r) => <tr key={r.item_id}><td>{L(r.item_id, r.title)}</td><td><Badge s={r.status} /></td></tr>)}</tbody></table>
  </>);
}

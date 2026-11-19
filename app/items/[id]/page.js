'use client';
import { use } from 'react';
import Link from 'next/link';
import { useApi, send } from '@/components/useApi';
import { Badge, Steps, Err, Form, Act, when } from '@/components/ui';

export default function ItemPage({ params }) {
  const { id } = use(params);
  const { data, error, reload } = useApi(`/api/items/${id}`);
  const { data: lost } = useApi('/api/lost-reports');
  if (error) return <Err error={error} />;
  if (!data) return <p className="muted">Loading...</p>;
  const { item, myClaims = [], timeline, claims = [], staffList = [], can } = data;
  const verified = claims.find((c) => c.status === 'VERIFIED');
  return (
    <>
      <h1>{item.title} <Badge s={item.status} /></h1>
      <p className="muted">{item.category} · found at {item.location} ({item.city}) on {when(item.found_at)}</p>
      <Steps s={item.status} />
      <div className="card"><p>{item.description}</p>
        <p className="muted">Colour: {item.color || '-'} · Brand: {item.brand || '-'}{item.finder_name && <> · Reported by {item.finder_name}</>}{item.holder_name && <> · Held by <b>{item.holder_name}</b></>}</p></div>

      {timeline && <><h2>Chain of custody</h2>
        <ol className="tl">{timeline.map((t, i) => <li key={i}><b>{String(t.event_type).replaceAll('_', ' ')}</b> · {when(t.event_time)}<br /><span className="muted">{t.actor} — {t.detail}</span></li>)}</ol></>}

      {can.claim && <><h2>This is mine</h2><div className="card">
        <p className="muted">The finder asked: <b>{item.verification_question}</b></p>
        <Form submit="Submit claim" onDone={() => reload()} onSubmit={(v) => send(`/api/items/${id}/claims`, v)} fields={[
          { name: 'description', label: 'Describe it in your own words', type: 'textarea', required: true },
          { name: 'answer', label: 'Your answer to the question above', required: true },
          { name: 'report_id', label: 'Link one of your lost reports (optional)', type: 'select', options: (lost?.reports || []).map((r) => ({ value: r.report_id, label: r.title })) }]} /></div></>}

      {myClaims.map((c) => <div className="card" key={c.claim_id}>Your claim #{c.claim_id}: <b>{c.status}</b>
        {c.status === 'PENDING' && <> · answer {c.answer_match ? 'correct ✓' : 'not matched yet'} (attempts {c.attempts})</>}
        {c.review_notes && <p className="muted">{c.review_notes}</p>}
        {c.status === 'PENDING' && !c.answer_match && <Form compact submit="Retry answer" onDone={reload} onSubmit={(v) => send(`/api/claims/${c.claim_id}/retry`, v)} fields={[{ name: 'answer', label: 'Answer', required: true }]} />}
        {c.status === 'PENDING' && <Act url={`/api/claims/${c.claim_id}/withdraw`} label="Withdraw claim" danger onDone={reload} />}</div>)}

      {can.register && <><h2>Register this item</h2><div className="card"><Form submit="Take custody & register" onDone={reload} onSubmit={(v) => send(`/api/items/${id}/register`, v)} fields={[{ name: 'note', label: 'Note (storage point, finder proof...)', placeholder: 'Shelf A3, finder signed hand-in form' }]} /></div></>}

      {can.review && claims.length > 0 && <><h2>Claims</h2>{claims.map((c) => <div className="card" key={c.claim_id}>
        <b>{c.claimant}</b> <span className="muted">{c.status} · answer {c.answer_match ? 'correct' : 'not matched'} · score {c.match_score ?? '-'}{c.open_flags > 0 && <span className="err"> · {c.open_flags} open fraud flag(s)</span>}</span>
        <p>{c.description}</p>
        {c.status === 'PENDING' && <div className="row">
          <Form compact submit="Approve" onDone={reload} extra={{ approve: true }} onSubmit={(v) => send(`/api/claims/${c.claim_id}/review`, v)} fields={[{ name: 'notes', label: 'Notes (ID checked...)' }]} />
          <Form compact danger submit="Reject" onDone={reload} extra={{ approve: false }} onSubmit={(v) => send(`/api/claims/${c.claim_id}/review`, v)} fields={[{ name: 'notes', label: 'Reason' }]} /></div>}</div>)}</>}

      {can.handover && <><h2>Hand over{verified ? ` to ${verified.claimant}` : ''}</h2><div className="card"><Form submit="Record handover" onDone={reload} onSubmit={(v) => send(`/api/items/${id}/handover`, v)} fields={[
        { name: 'proof_type', label: 'Proof', type: 'select', required: true, defaultValue: 'ID_CARD', options: ['ID_CARD', 'OTP', 'SIGNATURE', 'PHOTO'].map((v) => ({ value: v, label: v })) },
        { name: 'proof_ref', label: 'Proof reference', required: true, placeholder: 'College ID 4MH21CS001' }, { name: 'notes', label: 'Notes' }]} /></div></>}

      {can.transfer && staffList.length > 0 && <><h2>Transfer custody</h2><div className="card"><Form submit="Transfer" onDone={reload} onSubmit={(v) => send(`/api/items/${id}/transfer`, v)} fields={[
        { name: 'to', label: 'To', type: 'select', required: true, options: staffList.filter((s) => s.user_id !== item.current_holder_id).map((s) => ({ value: s.user_id, label: s.full_name })) },
        { name: 'note', label: 'Note' }]} /></div></>}

      {can.confirm && <div className="card"><Act url={`/api/items/${id}/confirm`} label="Confirm the owner received it" onDone={reload} /></div>}
      {can.delete && <div className="card"><Act url={`/api/items/${id}`} method="DELETE" label="Delete (admin: spam/unregistered only)" danger onDone={() => { window.location.href = '/items'; }} /></div>}
    </>
  );
}

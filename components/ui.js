'use client';
import { useState } from 'react';
import { send } from './useApi';

export const STATUSES = ['FOUND', 'REGISTERED', 'CLAIMED', 'VERIFIED', 'HANDED_OVER', 'RETURNED'];
export const label = (s) => String(s).replace('_', ' ');
export const when = (v) => (v ? String(v).replace('T', ' ').slice(0, 16) : '-');

export function Badge({ s }) {
  return <span className="badge" style={{ color: `var(--s-${s}, var(--muted))` }}>{label(s)}</span>;
}
export function Steps({ s }) {
  const at = STATUSES.indexOf(s);
  return <div className="steps">{STATUSES.map((x, i) => <span key={x} className={'badge' + (i <= at ? ' on' : '')} style={{ color: `var(--s-${x})` }}>{label(x)}</span>)}</div>;
}
export function Err({ error }) {
  if (!error) return null;
  if (error.status === 401) return <p className="err">Please <a href="/login">sign in</a> to see this page.</p>;
  return <p className="err">{error.message}</p>;
}

/** fields: [{name,label,type,options:[{value,label}],required,placeholder,defaultValue}]. onSubmit(values) -> promise */
export function Form({ fields, submit, onSubmit, onDone, extra = {}, danger, compact }) {
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState(null);
  async function go(e) {
    e.preventDefault(); setBusy(true); setMsg(null);
    const v = { ...extra };
    new FormData(e.currentTarget).forEach((val, k) => { if (String(val) !== '') v[k] = val; });
    try {
      const out = await onSubmit(v);
      setMsg({ ok: true, text: out?.message || 'Done.' });
      onDone && onDone(out);
    } catch (er) { setMsg({ ok: false, text: er.message }); }
    setBusy(false);
  }
  return (
    <form className="f" onSubmit={go}>
      <div className={compact ? 'row' : undefined} style={compact ? undefined : { display: 'grid', gap: '.7rem' }}>
        {fields.map((f) => (
          <label key={f.name}>{f.label}
            {f.type === 'textarea' ? <textarea name={f.name} required={f.required} placeholder={f.placeholder} defaultValue={f.defaultValue} /> :
             f.type === 'select' ? <select name={f.name} required={f.required} defaultValue={f.defaultValue ?? ''}><option value="">{f.required ? 'Choose...' : '(none)'}</option>{(f.options || []).map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}</select> :
             <input name={f.name} type={f.type || 'text'} required={f.required} placeholder={f.placeholder} defaultValue={f.defaultValue} />}
          </label>))}
      </div>
      <div><button disabled={busy} className={danger ? 'alt' : undefined}>{busy ? 'Working...' : submit}</button></div>
      {msg && <div className={msg.ok ? 'okmsg' : 'err'} role="status">{msg.text}</div>}
    </form>
  );
}

/** One-click action button (no fields). */
export function Act({ url, body, method, label: text, onDone, danger }) {
  return <Form fields={[]} submit={text} danger={danger} onSubmit={() => send(url, body, method)} onDone={onDone} />;
}

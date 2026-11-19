'use client';
import { useApi, send } from '@/components/useApi';
import { Form, Err } from '@/components/ui';

export default function Report() {
  const { data: meta } = useApi('/api/meta');
  const { error } = useApi('/api/auth/me');
  return <div className="card" style={{ maxWidth: 640 }}><h1>Report a found item</h1>
    <p className="muted">Ask one question only the real owner could answer (a wallpaper, an engraving, a card inside). The answer is stored hashed.</p>
    <Err error={error} />
    {meta && <Form submit="Report item" onSubmit={(v) => send('/api/items', v)} onDone={(r) => { window.location.href = `/items/${r.item_id}`; }} fields={[
      { name: 'title', label: 'Short title', required: true, placeholder: 'Black Samsung phone' },
      { name: 'description', label: 'Description', type: 'textarea', required: true },
      { name: 'category_id', label: 'Category', type: 'select', required: true, options: meta.categories.map((c) => ({ value: c.category_id, label: c.name })) },
      { name: 'color', label: 'Colour' }, { name: 'brand', label: 'Brand' },
      { name: 'location_id', label: 'Where was it found?', type: 'select', required: true, options: meta.locations.map((l) => ({ value: l.location_id, label: `${l.name} (${l.city})` })) },
      { name: 'found_at', label: 'When? (blank = now)', type: 'datetime-local' },
      { name: 'verification_question', label: 'Verification question', required: true, placeholder: 'What picture is on the lock screen?' },
      { name: 'verification_answer', label: 'Secret answer (case-insensitive)', required: true }]} />}</div>;
}

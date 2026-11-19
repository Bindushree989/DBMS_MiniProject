'use client';
import { Form } from '@/components/ui';
import { send } from '@/components/useApi';

export default function Register() {
  return <div className="card" style={{ maxWidth: 420 }}><h1>Create account</h1>
    <Form submit="Create account" onSubmit={(v) => send('/api/auth/register', v)} onDone={() => { window.location.href = '/items'; }} fields={[
      { name: 'full_name', label: 'Full name', required: true }, { name: 'email', label: 'Email', type: 'email', required: true },
      { name: 'phone', label: 'Phone (optional)' }, { name: 'password', label: 'Password (min 8)', type: 'password', required: true }]} /></div>;
}

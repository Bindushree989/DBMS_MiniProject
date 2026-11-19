'use client';
import { Form, } from '@/components/ui';
import { send } from '@/components/useApi';

export default function Login() {
  return <div className="card" style={{ maxWidth: 420 }}><h1>Sign in</h1>
    <Form submit="Sign in" onSubmit={(v) => send('/api/auth/login', v)} onDone={() => { window.location.href = '/items'; }} fields={[
      { name: 'email', label: 'Email', type: 'email', required: true }, { name: 'password', label: 'Password', type: 'password', required: true }]} />
    <p className="muted">Demo (after seeding): user1@back2you.dev / User@123 · staff1@back2you.dev / Staff@123 · admin@back2you.dev / Admin@123</p></div>;
}

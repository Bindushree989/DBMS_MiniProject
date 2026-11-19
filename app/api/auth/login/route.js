import bcrypt from 'bcryptjs';
import { handle, json, body, need } from '@/lib/api';
import { query } from '@/lib/db';
import { setCookie, HttpError } from '@/lib/auth';

const fails = globalThis.__b2yFails ||= new Map();     // email -> {n, until}
export const POST = handle(async (req) => {
  const b = await body(req); need(b, 'email', 'password');
  const email = String(b.email).trim().toLowerCase();
  const f = fails.get(email);
  if (f && f.n >= 5 && Date.now() < f.until) throw new HttpError(429, 'Too many failed attempts. Try again in a few minutes.', 'RATE');
  const r = await query('SELECT user_id, full_name, email, role, password_hash FROM users WHERE email = ? AND is_active = 1', [email]);
  const ok = r[0] && await bcrypt.compare(String(b.password), r[0].password_hash);
  if (!ok) { fails.set(email, { n: (f && Date.now() < f.until ? f.n : 0) + 1, until: Date.now() + 10 * 60e3 }); throw new HttpError(401, 'Invalid email or password', 'AUTH'); }
  fails.delete(email);
  const { password_hash, ...user } = r[0];
  await setCookie(user);
  return json({ user });
});

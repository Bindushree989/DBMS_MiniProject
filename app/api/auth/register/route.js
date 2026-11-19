import bcrypt from 'bcryptjs';
import { handle, json, body, need } from '@/lib/api';
import { query } from '@/lib/db';
import { setCookie, HttpError } from '@/lib/auth';

export const POST = handle(async (req) => {
  const b = await body(req); need(b, 'full_name', 'email', 'password');
  const email = String(b.email).trim().toLowerCase();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) throw new HttpError(422, 'Enter a valid email address', 'VALIDATION');
  if (String(b.password).length < 8) throw new HttpError(422, 'Password must be at least 8 characters', 'VALIDATION');
  const hash = await bcrypt.hash(String(b.password), 10);
  // role is NEVER taken from the request: every self-registration is a plain user
  const r = await query('INSERT INTO users (full_name, email, phone, password_hash, role) VALUES (?,?,?,?, "user")',
    [String(b.full_name).trim(), email, b.phone ? String(b.phone).trim() : null, hash]);
  const user = { user_id: r.insertId, full_name: b.full_name, email, role: 'user' };
  await setCookie(user);
  return json({ user }, 201);
});

// JWT session in an httpOnly cookie. Authorization is ALWAYS re-checked against the DB
// (role/is_active are read fresh on every request, never trusted from the token).
const { SignJWT, jwtVerify } = require('jose');
const { cookies } = require('next/headers');
const { query } = require('./db');

const COOKIE = 'b2y_token';
const secret = () => {
  if (!process.env.JWT_SECRET || process.env.JWT_SECRET.length < 16) throw new Error('JWT_SECRET missing or too short (see .env.example)');
  return new TextEncoder().encode(process.env.JWT_SECRET);
};

async function signSession(user) {
  return new SignJWT({ uid: user.user_id }).setProtectedHeader({ alg: 'HS256' }).setIssuedAt().setExpirationTime('8h').sign(secret());
}
async function setCookie(user) {
  (await cookies()).set(COOKIE, await signSession(user), { httpOnly: true, sameSite: 'lax', secure: process.env.NODE_ENV === 'production', path: '/', maxAge: 8 * 3600 });
}
async function clearCookie() { (await cookies()).delete(COOKIE); }

async function currentUser() {
  const tok = (await cookies()).get(COOKIE)?.value;
  if (!tok) return null;
  try {
    const { payload } = await jwtVerify(tok, secret());
    const r = await query('SELECT user_id, full_name, email, role FROM users WHERE user_id = ? AND is_active = 1', [payload.uid]);
    return r[0] || null;
  } catch { return null; }
}

class HttpError extends Error { constructor(status, message, code) { super(message); this.status = status; this.code = code; } }
async function requireUser(...roles) {
  const u = await currentUser();
  if (!u) throw new HttpError(401, 'Please sign in', 'AUTH');
  if (roles.length && !roles.includes(u.role)) throw new HttpError(403, 'Your role does not permit this action', 'FORBIDDEN');
  return u;
}

module.exports = { setCookie, clearCookie, currentUser, requireUser, HttpError };

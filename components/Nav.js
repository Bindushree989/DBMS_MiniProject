'use client';
import Link from 'next/link';
import { useApi, send } from './useApi';

export default function Nav() {
  const { data } = useApi('/api/auth/me');
  const u = data?.user;
  const staff = u && u.role !== 'user';
  return (
    <nav className="top">
      <Link className="brand" href="/">Back<span>2</span>You</Link>
      <Link className="l" href="/items">Found items</Link>
      {u && <Link className="l" href="/report">I found something</Link>}
      {u && <Link className="l" href="/lost">I lost something</Link>}
      {u && <Link className="l" href="/claims">My claims</Link>}
      {staff && <Link className="l" href="/staff">Staff desk</Link>}
      {u?.role === 'admin' && <Link className="l" href="/admin">Admin</Link>}
      <span className="sp" />
      {u ? <><span className="muted">{u.full_name} · {u.role}</span>
        <button className="alt" onClick={async () => { await send('/api/auth/logout'); window.location.href = '/'; }}>Sign out</button></> :
        <><Link className="l" href="/login">Sign in</Link><Link className="btn" href="/register">Create account</Link></>}
    </nav>
  );
}

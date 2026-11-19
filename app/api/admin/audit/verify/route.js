import { handle, json } from '@/lib/api';
import { call, query } from '@/lib/db';
import { requireUser } from '@/lib/auth';
export const GET = handle(async () => {
  await requireUser('admin');
  const broken = await call('sp_verify_audit_chain', []);
  const [{ n }] = await query('SELECT COUNT(*) n FROM audit_log');
  return json({ intact: broken.length === 0, checked: n, broken });
});

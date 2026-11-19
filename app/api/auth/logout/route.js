import { handle, json } from '@/lib/api';
import { clearCookie } from '@/lib/auth';
export const POST = handle(async () => { await clearCookie(); return json({ ok: true }); });

import { handle, json } from '@/lib/api';
import { currentUser } from '@/lib/auth';
export const GET = handle(async () => json({ user: await currentUser() }));

// Loads .env (if present) into process.env, then exposes typed config helpers.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

const envFile = path.join(ROOT, '.env');
if (fs.existsSync(envFile)) {
  try { process.loadEnvFile(envFile); } catch { /* ignore malformed file */ }
}

export function requireEnv(name) {
  const v = process.env[name];
  if (v === undefined || v === '') {
    console.error(`Missing environment variable ${name}. Copy .env.example to .env and fill it in.`);
    process.exit(1);
  }
  return v;
}

export const dbConfig = (admin = false) => ({
  host: process.env.DB_HOST || '127.0.0.1',
  port: Number(process.env.DB_PORT || 3306),
  user: admin ? requireEnv('DB_ADMIN_USER') : requireEnv('DB_USER'),
  password: admin ? (process.env.DB_ADMIN_PASSWORD ?? '') : (process.env.DB_PASSWORD ?? ''),
  database: process.env.DB_NAME || 'back2you',
  timezone: 'Z',
  dateStrings: true,
  charset: 'utf8mb4_unicode_ci',
});

import { handle, json } from '@/lib/api';
import { query } from '@/lib/db';
export const GET = handle(async () => json({
  categories: await query('SELECT category_id, name, is_high_value FROM categories ORDER BY name'),
  locations: await query('SELECT location_id, name, loc_type, city, is_staffed FROM locations ORDER BY loc_type, name'),
}));

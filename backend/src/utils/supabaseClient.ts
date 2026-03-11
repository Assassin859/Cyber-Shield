import { createClient } from '@supabase/supabase-js';

// these env vars should be set in .env or Railway config
const SUPABASE_URL = process.env.SUPABASE_URL || '';
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || '';

if (!SUPABASE_URL || !SUPABASE_KEY) {
  throw new Error('Supabase URL/Key not defined');
}

export const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

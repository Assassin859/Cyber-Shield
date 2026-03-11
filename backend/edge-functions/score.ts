// Placeholder for Supabase Edge Function that calculates fraud score
import { serve } from 'std/server';

serve(async (req) => {
  return new Response(JSON.stringify({ score: 'safe' }), { status: 200 });
});

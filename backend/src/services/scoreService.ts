import { supabase } from '../utils/supabaseClient';

export async function scoreRecipient(value: string) {
  // normalize value here if needed (lowercase, trim)
  const { data, error } = await supabase
    .from('fraud_numbers')
    .select('*')
    .eq('value', value)
    .limit(1)
    .single();

  if (error && error.code !== 'PGRST116') {
    // PGRST116 = no rows
    throw error;
  }

  if (data) {
    return {
      score: data.severity || 'dangerous',
      source: data.source,
    };
  }

  return { score: 'safe' };
}

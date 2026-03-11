// Placeholder for Razorpay webhook handler
import { serve } from 'std/server';

serve(async (req) => {
  // verify signature and update subscription table
  return new Response(JSON.stringify({ success: true }), { status: 200 });
});

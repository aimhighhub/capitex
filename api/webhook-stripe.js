// /api/webhook-stripe.js
// Vercel serverless function. Stripe calls this URL directly (not the browser)
// when a checkout session completes. Register this URL in your Stripe
// dashboard → Developers → Webhooks → Add endpoint:
//   https://your-domain.vercel.app/api/webhook-stripe
// and select the "checkout.session.completed" event.
//
// Requires env vars: STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET,
// SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (see create-deposit-intent.js for details).

import Stripe from 'stripe';
import { createClient } from '@supabase/supabase-js';
import { buffer } from 'micro';

export const config = { api: { bodyParser: false } }; // Stripe needs the raw body to verify the signature

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || '');
const supabaseAdmin = createClient(
  process.env.SUPABASE_URL || '',
  process.env.SUPABASE_SERVICE_ROLE_KEY || ''
);

export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).end();

  const sig = req.headers['stripe-signature'];
  const buf = await buffer(req);

  let event;
  try {
    event = stripe.webhooks.constructEvent(buf, sig, process.env.STRIPE_WEBHOOK_SECRET || '');
  } catch (err) {
    console.error('Webhook signature verification failed:', err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  if (event.type === 'checkout.session.completed') {
    const session = event.data.object;
    const depositId = session.metadata?.depositId;
    if (depositId) {
      await supabaseAdmin
        .from('deposits')
        .update({ status: 'success' })
        .eq('id', depositId);

      // TODO: this is the point where you'd actually instruct your
      // broker/custodian integration to buy the chosen asset mix with
      // the deposited amount. Nothing does that automatically yet.
    }
  }

  return res.status(200).json({ received: true });
}

// /api/create-deposit-intent.js
// Vercel serverless function (Node.js). Creates a Stripe Checkout Session
// for a lump-sum or recurring deposit, then redirects the user to Stripe.
//
// Requires environment variables set in your Vercel project settings:
//   STRIPE_SECRET_KEY        — from Stripe dashboard (server-side only, never in the HTML)
//   SUPABASE_URL              — same as LO_CONFIG.supabaseUrl in index.html
//   SUPABASE_SERVICE_ROLE_KEY — Supabase dashboard → Settings → API → service_role
//                                (server-side only — this key bypasses RLS, never expose it client-side)
//
// This is a working example, not a finished payment flow — you still need to:
//   1. npm install stripe @supabase/supabase-js
//   2. Set the env vars above in Vercel → Project → Settings → Environment Variables
//   3. Add a matching /api/webhook-stripe.js call (see that file) to actually
//      mark the deposit as successful once Stripe confirms payment
//   4. Decide what happens after payment succeeds — i.e. instructing your
//      broker/custodian integration to actually buy the chosen asset mix

import Stripe from 'stripe';
import { createClient } from '@supabase/supabase-js';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || '');
const supabaseAdmin = createClient(
  process.env.SUPABASE_URL || '',
  process.env.SUPABASE_SERVICE_ROLE_KEY || ''
);

export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  try {
    const { userId, amount, currency = 'usd', depositType = 'lump_sum' } = req.body;
    if (!userId || !amount || amount <= 0) {
      return res.status(400).json({ error: 'userId and a positive amount are required' });
    }

    // 1. Record a pending deposit row so we have something to reconcile against later
    const { data: deposit, error: dbError } = await supabaseAdmin
      .from('deposits')
      .insert({ user_id: userId, type: depositType, amount, currency: currency.toUpperCase(), gateway: 'stripe', status: 'pending' })
      .select()
      .single();
    if (dbError) throw dbError;

    // 2. Create the Stripe Checkout Session
    const session = await stripe.checkout.sessions.create({
      mode: 'payment',
      payment_method_types: ['card'],
      line_items: [{
        price_data: {
          currency,
          product_data: { name: 'LOInvest deposit' },
          unit_amount: Math.round(amount * 100),
        },
        quantity: 1,
      }],
      metadata: { userId, depositId: deposit.id },
      success_url: `${process.env.PUBLIC_SITE_URL || 'https://your-domain.vercel.app'}/?deposit=success`,
      cancel_url: `${process.env.PUBLIC_SITE_URL || 'https://your-domain.vercel.app'}/?deposit=cancelled`,
    });

    // 3. Save the Stripe session id so the webhook can find this deposit again
    await supabaseAdmin.from('deposits').update({ gateway_ref: session.id }).eq('id', deposit.id);

    return res.status(200).json({ checkoutUrl: session.url });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Could not start deposit — please try again.' });
  }
}

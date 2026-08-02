<<<<<<< HEAD
# capitex
=======
# LOInvest — "Left Over Invest"

Your real PocketFuture build, rebranded to LOInvest, extended with the
leftover-round-up mechanic and a Retirement goal, and now wired for a real
deploy: Supabase auth/database, Vercel API routes for Stripe deposits, SEO
meta, security headers, and a first-draft (not counsel-reviewed) legal page.

## Deploy to Vercel — no config needed for the static part

```
npm install -g vercel     # if you don't have it
cd loinvest
vercel                    # first deploy, follow the prompts
vercel --prod              # promote to your production URL
```

Or: drag the unzipped folder into vercel.com/new. Either way you get a
working demo URL immediately — everything currently runs in demo mode
(no backend needed) exactly like before, so nothing breaks on day one.

## Turning on the real backend (do this before real users/ads)

**1. Supabase — auth + database**
1. Create a project at supabase.com
2. SQL Editor → paste and run `supabase/schema.sql`
3. Settings → API → copy your Project URL and anon public key
4. In `index.html`, find `LO_CONFIG` near the top of the main `<script>`
   block and fill in `supabaseUrl` and `supabaseAnonKey`
5. Redeploy (`vercel --prod`) — signup/login/logout now hit a real backend;
   session persists on reload

**2. Vercel API routes — real deposits (Stripe)**
1. `npm install` in the project root (installs `stripe`, `@supabase/supabase-js`, `micro`)
2. Copy `.env.example` into Vercel → Project → Settings → Environment
   Variables and fill in real values (Stripe secret key, Supabase
   service-role key, your deployed site URL)
3. In Stripe dashboard → Developers → Webhooks, add an endpoint pointing
   to `https://your-domain.vercel.app/api/webhook-stripe`, event
   `checkout.session.completed`, and copy the signing secret into
   `STRIPE_WEBHOOK_SECRET`
4. `/api/create-deposit-intent.js` is a working example, and the deposit
   page's "Confirm & Start Schedule" button now calls it automatically
   once `LO_CONFIG.enabled` is true and the user is logged in — it hands
   off to Stripe Checkout, then falls back to the original demo flow if
   Supabase isn't configured yet or the call fails. Nothing to wire up
   here manually anymore.
5. Flutterwave/Paystack (mentioned in the FAQ for non-US countries) would
   need their own API routes, following the same pattern

**3. The pieces this doesn't include yet**
- A real broker/custodian integration — Stripe/Flutterwave move money *to*
  you, but nothing here actually buys stocks/gold/crypto with it. That's a
  separate integration (Alpaca, DriveWealth, or similar) called from the
  Stripe webhook once a deposit is confirmed.
- A card-linking provider (Plaid or similar) so Round-Ups reflect real
  purchases instead of the demo feed
- Real KYC document review (currently a demo upload flow)
- Legal review — `page-legal` (footer → Terms/Privacy/Risk/AML) has a
  realistic *draft*, clearly flagged as unreviewed, not final legal text
- Licensing/registration research for wherever you actually operate —
  this is the one item on this whole list that has to happen before ads,
  not after

## What's ready now

- **SEO**: meta description, Open Graph/Twitter card image
  (`assets/images/og/og-image.jpg`), canonical tag, JSON-LD — replace
  `YOUR-DOMAIN` throughout `index.html`, `robots.txt`, and `sitemap.xml`
  with your real Vercel domain once you have one
- **Security headers**: `vercel.json` sets standard headers (X-Frame-Options,
  nosniff, referrer policy)
- **Analytics**: a commented-out GA4 snippet in `<head>` — uncomment and add
  your measurement ID, or swap in Vercel Analytics / Plausible
- **Favicon/OG image**: generated in your existing Gold/Teal palette

## One real limitation worth knowing

This is a single-file SPA — `/pricing`, `/how-it-works` etc. aren't real
URLs, they're JS-toggled divs on one page. That's fine for the app itself,
but search engines mostly only index the one URL they can crawl (the
homepage). If organic search traffic matters to you beyond paid ads, that's
a structural thing to revisit later (e.g. separate static pages, or a
framework with server-side rendering) — not a quick fix.

## Files added this round

```
loinvest/
├── index.html                    Rebranded app + real Supabase auth + Legal page
├── supabase/schema.sql           Full DB schema with Row Level Security
├── api/
│   ├── create-deposit-intent.js  Stripe checkout session (Vercel function)
│   └── webhook-stripe.js         Confirms deposits after payment (Vercel function)
├── package.json                  Dependencies for the /api routes
├── vercel.json                   Security headers
├── .env.example                  Copy into Vercel's env var settings
├── robots.txt, sitemap.xml       Basic SEO
├── favicon.ico, assets/images/   Favicon + OG image
```
>>>>>>> 452b7d2 (Upload Capitex site v1)

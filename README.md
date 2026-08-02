# Capitex

Capitex is a single-page static site with Vercel API routes for Stripe deposits and Supabase authentication. The site is designed for a demo-ready launch with polished branding, mobile-friendly landing page layout, and an investment product concept built around automated round-ups.

## Quick Start

1. `npm install`
2. `npm run dev` or deploy to Vercel

## Deploy to Vercel

```bash
npm install -g vercel
vercel
vercel --prod
```

## Configure Supabase

1. Create a project at supabase.com
2. Run `supabase/schema.sql` in the SQL editor
3. Set `SUPABASE_URL` and `SUPABASE_ANON_KEY` on Vercel
4. Update `LO_CONFIG` in `index.html` with your Supabase values

## Configure Stripe

1. Set `STRIPE_SECRET_KEY` and `STRIPE_WEBHOOK_SECRET` on Vercel
2. Set `PUBLIC_SITE_URL` to your deployed site URL
3. Use `/api/create-deposit-intent.js` and `/api/webhook-stripe.js` as examples

## Notes

- This repository is a content-focused SPA, so `/pricing` and `/how-it-works` are page sections shown via JavaScript rather than separate routes.
- The brand is Capitex throughout the application.
- The legal content in `index.html` is a draft and should be reviewed before production use.
- Replace `YOUR-DOMAIN` values in `index.html`, `robots.txt`, and `sitemap.xml` with your real site URL before launch.

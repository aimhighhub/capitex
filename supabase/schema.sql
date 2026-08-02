-- ============================================================
-- LOInvest — Supabase schema
-- Run this in Supabase SQL Editor (or via `supabase db push`)
-- after creating a fresh project. Safe to run once on a clean DB.
-- ============================================================

-- ---------- PROFILES ----------
-- One row per auth.users, created automatically on signup.
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  first_name text,
  last_name text,
  country text,
  currency text default 'USD',
  kyc_tier int default 0,            -- 0=unverified, 1=email, 2=id, 3=full
  round_up_enabled boolean default false,
  round_up_multiplier int default 1, -- 1, 2, 3, or 10
  created_at timestamptz default now()
);
alter table public.profiles enable row level security;
create policy "profiles: read own" on public.profiles for select using (auth.uid() = id);
create policy "profiles: update own" on public.profiles for update using (auth.uid() = id);

-- Auto-create a profile row whenever a new auth user signs up.
create function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, first_name, last_name, country)
  values (
    new.id,
    new.raw_user_meta_data ->> 'first_name',
    new.raw_user_meta_data ->> 'last_name',
    new.raw_user_meta_data ->> 'country'
  );
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ---------- LINKED CARDS (for Round-Ups) ----------
-- Store only the token/reference your card-linking provider (e.g. Plaid) gives you —
-- never raw card numbers.
create table public.linked_cards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade not null,
  provider text not null,             -- e.g. 'plaid'
  provider_item_id text not null,     -- opaque token from the provider
  last4 text,
  brand text,
  status text default 'active',       -- active | disconnected
  created_at timestamptz default now()
);
alter table public.linked_cards enable row level security;
create policy "linked_cards: own rows" on public.linked_cards for all using (auth.uid() = user_id);

-- ---------- ROUND-UPS LEDGER ----------
-- One row per detected purchase + its round-up amount. A separate job/webhook
-- sweeps unswept rows into an investment once they cross the $5 threshold.
create table public.round_ups (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade not null,
  merchant text,
  purchase_amount numeric(12,2) not null,
  round_up_amount numeric(12,2) not null,
  swept boolean default false,        -- true once invested
  swept_at timestamptz,
  created_at timestamptz default now()
);
alter table public.round_ups enable row level security;
create policy "round_ups: own rows" on public.round_ups for all using (auth.uid() = user_id);
create index round_ups_user_unswept on public.round_ups (user_id, swept);

-- ---------- DEPOSITS ----------
create table public.deposits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade not null,
  type text not null,                 -- 'lump_sum' | 'recurring' | 'round_up_sweep' | 'gift_card'
  amount numeric(12,2) not null,
  currency text default 'USD',
  gateway text,                       -- 'stripe' | 'flutterwave' | 'paystack' | 'circle_usdc'
  gateway_ref text,                   -- external transaction id
  status text default 'pending',      -- pending | success | failed
  asset_mix jsonb,                    -- e.g. {"stocks":50,"gold":30,"etf":20}
  created_at timestamptz default now()
);
alter table public.deposits enable row level security;
create policy "deposits: own rows" on public.deposits for all using (auth.uid() = user_id);

-- ---------- RECURRING SCHEDULES ----------
create table public.schedules (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade not null,
  frequency text not null,            -- 'daily' | 'weekly' | 'monthly'
  amount numeric(12,2) not null,
  asset_mix jsonb,
  status text default 'active',       -- active | paused
  next_run_at timestamptz,
  created_at timestamptz default now()
);
alter table public.schedules enable row level security;
create policy "schedules: own rows" on public.schedules for all using (auth.uid() = user_id);

-- ---------- WITHDRAWALS ----------
create table public.withdrawals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade not null,
  amount numeric(12,2) not null,
  destination text,                   -- bank/crypto description (no raw account numbers)
  status text default 'pending',      -- pending | approved | processed | rejected
  note text,
  requested_at timestamptz default now(),
  resolved_at timestamptz
);
alter table public.withdrawals enable row level security;
create policy "withdrawals: own rows" on public.withdrawals for all using (auth.uid() = user_id);

-- ---------- RETIREMENT GOAL ----------
create table public.retirement_goals (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  monthly_contribution numeric(12,2) not null default 0,
  target_age int,
  current_age int,
  status text default 'active',       -- active | paused
  created_at timestamptz default now()
);
alter table public.retirement_goals enable row level security;
create policy "retirement_goals: own row" on public.retirement_goals for all using (auth.uid() = user_id);

create table public.retirement_contributions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade not null,
  amount numeric(12,2) not null,
  status text default 'pending',
  created_at timestamptz default now()
);
alter table public.retirement_contributions enable row level security;
create policy "retirement_contributions: own rows" on public.retirement_contributions for all using (auth.uid() = user_id);

-- ---------- KYC DOCUMENTS ----------
-- Store files in Supabase Storage (a private bucket); this table just tracks status/refs.
create table public.kyc_documents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade not null,
  doc_type text not null,             -- 'id' | 'proof_of_address' | 'selfie'
  storage_path text not null,
  status text default 'pending',      -- pending | approved | rejected
  reviewed_at timestamptz,
  created_at timestamptz default now()
);
alter table public.kyc_documents enable row level security;
create policy "kyc_documents: own rows" on public.kyc_documents for all using (auth.uid() = user_id);

-- ---------- FOUND MONEY (partner bonuses) ----------
create table public.found_money (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade not null,
  partner text not null,
  purchase_amount numeric(12,2),
  bonus_amount numeric(12,2) not null,
  status text default 'pending',      -- pending | credited
  created_at timestamptz default now()
);
alter table public.found_money enable row level security;
create policy "found_money: own rows" on public.found_money for all using (auth.uid() = user_id);

-- ============================================================
-- Notes:
-- 1. Admin access (the /admin panel in index.html) needs a service-role key
--    used only from a trusted server context (a Vercel API route with the
--    key in an env var) — never expose the service-role key client-side.
--    Simplest approach: add an `is_admin boolean default false` column to
--    profiles, then check it server-side before returning admin data.
-- 2. None of this executes automatically — actually crediting deposits,
--    sweeping round-ups, or approving withdrawals requires real webhook
--    handlers (Stripe/Flutterwave/Paystack, your card-linking provider,
--    and your broker/custodian) calling into these tables via a
--    service-role key from server-side code, not from the browser.
-- ============================================================

-- LAKDEALZ production marketplace expansion.
-- Run after schema.sql and migration-v2.sql in Supabase SQL Editor.

alter table public.profiles add column if not exists district text not null default '';
alter table public.profiles add column if not exists avatar_url text;
alter table public.profiles add column if not exists bio text not null default '';
alter table public.profiles add column if not exists verified boolean not null default false;
alter table public.profiles add column if not exists suspended_until timestamptz;

alter table public.ads add column if not exists slug text;
alter table public.ads add column if not exists expires_at timestamptz not null default (now()+interval '30 days');
alter table public.ads add column if not exists rejection_reason text;
alter table public.ads add column if not exists specifications jsonb not null default '{}'::jsonb;
create unique index if not exists ads_slug_idx on public.ads(slug) where slug is not null;
create index if not exists ads_search_idx on public.ads using gin(to_tsvector('simple',coalesce(title,'')||' '||coalesce(description,'')));

create table if not exists public.favourites(
  user_id uuid references auth.users(id) on delete cascade,
  ad_id uuid references public.ads(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(user_id,ad_id)
);
create table if not exists public.seller_follows(
  follower_id uuid references auth.users(id) on delete cascade,
  seller_id uuid references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(follower_id,seller_id), check(follower_id<>seller_id)
);
create table if not exists public.saved_searches(
  id uuid primary key default gen_random_uuid(), user_id uuid references auth.users(id) on delete cascade,
  name text not null, filters jsonb not null default '{}'::jsonb, alerts boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists public.price_alerts(
  user_id uuid references auth.users(id) on delete cascade, ad_id uuid references public.ads(id) on delete cascade,
  target_price numeric(14,2), created_at timestamptz not null default now(), primary key(user_id,ad_id)
);
create table if not exists public.seller_reviews(
  id uuid primary key default gen_random_uuid(), seller_id uuid references auth.users(id) on delete cascade,
  reviewer_id uuid references auth.users(id) on delete cascade, rating smallint not null check(rating between 1 and 5),
  comment text not null default '', status text not null default 'pending', created_at timestamptz not null default now(),
  unique(seller_id,reviewer_id)
);
create table if not exists public.questions(
  id uuid primary key default gen_random_uuid(), ad_id uuid references public.ads(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade, question text not null, answer text,
  created_at timestamptz not null default now(), answered_at timestamptz
);
create table if not exists public.notifications(
  id uuid primary key default gen_random_uuid(), user_id uuid references auth.users(id) on delete cascade,
  kind text not null default 'info', title text not null, body text not null default '', link text,
  read_at timestamptz, created_at timestamptz not null default now()
);
create table if not exists public.user_blocks(
  blocker_id uuid references auth.users(id) on delete cascade, blocked_id uuid references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(), primary key(blocker_id,blocked_id), check(blocker_id<>blocked_id)
);
create table if not exists public.audit_log(
  id bigint generated always as identity primary key, actor_id uuid references auth.users(id) on delete set null,
  action text not null, entity_type text not null, entity_id text, metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.favourites enable row level security;
alter table public.seller_follows enable row level security;
alter table public.saved_searches enable row level security;
alter table public.price_alerts enable row level security;
alter table public.seller_reviews enable row level security;
alter table public.questions enable row level security;
alter table public.notifications enable row level security;
alter table public.user_blocks enable row level security;
alter table public.audit_log enable row level security;

create policy "Own favourites" on public.favourites for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "Own follows" on public.seller_follows for all to authenticated using(follower_id=auth.uid()) with check(follower_id=auth.uid());
create policy "Own saved searches" on public.saved_searches for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "Own price alerts" on public.price_alerts for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "Public approved reviews" on public.seller_reviews for select using(status='approved' or reviewer_id=auth.uid());
create policy "Create own reviews" on public.seller_reviews for insert to authenticated with check(reviewer_id=auth.uid());
create policy "Question participants" on public.questions for select to authenticated using(user_id=auth.uid() or exists(select 1 from public.ads a where a.id=ad_id and a.user_id=auth.uid()));
create policy "Create own questions" on public.questions for insert to authenticated with check(user_id=auth.uid());
create policy "Own notifications" on public.notifications for select to authenticated using(user_id=auth.uid());
create policy "Update own notifications" on public.notifications for update to authenticated using(user_id=auth.uid());
create policy "Own blocks" on public.user_blocks for all to authenticated using(blocker_id=auth.uid()) with check(blocker_id=auth.uid());
create policy "Admins read audit" on public.audit_log for select to authenticated using(exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='admin'));

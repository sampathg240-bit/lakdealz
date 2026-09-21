-- Run once in Supabase Dashboard > SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default '',
  phone text not null default '',
  role text not null default 'user' check (role in ('user','admin')),
  created_at timestamptz not null default now()
);

create table if not exists public.ads (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 3 and 80),
  category text not null,
  price numeric(14,2) not null check (price >= 0),
  district text not null,
  phone text not null,
  condition text not null,
  price_type text not null default 'Negotiable',
  delivery boolean not null default false,
  description text not null default '',
  images text[] not null default '{}',
  status text not null default 'pending' check (status in ('pending','approved','rejected','paused','sold')),
  verified boolean not null default false,
  featured boolean not null default false,
  views integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  ad_id uuid references public.ads(id) on delete set null,
  reporter_id uuid references auth.users(id) on delete set null,
  reason text not null,
  details text not null,
  contact text,
  status text not null default 'pending' check (status in ('pending','reviewing','resolved','dismissed')),
  created_at timestamptz not null default now()
);

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.profiles(id,name,phone,role)
  values(new.id,coalesce(new.raw_user_meta_data->>'name',''),coalesce(new.raw_user_meta_data->>'phone',''),case when lower(new.email)='sampathg240@gmail.com' then 'admin' else 'user' end)
  on conflict(id) do nothing;
  return new;
end;$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.ads enable row level security;
alter table public.reports enable row level security;

create policy "Users read own profile" on public.profiles for select to authenticated using (auth.uid()=id);
create policy "Users update own profile" on public.profiles for update using (auth.uid()=id) with check (auth.uid()=id and role=(select role from public.profiles p where p.id=auth.uid()));
create policy "Approved ads are public" on public.ads for select using (status='approved' or user_id=auth.uid() or exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='admin'));
create policy "Users create pending ads" on public.ads for insert to authenticated with check (user_id=auth.uid() and status='pending' and verified=false and featured=false);
create policy "Users update own ads" on public.ads for update to authenticated using (user_id=auth.uid() or exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='admin'));
create policy "Users delete own ads" on public.ads for delete to authenticated using (user_id=auth.uid() or exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='admin'));
create policy "Authenticated reports" on public.reports for insert to authenticated with check (reporter_id=auth.uid());
create policy "Users view own reports" on public.reports for select to authenticated using (reporter_id=auth.uid() or exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='admin'));
create policy "Admins manage reports" on public.reports for update to authenticated using (exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='admin'));

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('ad-photos','ad-photos',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=true,file_size_limit=5242880,allowed_mime_types=array['image/jpeg','image/png','image/webp'];

create policy "Public ad photos" on storage.objects for select using (bucket_id='ad-photos');
create policy "Users upload own ad photos" on storage.objects for insert to authenticated with check (bucket_id='ad-photos' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "Users delete own ad photos" on storage.objects for delete to authenticated using (bucket_id='ad-photos' and (storage.foldername(name))[1]=auth.uid()::text);

create index if not exists ads_status_created_idx on public.ads(status,created_at desc);
create index if not exists ads_category_district_idx on public.ads(category,district);
create index if not exists reports_status_idx on public.reports(status,created_at desc);

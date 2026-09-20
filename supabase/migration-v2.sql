-- Run once after schema.sql to enable mandatory admin moderation.
alter table public.ads alter column status set default 'pending';
drop policy if exists "Users create own ads" on public.ads;
drop policy if exists "Users create pending ads" on public.ads;
create policy "Users create pending ads" on public.ads for insert to authenticated
with check (user_id=auth.uid() and status='pending' and verified=false and featured=false);

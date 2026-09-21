-- Final production security lock for LAKDEALZ.
-- Prevents authenticated sellers from bypassing moderation through direct API calls.

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.profiles where id=auth.uid() and role='admin');
$$;

create or replace function public.protect_ad_moderation() returns trigger
language plpgsql security definer set search_path=public as $$
begin
  if not public.is_admin() and (
    new.user_id is distinct from old.user_id or
    new.status is distinct from old.status or
    new.verified is distinct from old.verified or
    new.featured is distinct from old.featured
  ) then
    raise exception 'Only an administrator can change moderation fields';
  end if;
  return new;
end;$$;

drop trigger if exists protect_ad_moderation_fields on public.ads;
create trigger protect_ad_moderation_fields before update on public.ads
for each row execute function public.protect_ad_moderation();

create or replace function public.protect_profile_role() returns trigger
language plpgsql security definer set search_path=public as $$
begin
  if new.role is distinct from old.role and not public.is_admin() then
    raise exception 'Only an administrator can change account roles';
  end if;
  return new;
end;$$;

drop trigger if exists protect_profile_role_changes on public.profiles;
create trigger protect_profile_role_changes before update on public.profiles
for each row execute function public.protect_profile_role();

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

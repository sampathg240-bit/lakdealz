-- Repair/admin-bootstrap for accounts created before the profile trigger existed.
-- Authorized administrator: sampathonline2k@gmail.com
insert into public.profiles(id,name,phone,role)
select id,coalesce(raw_user_meta_data->>'name','LAKDEALZ Admin'),coalesce(raw_user_meta_data->>'phone',''),'admin'
from auth.users where lower(email)='sampathonline2k@gmail.com'
on conflict(id) do update set role='admin';

-- Keep future signups deterministic without storing any password in source code.
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.profiles(id,name,phone,role)
  values(new.id,coalesce(new.raw_user_meta_data->>'name',''),coalesce(new.raw_user_meta_data->>'phone',''),case when lower(new.email)='sampathonline2k@gmail.com' then 'admin' else 'user' end)
  on conflict(id) do update set name=excluded.name,phone=excluded.phone,role=case when lower(new.email)='sampathonline2k@gmail.com' then 'admin' else public.profiles.role end;
  return new;
end;$$;

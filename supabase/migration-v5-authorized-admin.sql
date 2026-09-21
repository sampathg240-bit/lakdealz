-- Assign the existing LAKDEALZ owner account as administrator.
insert into public.profiles(id,name,phone,role)
select id,coalesce(raw_user_meta_data->>'name','LAKDEALZ Admin'),coalesce(raw_user_meta_data->>'phone',''),'admin'
from auth.users where lower(email)='sampathg240@gmail.com'
on conflict(id) do update set role='admin';

-- Keep future signups deterministic without storing a password in source code.
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.profiles(id,name,phone,role)
  values(new.id,coalesce(new.raw_user_meta_data->>'name',''),coalesce(new.raw_user_meta_data->>'phone',''),case when lower(new.email)='sampathg240@gmail.com' then 'admin' else 'user' end)
  on conflict(id) do update set name=excluded.name,phone=excluded.phone,role=case when lower(new.email)='sampathg240@gmail.com' then 'admin' else public.profiles.role end;
  return new;
end;$$;

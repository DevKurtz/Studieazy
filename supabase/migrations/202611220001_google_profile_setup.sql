alter table public.app_users
  add column if not exists profile_complete boolean not null default true;

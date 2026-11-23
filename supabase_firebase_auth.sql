-- Run after adding Firebase as a Third-Party Auth provider in Supabase.
-- This restricts accepted Firebase tokens to this project's issuer/audience.

grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on public.app_users to anon, authenticated;
grant select, insert, update, delete on public.quizzes to anon, authenticated;
grant select, insert, update, delete on public.questions to anon, authenticated;
grant select, insert, delete on public.support_tickets to anon, authenticated;
grant select, insert, delete on public.error_logs to anon, authenticated;

drop policy if exists app_users_delete_own on public.app_users;
create policy app_users_delete_own on public.app_users
  for delete to anon, authenticated using (id = auth.uid()::text);
drop policy if exists tickets_delete_own on public.support_tickets;
create policy tickets_delete_own on public.support_tickets
  for delete to anon, authenticated using (user_id = auth.uid()::text);
drop policy if exists errors_delete_own on public.error_logs;
create policy errors_delete_own on public.error_logs
  for delete to anon, authenticated using (user_id = auth.uid()::text);

create or replace function public.prevent_client_role_change()
returns trigger
language plpgsql
as $$
begin
  if current_user in ('postgres', 'supabase_admin', 'service_role') then
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.role := 'user';
  elsif new.role is distinct from old.role then
    raise exception 'Only trusted administrators may change user roles';
  end if;
  return new;
end;
$$;

drop trigger if exists prevent_client_role_change on public.app_users;
create trigger prevent_client_role_change
before insert or update on public.app_users
for each row execute function public.prevent_client_role_change();

drop policy if exists app_users_firebase_project_guard on public.app_users;
create policy app_users_firebase_project_guard on public.app_users
  as restrictive for all to anon, authenticated
  using (
    auth.jwt()->>'iss' = 'https://securetoken.google.com/self-study-app-66c44'
    and auth.jwt()->>'aud' = 'self-study-app-66c44'
  )
  with check (
    auth.jwt()->>'iss' = 'https://securetoken.google.com/self-study-app-66c44'
    and auth.jwt()->>'aud' = 'self-study-app-66c44'
  );

drop policy if exists quizzes_firebase_project_guard on public.quizzes;
create policy quizzes_firebase_project_guard on public.quizzes
  as restrictive for all to anon, authenticated
  using (
    auth.jwt()->>'iss' = 'https://securetoken.google.com/self-study-app-66c44'
    and auth.jwt()->>'aud' = 'self-study-app-66c44'
  )
  with check (
    auth.jwt()->>'iss' = 'https://securetoken.google.com/self-study-app-66c44'
    and auth.jwt()->>'aud' = 'self-study-app-66c44'
  );

drop policy if exists questions_firebase_project_guard on public.questions;
create policy questions_firebase_project_guard on public.questions
  as restrictive for all to anon, authenticated
  using (
    auth.jwt()->>'iss' = 'https://securetoken.google.com/self-study-app-66c44'
    and auth.jwt()->>'aud' = 'self-study-app-66c44'
  )
  with check (
    auth.jwt()->>'iss' = 'https://securetoken.google.com/self-study-app-66c44'
    and auth.jwt()->>'aud' = 'self-study-app-66c44'
  );

drop policy if exists support_tickets_firebase_project_guard on public.support_tickets;
create policy support_tickets_firebase_project_guard on public.support_tickets
  as restrictive for all to anon, authenticated
  using (
    auth.jwt()->>'iss' = 'https://securetoken.google.com/self-study-app-66c44'
    and auth.jwt()->>'aud' = 'self-study-app-66c44'
  )
  with check (
    auth.jwt()->>'iss' = 'https://securetoken.google.com/self-study-app-66c44'
    and auth.jwt()->>'aud' = 'self-study-app-66c44'
  );

drop policy if exists error_logs_firebase_project_guard on public.error_logs;
create policy error_logs_firebase_project_guard on public.error_logs
  as restrictive for all to anon, authenticated
  using (
    auth.jwt()->>'iss' = 'https://securetoken.google.com/self-study-app-66c44'
    and auth.jwt()->>'aud' = 'self-study-app-66c44'
  )
  with check (
    auth.jwt()->>'iss' = 'https://securetoken.google.com/self-study-app-66c44'
    and auth.jwt()->>'aud' = 'self-study-app-66c44'
  );

-- OTP and system_config stay inaccessible from client roles.

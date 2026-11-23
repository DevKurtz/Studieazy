-- Supabase setup for Studieazy. Safe to run after the earlier generic schema.
-- Preserves existing rows and locks sensitive tables behind RLS.

create extension if not exists pgcrypto with schema extensions;

-- Existing profiles are already complete; Google sign-ups opt into setup first.
alter table public.app_users
  add column if not exists profile_complete boolean not null default true;

-- The previous draft used text IDs. Keep them for compatibility while
-- enforcing that authenticated users can only access rows with their own ID.
alter table public.app_users enable row level security;
alter table public.quizzes enable row level security;
alter table public.questions enable row level security;
alter table public.support_tickets enable row level security;
alter table public.error_logs enable row level security;
alter table public.otp_codes enable row level security;
alter table public.system_config enable row level security;

-- Drop only policies with these names so this file can be safely re-run.
drop policy if exists app_users_select_own on public.app_users;
drop policy if exists app_users_insert_own on public.app_users;
drop policy if exists app_users_update_own on public.app_users;
drop policy if exists app_users_delete_own on public.app_users;
drop policy if exists quizzes_select_own on public.quizzes;
drop policy if exists quizzes_insert_own on public.quizzes;
drop policy if exists quizzes_update_own on public.quizzes;
drop policy if exists quizzes_delete_own on public.quizzes;
drop policy if exists questions_select_own on public.questions;
drop policy if exists questions_insert_own on public.questions;
drop policy if exists questions_update_own on public.questions;
drop policy if exists questions_delete_own on public.questions;
drop policy if exists tickets_select_own on public.support_tickets;
drop policy if exists tickets_insert_own on public.support_tickets;
drop policy if exists tickets_delete_own on public.support_tickets;
drop policy if exists errors_insert_own on public.error_logs;
drop policy if exists errors_delete_own on public.error_logs;

create policy app_users_select_own on public.app_users
  for select to anon, authenticated using (id = auth.uid()::text);
create policy app_users_insert_own on public.app_users
  for insert to anon, authenticated with check (id = auth.uid()::text);
create policy app_users_update_own on public.app_users
  for update to anon, authenticated using (id = auth.uid()::text)
  with check (id = auth.uid()::text);
create policy app_users_delete_own on public.app_users
  for delete to anon, authenticated using (id = auth.uid()::text);

create policy quizzes_select_own on public.quizzes
  for select to anon, authenticated using (user_id = auth.uid()::text);
create policy quizzes_insert_own on public.quizzes
  for insert to anon, authenticated with check (user_id = auth.uid()::text);
create policy quizzes_update_own on public.quizzes
  for update to anon, authenticated using (user_id = auth.uid()::text)
  with check (user_id = auth.uid()::text);
create policy quizzes_delete_own on public.quizzes
  for delete to anon, authenticated using (user_id = auth.uid()::text);

create policy questions_select_own on public.questions
  for select to anon, authenticated using (
    exists (select 1 from public.quizzes q where q.id = quiz_id and q.user_id = auth.uid()::text)
  );
create policy questions_insert_own on public.questions
  for insert to anon, authenticated with check (
    exists (select 1 from public.quizzes q where q.id = quiz_id and q.user_id = auth.uid()::text)
  );
create policy questions_update_own on public.questions
  for update to anon, authenticated using (
    exists (select 1 from public.quizzes q where q.id = quiz_id and q.user_id = auth.uid()::text)
  ) with check (
    exists (select 1 from public.quizzes q where q.id = quiz_id and q.user_id = auth.uid()::text)
  );
create policy questions_delete_own on public.questions
  for delete to anon, authenticated using (
    exists (select 1 from public.quizzes q where q.id = quiz_id and q.user_id = auth.uid()::text)
  );

create policy tickets_select_own on public.support_tickets
  for select to anon, authenticated using (user_id = auth.uid()::text);
create policy tickets_insert_own on public.support_tickets
  for insert to anon, authenticated with check (user_id = auth.uid()::text);
create policy tickets_delete_own on public.support_tickets
  for delete to anon, authenticated using (user_id = auth.uid()::text);
create policy errors_insert_own on public.error_logs
  for insert to anon, authenticated with check (user_id is null or user_id = auth.uid()::text);
create policy errors_delete_own on public.error_logs
  for delete to anon, authenticated using (user_id = auth.uid()::text);

-- No client policies are granted for OTP codes, system config, support-ticket
-- administration, or error-log reads/updates. Those require trusted backend access.
-- Note: enable Supabase Auth and make Supabase Auth UUIDs the app user IDs before
-- migrating Firebase-owned accounts. Do not expose a service-role key in Flutter.

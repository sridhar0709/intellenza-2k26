create extension if not exists pgcrypto;
create table if not exists public.registrations (
 id uuid primary key default gen_random_uuid(),
 full_name text not null check(char_length(trim(full_name)) between 2 and 120),
 email text not null check(char_length(email)<=254),
 phone text not null check(char_length(phone) between 10 and 20),
 college text not null check(char_length(trim(college)) between 2 and 180),
 department text not null check(char_length(trim(department)) between 2 and 120),
 year_of_study text check(year_of_study is null or year_of_study in ('1st Year','2nd Year','3rd Year','4th Year','Other')),
 event_name text not null check(event_name in ('SLIDEVERSE · Paper Presentation','CODEBREACH · Debugging','PROMPTIX · Prompt Creation','HUNTOPIA 2.0 · Treasure Hunt','BOOYAH ARENA · Free Fire','MEMORIA · Memory Challenge')),
 package text not null check(package in ('Symposium - ₹250','Workshop - ₹200','Both days - ₹400')),
 amount_inr integer generated always as (case package when 'Symposium - ₹250' then 250 when 'Workshop - ₹200' then 200 when 'Both days - ₹400' then 400 end) stored,
 utr text not null check(char_length(trim(utr)) between 6 and 100),
 payment_status text not null default 'pending' check(payment_status in ('pending','verified','rejected')),
 reviewed_by uuid references auth.users(id) on delete set null,
 reviewed_at timestamptz,
 created_at timestamptz not null default now()
);
create unique index if not exists registrations_utr_unique on public.registrations(upper(trim(utr)));
create index if not exists registrations_created_at_idx on public.registrations(created_at desc);
create index if not exists registrations_payment_status_idx on public.registrations(payment_status);
create index if not exists registrations_event_name_idx on public.registrations(event_name);
create table if not exists public.admin_users(user_id uuid primary key references auth.users(id) on delete cascade,created_at timestamptz not null default now(),created_by uuid references auth.users(id) on delete set null);
alter table public.registrations enable row level security;
alter table public.admin_users enable row level security;
create or replace function public.is_intellenza_admin() returns boolean language sql stable security definer set search_path='' as $$ select exists(select 1 from public.admin_users a where a.user_id=(select auth.uid())); $$;
revoke all on function public.is_intellenza_admin() from public;
grant execute on function public.is_intellenza_admin() to anon,authenticated;
revoke all on public.registrations from anon,authenticated;
grant insert on public.registrations to anon,authenticated;
grant select,update on public.registrations to authenticated;
revoke all on public.admin_users from anon,authenticated;
grant select on public.admin_users to authenticated;
drop policy if exists "Public can submit registrations as pending" on public.registrations;
create policy "Public can submit registrations as pending" on public.registrations for insert to anon,authenticated with check(payment_status='pending' and reviewed_by is null and reviewed_at is null);
drop policy if exists "Admins can read all registrations" on public.registrations;
create policy "Admins can read all registrations" on public.registrations for select to authenticated using((select public.is_intellenza_admin()));
drop policy if exists "Admins can update payment review" on public.registrations;
create policy "Admins can update payment review" on public.registrations for update to authenticated using((select public.is_intellenza_admin())) with check((select public.is_intellenza_admin()));
drop policy if exists "Admins can read own admin grant" on public.admin_users;
create policy "Admins can read own admin grant" on public.admin_users for select to authenticated using(user_id=(select auth.uid()));
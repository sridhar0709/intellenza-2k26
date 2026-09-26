-- INTELLENZA 2K26 manual UPI verification
-- Apply to the INTELLENZA Supabase project only after reviewing the feature preview.
begin;

alter table public.registrations
  add column if not exists payment_screenshot_path text,
  add column if not exists payment_verified_utr text,
  add column if not exists rejection_reason text;

create table if not exists public.payment_review_audit (
  id uuid primary key default gen_random_uuid(),
  registration_id uuid not null references public.registrations(id) on delete cascade,
  action text not null check (action in ('verified','rejected','reset_to_pending')),
  old_status text not null,
  new_status text not null,
  utr text,
  reviewer_id uuid not null references auth.users(id),
  note text,
  created_at timestamptz not null default now()
);

alter table public.payment_review_audit enable row level security;
revoke all on public.payment_review_audit from anon, authenticated;
grant select on public.payment_review_audit to authenticated;
drop policy if exists "Admins read payment audit" on public.payment_review_audit;
create policy "Admins read payment audit" on public.payment_review_audit
  for select to authenticated using ((select public.is_intellenza_admin()));

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('intellenza-payment-proofs','intellenza-payment-proofs',false,5242880,
  array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict (id) do update set public=false,file_size_limit=5242880,
  allowed_mime_types=array['image/jpeg','image/png','image/webp','application/pdf'];

-- Private proof files are readable only by authorized admins.
drop policy if exists "Admins read payment proofs" on storage.objects;
create policy "Admins read payment proofs" on storage.objects
  for select to authenticated
  using (bucket_id='intellenza-payment-proofs' and (select public.is_intellenza_admin()));

-- No client-side INSERT/UPDATE/DELETE policies are created for this bucket.
-- A server-side Edge Function must validate the registration and file, then upload
-- using the service-role key stored only as a Supabase Function secret.

create or replace function public.review_intellenza_payment(
  p_registration_id uuid,
  p_decision text,
  p_note text default null
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.registrations%rowtype;
  v_uid uuid := auth.uid();
begin
  if v_uid is null or not exists (
    select 1 from public.admin_users a where a.user_id=v_uid
  ) then
    raise exception 'Administrator access required' using errcode='42501';
  end if;

  if p_decision is null or p_decision not in ('verified','rejected','pending') then
    raise exception 'Invalid payment decision' using errcode='22023';
  end if;

  select * into v_row from public.registrations
    where id=p_registration_id for update;
  if not found then
    raise exception 'Registration not found' using errcode='P0002';
  end if;

  if p_decision='verified' and (v_row.utr is null or length(trim(v_row.utr)) < 6) then
    raise exception 'A payment UTR is required before verification' using errcode='22023';
  end if;

  update public.registrations
    set payment_status=p_decision,
        reviewed_by=case when p_decision='pending' then null else v_uid end,
        reviewed_at=case when p_decision='pending' then null else now() end,
        payment_verified_utr=case when p_decision='verified' then upper(trim(v_row.utr)) else null end,
        rejection_reason=case when p_decision='rejected' then nullif(trim(coalesce(p_note,'')),'') else null end
    where id=p_registration_id;

  insert into public.payment_review_audit
    (registration_id,action,old_status,new_status,utr,reviewer_id,note)
  values (
    p_registration_id,
    case when p_decision='pending' then 'reset_to_pending' else p_decision end,
    v_row.payment_status,p_decision,v_row.utr,v_uid,nullif(trim(coalesce(p_note,'')),'')
  );
end;
$$;

revoke all on function public.review_intellenza_payment(uuid,text,text) from public, anon;
grant execute on function public.review_intellenza_payment(uuid,text,text) to authenticated;

commit;

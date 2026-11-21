-- RECLAIM recovery cases v1. Apply after 20261115_001_foundation.sql.
-- Requires a signed-in user who belongs to the organisation.
create table if not exists public.recovery_cases (
 id uuid primary key default gen_random_uuid(),
 organisation_id uuid not null references public.organisations(id) on delete cascade,
 created_by uuid not null default auth.uid() references auth.users(id),
 assigned_to uuid references auth.users(id),
 category text not null check (category in ('stock','courier','task','finance')),
 issue_type text not null check (length(issue_type) between 2 and 100),
 title text not null check (length(trim(title)) between 1 and 160),
 description text not null default '',
 department text,
 supplier text,
 reference_number text,
 expected_items text,
 received_items text,
 priority text not null default 'medium' check (priority in ('low','medium','high')),
 status text not null default 'open' check (status in ('open','assigned','investigating','waiting_supplier','resolved','closed')),
 estimated_loss numeric(14,2) not null default 0 check (estimated_loss >= 0),
 confirmed_recovered numeric(14,2) not null default 0 check (confirmed_recovered >= 0 and confirmed_recovered <= estimated_loss),
 due_date date,
 resolved_at timestamptz,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index if not exists recovery_cases_org_status_idx on public.recovery_cases(organisation_id,status);
create index if not exists recovery_cases_org_due_idx on public.recovery_cases(organisation_id,due_date);
create table if not exists public.recovery_case_events (
 id uuid primary key default gen_random_uuid(),
 organisation_id uuid not null references public.organisations(id) on delete cascade,
 case_id uuid not null references public.recovery_cases(id) on delete cascade,
 actor_id uuid not null default auth.uid() references auth.users(id),
 event_type text not null check(event_type in ('created','status_changed','assigned','note','recovery_confirmed')),
 note text not null default '',
 amount numeric(14,2) check(amount is null or amount >= 0),
 created_at timestamptz not null default now()
);
create unique index if not exists recovery_cases_org_id_idx on public.recovery_cases(organisation_id,id);
alter table public.recovery_case_events
 add constraint recovery_case_events_org_case_fk
 foreign key (organisation_id,case_id) references public.recovery_cases(organisation_id,id);
alter table public.recovery_cases enable row level security;
alter table public.recovery_case_events enable row level security;
create policy "members read recovery cases" on public.recovery_cases
 for select to authenticated using (public.is_org_member(organisation_id));
create policy "members create recovery cases" on public.recovery_cases
 for insert to authenticated with check (
 public.is_org_member(organisation_id) and created_by=(select auth.uid())
 and confirmed_recovered=0 and status='open'
 and (assigned_to is null or exists (
  select 1 from public.memberships m where m.organisation_id=recovery_cases.organisation_id and m.user_id=recovery_cases.assigned_to
 ))
);
-- Updates are manager-only until a server-side audited workflow is added.
-- Prevent direct browser updates to recovered amounts or other sensitive columns.
-- No UPDATE policy is intentionally granted.
create policy "members read recovery history" on public.recovery_case_events
 for select to authenticated using (public.is_org_member(organisation_id));
-- No direct INSERT/UPDATE/DELETE policy for events: trusted server functions must append.
comment on table public.recovery_cases is 'Organisation-scoped financial recovery cases; updates intentionally disabled pending audited RPC.';
comment on table public.recovery_case_events is 'Read-only audit history; append via trusted server-side workflow only.';

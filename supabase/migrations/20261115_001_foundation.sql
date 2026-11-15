-- RECLAIM foundation schema v1. Run in Supabase SQL Editor after reviewing.
-- All business data is scoped to an organisation. RLS denies access unless a membership exists.
create extension if not exists pgcrypto;
create table if not exists public.organisations (
 id uuid primary key default gen_random_uuid(),
 name text not null check (length(trim(name)) between 2 and 120),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now()
);
create table if not exists public.memberships (
 organisation_id uuid not null references public.organisations(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 role text not null check (role in ('owner','admin','manager','member')),
 created_at timestamptz not null default now(),
 primary key(organisation_id,user_id)
);
create or replace function public.is_org_member(p_org uuid)
returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.memberships m where m.organisation_id=p_org and m.user_id=(select auth.uid()))
$$;
create or replace function public.is_org_manager(p_org uuid)
returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.memberships m where m.organisation_id=p_org and m.user_id=(select auth.uid()) and m.role in ('owner','admin','manager'))
$$;
create or replace function public.create_organisation(p_name text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
 if auth.uid() is null then raise exception 'Login required'; end if;
 if p_name is null or length(trim(p_name)) not between 2 and 120 then raise exception 'Invalid organisation name'; end if;
 insert into public.organisations(name,created_by) values(trim(p_name),auth.uid()) returning id into v_id;
 insert into public.memberships(organisation_id,user_id,role) values(v_id,auth.uid(),'owner');
 return v_id;
end;$$;
revoke all on function public.create_organisation(text) from public;
grant execute on function public.create_organisation(text) to authenticated;
create table if not exists public.stock_items (
 id uuid primary key default gen_random_uuid(),
 organisation_id uuid not null references public.organisations(id) on delete cascade,
 name text not null check (length(trim(name)) between 1 and 160),
 sku text not null,
 category text not null default 'Other',
 quantity integer not null default 0 check (quantity>=0),
 reorder_level integer not null default 0 check (reorder_level>=0),
 unit text not null default 'units',
 supplier text,
 location text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(organisation_id,sku)
);
create unique index if not exists stock_items_org_id_idx on public.stock_items(organisation_id,id);
create table if not exists public.stock_requests (
 id uuid primary key default gen_random_uuid(),
 organisation_id uuid not null references public.organisations(id) on delete cascade,
 stock_item_id uuid not null references public.stock_items(id) on delete cascade,
 quantity integer not null check (quantity>0),
 requested_by uuid not null default auth.uid() references auth.users(id),
 note text,
 status text not null default 'pending' check (status in ('pending','approved','rejected')),
 reviewed_by uuid references auth.users(id),
 created_at timestamptz not null default now(),
 constraint stock_request_org_fk foreign key(organisation_id,stock_item_id)
 references public.stock_items(organisation_id,id)
);
create table if not exists public.courier_issues (
 id uuid primary key default gen_random_uuid(),
 organisation_id uuid not null references public.organisations(id) on delete cascade,
 title text not null,
 issue_type text not null,
 courier text,
 tracking_number text,
 owner_user_id uuid references auth.users(id),
 priority text not null default 'medium' check(priority in ('low','medium','high')),
 status text not null default 'open' check(status in ('open','in_progress','resolved')),
 description text,
 created_by uuid not null default auth.uid() references auth.users(id),
 created_at timestamptz not null default now()
);
create table if not exists public.team_tasks (
 id uuid primary key default gen_random_uuid(),
 organisation_id uuid not null references public.organisations(id) on delete cascade,
 title text not null,
 department text,
 assignee_user_id uuid references auth.users(id),
 priority text not null default 'medium' check(priority in ('low','medium','high')),
 status text not null default 'open' check(status in ('open','in_progress','completed')),
 due_date date,
 notes text,
 created_by uuid not null default auth.uid() references auth.users(id),
 created_at timestamptz not null default now()
);
create table if not exists public.activity_events (
 id uuid primary key default gen_random_uuid(),
 organisation_id uuid not null references public.organisations(id) on delete cascade,
 actor_id uuid not null default auth.uid() references auth.users(id),
 entity_type text not null,
 entity_id uuid not null,
 action text not null,
 details jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now()
);
alter table public.organisations enable row level security;
alter table public.memberships enable row level security;
alter table public.stock_items enable row level security;
alter table public.stock_requests enable row level security;
alter table public.courier_issues enable row level security;
alter table public.team_tasks enable row level security;
alter table public.activity_events enable row level security;
create policy "org members read organisations" on public.organisations for select to authenticated using(public.is_org_member(id));
create policy "org members read memberships" on public.memberships for select to authenticated using(public.is_org_member(organisation_id));
-- No direct membership inserts/updates/deletes: use audited server-side invitation flow later.
create policy "org members read stock" on public.stock_items for select to authenticated using(public.is_org_member(organisation_id));
create policy "org managers add stock" on public.stock_items for insert to authenticated with check(public.is_org_manager(organisation_id));
create policy "org managers update stock" on public.stock_items for update to authenticated using(public.is_org_manager(organisation_id)) with check(public.is_org_manager(organisation_id));
create policy "org managers delete stock" on public.stock_items for delete to authenticated using(public.is_org_manager(organisation_id));
create policy "org members read requests" on public.stock_requests for select to authenticated using(public.is_org_member(organisation_id));
create policy "members submit own requests" on public.stock_requests for insert to authenticated with check(public.is_org_member(organisation_id) and requested_by=auth.uid() and status='pending' and reviewed_by is null);
create policy "managers review requests" on public.stock_requests for update to authenticated using(public.is_org_manager(organisation_id)) with check(public.is_org_manager(organisation_id));
create policy "members read courier issues" on public.courier_issues for select to authenticated using(public.is_org_member(organisation_id));
create policy "members create courier issues" on public.courier_issues for insert to authenticated with check(public.is_org_member(organisation_id) and created_by=auth.uid());
create policy "managers update courier issues" on public.courier_issues for update to authenticated using(public.is_org_manager(organisation_id)) with check(public.is_org_manager(organisation_id));
create policy "members read tasks" on public.team_tasks for select to authenticated using(public.is_org_member(organisation_id));
create policy "managers create tasks" on public.team_tasks for insert to authenticated with check(public.is_org_manager(organisation_id) and created_by=auth.uid());
create policy "managers update tasks" on public.team_tasks for update to authenticated using(public.is_org_manager(organisation_id)) with check(public.is_org_manager(organisation_id));
create policy "members read activity" on public.activity_events for select to authenticated using(public.is_org_member(organisation_id));
-- Activity events must be written by trusted server-side workflows, not arbitrary clients.
create index if not exists stock_items_org_idx on public.stock_items(organisation_id);
create index if not exists stock_requests_org_idx on public.stock_requests(organisation_id);
create index if not exists courier_issues_org_idx on public.courier_issues(organisation_id);
create index if not exists team_tasks_org_idx on public.team_tasks(organisation_id);

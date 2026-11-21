-- RECLAIM read-only security verification. Safe to run in Supabase SQL Editor.
-- This checks configuration, not cross-account behaviour. Do not insert real client data.
select t.tablename, t.rowsecurity as rls_enabled
from pg_tables t
where t.schemaname='public'
and t.tablename in ('organisations','memberships','recovery_cases','recovery_case_events')
order by t.tablename;

select tablename, policyname, cmd, roles, qual, with_check
from pg_policies
where schemaname='public'
and tablename in ('organisations','memberships','recovery_cases','recovery_case_events')
order by tablename,cmd,policyname;

select table_name, grantee, privilege_type
from information_schema.role_table_grants
where table_schema='public'
and table_name in ('recovery_cases','recovery_case_events')
and grantee in ('anon','authenticated')
order by table_name,grantee,privilege_type;

-- Expected: all four tables have RLS; authenticated users may SELECT recovery
-- cases/events and INSERT recovery cases; no browser UPDATE/DELETE permissions.
-- Anonymous users should have no recovery-table privileges.
-- This does NOT prove isolation. Test with two independent users/workspaces
-- before accepting confidential business data.

# RECLAIM — Supabase connection checklist

## Current status
The public website and the stock, courier and team-task pages are **interactive demos**. They use browser memory and reset on refresh. The SQL in `supabase/migrations/20261115_001_foundation.sql` is a **proposed database foundation only**; it is not installed or connected yet.

## Before enabling real customer data
1. Open the RECLAIM Supabase project dashboard and confirm it is the correct project.
2. Review the migration in GitHub, then run it **once** in Supabase SQL Editor. Use a test project first. Do not paste credentials into GitHub or a chat.
3. In Vercel → RECLAIM project → Settings → Environment Variables, add `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` (Supabase publishable/anon key). These are client-side keys; never add the Supabase service-role/secret key to a `NEXT_PUBLIC_` variable.
4. Configure Supabase Auth redirect URLs for the exact Vercel domain and localhost development URL. Enable email confirmation and sensible abuse prevention.
5. Add a Supabase client package and authentication screens, then use `create_organisation(name)` RPC to create the first organisation and its owner membership in one transaction.
6. Connect each UI module to authenticated queries scoped to the active organisation. Do not trust organisation IDs, roles or user IDs from form inputs; RLS must enforce them.
7. Build invitations and role management through a reviewed, server-side flow. **Never** let a browser user assign themselves an owner/admin role.
8. Add server-validated stock adjustments and an immutable activity log. Avoid directly changing stock quantities from an untrusted browser if traceability matters.
9. Test with two unrelated organisations and at least two roles. Confirm a user from Organisation A cannot read or change Organisation B's stock, tasks, requests or courier issues.
10. Add backups, privacy notice, retention/deletion policy, rate limits and an error-monitoring plan before real business trials.

## Demo restrictions
- No persistent data
- No actual courier integrations or notifications
- No employee identity verification or real approval enforcement
- No supplier ordering
- Do not enter patient information, personal customer data or confidential business information

## Database design
The migration defines organisations, memberships, stock items, stock requests, courier issues, team tasks and activity events. Row Level Security is enabled for all tables. Membership is required to read organisation data, and management roles are required for privileged updates.

**Important:** The migration is not proof of a complete secure production system. A security review, integration tests and operational controls are still required.

## Recovery cases migration (2026-11-21)
A second, **not yet executed**, migration is committed at `supabase/migrations/20261121_001_recovery_cases.sql`. It must be run after the foundation migration, in a test Supabase project first.

It adds `recovery_cases` and `recovery_case_events` with organisation-scoped RLS. Authenticated members can create cases and read their organisation's cases. Direct updates and audit event writes are intentionally disabled until a reviewed server-side workflow can validate status changes, record actual recoveries and append immutable events together.

**This migration is not yet installed in Supabase.** The public dashboard remains a reset-on-refresh demonstration. Do not use it for real customer, supplier or patient records. Before connecting the UI, test unauthenticated access, cross-organisation isolation, member/manager roles, invalid amounts and audit-event immutability. Add an audited recovery RPC and verify it cannot be called on another organisation's cases.

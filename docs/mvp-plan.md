# RECLAIM — MVP build plan

## Purpose
Help small businesses identify, assign, resolve and measure preventable financial losses. The first pilot is a dental practice using spreadsheets and a paper stock book.

## Pilot workflows (in scope)
1. Wrong item or quantity delivered (e.g. gloves sizes ordered versus received).
2. Missing supplier invoice for goods received.
3. Supplier statement and invoice mismatch.
4. Credit note or refund owed but not received.
5. Low stock / reorder reminder recorded manually.
6. Courier delivery issue or missing proof of delivery (general business template).

## Core case fields
- ID, company ID, department, case type, title, description
- Supplier, purchase order reference, invoice reference, delivery reference
- Expected items/quantities, received items/quantities
- Estimated loss amount (ZAR initially), confirmed recovered amount
- Priority, status, assigned owner, due date, created/updated timestamps
- Evidence attachments and audit history

## Case status flow
New -> Assigned -> Investigating -> Waiting on supplier -> Resolved / Closed (no recovery).
Reopen permitted with an audit entry. A case is counted as recovered only after confirmed credit/refund or stock correction.

## MVP screens
1. Sign in and select company.
2. Dashboard: open cases, overdue cases, value at risk, confirmed recovered value.
3. Cases list: filter by status, owner, supplier and department.
4. New case: quick capture with type-specific optional fields.
5. Case detail: owner, notes, evidence, status changes and follow-up dates.
6. Settings: departments, team members, notification preferences.

## Roles / access
- Owner/Admin: all cases, users, settings and reporting in their company.
- Manager: all company cases, assign and update cases; no billing/admin ownership.
- Staff: create cases and see cases assigned to them (and cases they created); no user management.
- Enforce company isolation and permissions on the database, not only in UI.

## Notifications
- In-app reminders first; email second; WhatsApp only after consent, delivery design and cost validation.
- Trigger on assignment, approaching due date, overdue, and supplier follow-up.
- Avoid duplicate notifications; keep delivery history and opt-out preferences.

## Pilot acceptance checks
- Staff logs wrong-size gloves received in under two minutes.
- Manager assigns the issue to an owner.
- Owner records supplier follow-up and expected credit.
- Dashboard shows amount at risk but does not count it as recovered.
- Manager records confirmed credit and case is closed.
- Users from another company cannot access the case.
- Pilot uses synthetic/sample records until privacy and security controls are tested.

## Suggested implementation order
1. Inspect existing Next.js App Router structure and confirm build/deployment.
2. Create database schema, auth and row-level security policies.
3. Implement case create/list/detail and dashboard with sample data.
4. Add roles, audit log and notifications.
5. Run dental-practice pilot with test data and iterate.

## Out of scope for first pilot
Automated supplier integrations, AI detection, direct WhatsApp actions, payment processing, advanced analytics and multi-currency reporting.

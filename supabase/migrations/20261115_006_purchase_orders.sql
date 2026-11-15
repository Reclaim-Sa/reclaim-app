-- RECLAIM purchase orders: first release, one stock item per order.
-- No stock quantity changes on order creation.
create table if not exists public.purchase_orders (
 id uuid primary key default gen_random_uuid(),
 organisation_id uuid not null references public.organisations(id) on delete cascade,
 stock_item_id uuid not null,
 supplier text not null check(length(trim(supplier)) between 1 and 160),
 order_reference text not null check(length(trim(order_reference)) between 1 and 120),
 ordered_quantity integer not null check(ordered_quantity between 1 and 1000000),
 note text check(length(note)<=500),
 status text not null default 'ordered' check(status in ('ordered','part_received','received','cancelled')),
 created_by uuid not null default auth.uid() references auth.users(id),
 created_at timestamptz not null default now(),
 foreign key(organisation_id,stock_item_id) references public.stock_items(organisation_id,id),
 unique(organisation_id,order_reference,stock_item_id)
);
create index if not exists purchase_orders_org_date_idx on public.purchase_orders(organisation_id,created_at desc);
alter table public.purchase_orders enable row level security;
create policy "members read purchase orders" on public.purchase_orders for select to authenticated using(public.is_org_member(organisation_id));
create policy "managers create purchase orders" on public.purchase_orders for insert to authenticated with check(public.is_org_manager(organisation_id) and created_by=auth.uid() and status='ordered');
-- No direct client update/delete: delivery matching and cancellation will use audited server workflows later.

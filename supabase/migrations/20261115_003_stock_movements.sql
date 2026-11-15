-- Run this migration once in Supabase SQL Editor.
-- Atomic stock receiving/issuing, with an immutable actor/time audit trail.
create table if not exists public.stock_movements (
 id uuid primary key default gen_random_uuid(),
 organisation_id uuid not null references public.organisations(id) on delete cascade,
 stock_item_id uuid not null,
 movement_type text not null check (movement_type in ('receive','issue')),
 quantity integer not null check (quantity > 0),
 quantity_before integer not null check (quantity_before >= 0),
 quantity_after integer not null check (quantity_after >= 0),
 reference text,
 note text,
 actor_id uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 constraint stock_movements_item_fk foreign key (organisation_id,stock_item_id)
 references public.stock_items(organisation_id,id) on delete restrict
);
create index if not exists stock_movements_org_date_idx on public.stock_movements(organisation_id,created_at desc);
create index if not exists stock_movements_item_idx on public.stock_movements(stock_item_id,created_at desc);
alter table public.stock_movements enable row level security;
create policy "org members read stock movements" on public.stock_movements
 for select to authenticated using (public.is_org_member(organisation_id));
-- No direct inserts, updates or deletes. The RPC below is the only write route.
create or replace function public.record_stock_movement(
 p_organisation_id uuid,p_stock_item_id uuid,p_movement_type text,
 p_quantity integer,p_reference text default null,p_note text default null)
returns public.stock_movements
language plpgsql security definer set search_path = ''
as $$
declare v_before integer;v_after integer;v_movement public.stock_movements;
begin
 if auth.uid() is null or not public.is_org_manager(p_organisation_id) then
  raise exception 'Manager access required';
 end if;
 if p_movement_type not in ('receive','issue') or p_movement_type is null then
  raise exception 'Invalid movement type';
 end if;
 if p_quantity is null or p_quantity <= 0 or p_quantity > 1000000 then
  raise exception 'Quantity must be between 1 and 1000000';
 end if;
 if length(coalesce(p_reference,'')) > 120 or length(coalesce(p_note,'')) > 500 then
  raise exception 'Reference or note is too long';
 end if;
 select quantity into v_before from public.stock_items
 where id=p_stock_item_id and organisation_id=p_organisation_id for update;
 if not found then raise exception 'Stock item not found'; end if;
 if p_movement_type='issue' and v_before < p_quantity then
  raise exception 'Insufficient stock: % available',v_before;
 end if;
 v_after := case when p_movement_type='receive' then v_before+p_quantity else v_before-p_quantity end;
 update public.stock_items set quantity=v_after,updated_at=now()
 where id=p_stock_item_id and organisation_id=p_organisation_id;
 insert into public.stock_movements(organisation_id,stock_item_id,movement_type,quantity,quantity_before,quantity_after,reference,note,actor_id)
 values(p_organisation_id,p_stock_item_id,p_movement_type,p_quantity,v_before,v_after,nullif(trim(p_reference),''),nullif(trim(p_note),''),auth.uid())
 returning * into v_movement;
 return v_movement;
end;$$;
revoke all on function public.record_stock_movement(uuid,uuid,text,integer,text,text) from public;
grant execute on function public.record_stock_movement(uuid,uuid,text,integer,text,text) to authenticated;

-- RECLAIM stock takes: counts never alter stock automatically.
create table if not exists public.stock_counts (
 id uuid primary key default gen_random_uuid(),
 organisation_id uuid not null references public.organisations(id) on delete cascade,
 stock_item_id uuid not null,
 expected_quantity integer not null check(expected_quantity>=0),
 counted_quantity integer not null check(counted_quantity>=0),
 note text,
 status text not null default 'pending' check(status in ('pending','approved','rejected')),
 counted_by uuid not null default auth.uid() references auth.users(id),
 reviewed_by uuid references auth.users(id),
 reviewed_at timestamptz,
 created_at timestamptz not null default now(),
 foreign key(organisation_id,stock_item_id) references public.stock_items(organisation_id,id)
);
create index if not exists stock_counts_org_date_idx on public.stock_counts(organisation_id,created_at desc);
alter table public.stock_counts enable row level security;
create policy "members read stock counts" on public.stock_counts for select to authenticated using(public.is_org_member(organisation_id));
create policy "members submit stock counts" on public.stock_counts for insert to authenticated with check(public.is_org_member(organisation_id) and counted_by=auth.uid() and status='pending' and reviewed_by is null and reviewed_at is null);
-- Approval is atomic and logs a movement, with a concurrency check.
create or replace function public.review_stock_count(p_count_id uuid,p_approve boolean)
returns void language plpgsql security definer set search_path='' as $$
declare c public.stock_counts%rowtype; v_before integer; v_delta integer;
begin
 select * into c from public.stock_counts where id=p_count_id for update;
 if not found then raise exception 'Stock count not found'; end if;
 if not public.is_org_manager(c.organisation_id) then raise exception 'Manager access required'; end if;
 if c.status<>'pending' then raise exception 'Already reviewed'; end if;
 if p_approve then
   select quantity into v_before from public.stock_items where id=c.stock_item_id and organisation_id=c.organisation_id for update;
   if v_before is null then raise exception 'Stock item not found'; end if;
   if v_before<>c.expected_quantity then raise exception 'Stock has changed since count. Reject and recount before approving.'; end if;
   v_delta:=c.counted_quantity-v_before;
   update public.stock_items set quantity=c.counted_quantity,updated_at=now() where id=c.stock_item_id;
   if v_delta<>0 then
     insert into public.stock_movements(organisation_id,stock_item_id,movement_type,quantity,quantity_before,quantity_after,reference,note,actor_id)
     values(c.organisation_id,c.stock_item_id,case when v_delta>0 then 'receive' else 'issue' end,abs(v_delta),v_before,c.counted_quantity,'STOCK-TAKE',coalesce(c.note,'Approved physical stock count'),auth.uid());
   end if;
 end if;
 update public.stock_counts set status=case when p_approve then 'approved' else 'rejected' end,reviewed_by=auth.uid(),reviewed_at=now() where id=c.id;
end;$$;
revoke all on function public.review_stock_count(uuid,boolean) from public;
grant execute on function public.review_stock_count(uuid,boolean) to authenticated;

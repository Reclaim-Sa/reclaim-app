-- RECLAIM: safe workspace deletion.
-- Only the sole owner may delete an EMPTY workspace.
-- Existing business records or additional members block deletion.
create or replace function public.delete_empty_organisation(p_organisation_id uuid, p_confirm_name text)
returns void
language plpgsql security definer set search_path = ''
as $$
declare v_name text;
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 select o.name into v_name from public.organisations o
 where o.id=p_organisation_id and o.created_by=auth.uid()
 for update;
 if v_name is null then raise exception 'Only the workspace creator can delete it'; end if;
 if p_confirm_name is distinct from v_name then raise exception 'Workspace name does not match'; end if;
 if not exists(select 1 from public.memberships m where m.organisation_id=p_organisation_id and m.user_id=auth.uid() and m.role='owner')
 then raise exception 'Owner permission required'; end if;
 if (select count(*) from public.memberships m where m.organisation_id=p_organisation_id)<>1
 then raise exception 'Workspace has other members. Deletion blocked'; end if;
 if exists(select 1 from public.stock_items where organisation_id=p_organisation_id)
 or exists(select 1 from public.stock_requests where organisation_id=p_organisation_id)
 or exists(select 1 from public.courier_issues where organisation_id=p_organisation_id)
 or exists(select 1 from public.team_tasks where organisation_id=p_organisation_id)
 or exists(select 1 from public.activity_events where organisation_id=p_organisation_id)
 then raise exception 'Workspace contains business records. Deletion blocked'; end if;
 delete from public.organisations where id=p_organisation_id;
end;$$;
revoke all on function public.delete_empty_organisation(uuid,text) from public;
grant execute on function public.delete_empty_organisation(uuid,text) to authenticated;

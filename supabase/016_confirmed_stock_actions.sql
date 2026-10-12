-- Additive migration: preserve all existing movements and balances.
alter table public.stock_movements add column if not exists client_details jsonb not null default '{}'::jsonb;
create table if not exists phelox_private.stock_action_receipts (
  id uuid primary key,
  actor uuid not null references public.profiles(id),
  payload jsonb not null,
  movement_id uuid not null references public.stock_movements(id)
);
alter table phelox_private.stock_action_receipts enable row level security;
revoke all on phelox_private.stock_action_receipts from public, anon, authenticated;

create or replace function phelox_private.commit_stock_action(p_id uuid,p_action jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare
  a uuid := (p_action->>'article')::uuid;
  src uuid := nullif(p_action->>'from','')::uuid;
  dst uuid := nullif(p_action->>'to','')::uuid;
  vehicle uuid := nullif(p_action->>'vehicle_id','')::uuid;
  qty numeric := (p_action->>'quantity')::numeric;
  price numeric := nullif(p_action->>'price','')::numeric;
  cur text := p_action->>'currency';
  b public.stock_balances; d public.stock_balances;
  receipt phelox_private.stock_action_receipts;
  owner_company uuid; average numeric; previous numeric; resulting numeric;
  kind text; movement uuid; actor_name text;
begin
  if auth.uid() is null or public.current_role() is null then raise exception 'Sesión inválida'; end if;
  if public.current_role() not in ('superadministrador','administrador_general','encargado_stock','encargado_frente','mecanico') then raise exception 'Sin permiso para modificar stock'; end if;
  if p_id is null or p_action is null or a is null or qty is null or qty<=0 or qty::text in ('NaN','Infinity','-Infinity') then raise exception 'Cantidad o artículo inválido'; end if;
  if (src is null and dst is null) or src=dst then raise exception 'Origen y destino inválidos'; end if;
  if (src is not null and not public.can_access_stock_location(src)) or (dst is not null and not public.can_access_stock_location(dst)) then raise exception 'Sin acceso a la ubicación'; end if;
  if not exists(select 1 from public.articles where id=a and active) then raise exception 'Artículo no disponible'; end if;
  if vehicle is not null and not exists(select 1 from public.vehicles v where v.id=vehicle and public.can_access_company(v.company_id)) then raise exception 'Vehículo no autorizado'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_id::text,2));
  select * into receipt from phelox_private.stock_action_receipts where id=p_id;
  if found then
    if receipt.actor<>auth.uid() or receipt.payload<>p_action then raise exception 'Identificador utilizado por otra operación'; end if;
    return receipt.movement_id;
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(a::text,1));
  if src is not null then
    select * into b from public.stock_balances where article_id=a and location_id=src for update;
    if not found or b.quantity<qty then raise exception 'Stock insuficiente'; end if;
    if nullif(p_action->>'expected_version','')::bigint is distinct from b.version then raise exception 'El stock cambió desde otro dispositivo. Actualizá antes de confirmar.'; end if;
    average:=b.average_cost; cur:=b.currency; previous:=b.quantity; resulting:=previous-qty;
    update public.stock_balances set quantity=resulting,version=version+1,updated_by=auth.uid(),updated_at=now() where article_id=a and location_id=src;
  end if;
  if dst is not null then
    select company_id into owner_company from public.locations where id=dst and active;
    if owner_company is null then raise exception 'Destino desactivado'; end if;
    select * into d from public.stock_balances where article_id=a and location_id=dst for update;
    if src is null then
      if price is null or price<=0 or price::text in ('NaN','Infinity','-Infinity') or cur not in ('UYU','USD') or cur is null then raise exception 'Precio o moneda inválido'; end if;
      previous:=coalesce(d.quantity,0); resulting:=previous+qty;
      if previous>0 and d.currency<>cur then raise exception 'No se pueden promediar monedas diferentes'; end if;
      average:=(previous*coalesce(d.average_cost,0)+qty*price)/resulting;
    else
      if coalesce(d.quantity,0)>0 and d.currency<>cur then raise exception 'No se pueden mezclar monedas en el destino'; end if;
      average:=(coalesce(d.quantity,0)*coalesce(d.average_cost,0)+qty*average)/(coalesce(d.quantity,0)+qty);
    end if;
    insert into public.stock_balances(article_id,company_id,location_id,quantity,average_cost,currency,version,updated_by)
    values(a,owner_company,dst,qty,average,cur,1,auth.uid())
    on conflict(article_id,location_id) do update set quantity=public.stock_balances.quantity+excluded.quantity,
      average_cost=excluded.average_cost,currency=excluded.currency,version=public.stock_balances.version+1,updated_by=auth.uid(),updated_at=now();
  else
    owner_company:=b.company_id;
  end if;
  kind:=case when src is null then 'ingreso' when dst is null then 'consumo' else 'transferencia' end;
  select full_name into actor_name from public.profiles where id=auth.uid();
  insert into public.stock_movements(article_id,company_id,from_location_id,to_location_id,vehicle_id,movement_type,quantity,unit_cost,currency,previous_quantity,resulting_quantity,reason,created_by,client_details)
  values(a,owner_company,src,dst,vehicle,kind,qty,case when src is null then price else b.average_cost end,cur,previous,resulting,
    coalesce(p_action->>'reason',''),auth.uid(),jsonb_build_object('vehicle',p_action->>'vehicle','user',actor_name,'previousAverage',case when src is null then d.average_cost else b.average_cost end,'newAverage',average)) returning id into movement;
  insert into phelox_private.stock_action_receipts values(p_id,auth.uid(),p_action,movement);
  return movement;
end; $$;
revoke all on function phelox_private.commit_stock_action(uuid,jsonb) from public,anon,authenticated;
grant execute on function phelox_private.commit_stock_action(uuid,jsonb) to authenticated;
create or replace function public.commit_stock_action(p_id uuid,p_action jsonb)
returns uuid language sql security invoker set search_path='' as $$ select phelox_private.commit_stock_action(p_id,p_action); $$;
revoke all on function public.commit_stock_action(uuid,jsonb) from public,anon;
grant execute on function public.commit_stock_action(uuid,jsonb) to authenticated;

create or replace function phelox_private.stock_movement_history()
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null or public.current_role() is null then raise exception 'Sesión inválida'; end if;
  return coalesce((select jsonb_agg(to_jsonb(rows) order by rows.created_at desc,rows.id) from (
    select m.*,a.code,lf.name as from_name,lt.name as to_name,p.full_name as actor_name
    from public.stock_movements m join public.articles a on a.id=m.article_id
    left join public.locations lf on lf.id=m.from_location_id
    left join public.locations lt on lt.id=m.to_location_id
    left join public.profiles p on p.id=m.created_by
    where (m.from_location_id is null or public.can_access_stock_location(m.from_location_id))
      and (m.to_location_id is null or public.can_access_stock_location(m.to_location_id))
      and (m.from_location_id is not null or m.to_location_id is not null)
  ) rows),'[]'::jsonb);
end; $$;
revoke all on function phelox_private.stock_movement_history() from public,anon;
grant execute on function phelox_private.stock_movement_history() to authenticated;
create or replace function public.stock_movement_history()
returns jsonb language sql security invoker set search_path='' as $$ select phelox_private.stock_movement_history(); $$;
revoke all on function public.stock_movement_history() from public,anon;
grant execute on function public.stock_movement_history() to authenticated;

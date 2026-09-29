-- VILLA es un unico deposito fisico de PHELOX cuyo stock tambien puede ser
-- utilizado desde servicios de Transportes El Avion en Taller Villa Rosario.

create or replace function public.can_access_stock_location(target uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_company_id uuid;
  v_company_name text;
  v_location_name text;
begin
  if auth.uid() is null then
    return false;
  end if;

  select l.company_id, c.name, l.name
    into v_company_id, v_company_name, v_location_name
  from public.locations l
  join public.companies c on c.id = l.company_id
  where l.id = target
    and l.active;

  if v_company_id is null then
    return false;
  end if;

  if public.can_access_company(v_company_id)
     and public.can_access_location(target) then
    return true;
  end if;

  if upper(trim(v_location_name)) <> 'VILLA'
     or lower(trim(v_company_name)) <> 'phelox ltda' then
    return false;
  end if;

  return exists (
    select 1
    from public.companies transportes
    join public.locations taller
      on taller.company_id = transportes.id
     and taller.active
    where lower(trim(transportes.name)) in (
      'transportes el avion',
      'transportes el avión'
    )
      and upper(trim(taller.name)) = 'TALLER VILLA ROSARIO'
      and public.can_access_company(transportes.id)
      and public.can_access_location(taller.id)
  );
end;
$$;

revoke all on function public.can_access_stock_location(uuid) from public;
grant execute on function public.can_access_stock_location(uuid) to authenticated;

drop policy if exists locations_read on public.locations;
create policy locations_read on public.locations
  for select to authenticated
  using (
    public.can_access_company(company_id)
    or public.can_access_stock_location(id)
  );

drop policy if exists balances_read on public.stock_balances;
create policy balances_read on public.stock_balances
  for select to authenticated
  using (public.can_access_stock_location(location_id));

drop policy if exists balances_stock_write on public.stock_balances;
create policy balances_stock_write on public.stock_balances
  for all to authenticated
  using (
    public.current_role() in (
      'superadministrador',
      'administrador_general',
      'encargado_stock',
      'encargado_frente',
      'mecanico'
    )
    and public.can_access_stock_location(location_id)
  )
  with check (
    public.current_role() in (
      'superadministrador',
      'administrador_general',
      'encargado_stock',
      'encargado_frente',
      'mecanico'
    )
    and public.can_access_stock_location(location_id)
  );

create or replace function public.set_stock_balance(
  p_article_id uuid,
  p_location_id uuid,
  p_quantity numeric,
  p_average_cost numeric,
  p_currency text,
  p_positions jsonb,
  p_expected_version bigint
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_version bigint;
begin
  if auth.uid() is null then
    raise exception 'Sesion no valida';
  end if;

  if public.current_role() not in (
    'superadministrador','administrador_general','encargado_stock',
    'encargado_frente','mecanico'
  ) then
    raise exception 'Sin permiso para modificar stock';
  end if;

  if not public.can_access_stock_location(p_location_id) then
    raise exception 'Sin acceso a la sububicacion';
  end if;

  if p_quantity < 0 then
    raise exception 'El stock no puede quedar negativo';
  end if;

  update public.stock_balances set
    quantity = p_quantity,
    average_cost = greatest(coalesce(p_average_cost, 0), 0),
    currency = case when upper(p_currency) = 'USD' then 'USD' else 'UYU' end,
    warehouse_positions = coalesce(p_positions, '[]'::jsonb),
    version = version + 1,
    updated_by = auth.uid(),
    updated_at = now()
  where article_id = p_article_id
    and location_id = p_location_id
    and version = p_expected_version
  returning version into v_version;

  if v_version is null then
    raise exception 'El stock fue modificado desde otro dispositivo. Recarga antes de continuar.';
  end if;

  return v_version;
end;
$$;

revoke all on function public.set_stock_balance(uuid,uuid,numeric,numeric,text,jsonb,bigint) from public;
grant execute on function public.set_stock_balance(uuid,uuid,numeric,numeric,text,jsonb,bigint) to authenticated;

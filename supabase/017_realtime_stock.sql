-- Actualización inmediata de saldos, movimientos y solicitudes entre dispositivos.

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'stock_movements'
      and policyname = 'movements_shared_stock_read'
  ) then
    create policy movements_shared_stock_read
    on public.stock_movements
    for select
    to authenticated
    using (
      (from_location_id is null or public.can_access_stock_location(from_location_id))
      and (to_location_id is null or public.can_access_stock_location(to_location_id))
      and (from_location_id is not null or to_location_id is not null)
    );
  end if;
end
$$;

grant select on table public.stock_movements to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'stock_balances'
  ) then
    alter publication supabase_realtime add table public.stock_balances;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'stock_movements'
  ) then
    alter publication supabase_realtime add table public.stock_movements;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'stock_movement_requests'
  ) then
    alter publication supabase_realtime add table public.stock_movement_requests;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end
$$;

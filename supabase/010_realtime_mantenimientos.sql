-- Activa eventos instantaneos para solicitudes, aceptaciones y rechazos.
-- Es idempotente: puede ejecutarse mas de una vez sin duplicar la tabla.

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'maintenance_orders'
  ) then
    alter publication supabase_realtime add table public.maintenance_orders;
  end if;
end
$$;

-- Permisos base para solicitudes y respuestas de mantenimiento.
-- La seguridad por fila (RLS) existente sigue limitando cada operacion:
--   * el solicitante crea sus propias solicitudes;
--   * solicitante y destinatario pueden leerlas;
--   * el destinatario o un administrador habilitado puede responderlas.

begin;

grant usage on schema public to authenticated;
grant select, insert, update on table public.maintenance_orders to authenticated;

commit;

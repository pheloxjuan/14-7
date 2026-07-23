-- Permisos exclusivos para las Edge Functions que administran usuarios.
-- service_role no se utiliza en el navegador y mantiene el bypass de RLS.

grant usage on schema public to service_role;

grant select, insert, update, delete on table public.profiles to service_role;
grant select on table public.companies to service_role;
grant select on table public.areas to service_role;
grant select on table public.locations to service_role;
grant select, insert, update, delete on table public.profile_companies to service_role;
grant select, insert, update, delete on table public.profile_areas to service_role;
grant select, insert, update, delete on table public.profile_locations to service_role;

-- La pantalla de ingreso puede crear una solicitud, pero no leer solicitudes.
grant usage on schema public to anon;
grant insert on table public.password_reset_requests to anon;
grant select, update on table public.password_reset_requests to authenticated;
grant select, update on table public.password_reset_requests to service_role;

-- Acceso base de la flota. Las políticas RLS siguen decidiendo qué vehículos
-- puede leer o modificar cada usuario autenticado.
grant select, insert, update, delete on table public.vehicles to authenticated;
grant select, insert, update, delete on table public.vehicles to service_role;

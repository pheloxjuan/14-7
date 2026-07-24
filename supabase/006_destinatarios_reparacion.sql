-- Personal habilitado para recibir solicitudes en la misma sububicación o área.
-- La función expone solamente los datos mínimos necesarios y nunca devuelve
-- administradores ni superadministradores.
create or replace function public.repair_recipient_candidates(
  p_company_name text,
  p_location_names text[]
)
returns table (
  profile_id uuid,
  username text,
  full_name text,
  role public.app_role,
  location_names text[],
  area_names text[]
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.username,
    p.full_name,
    p.role,
    coalesce((
      select array_agg(distinct l2.name order by l2.name)
      from public.profile_locations pl2
      join public.locations l2 on l2.id = pl2.location_id
      where pl2.profile_id = p.id
        and l2.company_id = c.id
        and l2.active
    ), array[]::text[]) as location_names,
    coalesce((
      select array_agg(distinct a2.name order by a2.name)
      from public.profile_areas pa2
      join public.areas a2 on a2.id = pa2.area_id
      where pa2.profile_id = p.id
        and a2.company_id = c.id
        and a2.active
    ), array[]::text[]) as area_names
  from public.profiles p
  join public.companies c
    on lower(c.name) = lower(p_company_name)
  where p.active
    and p.id <> auth.uid()
    and p.role not in ('superadministrador', 'administrador_general')
    and public.can_access_company(c.id)
    and (
      exists (
        select 1
        from public.profile_locations pl
        join public.locations l on l.id = pl.location_id
        where pl.profile_id = p.id
          and l.company_id = c.id
          and l.active
          and lower(l.name) in (
            select lower(value)
            from unnest(coalesce(p_location_names, array[]::text[])) value
          )
      )
      or exists (
        select 1
        from public.profile_areas pa
        join public.areas a on a.id = pa.area_id
        join public.locations target_location
          on target_location.area_id = a.id
         and target_location.company_id = c.id
        where pa.profile_id = p.id
          and a.active
          and target_location.active
          and lower(target_location.name) in (
            select lower(value)
            from unnest(coalesce(p_location_names, array[]::text[])) value
          )
      )
    )
  order by p.full_name;
$$;

revoke all on function public.repair_recipient_candidates(text,text[]) from public;
grant execute on function public.repair_recipient_candidates(text,text[]) to authenticated;

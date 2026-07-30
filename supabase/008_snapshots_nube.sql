-- Descarga completa para la aplicación web.
-- Devuelve JSON agregado para evitar el límite de 1.000 filas de PostgREST.

create or replace function public.get_admin_users_snapshot()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not public.is_general_admin() then
    raise exception 'No tienes permiso para consultar usuarios';
  end if;

  return jsonb_build_object(
    'profiles', coalesce((select jsonb_agg(to_jsonb(p) order by p.full_name, p.username) from public.profiles p), '[]'::jsonb),
    'profile_companies', coalesce((select jsonb_agg(to_jsonb(pc)) from public.profile_companies pc), '[]'::jsonb),
    'profile_areas', coalesce((select jsonb_agg(to_jsonb(pa)) from public.profile_areas pa), '[]'::jsonb),
    'profile_locations', coalesce((select jsonb_agg(to_jsonb(pl)) from public.profile_locations pl), '[]'::jsonb)
  );
end;
$$;

create or replace function public.get_stock_snapshot()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Debes ingresar para consultar stock';
  end if;

  return jsonb_build_object(
    'articles', coalesce((select jsonb_agg(to_jsonb(a) order by a.code) from public.articles a where exists (select 1 from public.stock_balances sb where sb.article_id = a.id and public.can_access_company(sb.company_id) and public.can_access_location(sb.location_id))), '[]'::jsonb),
    'balances', coalesce((select jsonb_agg(to_jsonb(sb) order by sb.updated_at, sb.article_id, sb.location_id) from public.stock_balances sb where public.can_access_company(sb.company_id) and public.can_access_location(sb.location_id)), '[]'::jsonb),
    'companies', coalesce((select jsonb_agg(to_jsonb(c) order by c.name) from public.companies c where public.can_access_company(c.id)), '[]'::jsonb),
    'locations', coalesce((select jsonb_agg(to_jsonb(l) order by l.name) from public.locations l where public.can_access_company(l.company_id) and public.can_access_location(l.id)), '[]'::jsonb),
    'article_companies', coalesce((select jsonb_agg(to_jsonb(ac)) from public.article_companies ac where public.can_access_company(ac.company_id)), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.get_admin_users_snapshot() from public;
revoke all on function public.get_stock_snapshot() from public;
grant execute on function public.get_admin_users_snapshot() to authenticated;
grant execute on function public.get_stock_snapshot() to authenticated;

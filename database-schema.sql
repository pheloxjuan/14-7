-- PHELOX: estructura sin datos, capturada el 2026-09-18.

-- Para un proyecto Supabase NUEVO. No ejecutar sobre producción.

-- Revisar INSTALACION.md. No incluye usuarios Auth, secretos ni archivos.

begin;

do $$ begin if to_regclass('public.profiles') is not null then raise exception 'El proyecto ya contiene PHELOX. No aplicar esta base sobre una instalación existente.'; end if; end $$;

set local check_function_bodies = false;

set local search_path = public, extensions;

create extension if not exists "uuid-ossp" with schema extensions;

create extension if not exists pgcrypto with schema extensions;

create type public."app_role" as enum ('superadministrador', 'administrador_general', 'encargado_frente', 'encargado_stock', 'mecanico', 'chofer');

create type public."maintenance_status" as enum ('solicitado', 'en_proceso', 'terminado');

create type public."password_request_status" as enum ('pendiente', 'atendida', 'cancelada');

create type public."request_status" as enum ('pendiente', 'aprobado', 'rechazado', 'preparando', 'enviado', 'recibido');

create table public."areas" (
  "id" uuid default gen_random_uuid() not null,
  "company_id" uuid not null,
  "name" text not null,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null
);

create table public."article_companies" (
  "article_id" uuid not null,
  "company_id" uuid not null,
  "created_at" timestamp with time zone default now() not null
);

create table public."article_compatibilities" (
  "article_id" uuid not null,
  "compatible_article_id" uuid not null,
  "created_at" timestamp with time zone default now() not null
);

create table public."article_photos" (
  "id" uuid default gen_random_uuid() not null,
  "article_id" uuid not null,
  "storage_path" text not null,
  "is_cover" boolean default false not null,
  "uploaded_by" uuid,
  "created_at" timestamp with time zone default now() not null
);

create table public."article_types" (
  "id" uuid default gen_random_uuid() not null,
  "name" text not null,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null
);

create table public."articles" (
  "id" uuid default gen_random_uuid() not null,
  "code" text not null,
  "name" text not null,
  "article_type" text,
  "brand" text,
  "model" text,
  "unit" text default 'unidad'::text not null,
  "minimum_stock" numeric(14,3) default 0 not null,
  "ideal_stock" numeric(14,3) default 0 not null,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  "article_type_id" uuid,
  "description" text
);

create table public."audit_log" (
  "id" bigint generated always as identity not null,
  "profile_id" uuid,
  "action" text not null,
  "table_name" text not null,
  "record_id" text,
  "company_id" uuid,
  "location_id" uuid,
  "old_data" jsonb,
  "new_data" jsonb,
  "created_at" timestamp with time zone default now() not null
);

create table public."companies" (
  "id" uuid default gen_random_uuid() not null,
  "name" text not null,
  "active" boolean default true not null,
  "stock_mode" text default 'private'::text not null,
  "logo_path" text,
  "kilometer_price" numeric(14,2) default 0 not null,
  "currency" text default 'UYU'::text not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null
);

create table public."document_library_items" (
  "id" uuid default gen_random_uuid() not null,
  "parent_id" uuid,
  "item_type" text not null,
  "name" text not null,
  "storage_path" text,
  "mime_type" text,
  "size_bytes" bigint default 0 not null,
  "created_by" uuid,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null
);

create table public."google_drive_connections" (
  "id" text default 'primary'::text not null,
  "refresh_token" text not null,
  "scope" text,
  "folder_id" text,
  "folder_name" text default 'Respaldos Gestion Phelox'::text not null,
  "retention" integer default 10 not null,
  "connected_by" uuid,
  "connected_at" timestamp with time zone default now() not null,
  "last_backup_at" timestamp with time zone,
  "last_file_name" text,
  "last_status" text default 'Google Drive conectado'::text not null,
  "updated_at" timestamp with time zone default now() not null
);

create table public."google_drive_oauth_states" (
  "state" text not null,
  "user_id" uuid not null,
  "expires_at" timestamp with time zone not null,
  "created_at" timestamp with time zone default now() not null
);

create table public."locations" (
  "id" uuid default gen_random_uuid() not null,
  "company_id" uuid not null,
  "name" text not null,
  "parent_id" uuid,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "area_id" uuid,
  "location_type" text default 'frente'::text not null,
  "updated_at" timestamp with time zone default now() not null
);

create table public."maintenance_expenses" (
  "id" uuid default gen_random_uuid() not null,
  "maintenance_id" uuid not null,
  "expense_type" text not null,
  "kilometers" numeric(12,2),
  "price_per_km" numeric(14,2),
  "amount" numeric(14,2) not null,
  "currency" text default 'UYU'::text not null,
  "receipt_path" text,
  "description" text,
  "created_by" uuid not null,
  "created_at" timestamp with time zone default now() not null
);

create table public."maintenance_labor" (
  "id" uuid default gen_random_uuid() not null,
  "maintenance_id" uuid not null,
  "mechanic_id" uuid not null,
  "hours" numeric(10,2) not null,
  "hourly_rate" numeric(14,2) not null,
  "currency" text default 'UYU'::text not null,
  "created_at" timestamp with time zone default now() not null
);

create table public."maintenance_orders" (
  "id" uuid default gen_random_uuid() not null,
  "company_id" uuid not null,
  "location_id" uuid not null,
  "vehicle_id" uuid not null,
  "status" maintenance_status default 'solicitado'::maintenance_status not null,
  "title" text not null,
  "description" text,
  "priority" text default 'normal'::text not null,
  "requested_by" uuid not null,
  "assigned_to" uuid,
  "started_at" timestamp with time zone,
  "completed_at" timestamp with time zone,
  "completed_by" uuid,
  "kilometers" numeric(14,1),
  "pause_reason" text,
  "notes" text,
  "total_labor" numeric(14,2) default 0 not null,
  "total_parts" numeric(14,2) default 0 not null,
  "total_travel" numeric(14,2) default 0 not null,
  "total_allowances" numeric(14,2) default 0 not null,
  "total_other" numeric(14,2) default 0 not null,
  "total_cost" numeric(14,2) default 0 not null,
  "currency" text default 'UYU'::text not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null
);

create table public."maintenance_parts" (
  "id" uuid default gen_random_uuid() not null,
  "maintenance_id" uuid not null,
  "article_id" uuid not null,
  "location_id" uuid not null,
  "quantity" numeric(14,3) not null,
  "unit_cost" numeric(14,2) not null,
  "currency" text default 'UYU'::text not null,
  "stock_movement_id" uuid,
  "created_at" timestamp with time zone default now() not null
);

create table public."maintenance_photos" (
  "id" uuid default gen_random_uuid() not null,
  "maintenance_id" uuid not null,
  "storage_path" text not null,
  "photo_type" text default 'evidencia'::text not null,
  "uploaded_by" uuid not null,
  "created_at" timestamp with time zone default now() not null
);

create table public."notifications" (
  "id" uuid default gen_random_uuid() not null,
  "profile_id" uuid not null,
  "title" text not null,
  "body" text not null,
  "notification_type" text not null,
  "entity_type" text,
  "entity_id" uuid,
  "read_at" timestamp with time zone,
  "created_at" timestamp with time zone default now() not null
);

create table public."password_reset_requests" (
  "id" uuid default gen_random_uuid() not null,
  "username" text not null,
  "phone_last4" text,
  "status" password_request_status default 'pendiente'::password_request_status not null,
  "requested_at" timestamp with time zone default now() not null,
  "resolved_at" timestamp with time zone,
  "resolved_by" uuid,
  "notes" text
);

create table public."profile_areas" (
  "profile_id" uuid not null,
  "area_id" uuid not null
);

create table public."profile_companies" (
  "profile_id" uuid not null,
  "company_id" uuid not null
);

create table public."profile_locations" (
  "profile_id" uuid not null,
  "location_id" uuid not null
);

create table public."profiles" (
  "id" uuid not null,
  "username" text not null,
  "full_name" text not null,
  "phone" text,
  "role" app_role not null,
  "active" boolean default true not null,
  "hourly_rate" numeric(14,2) default 0 not null,
  "hourly_currency" text default 'UYU'::text not null,
  "must_change_password" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null
);

create table public."push_subscriptions" (
  "id" uuid default gen_random_uuid() not null,
  "user_id" uuid not null,
  "endpoint" text not null,
  "p256dh" text not null,
  "auth" text not null,
  "user_agent" text,
  "active" boolean default true not null,
  "last_seen_at" timestamp with time zone default now() not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null
);

create table public."stock_balances" (
  "article_id" uuid not null,
  "company_id" uuid not null,
  "location_id" uuid not null,
  "quantity" numeric(14,3) default 0 not null,
  "average_cost" numeric(14,2) default 0 not null,
  "currency" text default 'UYU'::text not null,
  "version" bigint default 0 not null,
  "updated_at" timestamp with time zone default now() not null,
  "warehouse_positions" jsonb default '[]'::jsonb not null,
  "updated_by" uuid
);

create table public."stock_lots" (
  "id" uuid default gen_random_uuid() not null,
  "article_id" uuid not null,
  "company_id" uuid not null,
  "location_id" uuid not null,
  "quantity_received" numeric(14,3) not null,
  "quantity_remaining" numeric(14,3) not null,
  "unit_cost" numeric(14,2) default 0 not null,
  "currency" text default 'UYU'::text not null,
  "supplier" text,
  "invoice_number" text,
  "received_by" uuid not null,
  "received_at" timestamp with time zone default now() not null,
  "notes" text
);

create table public."stock_movement_request_items" (
  "request_id" uuid not null,
  "article_id" uuid not null,
  "quantity" numeric(14,3) not null,
  "approved_quantity" numeric(14,3)
);

create table public."stock_movement_requests" (
  "id" uuid default gen_random_uuid() not null,
  "company_id" uuid not null,
  "from_location_id" uuid not null,
  "to_location_id" uuid not null,
  "requested_by" uuid not null,
  "status" request_status default 'pendiente'::request_status not null,
  "reason" text,
  "decided_by" uuid,
  "requested_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  "received_at" timestamp with time zone
);

create table public."stock_movements" (
  "id" uuid default gen_random_uuid() not null,
  "article_id" uuid not null,
  "company_id" uuid not null,
  "from_location_id" uuid,
  "to_location_id" uuid,
  "vehicle_id" uuid,
  "movement_type" text not null,
  "quantity" numeric(14,3) not null,
  "unit_cost" numeric(14,2) default 0 not null,
  "currency" text default 'UYU'::text not null,
  "previous_quantity" numeric(14,3),
  "resulting_quantity" numeric(14,3),
  "reason" text,
  "created_by" uuid not null,
  "created_at" timestamp with time zone default now() not null
);

create table public."vehicle_areas" (
  "vehicle_id" uuid not null,
  "area_id" uuid not null,
  "created_at" timestamp with time zone default now() not null
);

create table public."vehicle_brands" (
  "id" uuid default gen_random_uuid() not null,
  "name" text not null,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null
);

create table public."vehicle_locations" (
  "vehicle_id" uuid not null,
  "location_id" uuid not null,
  "is_primary" boolean default false not null,
  "created_at" timestamp with time zone default now() not null
);

create table public."vehicle_models" (
  "id" uuid default gen_random_uuid() not null,
  "vehicle_type_id" uuid,
  "brand_id" uuid,
  "name" text not null,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null
);

create table public."vehicle_recommended_articles" (
  "vehicle_id" uuid not null,
  "article_id" uuid not null,
  "notes" text,
  "created_at" timestamp with time zone default now() not null
);

create table public."vehicle_types" (
  "id" uuid default gen_random_uuid() not null,
  "name" text not null,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null
);

create table public."vehicles" (
  "id" uuid default gen_random_uuid() not null,
  "company_id" uuid not null,
  "location_id" uuid,
  "vehicle_type" text not null,
  "brand" text not null,
  "model" text not null,
  "plate" text not null,
  "year" integer,
  "area" text,
  "axles" integer,
  "tires_per_axle" text,
  "tire_size" text,
  "oil_type" text,
  "oil_liters" numeric(12,2),
  "oil_code" text,
  "filter_codes" text,
  "current_km" numeric(14,1) default 0 not null,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  "vehicle_type_id" uuid,
  "brand_id" uuid,
  "model_id" uuid,
  "ownership" text,
  "usual_operator" text,
  "gps" boolean,
  "operational_status" text,
  "chassis" text
);

CREATE OR REPLACE FUNCTION public.can_access_company(target uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ select public.is_super_admin() or exists(select 1 from public.profile_companies pc where pc.profile_id=auth.uid() and pc.company_id=target) $function$;

CREATE OR REPLACE FUNCTION public.can_access_location(target uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ select public.is_general_admin() or exists(select 1 from public.profile_locations pl where pl.profile_id=auth.uid() and pl.location_id=target) $function$;

CREATE OR REPLACE FUNCTION public."current_role"()
 RETURNS app_role
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ select role from public.profiles where id=auth.uid() and active $function$;

CREATE OR REPLACE FUNCTION public.get_admin_users_snapshot()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

begin

  if auth.uid() is null or not public.is_general_admin() then raise exception 'No tienes permiso para consultar usuarios'; end if;

  return jsonb_build_object(

    'profiles',coalesce((select jsonb_agg(to_jsonb(p) order by p.full_name,p.username) from public.profiles p),'[]'::jsonb),

    'profile_companies',coalesce((select jsonb_agg(to_jsonb(pc)) from public.profile_companies pc),'[]'::jsonb),

    'profile_areas',coalesce((select jsonb_agg(to_jsonb(pa)) from public.profile_areas pa),'[]'::jsonb),

    'profile_locations',coalesce((select jsonb_agg(to_jsonb(pl)) from public.profile_locations pl),'[]'::jsonb));

end; $function$;

CREATE OR REPLACE FUNCTION public.get_stock_snapshot()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

begin

  if auth.uid() is null then raise exception 'Debes ingresar para consultar stock'; end if;

  return jsonb_build_object(

    'articles',coalesce((select jsonb_agg(to_jsonb(a) order by a.code) from public.articles a where exists(select 1 from public.stock_balances sb where sb.article_id=a.id and public.can_access_company(sb.company_id) and public.can_access_location(sb.location_id))),'[]'::jsonb),

    'balances',coalesce((select jsonb_agg(to_jsonb(sb) order by sb.updated_at,sb.article_id,sb.location_id) from public.stock_balances sb where public.can_access_company(sb.company_id) and public.can_access_location(sb.location_id)),'[]'::jsonb),

    'companies',coalesce((select jsonb_agg(to_jsonb(c) order by c.name) from public.companies c where public.can_access_company(c.id)),'[]'::jsonb),

    'locations',coalesce((select jsonb_agg(to_jsonb(l) order by l.name) from public.locations l where public.can_access_company(l.company_id) and public.can_access_location(l.id)),'[]'::jsonb),

    'article_companies',coalesce((select jsonb_agg(to_jsonb(ac)) from public.article_companies ac where public.can_access_company(ac.company_id)),'[]'::jsonb));

end; $function$;

CREATE OR REPLACE FUNCTION public.import_stock_rows(p_company_name text, p_rows jsonb, p_quantity_mode text DEFAULT 'replace'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

declare

  v_company uuid;

  v_row jsonb;

  v_article uuid;

  v_location uuid;

  v_created integer := 0;

  v_updated integer := 0;

begin

  if public.current_role() not in ('superadministrador','administrador_general','encargado_stock') then

    raise exception 'Sin permiso para importar stock';

  end if;

  if p_quantity_mode not in ('replace','add') then

    raise exception 'Modalidad de cantidad invalida';

  end if;



  select id into v_company

  from public.companies

  where lower(name)=lower(trim(p_company_name)) and active

  limit 1;

  if v_company is null then raise exception 'Empresa no encontrada: %',p_company_name; end if;



  for v_row in select value from jsonb_array_elements(p_rows)

  loop

    select id into v_location

    from public.locations

    where company_id=v_company

      and lower(name)=lower(trim(v_row->>'location'))

      and active

    limit 1;

    if v_location is null then

      raise exception 'Sububicacion no encontrada o desactivada: %',v_row->>'location';

    end if;



    insert into public.articles(

      code,name,article_type,brand,model,minimum_stock,ideal_stock,active,updated_at

    ) values (

      upper(trim(v_row->>'code')),

      coalesce(nullif(trim(v_row->>'name'),''),upper(trim(v_row->>'code'))),

      nullif(trim(v_row->>'type'),''),

      nullif(trim(v_row->>'brand'),''),

      nullif(trim(v_row->>'model'),''),

      greatest(coalesce((v_row->>'minimum')::numeric,0),0),

      greatest(coalesce((v_row->>'ideal')::numeric,0),0),

      true,now()

    )

    on conflict(code) do update set

      name=coalesce(nullif(excluded.name,''),articles.name),

      article_type=coalesce(nullif(excluded.article_type,''),articles.article_type),

      brand=coalesce(nullif(excluded.brand,''),articles.brand),

      model=coalesce(nullif(excluded.model,''),articles.model),

      minimum_stock=excluded.minimum_stock,

      ideal_stock=excluded.ideal_stock,

      active=true,

      updated_at=now()

    returning id into v_article;



    if exists(select 1 from public.stock_balances where article_id=v_article and location_id=v_location) then

      update public.stock_balances set

        quantity=case when p_quantity_mode='add'

          then quantity+greatest((v_row->>'quantity')::numeric,0)

          else greatest((v_row->>'quantity')::numeric,0) end,

        average_cost=greatest(coalesce((v_row->>'price')::numeric,0),0),

        currency=case when upper(v_row->>'currency')='USD' then 'USD' else 'UYU' end,

        warehouse_positions=coalesce(v_row->'positions','[]'::jsonb),

        version=version+1,

        updated_by=auth.uid(),

        updated_at=now()

      where article_id=v_article and location_id=v_location;

      v_updated := v_updated+1;

    else

      insert into public.stock_balances(

        article_id,company_id,location_id,quantity,average_cost,currency,

        warehouse_positions,version,updated_by,updated_at

      ) values (

        v_article,v_company,v_location,greatest((v_row->>'quantity')::numeric,0),

        greatest(coalesce((v_row->>'price')::numeric,0),0),

        case when upper(v_row->>'currency')='USD' then 'USD' else 'UYU' end,

        coalesce(v_row->'positions','[]'::jsonb),1,auth.uid(),now()

      );

      v_created := v_created+1;

    end if;

  end loop;

  return jsonb_build_object('created',v_created,'updated',v_updated);

end $function$;

CREATE OR REPLACE FUNCTION public.is_general_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ select coalesce(public.current_role() in ('superadministrador','administrador_general'),false) $function$;

CREATE OR REPLACE FUNCTION public.is_super_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ select coalesce(public.current_role()='superadministrador',false) $function$;

CREATE OR REPLACE FUNCTION public.move_stock(p_article uuid, p_company uuid, p_from uuid, p_to uuid, p_quantity numeric, p_reason text DEFAULT NULL::text, p_vehicle uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

declare

  source_qty numeric;

  destination_qty numeric;

  movement_id uuid;

begin

  if auth.uid() is null then raise exception 'Usuario no autenticado'; end if;

  if p_quantity <= 0 then raise exception 'La cantidad debe ser mayor a cero'; end if;

  if p_from is null and p_to is null then raise exception 'Debe indicar origen o destino'; end if;

  if p_from is not null and not public.can_access_location(p_from) then raise exception 'Sin acceso a la ubicacion de origen'; end if;

  if p_to is not null and not public.can_access_location(p_to) then raise exception 'Sin acceso a la ubicacion de destino'; end if;



  if p_from is not null then

    select quantity into source_qty from public.stock_balances

      where article_id=p_article and location_id=p_from for update;

    if source_qty is null or source_qty < p_quantity then

      raise exception 'Stock insuficiente. Disponible: %',coalesce(source_qty,0);

    end if;

    update public.stock_balances set quantity=quantity-p_quantity,version=version+1,updated_at=now()

      where article_id=p_article and location_id=p_from;

  end if;



  if p_to is not null then

    insert into public.stock_balances(article_id,company_id,location_id,quantity)

      values(p_article,p_company,p_to,p_quantity)

    on conflict(article_id,location_id) do update

      set quantity=public.stock_balances.quantity+excluded.quantity,

          version=public.stock_balances.version+1,

          updated_at=now();

    select quantity into destination_qty from public.stock_balances

      where article_id=p_article and location_id=p_to;

  end if;



  insert into public.stock_movements(

    article_id,company_id,from_location_id,to_location_id,vehicle_id,movement_type,

    quantity,previous_quantity,resulting_quantity,reason,created_by

  ) values (

    p_article,p_company,p_from,p_to,p_vehicle,

    case when p_from is not null and p_to is not null then 'transferencia'

         when p_from is not null then 'consumo' else 'ingreso' end,

    p_quantity,

    case when p_from is not null then source_qty else coalesce(destination_qty,0)-p_quantity end,

    case when p_from is not null then source_qty-p_quantity else destination_qty end,

    p_reason,auth.uid()

  ) returning id into movement_id;

  return movement_id;

end $function$;

CREATE OR REPLACE FUNCTION public.repair_recipient_candidates(p_company_name text, p_location_names text[])
 RETURNS TABLE(profile_id uuid, username text, full_name text, role app_role, location_names text[], area_names text[])
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

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

$function$;

CREATE OR REPLACE FUNCTION public.rls_auto_enable()
 RETURNS event_trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$function$;

CREATE OR REPLACE FUNCTION public.set_imported_articles_company_scope(p_codes jsonb, p_scope text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

declare

  v_count integer := 0;

begin

  if public.current_role() not in ('superadministrador','administrador_general','encargado_stock') then

    raise exception 'Sin permiso para asignar empresas a los articulos';

  end if;

  if p_scope not in ('Phelox Ltda','Transportes El Avion','Ambas empresas') then

    raise exception 'Alcance de empresa invalido';

  end if;



  delete from public.article_companies ac

  using public.articles a

  where ac.article_id=a.id

    and a.code in (select upper(trim(value #>> '{}')) from jsonb_array_elements(p_codes));



  insert into public.article_companies(article_id,company_id)

  select a.id,c.id

  from public.articles a

  cross join public.companies c

  where a.code in (select upper(trim(value #>> '{}')) from jsonb_array_elements(p_codes))

    and (

      p_scope='Ambas empresas'

      or lower(c.name)=lower(p_scope)

    )

  on conflict do nothing;



  get diagnostics v_count = row_count;

  return v_count;

end $function$;

CREATE OR REPLACE FUNCTION public.set_stock_balance(p_article_id uuid, p_location_id uuid, p_quantity numeric, p_average_cost numeric, p_currency text, p_positions jsonb, p_expected_version bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

declare

  v_company uuid;

  v_version bigint;

begin

  if public.current_role() not in (

    'superadministrador','administrador_general','encargado_stock',

    'encargado_frente','mecanico'

  ) then raise exception 'Sin permiso para modificar stock'; end if;

  select company_id into v_company from public.locations where id=p_location_id and active;

  if v_company is null

     or not public.can_access_company(v_company)

     or not public.can_access_location(p_location_id) then

    raise exception 'Sin acceso a la sububicacion';

  end if;

  if p_quantity < 0 then raise exception 'El stock no puede quedar negativo'; end if;



  update public.stock_balances set

    quantity=p_quantity,

    average_cost=greatest(coalesce(p_average_cost,0),0),

    currency=case when upper(p_currency)='USD' then 'USD' else 'UYU' end,

    warehouse_positions=coalesce(p_positions,'[]'::jsonb),

    version=version+1,

    updated_by=auth.uid(),

    updated_at=now()

  where article_id=p_article_id and location_id=p_location_id

    and version=p_expected_version

  returning version into v_version;

  if v_version is null then

    raise exception 'El stock fue modificado desde otro dispositivo. Recarga antes de continuar.';

  end if;

  return v_version;

end $function$;

alter table public."article_compatibilities" add constraint "article_compatibilities_check" CHECK (article_id <> compatible_article_id);

alter table public."articles" add constraint "articles_ideal_stock_check" CHECK (ideal_stock >= 0::numeric);

alter table public."articles" add constraint "articles_minimum_stock_check" CHECK (minimum_stock >= 0::numeric);

alter table public."companies" add constraint "companies_currency_check" CHECK (currency = ANY (ARRAY['UYU'::text, 'USD'::text]));

alter table public."companies" add constraint "companies_kilometer_price_check" CHECK (kilometer_price >= 0::numeric);

alter table public."companies" add constraint "companies_stock_mode_check" CHECK (stock_mode = ANY (ARRAY['private'::text, 'shared'::text]));

alter table public."document_library_items" add constraint "document_library_items_check" CHECK (item_type = 'folder'::text AND storage_path IS NULL OR item_type = 'file'::text AND storage_path IS NOT NULL);

alter table public."document_library_items" add constraint "document_library_items_item_type_check" CHECK (item_type = ANY (ARRAY['folder'::text, 'file'::text]));

alter table public."document_library_items" add constraint "document_library_items_name_check" CHECK (length(TRIM(BOTH FROM name)) > 0);

alter table public."document_library_items" add constraint "document_library_items_size_bytes_check" CHECK (size_bytes >= 0);

alter table public."google_drive_connections" add constraint "google_drive_connections_id_check" CHECK (id = 'primary'::text);

alter table public."google_drive_connections" add constraint "google_drive_connections_retention_check" CHECK (retention >= 1 AND retention <= 365);

alter table public."locations" add constraint "locations_type_check" CHECK (location_type = ANY (ARRAY['frente'::text, 'deposito'::text, 'taller'::text, 'deposito_taller'::text, 'administracion'::text]));

alter table public."maintenance_expenses" add constraint "maintenance_expenses_amount_check" CHECK (amount >= 0::numeric);

alter table public."maintenance_expenses" add constraint "maintenance_expenses_currency_check" CHECK (currency = ANY (ARRAY['UYU'::text, 'USD'::text]));

alter table public."maintenance_expenses" add constraint "maintenance_expenses_expense_type_check" CHECK (expense_type = ANY (ARRAY['traslado'::text, 'viatico'::text, 'otro'::text]));

alter table public."maintenance_expenses" add constraint "maintenance_expenses_kilometers_check" CHECK (kilometers IS NULL OR kilometers >= 0::numeric);

alter table public."maintenance_expenses" add constraint "maintenance_expenses_price_per_km_check" CHECK (price_per_km IS NULL OR price_per_km >= 0::numeric);

alter table public."maintenance_labor" add constraint "maintenance_labor_currency_check" CHECK (currency = ANY (ARRAY['UYU'::text, 'USD'::text]));

alter table public."maintenance_labor" add constraint "maintenance_labor_hourly_rate_check" CHECK (hourly_rate >= 0::numeric);

alter table public."maintenance_labor" add constraint "maintenance_labor_hours_check" CHECK (hours > 0::numeric);

alter table public."maintenance_orders" add constraint "maintenance_orders_currency_check" CHECK (currency = ANY (ARRAY['UYU'::text, 'USD'::text]));

alter table public."maintenance_orders" add constraint "maintenance_orders_kilometers_check" CHECK (kilometers IS NULL OR kilometers >= 0::numeric);

alter table public."maintenance_orders" add constraint "maintenance_orders_priority_check" CHECK (priority = ANY (ARRAY['baja'::text, 'normal'::text, 'alta'::text, 'urgente'::text]));

alter table public."maintenance_parts" add constraint "maintenance_parts_currency_check" CHECK (currency = ANY (ARRAY['UYU'::text, 'USD'::text]));

alter table public."maintenance_parts" add constraint "maintenance_parts_quantity_check" CHECK (quantity > 0::numeric);

alter table public."maintenance_parts" add constraint "maintenance_parts_unit_cost_check" CHECK (unit_cost >= 0::numeric);

alter table public."maintenance_photos" add constraint "maintenance_photos_photo_type_check" CHECK (photo_type = ANY (ARRAY['solicitud'::text, 'evidencia'::text, 'boleta'::text]));

alter table public."profiles" add constraint "profiles_hourly_currency_check" CHECK (hourly_currency = ANY (ARRAY['UYU'::text, 'USD'::text]));

alter table public."profiles" add constraint "profiles_hourly_rate_check" CHECK (hourly_rate >= 0::numeric);

alter table public."stock_balances" add constraint "stock_balances_average_cost_check" CHECK (average_cost >= 0::numeric);

alter table public."stock_balances" add constraint "stock_balances_currency_check" CHECK (currency = ANY (ARRAY['UYU'::text, 'USD'::text]));

alter table public."stock_balances" add constraint "stock_balances_quantity_check" CHECK (quantity >= 0::numeric);

alter table public."stock_lots" add constraint "stock_lots_currency_check" CHECK (currency = ANY (ARRAY['UYU'::text, 'USD'::text]));

alter table public."stock_lots" add constraint "stock_lots_quantity_received_check" CHECK (quantity_received > 0::numeric);

alter table public."stock_lots" add constraint "stock_lots_quantity_remaining_check" CHECK (quantity_remaining >= 0::numeric);

alter table public."stock_lots" add constraint "stock_lots_unit_cost_check" CHECK (unit_cost >= 0::numeric);

alter table public."stock_movement_request_items" add constraint "stock_movement_request_items_approved_quantity_check" CHECK (approved_quantity IS NULL OR approved_quantity >= 0::numeric);

alter table public."stock_movement_request_items" add constraint "stock_movement_request_items_quantity_check" CHECK (quantity > 0::numeric);

alter table public."stock_movements" add constraint "stock_movements_currency_check" CHECK (currency = ANY (ARRAY['UYU'::text, 'USD'::text]));

alter table public."stock_movements" add constraint "stock_movements_movement_type_check" CHECK (movement_type = ANY (ARRAY['ingreso'::text, 'consumo'::text, 'transferencia'::text, 'ajuste'::text, 'devolucion'::text]));

alter table public."stock_movements" add constraint "stock_movements_quantity_check" CHECK (quantity > 0::numeric);

alter table public."stock_movements" add constraint "stock_movements_unit_cost_check" CHECK (unit_cost >= 0::numeric);

alter table public."vehicles" add constraint "vehicles_axles_check" CHECK (axles IS NULL OR axles > 0);

alter table public."vehicles" add constraint "vehicles_current_km_check" CHECK (current_km >= 0::numeric);

alter table public."vehicles" add constraint "vehicles_oil_liters_check" CHECK (oil_liters IS NULL OR oil_liters >= 0::numeric);

alter table public."vehicles" add constraint "vehicles_year_check" CHECK (year IS NULL OR year >= 1900 AND year <= 2100);

alter table public."areas" add constraint "areas_pkey" PRIMARY KEY (id);

alter table public."article_companies" add constraint "article_companies_pkey" PRIMARY KEY (article_id, company_id);

alter table public."article_compatibilities" add constraint "article_compatibilities_pkey" PRIMARY KEY (article_id, compatible_article_id);

alter table public."article_photos" add constraint "article_photos_pkey" PRIMARY KEY (id);

alter table public."article_types" add constraint "article_types_pkey" PRIMARY KEY (id);

alter table public."articles" add constraint "articles_pkey" PRIMARY KEY (id);

alter table public."audit_log" add constraint "audit_log_pkey" PRIMARY KEY (id);

alter table public."companies" add constraint "companies_pkey" PRIMARY KEY (id);

alter table public."document_library_items" add constraint "document_library_items_pkey" PRIMARY KEY (id);

alter table public."google_drive_connections" add constraint "google_drive_connections_pkey" PRIMARY KEY (id);

alter table public."google_drive_oauth_states" add constraint "google_drive_oauth_states_pkey" PRIMARY KEY (state);

alter table public."locations" add constraint "locations_pkey" PRIMARY KEY (id);

alter table public."maintenance_expenses" add constraint "maintenance_expenses_pkey" PRIMARY KEY (id);

alter table public."maintenance_labor" add constraint "maintenance_labor_pkey" PRIMARY KEY (id);

alter table public."maintenance_orders" add constraint "maintenance_orders_pkey" PRIMARY KEY (id);

alter table public."maintenance_parts" add constraint "maintenance_parts_pkey" PRIMARY KEY (id);

alter table public."maintenance_photos" add constraint "maintenance_photos_pkey" PRIMARY KEY (id);

alter table public."notifications" add constraint "notifications_pkey" PRIMARY KEY (id);

alter table public."password_reset_requests" add constraint "password_reset_requests_pkey" PRIMARY KEY (id);

alter table public."profile_areas" add constraint "profile_areas_pkey" PRIMARY KEY (profile_id, area_id);

alter table public."profile_companies" add constraint "profile_companies_pkey" PRIMARY KEY (profile_id, company_id);

alter table public."profile_locations" add constraint "profile_locations_pkey" PRIMARY KEY (profile_id, location_id);

alter table public."profiles" add constraint "profiles_pkey" PRIMARY KEY (id);

alter table public."push_subscriptions" add constraint "push_subscriptions_pkey" PRIMARY KEY (id);

alter table public."stock_balances" add constraint "stock_balances_pkey" PRIMARY KEY (article_id, location_id);

alter table public."stock_lots" add constraint "stock_lots_pkey" PRIMARY KEY (id);

alter table public."stock_movement_request_items" add constraint "stock_movement_request_items_pkey" PRIMARY KEY (request_id, article_id);

alter table public."stock_movement_requests" add constraint "stock_movement_requests_pkey" PRIMARY KEY (id);

alter table public."stock_movements" add constraint "stock_movements_pkey" PRIMARY KEY (id);

alter table public."vehicle_areas" add constraint "vehicle_areas_pkey" PRIMARY KEY (vehicle_id, area_id);

alter table public."vehicle_brands" add constraint "vehicle_brands_pkey" PRIMARY KEY (id);

alter table public."vehicle_locations" add constraint "vehicle_locations_pkey" PRIMARY KEY (vehicle_id, location_id);

alter table public."vehicle_models" add constraint "vehicle_models_pkey" PRIMARY KEY (id);

alter table public."vehicle_recommended_articles" add constraint "vehicle_recommended_articles_pkey" PRIMARY KEY (vehicle_id, article_id);

alter table public."vehicle_types" add constraint "vehicle_types_pkey" PRIMARY KEY (id);

alter table public."vehicles" add constraint "vehicles_pkey" PRIMARY KEY (id);

alter table public."areas" add constraint "areas_company_id_name_key" UNIQUE (company_id, name);

alter table public."article_types" add constraint "article_types_name_key" UNIQUE (name);

alter table public."articles" add constraint "articles_code_key" UNIQUE (code);

alter table public."companies" add constraint "companies_name_key" UNIQUE (name);

alter table public."locations" add constraint "locations_company_id_name_key" UNIQUE (company_id, name);

alter table public."profiles" add constraint "profiles_username_key" UNIQUE (username);

alter table public."push_subscriptions" add constraint "push_subscriptions_endpoint_key" UNIQUE (endpoint);

alter table public."vehicle_brands" add constraint "vehicle_brands_name_key" UNIQUE (name);

alter table public."vehicle_types" add constraint "vehicle_types_name_key" UNIQUE (name);

alter table public."vehicles" add constraint "vehicles_plate_key" UNIQUE (plate);

alter table public."areas" add constraint "areas_company_id_fkey" FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE;

alter table public."article_companies" add constraint "article_companies_article_id_fkey" FOREIGN KEY (article_id) REFERENCES articles(id) ON DELETE CASCADE;

alter table public."article_companies" add constraint "article_companies_company_id_fkey" FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE;

alter table public."article_compatibilities" add constraint "article_compatibilities_article_id_fkey" FOREIGN KEY (article_id) REFERENCES articles(id) ON DELETE CASCADE;

alter table public."article_compatibilities" add constraint "article_compatibilities_compatible_article_id_fkey" FOREIGN KEY (compatible_article_id) REFERENCES articles(id) ON DELETE CASCADE;

alter table public."article_photos" add constraint "article_photos_article_id_fkey" FOREIGN KEY (article_id) REFERENCES articles(id) ON DELETE CASCADE;

alter table public."article_photos" add constraint "article_photos_uploaded_by_fkey" FOREIGN KEY (uploaded_by) REFERENCES profiles(id);

alter table public."articles" add constraint "articles_article_type_id_fkey" FOREIGN KEY (article_type_id) REFERENCES article_types(id);

alter table public."audit_log" add constraint "audit_log_company_id_fkey" FOREIGN KEY (company_id) REFERENCES companies(id);

alter table public."audit_log" add constraint "audit_log_location_id_fkey" FOREIGN KEY (location_id) REFERENCES locations(id);

alter table public."audit_log" add constraint "audit_log_profile_id_fkey" FOREIGN KEY (profile_id) REFERENCES profiles(id);

alter table public."document_library_items" add constraint "document_library_items_created_by_fkey" FOREIGN KEY (created_by) REFERENCES profiles(id) ON DELETE SET NULL;

alter table public."document_library_items" add constraint "document_library_items_parent_id_fkey" FOREIGN KEY (parent_id) REFERENCES document_library_items(id) ON DELETE CASCADE;

alter table public."google_drive_connections" add constraint "google_drive_connections_connected_by_fkey" FOREIGN KEY (connected_by) REFERENCES auth.users(id) ON DELETE SET NULL;

alter table public."google_drive_oauth_states" add constraint "google_drive_oauth_states_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table public."locations" add constraint "locations_area_id_fkey" FOREIGN KEY (area_id) REFERENCES areas(id);

alter table public."locations" add constraint "locations_company_id_fkey" FOREIGN KEY (company_id) REFERENCES companies(id);

alter table public."locations" add constraint "locations_parent_id_fkey" FOREIGN KEY (parent_id) REFERENCES locations(id);

alter table public."maintenance_expenses" add constraint "maintenance_expenses_created_by_fkey" FOREIGN KEY (created_by) REFERENCES profiles(id);

alter table public."maintenance_expenses" add constraint "maintenance_expenses_maintenance_id_fkey" FOREIGN KEY (maintenance_id) REFERENCES maintenance_orders(id) ON DELETE CASCADE;

alter table public."maintenance_labor" add constraint "maintenance_labor_maintenance_id_fkey" FOREIGN KEY (maintenance_id) REFERENCES maintenance_orders(id) ON DELETE CASCADE;

alter table public."maintenance_labor" add constraint "maintenance_labor_mechanic_id_fkey" FOREIGN KEY (mechanic_id) REFERENCES profiles(id);

alter table public."maintenance_orders" add constraint "maintenance_orders_assigned_to_fkey" FOREIGN KEY (assigned_to) REFERENCES profiles(id);

alter table public."maintenance_orders" add constraint "maintenance_orders_company_id_fkey" FOREIGN KEY (company_id) REFERENCES companies(id);

alter table public."maintenance_orders" add constraint "maintenance_orders_completed_by_fkey" FOREIGN KEY (completed_by) REFERENCES profiles(id);

alter table public."maintenance_orders" add constraint "maintenance_orders_location_id_fkey" FOREIGN KEY (location_id) REFERENCES locations(id);

alter table public."maintenance_orders" add constraint "maintenance_orders_requested_by_fkey" FOREIGN KEY (requested_by) REFERENCES profiles(id);

alter table public."maintenance_orders" add constraint "maintenance_orders_vehicle_id_fkey" FOREIGN KEY (vehicle_id) REFERENCES vehicles(id);

alter table public."maintenance_parts" add constraint "maintenance_parts_article_id_fkey" FOREIGN KEY (article_id) REFERENCES articles(id);

alter table public."maintenance_parts" add constraint "maintenance_parts_location_id_fkey" FOREIGN KEY (location_id) REFERENCES locations(id);

alter table public."maintenance_parts" add constraint "maintenance_parts_maintenance_id_fkey" FOREIGN KEY (maintenance_id) REFERENCES maintenance_orders(id) ON DELETE CASCADE;

alter table public."maintenance_parts" add constraint "maintenance_parts_stock_movement_id_fkey" FOREIGN KEY (stock_movement_id) REFERENCES stock_movements(id);

alter table public."maintenance_photos" add constraint "maintenance_photos_maintenance_id_fkey" FOREIGN KEY (maintenance_id) REFERENCES maintenance_orders(id) ON DELETE CASCADE;

alter table public."maintenance_photos" add constraint "maintenance_photos_uploaded_by_fkey" FOREIGN KEY (uploaded_by) REFERENCES profiles(id);

alter table public."notifications" add constraint "notifications_profile_id_fkey" FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;

alter table public."password_reset_requests" add constraint "password_reset_requests_resolved_by_fkey" FOREIGN KEY (resolved_by) REFERENCES profiles(id);

alter table public."profile_areas" add constraint "profile_areas_area_id_fkey" FOREIGN KEY (area_id) REFERENCES areas(id) ON DELETE CASCADE;

alter table public."profile_areas" add constraint "profile_areas_profile_id_fkey" FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;

alter table public."profile_companies" add constraint "profile_companies_company_id_fkey" FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE;

alter table public."profile_companies" add constraint "profile_companies_profile_id_fkey" FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;

alter table public."profile_locations" add constraint "profile_locations_location_id_fkey" FOREIGN KEY (location_id) REFERENCES locations(id) ON DELETE CASCADE;

alter table public."profile_locations" add constraint "profile_locations_profile_id_fkey" FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;

alter table public."profiles" add constraint "profiles_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table public."push_subscriptions" add constraint "push_subscriptions_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table public."stock_balances" add constraint "stock_balances_article_id_fkey" FOREIGN KEY (article_id) REFERENCES articles(id);

alter table public."stock_balances" add constraint "stock_balances_company_id_fkey" FOREIGN KEY (company_id) REFERENCES companies(id);

alter table public."stock_balances" add constraint "stock_balances_location_id_fkey" FOREIGN KEY (location_id) REFERENCES locations(id);

alter table public."stock_balances" add constraint "stock_balances_updated_by_fkey" FOREIGN KEY (updated_by) REFERENCES profiles(id);

alter table public."stock_lots" add constraint "stock_lots_article_id_fkey" FOREIGN KEY (article_id) REFERENCES articles(id);

alter table public."stock_lots" add constraint "stock_lots_company_id_fkey" FOREIGN KEY (company_id) REFERENCES companies(id);

alter table public."stock_lots" add constraint "stock_lots_location_id_fkey" FOREIGN KEY (location_id) REFERENCES locations(id);

alter table public."stock_lots" add constraint "stock_lots_received_by_fkey" FOREIGN KEY (received_by) REFERENCES profiles(id);

alter table public."stock_movement_request_items" add constraint "stock_movement_request_items_article_id_fkey" FOREIGN KEY (article_id) REFERENCES articles(id);

alter table public."stock_movement_request_items" add constraint "stock_movement_request_items_request_id_fkey" FOREIGN KEY (request_id) REFERENCES stock_movement_requests(id) ON DELETE CASCADE;

alter table public."stock_movement_requests" add constraint "stock_movement_requests_company_id_fkey" FOREIGN KEY (company_id) REFERENCES companies(id);

alter table public."stock_movement_requests" add constraint "stock_movement_requests_decided_by_fkey" FOREIGN KEY (decided_by) REFERENCES profiles(id);

alter table public."stock_movement_requests" add constraint "stock_movement_requests_from_location_id_fkey" FOREIGN KEY (from_location_id) REFERENCES locations(id);

alter table public."stock_movement_requests" add constraint "stock_movement_requests_requested_by_fkey" FOREIGN KEY (requested_by) REFERENCES profiles(id);

alter table public."stock_movement_requests" add constraint "stock_movement_requests_to_location_id_fkey" FOREIGN KEY (to_location_id) REFERENCES locations(id);

alter table public."stock_movements" add constraint "stock_movements_article_id_fkey" FOREIGN KEY (article_id) REFERENCES articles(id);

alter table public."stock_movements" add constraint "stock_movements_company_id_fkey" FOREIGN KEY (company_id) REFERENCES companies(id);

alter table public."stock_movements" add constraint "stock_movements_created_by_fkey" FOREIGN KEY (created_by) REFERENCES profiles(id);

alter table public."stock_movements" add constraint "stock_movements_from_location_id_fkey" FOREIGN KEY (from_location_id) REFERENCES locations(id);

alter table public."stock_movements" add constraint "stock_movements_to_location_id_fkey" FOREIGN KEY (to_location_id) REFERENCES locations(id);

alter table public."stock_movements" add constraint "stock_movements_vehicle_id_fkey" FOREIGN KEY (vehicle_id) REFERENCES vehicles(id);

alter table public."vehicle_areas" add constraint "vehicle_areas_area_id_fkey" FOREIGN KEY (area_id) REFERENCES areas(id) ON DELETE CASCADE;

alter table public."vehicle_areas" add constraint "vehicle_areas_vehicle_id_fkey" FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE;

alter table public."vehicle_locations" add constraint "vehicle_locations_location_id_fkey" FOREIGN KEY (location_id) REFERENCES locations(id) ON DELETE CASCADE;

alter table public."vehicle_locations" add constraint "vehicle_locations_vehicle_id_fkey" FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE;

alter table public."vehicle_models" add constraint "vehicle_models_brand_id_fkey" FOREIGN KEY (brand_id) REFERENCES vehicle_brands(id);

alter table public."vehicle_models" add constraint "vehicle_models_vehicle_type_id_fkey" FOREIGN KEY (vehicle_type_id) REFERENCES vehicle_types(id);

alter table public."vehicle_recommended_articles" add constraint "vehicle_recommended_articles_article_id_fkey" FOREIGN KEY (article_id) REFERENCES articles(id) ON DELETE CASCADE;

alter table public."vehicle_recommended_articles" add constraint "vehicle_recommended_articles_vehicle_id_fkey" FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE;

alter table public."vehicles" add constraint "vehicles_brand_id_fkey" FOREIGN KEY (brand_id) REFERENCES vehicle_brands(id);

alter table public."vehicles" add constraint "vehicles_company_id_fkey" FOREIGN KEY (company_id) REFERENCES companies(id);

alter table public."vehicles" add constraint "vehicles_location_id_fkey" FOREIGN KEY (location_id) REFERENCES locations(id);

alter table public."vehicles" add constraint "vehicles_model_id_fkey" FOREIGN KEY (model_id) REFERENCES vehicle_models(id);

alter table public."vehicles" add constraint "vehicles_vehicle_type_id_fkey" FOREIGN KEY (vehicle_type_id) REFERENCES vehicle_types(id);

CREATE INDEX areas_company_idx ON public.areas USING btree (company_id, active);

CREATE INDEX article_companies_company_idx ON public.article_companies USING btree (company_id);

CREATE UNIQUE INDEX article_one_cover_photo ON public.article_photos USING btree (article_id) WHERE is_cover;

CREATE INDEX audit_created_idx ON public.audit_log USING btree (created_at DESC);

CREATE INDEX document_library_parent_idx ON public.document_library_items USING btree (parent_id, item_type, name);

CREATE UNIQUE INDEX document_library_storage_path_unique ON public.document_library_items USING btree (storage_path) WHERE (storage_path IS NOT NULL);

CREATE UNIQUE INDEX document_library_unique_name ON public.document_library_items USING btree (COALESCE(parent_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(name));

CREATE INDEX locations_area_idx ON public.locations USING btree (area_id, active);

CREATE INDEX locations_company_idx ON public.locations USING btree (company_id);

CREATE INDEX maintenance_status_assigned_idx ON public.maintenance_orders USING btree (status, assigned_to);

CREATE INDEX notifications_profile_unread_idx ON public.notifications USING btree (profile_id, read_at, created_at DESC);

CREATE INDEX profile_areas_profile_idx ON public.profile_areas USING btree (profile_id);

CREATE INDEX profiles_role_idx ON public.profiles USING btree (role);

CREATE INDEX push_subscriptions_user_active_idx ON public.push_subscriptions USING btree (user_id, active);

CREATE INDEX stock_balances_company_location_idx ON public.stock_balances USING btree (company_id, location_id);

CREATE INDEX stock_lots_location_article_idx ON public.stock_lots USING btree (location_id, article_id, received_at);

CREATE INDEX stock_movements_created_idx ON public.stock_movements USING btree (created_at DESC);

CREATE INDEX vehicle_areas_area_idx ON public.vehicle_areas USING btree (area_id);

CREATE INDEX vehicle_locations_location_idx ON public.vehicle_locations USING btree (location_id);

CREATE UNIQUE INDEX vehicle_one_primary_location ON public.vehicle_locations USING btree (vehicle_id) WHERE is_primary;

CREATE UNIQUE INDEX vehicle_models_catalog_unique ON public.vehicle_models USING btree (COALESCE(vehicle_type_id, '00000000-0000-0000-0000-000000000000'::uuid), COALESCE(brand_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(name));

CREATE INDEX vehicles_company_location_idx ON public.vehicles USING btree (company_id, location_id);

alter table public."areas" enable row level security;

alter table public."article_companies" enable row level security;

alter table public."article_compatibilities" enable row level security;

alter table public."article_photos" enable row level security;

alter table public."article_types" enable row level security;

alter table public."articles" enable row level security;

alter table public."audit_log" enable row level security;

alter table public."companies" enable row level security;

alter table public."document_library_items" enable row level security;

alter table public."google_drive_connections" enable row level security;

alter table public."google_drive_oauth_states" enable row level security;

alter table public."locations" enable row level security;

alter table public."maintenance_expenses" enable row level security;

alter table public."maintenance_labor" enable row level security;

alter table public."maintenance_orders" enable row level security;

alter table public."maintenance_parts" enable row level security;

alter table public."maintenance_photos" enable row level security;

alter table public."notifications" enable row level security;

alter table public."password_reset_requests" enable row level security;

alter table public."profile_areas" enable row level security;

alter table public."profile_companies" enable row level security;

alter table public."profile_locations" enable row level security;

alter table public."profiles" enable row level security;

alter table public."push_subscriptions" enable row level security;

alter table public."stock_balances" enable row level security;

alter table public."stock_lots" enable row level security;

alter table public."stock_movement_request_items" enable row level security;

alter table public."stock_movement_requests" enable row level security;

alter table public."stock_movements" enable row level security;

alter table public."vehicle_areas" enable row level security;

alter table public."vehicle_brands" enable row level security;

alter table public."vehicle_locations" enable row level security;

alter table public."vehicle_models" enable row level security;

alter table public."vehicle_recommended_articles" enable row level security;

alter table public."vehicle_types" enable row level security;

alter table public."vehicles" enable row level security;

create policy "areas_admin_write" on "public"."areas" as PERMISSIVE for ALL to "authenticated" using (is_general_admin()) with check (is_general_admin());

create policy "areas_read" on "public"."areas" as PERMISSIVE for SELECT to "authenticated" using (can_access_company(company_id));

create policy "article_companies_read" on "public"."article_companies" as PERMISSIVE for SELECT to "authenticated" using (can_access_company(company_id));

create policy "article_companies_stock_write" on "public"."article_companies" as PERMISSIVE for ALL to "authenticated" using (("current_role"() = ANY (ARRAY['superadministrador'::app_role, 'administrador_general'::app_role, 'encargado_stock'::app_role]))) with check (("current_role"() = ANY (ARRAY['superadministrador'::app_role, 'administrador_general'::app_role, 'encargado_stock'::app_role])));

create policy "compatibilities_read" on "public"."article_compatibilities" as PERMISSIVE for SELECT to "authenticated" using (true);

create policy "compatibilities_stock_write" on "public"."article_compatibilities" as PERMISSIVE for ALL to "authenticated" using (("current_role"() = ANY (ARRAY['superadministrador'::app_role, 'administrador_general'::app_role, 'encargado_stock'::app_role]))) with check (("current_role"() = ANY (ARRAY['superadministrador'::app_role, 'administrador_general'::app_role, 'encargado_stock'::app_role])));

create policy "article_photos_read" on "public"."article_photos" as PERMISSIVE for SELECT to "authenticated" using (true);

create policy "article_photos_stock_write" on "public"."article_photos" as PERMISSIVE for ALL to "authenticated" using (("current_role"() = ANY (ARRAY['superadministrador'::app_role, 'administrador_general'::app_role, 'encargado_stock'::app_role]))) with check (("current_role"() = ANY (ARRAY['superadministrador'::app_role, 'administrador_general'::app_role, 'encargado_stock'::app_role])));

create policy "article_types_read" on "public"."article_types" as PERMISSIVE for SELECT to "authenticated" using (true);

create policy "article_types_stock_write" on "public"."article_types" as PERMISSIVE for ALL to "authenticated" using (("current_role"() = ANY (ARRAY['superadministrador'::app_role, 'administrador_general'::app_role, 'encargado_stock'::app_role]))) with check (("current_role"() = ANY (ARRAY['superadministrador'::app_role, 'administrador_general'::app_role, 'encargado_stock'::app_role])));

create policy "articles_read" on "public"."articles" as PERMISSIVE for SELECT to "authenticated" using (true);

create policy "articles_stock_write" on "public"."articles" as PERMISSIVE for ALL to "authenticated" using (("current_role"() = ANY (ARRAY['superadministrador'::app_role, 'administrador_general'::app_role, 'encargado_stock'::app_role]))) with check (("current_role"() = ANY (ARRAY['superadministrador'::app_role, 'administrador_general'::app_role, 'encargado_stock'::app_role])));

create policy "audit_admin_read" on "public"."audit_log" as PERMISSIVE for SELECT to "authenticated" using (is_general_admin());

create policy "companies_read" on "public"."companies" as PERMISSIVE for SELECT to "authenticated" using (can_access_company(id));

create policy "companies_super_write" on "public"."companies" as PERMISSIVE for ALL to "authenticated" using (is_super_admin()) with check (is_super_admin());

create policy "document_library_admin_delete" on "public"."document_library_items" as PERMISSIVE for DELETE to "authenticated" using (("current_role"() = ANY (ARRAY['superadministrador'::app_role, 'administrador_general'::app_role])));

create policy "document_library_admin_insert" on "public"."document_library_items" as PERMISSIVE for INSERT to "authenticated" with check ((("current_role"() = ANY (ARRAY['superadministrador'::app_role, 'administrador_general'::app_role])) AND (created_by = auth.uid())));

create policy "document_library_admin_update" on "public"."document_library_items" as PERMISSIVE for UPDATE to "authenticated" using (("current_role"() = ANY (ARRAY['superadministrador'::app_role, 'administrador_general'::app_role]))) with check (("current_role"() = ANY (ARRAY['superadministrador'::app_role, 'administrador_general'::app_role])));

create policy "document_library_read" on "public"."document_library_items" as PERMISSIVE for SELECT to "authenticated" using (("current_role"() = ANY (ARRAY['superadministrador'::app_role, 'administrador_general'::app_role, 'mecanico'::app_role])));

create policy "locations_admin_write" on "public"."locations" as PERMISSIVE for ALL to "authenticated" using (is_general_admin()) with check (is_general_admin());

create policy "locations_read" on "public"."locations" as PERMISSIVE for SELECT to "authenticated" using (can_access_company(company_id));

create policy "expenses_access" on "public"."maintenance_expenses" as PERMISSIVE for ALL to "authenticated" using (((created_by = auth.uid()) OR is_general_admin() OR (EXISTS ( SELECT 1
   FROM maintenance_orders m
  WHERE ((m.id = maintenance_expenses.maintenance_id) AND (m.assigned_to = auth.uid())))))) with check (((created_by = auth.uid()) OR is_general_admin()));

create policy "labor_access" on "public"."maintenance_labor" as PERMISSIVE for ALL to "authenticated" using (((mechanic_id = auth.uid()) OR is_general_admin() OR (EXISTS ( SELECT 1
   FROM maintenance_orders m
  WHERE ((m.id = maintenance_labor.maintenance_id) AND (m.assigned_to = auth.uid())))))) with check (((mechanic_id = auth.uid()) OR is_general_admin()));

create policy "maintenance_create" on "public"."maintenance_orders" as PERMISSIVE for INSERT to "authenticated" with check (((requested_by = auth.uid()) AND can_access_company(company_id)));

create policy "maintenance_read" on "public"."maintenance_orders" as PERMISSIVE for SELECT to "authenticated" using ((can_access_company(company_id) AND ((requested_by = auth.uid()) OR (assigned_to = auth.uid()) OR is_general_admin() OR can_access_location(location_id))));

create policy "maintenance_update" on "public"."maintenance_orders" as PERMISSIVE for UPDATE to "authenticated" using (((assigned_to = auth.uid()) OR is_general_admin() OR can_access_location(location_id))) with check (((assigned_to = auth.uid()) OR is_general_admin() OR can_access_location(location_id)));

create policy "parts_access" on "public"."maintenance_parts" as PERMISSIVE for ALL to "authenticated" using ((is_general_admin() OR (EXISTS ( SELECT 1
   FROM maintenance_orders m
  WHERE ((m.id = maintenance_parts.maintenance_id) AND ((m.assigned_to = auth.uid()) OR (m.requested_by = auth.uid()))))))) with check ((is_general_admin() OR (EXISTS ( SELECT 1
   FROM maintenance_orders m
  WHERE ((m.id = maintenance_parts.maintenance_id) AND (m.assigned_to = auth.uid()))))));

create policy "maintenance_photos_access" on "public"."maintenance_photos" as PERMISSIVE for ALL to "authenticated" using (((uploaded_by = auth.uid()) OR is_general_admin() OR (EXISTS ( SELECT 1
   FROM maintenance_orders m
  WHERE ((m.id = maintenance_photos.maintenance_id) AND ((m.assigned_to = auth.uid()) OR (m.requested_by = auth.uid()))))))) with check (((uploaded_by = auth.uid()) OR is_general_admin()));

create policy "notifications_own" on "public"."notifications" as PERMISSIVE for SELECT to "authenticated" using ((profile_id = auth.uid()));

create policy "notifications_own_update" on "public"."notifications" as PERMISSIVE for UPDATE to "authenticated" using ((profile_id = auth.uid())) with check ((profile_id = auth.uid()));

create policy "password_request_create" on "public"."password_reset_requests" as PERMISSIVE for INSERT to "anon", "authenticated" with check ((status = 'pendiente'::password_request_status));

create policy "password_request_super_read" on "public"."password_reset_requests" as PERMISSIVE for SELECT to "authenticated" using (is_super_admin());

create policy "password_request_super_update" on "public"."password_reset_requests" as PERMISSIVE for UPDATE to "authenticated" using (is_super_admin()) with check (is_super_admin());

create policy "profile_areas_admin_write" on "public"."profile_areas" as PERMISSIVE for ALL to "authenticated" using (is_general_admin()) with check (is_general_admin());

create policy "profile_areas_read" on "public"."profile_areas" as PERMISSIVE for SELECT to "authenticated" using (((profile_id = auth.uid()) OR is_general_admin()));

create policy "profile_companies_read" on "public"."profile_companies" as PERMISSIVE for SELECT to "authenticated" using (((profile_id = auth.uid()) OR is_general_admin()));

create policy "profile_companies_super_write" on "public"."profile_companies" as PERMISSIVE for ALL to "authenticated" using (is_super_admin()) with check (is_super_admin());

create policy "profile_locations_admin_write" on "public"."profile_locations" as PERMISSIVE for ALL to "authenticated" using (is_general_admin()) with check (is_general_admin());

create policy "profile_locations_read" on "public"."profile_locations" as PERMISSIVE for SELECT to "authenticated" using (((profile_id = auth.uid()) OR is_general_admin()));

create policy "profiles_self_read" on "public"."profiles" as PERMISSIVE for SELECT to "authenticated" using (((id = auth.uid()) OR is_general_admin()));

create policy "profiles_self_update" on "public"."profiles" as PERMISSIVE for UPDATE to "authenticated" using (((id = auth.uid()) OR is_super_admin())) with check (((id = auth.uid()) OR is_super_admin()));

create policy "push_subscriptions_delete_own" on "public"."push_subscriptions" as PERMISSIVE for DELETE to "authenticated" using ((user_id = auth.uid()));

create policy "push_subscriptions_insert_own" on "public"."push_subscriptions" as PERMISSIVE for INSERT to "authenticated" with check ((user_id = auth.uid()));

create policy "push_subscriptions_read_own" on "public"."push_subscriptions" as PERMISSIVE for SELECT to "authenticated" using ((user_id = auth.uid()));

create policy "push_subscriptions_update_own" on "public"."push_subscriptions" as PERMISSIVE for UPDATE to "authenticated" using ((user_id = auth.uid())) with check ((user_id = auth.uid()));

create policy "balances_read" on "public"."stock_balances" as PERMISSIVE for SELECT to "authenticated" using ((can_access_company(company_id) AND can_access_location(location_id)));

create policy "balances_stock_write" on "public"."stock_balances" as PERMISSIVE for ALL to "authenticated" using ((("current_role"() = ANY (ARRAY['superadministrador'::app_role, 'administrador_general'::app_role, 'encargado_stock'::app_role, 'encargado_frente'::app_role, 'mecanico'::app_role])) AND can_access_company(company_id) AND can_access_location(location_id))) with check ((("current_role"() = ANY (ARRAY['superadministrador'::app_role, 'administrador_general'::app_role, 'encargado_stock'::app_role, 'encargado_frente'::app_role, 'mecanico'::app_role])) AND can_access_company(company_id) AND can_access_location(location_id)));

create policy "stock_lots_read" on "public"."stock_lots" as PERMISSIVE for SELECT to "authenticated" using ((can_access_company(company_id) AND can_access_location(location_id)));

create policy "stock_lots_stock_write" on "public"."stock_lots" as PERMISSIVE for ALL to "authenticated" using (("current_role"() = ANY (ARRAY['superadministrador'::app_role, 'administrador_general'::app_role, 'encargado_stock'::app_role]))) with check ((("current_role"() = ANY (ARRAY['superadministrador'::app_role, 'administrador_general'::app_role, 'encargado_stock'::app_role])) AND can_access_location(location_id)));

create policy "movement_request_items_create" on "public"."stock_movement_request_items" as PERMISSIVE for INSERT to "authenticated" with check ((EXISTS ( SELECT 1
   FROM stock_movement_requests r
  WHERE ((r.id = stock_movement_request_items.request_id) AND (r.requested_by = auth.uid()) AND (r.status = 'pendiente'::request_status)))));

create policy "movement_request_items_read" on "public"."stock_movement_request_items" as PERMISSIVE for SELECT to "authenticated" using ((EXISTS ( SELECT 1
   FROM stock_movement_requests r
  WHERE ((r.id = stock_movement_request_items.request_id) AND ((r.requested_by = auth.uid()) OR is_general_admin() OR can_access_location(r.from_location_id) OR can_access_location(r.to_location_id))))));

create policy "movement_requests_create" on "public"."stock_movement_requests" as PERMISSIVE for INSERT to "authenticated" with check (((requested_by = auth.uid()) AND can_access_company(company_id)));

create policy "movement_requests_read" on "public"."stock_movement_requests" as PERMISSIVE for SELECT to "authenticated" using (((requested_by = auth.uid()) OR is_general_admin() OR can_access_location(from_location_id) OR can_access_location(to_location_id)));

create policy "movement_requests_update" on "public"."stock_movement_requests" as PERMISSIVE for UPDATE to "authenticated" using (("current_role"() = ANY (ARRAY['superadministrador'::app_role, 'administrador_general'::app_role, 'encargado_stock'::app_role, 'encargado_frente'::app_role]))) with check (("current_role"() = ANY (ARRAY['superadministrador'::app_role, 'administrador_general'::app_role, 'encargado_stock'::app_role, 'encargado_frente'::app_role])));

create policy "movements_read" on "public"."stock_movements" as PERMISSIVE for SELECT to "authenticated" using ((can_access_company(company_id) AND ((from_location_id IS NULL) OR can_access_location(from_location_id)) AND ((to_location_id IS NULL) OR can_access_location(to_location_id))));

create policy "vehicle_areas_admin_write" on "public"."vehicle_areas" as PERMISSIVE for ALL to "authenticated" using (is_general_admin()) with check (is_general_admin());

create policy "vehicle_areas_read" on "public"."vehicle_areas" as PERMISSIVE for SELECT to "authenticated" using ((EXISTS ( SELECT 1
   FROM areas a
  WHERE ((a.id = vehicle_areas.area_id) AND can_access_company(a.company_id)))));

create policy "vehicle_brands_admin_write" on "public"."vehicle_brands" as PERMISSIVE for ALL to "authenticated" using (is_general_admin()) with check (is_general_admin());

create policy "vehicle_brands_read" on "public"."vehicle_brands" as PERMISSIVE for SELECT to "authenticated" using (true);

create policy "vehicle_locations_admin_write" on "public"."vehicle_locations" as PERMISSIVE for ALL to "authenticated" using (is_general_admin()) with check (is_general_admin());

create policy "vehicle_locations_read" on "public"."vehicle_locations" as PERMISSIVE for SELECT to "authenticated" using (can_access_location(location_id));

create policy "vehicle_models_admin_write" on "public"."vehicle_models" as PERMISSIVE for ALL to "authenticated" using (is_general_admin()) with check (is_general_admin());

create policy "vehicle_models_read" on "public"."vehicle_models" as PERMISSIVE for SELECT to "authenticated" using (true);

create policy "recommended_articles_read" on "public"."vehicle_recommended_articles" as PERMISSIVE for SELECT to "authenticated" using ((EXISTS ( SELECT 1
   FROM vehicles v
  WHERE ((v.id = vehicle_recommended_articles.vehicle_id) AND can_access_company(v.company_id)))));

create policy "recommended_articles_stock_write" on "public"."vehicle_recommended_articles" as PERMISSIVE for ALL to "authenticated" using (("current_role"() = ANY (ARRAY['superadministrador'::app_role, 'administrador_general'::app_role, 'encargado_stock'::app_role]))) with check (("current_role"() = ANY (ARRAY['superadministrador'::app_role, 'administrador_general'::app_role, 'encargado_stock'::app_role])));

create policy "vehicle_types_admin_write" on "public"."vehicle_types" as PERMISSIVE for ALL to "authenticated" using (is_general_admin()) with check (is_general_admin());

create policy "vehicle_types_read" on "public"."vehicle_types" as PERMISSIVE for SELECT to "authenticated" using (true);

create policy "vehicles_admin_write" on "public"."vehicles" as PERMISSIVE for ALL to "authenticated" using (is_general_admin()) with check (is_general_admin());

create policy "vehicles_read" on "public"."vehicles" as PERMISSIVE for SELECT to "authenticated" using ((can_access_company(company_id) AND (is_general_admin() OR (location_id IS NULL) OR can_access_location(location_id))));

create policy "manuales_archivos_admin_delete" on "storage"."objects" as PERMISSIVE for DELETE to "authenticated" using (((bucket_id = 'manuales-archivos'::text) AND ("current_role"() = ANY (ARRAY['superadministrador'::app_role, 'administrador_general'::app_role]))));

create policy "manuales_archivos_admin_insert" on "storage"."objects" as PERMISSIVE for INSERT to "authenticated" with check (((bucket_id = 'manuales-archivos'::text) AND ("current_role"() = ANY (ARRAY['superadministrador'::app_role, 'administrador_general'::app_role]))));

create policy "manuales_archivos_admin_update" on "storage"."objects" as PERMISSIVE for UPDATE to "authenticated" using (((bucket_id = 'manuales-archivos'::text) AND ("current_role"() = ANY (ARRAY['superadministrador'::app_role, 'administrador_general'::app_role])))) with check (((bucket_id = 'manuales-archivos'::text) AND ("current_role"() = ANY (ARRAY['superadministrador'::app_role, 'administrador_general'::app_role]))));

create policy "manuales_archivos_read" on "storage"."objects" as PERMISSIVE for SELECT to "authenticated" using (((bucket_id = 'manuales-archivos'::text) AND ("current_role"() = ANY (ARRAY['superadministrador'::app_role, 'administrador_general'::app_role, 'mecanico'::app_role]))));

revoke all on table public."areas" from PUBLIC, anon, authenticated, service_role;

revoke all on table public."article_companies" from PUBLIC, anon, authenticated, service_role;

revoke all on table public."article_compatibilities" from PUBLIC, anon, authenticated, service_role;

revoke all on table public."article_photos" from PUBLIC, anon, authenticated, service_role;

revoke all on table public."article_types" from PUBLIC, anon, authenticated, service_role;

revoke all on table public."articles" from PUBLIC, anon, authenticated, service_role;

revoke all on table public."audit_log" from PUBLIC, anon, authenticated, service_role;

revoke all on table public."companies" from PUBLIC, anon, authenticated, service_role;

revoke all on table public."document_library_items" from PUBLIC, anon, authenticated, service_role;

revoke all on table public."google_drive_connections" from PUBLIC, anon, authenticated, service_role;

revoke all on table public."google_drive_oauth_states" from PUBLIC, anon, authenticated, service_role;

revoke all on table public."locations" from PUBLIC, anon, authenticated, service_role;

revoke all on table public."maintenance_expenses" from PUBLIC, anon, authenticated, service_role;

revoke all on table public."maintenance_labor" from PUBLIC, anon, authenticated, service_role;

revoke all on table public."maintenance_orders" from PUBLIC, anon, authenticated, service_role;

revoke all on table public."maintenance_parts" from PUBLIC, anon, authenticated, service_role;

revoke all on table public."maintenance_photos" from PUBLIC, anon, authenticated, service_role;

revoke all on table public."notifications" from PUBLIC, anon, authenticated, service_role;

revoke all on table public."password_reset_requests" from PUBLIC, anon, authenticated, service_role;

revoke all on table public."profile_areas" from PUBLIC, anon, authenticated, service_role;

revoke all on table public."profile_companies" from PUBLIC, anon, authenticated, service_role;

revoke all on table public."profile_locations" from PUBLIC, anon, authenticated, service_role;

revoke all on table public."profiles" from PUBLIC, anon, authenticated, service_role;

revoke all on table public."push_subscriptions" from PUBLIC, anon, authenticated, service_role;

revoke all on table public."stock_balances" from PUBLIC, anon, authenticated, service_role;

revoke all on table public."stock_lots" from PUBLIC, anon, authenticated, service_role;

revoke all on table public."stock_movement_request_items" from PUBLIC, anon, authenticated, service_role;

revoke all on table public."stock_movement_requests" from PUBLIC, anon, authenticated, service_role;

revoke all on table public."stock_movements" from PUBLIC, anon, authenticated, service_role;

revoke all on table public."vehicle_areas" from PUBLIC, anon, authenticated, service_role;

revoke all on table public."vehicle_brands" from PUBLIC, anon, authenticated, service_role;

revoke all on table public."vehicle_locations" from PUBLIC, anon, authenticated, service_role;

revoke all on table public."vehicle_models" from PUBLIC, anon, authenticated, service_role;

revoke all on table public."vehicle_recommended_articles" from PUBLIC, anon, authenticated, service_role;

revoke all on table public."vehicle_types" from PUBLIC, anon, authenticated, service_role;

revoke all on table public."vehicles" from PUBLIC, anon, authenticated, service_role;

grant INSERT on table public."profile_companies" to "postgres" with grant option;

grant SELECT on table public."profile_companies" to "postgres" with grant option;

grant UPDATE on table public."profile_companies" to "postgres" with grant option;

grant DELETE on table public."profile_companies" to "postgres" with grant option;

grant TRUNCATE on table public."profile_companies" to "postgres" with grant option;

grant REFERENCES on table public."profile_companies" to "postgres" with grant option;

grant TRIGGER on table public."profile_companies" to "postgres" with grant option;

grant TRUNCATE on table public."profile_companies" to "anon";

grant REFERENCES on table public."profile_companies" to "anon";

grant TRIGGER on table public."profile_companies" to "anon";

grant SELECT on table public."profile_companies" to "authenticated";

grant TRUNCATE on table public."profile_companies" to "authenticated";

grant REFERENCES on table public."profile_companies" to "authenticated";

grant TRIGGER on table public."profile_companies" to "authenticated";

grant INSERT on table public."profile_companies" to "service_role";

grant SELECT on table public."profile_companies" to "service_role";

grant UPDATE on table public."profile_companies" to "service_role";

grant DELETE on table public."profile_companies" to "service_role";

grant TRUNCATE on table public."profile_companies" to "service_role";

grant REFERENCES on table public."profile_companies" to "service_role";

grant TRIGGER on table public."profile_companies" to "service_role";

grant INSERT on table public."profile_locations" to "postgres" with grant option;

grant SELECT on table public."profile_locations" to "postgres" with grant option;

grant UPDATE on table public."profile_locations" to "postgres" with grant option;

grant DELETE on table public."profile_locations" to "postgres" with grant option;

grant TRUNCATE on table public."profile_locations" to "postgres" with grant option;

grant REFERENCES on table public."profile_locations" to "postgres" with grant option;

grant TRIGGER on table public."profile_locations" to "postgres" with grant option;

grant TRUNCATE on table public."profile_locations" to "anon";

grant REFERENCES on table public."profile_locations" to "anon";

grant TRIGGER on table public."profile_locations" to "anon";

grant SELECT on table public."profile_locations" to "authenticated";

grant TRUNCATE on table public."profile_locations" to "authenticated";

grant REFERENCES on table public."profile_locations" to "authenticated";

grant TRIGGER on table public."profile_locations" to "authenticated";

grant INSERT on table public."profile_locations" to "service_role";

grant SELECT on table public."profile_locations" to "service_role";

grant UPDATE on table public."profile_locations" to "service_role";

grant DELETE on table public."profile_locations" to "service_role";

grant TRUNCATE on table public."profile_locations" to "service_role";

grant REFERENCES on table public."profile_locations" to "service_role";

grant TRIGGER on table public."profile_locations" to "service_role";

grant INSERT on table public."locations" to "postgres" with grant option;

grant SELECT on table public."locations" to "postgres" with grant option;

grant UPDATE on table public."locations" to "postgres" with grant option;

grant DELETE on table public."locations" to "postgres" with grant option;

grant TRUNCATE on table public."locations" to "postgres" with grant option;

grant REFERENCES on table public."locations" to "postgres" with grant option;

grant TRIGGER on table public."locations" to "postgres" with grant option;

grant TRUNCATE on table public."locations" to "anon";

grant REFERENCES on table public."locations" to "anon";

grant TRIGGER on table public."locations" to "anon";

grant INSERT on table public."locations" to "authenticated";

grant SELECT on table public."locations" to "authenticated";

grant UPDATE on table public."locations" to "authenticated";

grant DELETE on table public."locations" to "authenticated";

grant TRUNCATE on table public."locations" to "authenticated";

grant REFERENCES on table public."locations" to "authenticated";

grant TRIGGER on table public."locations" to "authenticated";

grant SELECT on table public."locations" to "service_role";

grant TRUNCATE on table public."locations" to "service_role";

grant REFERENCES on table public."locations" to "service_role";

grant TRIGGER on table public."locations" to "service_role";

grant INSERT on table public."profiles" to "postgres" with grant option;

grant SELECT on table public."profiles" to "postgres" with grant option;

grant UPDATE on table public."profiles" to "postgres" with grant option;

grant DELETE on table public."profiles" to "postgres" with grant option;

grant TRUNCATE on table public."profiles" to "postgres" with grant option;

grant REFERENCES on table public."profiles" to "postgres" with grant option;

grant TRIGGER on table public."profiles" to "postgres" with grant option;

grant TRUNCATE on table public."profiles" to "anon";

grant REFERENCES on table public."profiles" to "anon";

grant TRIGGER on table public."profiles" to "anon";

grant SELECT on table public."profiles" to "authenticated";

grant UPDATE on table public."profiles" to "authenticated";

grant TRUNCATE on table public."profiles" to "authenticated";

grant REFERENCES on table public."profiles" to "authenticated";

grant TRIGGER on table public."profiles" to "authenticated";

grant INSERT on table public."profiles" to "service_role";

grant SELECT on table public."profiles" to "service_role";

grant UPDATE on table public."profiles" to "service_role";

grant DELETE on table public."profiles" to "service_role";

grant TRUNCATE on table public."profiles" to "service_role";

grant REFERENCES on table public."profiles" to "service_role";

grant TRIGGER on table public."profiles" to "service_role";

grant INSERT on table public."companies" to "postgres" with grant option;

grant SELECT on table public."companies" to "postgres" with grant option;

grant UPDATE on table public."companies" to "postgres" with grant option;

grant DELETE on table public."companies" to "postgres" with grant option;

grant TRUNCATE on table public."companies" to "postgres" with grant option;

grant REFERENCES on table public."companies" to "postgres" with grant option;

grant TRIGGER on table public."companies" to "postgres" with grant option;

grant TRUNCATE on table public."companies" to "anon";

grant REFERENCES on table public."companies" to "anon";

grant TRIGGER on table public."companies" to "anon";

grant INSERT on table public."companies" to "authenticated";

grant SELECT on table public."companies" to "authenticated";

grant UPDATE on table public."companies" to "authenticated";

grant TRUNCATE on table public."companies" to "authenticated";

grant REFERENCES on table public."companies" to "authenticated";

grant TRIGGER on table public."companies" to "authenticated";

grant SELECT on table public."companies" to "service_role";

grant TRUNCATE on table public."companies" to "service_role";

grant REFERENCES on table public."companies" to "service_role";

grant TRIGGER on table public."companies" to "service_role";

grant INSERT on table public."article_compatibilities" to "postgres" with grant option;

grant SELECT on table public."article_compatibilities" to "postgres" with grant option;

grant UPDATE on table public."article_compatibilities" to "postgres" with grant option;

grant DELETE on table public."article_compatibilities" to "postgres" with grant option;

grant TRUNCATE on table public."article_compatibilities" to "postgres" with grant option;

grant REFERENCES on table public."article_compatibilities" to "postgres" with grant option;

grant TRIGGER on table public."article_compatibilities" to "postgres" with grant option;

grant TRUNCATE on table public."article_compatibilities" to "anon";

grant REFERENCES on table public."article_compatibilities" to "anon";

grant TRIGGER on table public."article_compatibilities" to "anon";

grant TRUNCATE on table public."article_compatibilities" to "authenticated";

grant REFERENCES on table public."article_compatibilities" to "authenticated";

grant TRIGGER on table public."article_compatibilities" to "authenticated";

grant TRUNCATE on table public."article_compatibilities" to "service_role";

grant REFERENCES on table public."article_compatibilities" to "service_role";

grant TRIGGER on table public."article_compatibilities" to "service_role";

grant INSERT on table public."article_photos" to "postgres" with grant option;

grant SELECT on table public."article_photos" to "postgres" with grant option;

grant UPDATE on table public."article_photos" to "postgres" with grant option;

grant DELETE on table public."article_photos" to "postgres" with grant option;

grant TRUNCATE on table public."article_photos" to "postgres" with grant option;

grant REFERENCES on table public."article_photos" to "postgres" with grant option;

grant TRIGGER on table public."article_photos" to "postgres" with grant option;

grant TRUNCATE on table public."article_photos" to "anon";

grant REFERENCES on table public."article_photos" to "anon";

grant TRIGGER on table public."article_photos" to "anon";

grant TRUNCATE on table public."article_photos" to "authenticated";

grant REFERENCES on table public."article_photos" to "authenticated";

grant TRIGGER on table public."article_photos" to "authenticated";

grant TRUNCATE on table public."article_photos" to "service_role";

grant REFERENCES on table public."article_photos" to "service_role";

grant TRIGGER on table public."article_photos" to "service_role";

grant INSERT on table public."stock_movements" to "postgres" with grant option;

grant SELECT on table public."stock_movements" to "postgres" with grant option;

grant UPDATE on table public."stock_movements" to "postgres" with grant option;

grant DELETE on table public."stock_movements" to "postgres" with grant option;

grant TRUNCATE on table public."stock_movements" to "postgres" with grant option;

grant REFERENCES on table public."stock_movements" to "postgres" with grant option;

grant TRIGGER on table public."stock_movements" to "postgres" with grant option;

grant TRUNCATE on table public."stock_movements" to "anon";

grant REFERENCES on table public."stock_movements" to "anon";

grant TRIGGER on table public."stock_movements" to "anon";

grant TRUNCATE on table public."stock_movements" to "authenticated";

grant REFERENCES on table public."stock_movements" to "authenticated";

grant TRIGGER on table public."stock_movements" to "authenticated";

grant TRUNCATE on table public."stock_movements" to "service_role";

grant REFERENCES on table public."stock_movements" to "service_role";

grant TRIGGER on table public."stock_movements" to "service_role";

grant INSERT on table public."stock_movement_requests" to "postgres" with grant option;

grant SELECT on table public."stock_movement_requests" to "postgres" with grant option;

grant UPDATE on table public."stock_movement_requests" to "postgres" with grant option;

grant DELETE on table public."stock_movement_requests" to "postgres" with grant option;

grant TRUNCATE on table public."stock_movement_requests" to "postgres" with grant option;

grant REFERENCES on table public."stock_movement_requests" to "postgres" with grant option;

grant TRIGGER on table public."stock_movement_requests" to "postgres" with grant option;

grant TRUNCATE on table public."stock_movement_requests" to "anon";

grant REFERENCES on table public."stock_movement_requests" to "anon";

grant TRIGGER on table public."stock_movement_requests" to "anon";

grant TRUNCATE on table public."stock_movement_requests" to "authenticated";

grant REFERENCES on table public."stock_movement_requests" to "authenticated";

grant TRIGGER on table public."stock_movement_requests" to "authenticated";

grant TRUNCATE on table public."stock_movement_requests" to "service_role";

grant REFERENCES on table public."stock_movement_requests" to "service_role";

grant TRIGGER on table public."stock_movement_requests" to "service_role";

grant INSERT on table public."stock_movement_request_items" to "postgres" with grant option;

grant SELECT on table public."stock_movement_request_items" to "postgres" with grant option;

grant UPDATE on table public."stock_movement_request_items" to "postgres" with grant option;

grant DELETE on table public."stock_movement_request_items" to "postgres" with grant option;

grant TRUNCATE on table public."stock_movement_request_items" to "postgres" with grant option;

grant REFERENCES on table public."stock_movement_request_items" to "postgres" with grant option;

grant TRIGGER on table public."stock_movement_request_items" to "postgres" with grant option;

grant TRUNCATE on table public."stock_movement_request_items" to "anon";

grant REFERENCES on table public."stock_movement_request_items" to "anon";

grant TRIGGER on table public."stock_movement_request_items" to "anon";

grant TRUNCATE on table public."stock_movement_request_items" to "authenticated";

grant REFERENCES on table public."stock_movement_request_items" to "authenticated";

grant TRIGGER on table public."stock_movement_request_items" to "authenticated";

grant TRUNCATE on table public."stock_movement_request_items" to "service_role";

grant REFERENCES on table public."stock_movement_request_items" to "service_role";

grant TRIGGER on table public."stock_movement_request_items" to "service_role";

grant INSERT on table public."maintenance_labor" to "postgres" with grant option;

grant SELECT on table public."maintenance_labor" to "postgres" with grant option;

grant UPDATE on table public."maintenance_labor" to "postgres" with grant option;

grant DELETE on table public."maintenance_labor" to "postgres" with grant option;

grant TRUNCATE on table public."maintenance_labor" to "postgres" with grant option;

grant REFERENCES on table public."maintenance_labor" to "postgres" with grant option;

grant TRIGGER on table public."maintenance_labor" to "postgres" with grant option;

grant TRUNCATE on table public."maintenance_labor" to "anon";

grant REFERENCES on table public."maintenance_labor" to "anon";

grant TRIGGER on table public."maintenance_labor" to "anon";

grant TRUNCATE on table public."maintenance_labor" to "authenticated";

grant REFERENCES on table public."maintenance_labor" to "authenticated";

grant TRIGGER on table public."maintenance_labor" to "authenticated";

grant TRUNCATE on table public."maintenance_labor" to "service_role";

grant REFERENCES on table public."maintenance_labor" to "service_role";

grant TRIGGER on table public."maintenance_labor" to "service_role";

grant INSERT on table public."maintenance_parts" to "postgres" with grant option;

grant SELECT on table public."maintenance_parts" to "postgres" with grant option;

grant UPDATE on table public."maintenance_parts" to "postgres" with grant option;

grant DELETE on table public."maintenance_parts" to "postgres" with grant option;

grant TRUNCATE on table public."maintenance_parts" to "postgres" with grant option;

grant REFERENCES on table public."maintenance_parts" to "postgres" with grant option;

grant TRIGGER on table public."maintenance_parts" to "postgres" with grant option;

grant TRUNCATE on table public."maintenance_parts" to "anon";

grant REFERENCES on table public."maintenance_parts" to "anon";

grant TRIGGER on table public."maintenance_parts" to "anon";

grant TRUNCATE on table public."maintenance_parts" to "authenticated";

grant REFERENCES on table public."maintenance_parts" to "authenticated";

grant TRIGGER on table public."maintenance_parts" to "authenticated";

grant TRUNCATE on table public."maintenance_parts" to "service_role";

grant REFERENCES on table public."maintenance_parts" to "service_role";

grant TRIGGER on table public."maintenance_parts" to "service_role";

grant INSERT on table public."maintenance_expenses" to "postgres" with grant option;

grant SELECT on table public."maintenance_expenses" to "postgres" with grant option;

grant UPDATE on table public."maintenance_expenses" to "postgres" with grant option;

grant DELETE on table public."maintenance_expenses" to "postgres" with grant option;

grant TRUNCATE on table public."maintenance_expenses" to "postgres" with grant option;

grant REFERENCES on table public."maintenance_expenses" to "postgres" with grant option;

grant TRIGGER on table public."maintenance_expenses" to "postgres" with grant option;

grant TRUNCATE on table public."maintenance_expenses" to "anon";

grant REFERENCES on table public."maintenance_expenses" to "anon";

grant TRIGGER on table public."maintenance_expenses" to "anon";

grant TRUNCATE on table public."maintenance_expenses" to "authenticated";

grant REFERENCES on table public."maintenance_expenses" to "authenticated";

grant TRIGGER on table public."maintenance_expenses" to "authenticated";

grant TRUNCATE on table public."maintenance_expenses" to "service_role";

grant REFERENCES on table public."maintenance_expenses" to "service_role";

grant TRIGGER on table public."maintenance_expenses" to "service_role";

grant INSERT on table public."maintenance_photos" to "postgres" with grant option;

grant SELECT on table public."maintenance_photos" to "postgres" with grant option;

grant UPDATE on table public."maintenance_photos" to "postgres" with grant option;

grant DELETE on table public."maintenance_photos" to "postgres" with grant option;

grant TRUNCATE on table public."maintenance_photos" to "postgres" with grant option;

grant REFERENCES on table public."maintenance_photos" to "postgres" with grant option;

grant TRIGGER on table public."maintenance_photos" to "postgres" with grant option;

grant TRUNCATE on table public."maintenance_photos" to "anon";

grant REFERENCES on table public."maintenance_photos" to "anon";

grant TRIGGER on table public."maintenance_photos" to "anon";

grant TRUNCATE on table public."maintenance_photos" to "authenticated";

grant REFERENCES on table public."maintenance_photos" to "authenticated";

grant TRIGGER on table public."maintenance_photos" to "authenticated";

grant TRUNCATE on table public."maintenance_photos" to "service_role";

grant REFERENCES on table public."maintenance_photos" to "service_role";

grant TRIGGER on table public."maintenance_photos" to "service_role";

grant INSERT on table public."notifications" to "postgres" with grant option;

grant SELECT on table public."notifications" to "postgres" with grant option;

grant UPDATE on table public."notifications" to "postgres" with grant option;

grant DELETE on table public."notifications" to "postgres" with grant option;

grant TRUNCATE on table public."notifications" to "postgres" with grant option;

grant REFERENCES on table public."notifications" to "postgres" with grant option;

grant TRIGGER on table public."notifications" to "postgres" with grant option;

grant TRUNCATE on table public."notifications" to "anon";

grant REFERENCES on table public."notifications" to "anon";

grant TRIGGER on table public."notifications" to "anon";

grant TRUNCATE on table public."notifications" to "authenticated";

grant REFERENCES on table public."notifications" to "authenticated";

grant TRIGGER on table public."notifications" to "authenticated";

grant TRUNCATE on table public."notifications" to "service_role";

grant REFERENCES on table public."notifications" to "service_role";

grant TRIGGER on table public."notifications" to "service_role";

grant INSERT on table public."audit_log" to "postgres" with grant option;

grant SELECT on table public."audit_log" to "postgres" with grant option;

grant UPDATE on table public."audit_log" to "postgres" with grant option;

grant DELETE on table public."audit_log" to "postgres" with grant option;

grant TRUNCATE on table public."audit_log" to "postgres" with grant option;

grant REFERENCES on table public."audit_log" to "postgres" with grant option;

grant TRIGGER on table public."audit_log" to "postgres" with grant option;

grant TRUNCATE on table public."audit_log" to "anon";

grant REFERENCES on table public."audit_log" to "anon";

grant TRIGGER on table public."audit_log" to "anon";

grant TRUNCATE on table public."audit_log" to "authenticated";

grant REFERENCES on table public."audit_log" to "authenticated";

grant TRIGGER on table public."audit_log" to "authenticated";

grant TRUNCATE on table public."audit_log" to "service_role";

grant REFERENCES on table public."audit_log" to "service_role";

grant TRIGGER on table public."audit_log" to "service_role";

grant INSERT on table public."password_reset_requests" to "postgres" with grant option;

grant SELECT on table public."password_reset_requests" to "postgres" with grant option;

grant UPDATE on table public."password_reset_requests" to "postgres" with grant option;

grant DELETE on table public."password_reset_requests" to "postgres" with grant option;

grant TRUNCATE on table public."password_reset_requests" to "postgres" with grant option;

grant REFERENCES on table public."password_reset_requests" to "postgres" with grant option;

grant TRIGGER on table public."password_reset_requests" to "postgres" with grant option;

grant INSERT on table public."password_reset_requests" to "anon";

grant TRUNCATE on table public."password_reset_requests" to "anon";

grant REFERENCES on table public."password_reset_requests" to "anon";

grant TRIGGER on table public."password_reset_requests" to "anon";

grant SELECT on table public."password_reset_requests" to "authenticated";

grant UPDATE on table public."password_reset_requests" to "authenticated";

grant TRUNCATE on table public."password_reset_requests" to "authenticated";

grant REFERENCES on table public."password_reset_requests" to "authenticated";

grant TRIGGER on table public."password_reset_requests" to "authenticated";

grant SELECT on table public."password_reset_requests" to "service_role";

grant UPDATE on table public."password_reset_requests" to "service_role";

grant TRUNCATE on table public."password_reset_requests" to "service_role";

grant REFERENCES on table public."password_reset_requests" to "service_role";

grant TRIGGER on table public."password_reset_requests" to "service_role";

grant INSERT on table public."stock_balances" to "postgres" with grant option;

grant SELECT on table public."stock_balances" to "postgres" with grant option;

grant UPDATE on table public."stock_balances" to "postgres" with grant option;

grant DELETE on table public."stock_balances" to "postgres" with grant option;

grant TRUNCATE on table public."stock_balances" to "postgres" with grant option;

grant REFERENCES on table public."stock_balances" to "postgres" with grant option;

grant TRIGGER on table public."stock_balances" to "postgres" with grant option;

grant TRUNCATE on table public."stock_balances" to "anon";

grant REFERENCES on table public."stock_balances" to "anon";

grant TRIGGER on table public."stock_balances" to "anon";

grant INSERT on table public."stock_balances" to "authenticated";

grant SELECT on table public."stock_balances" to "authenticated";

grant UPDATE on table public."stock_balances" to "authenticated";

grant DELETE on table public."stock_balances" to "authenticated";

grant TRUNCATE on table public."stock_balances" to "authenticated";

grant REFERENCES on table public."stock_balances" to "authenticated";

grant TRIGGER on table public."stock_balances" to "authenticated";

grant TRUNCATE on table public."stock_balances" to "service_role";

grant REFERENCES on table public."stock_balances" to "service_role";

grant TRIGGER on table public."stock_balances" to "service_role";

grant INSERT on table public."maintenance_orders" to "postgres" with grant option;

grant SELECT on table public."maintenance_orders" to "postgres" with grant option;

grant UPDATE on table public."maintenance_orders" to "postgres" with grant option;

grant DELETE on table public."maintenance_orders" to "postgres" with grant option;

grant TRUNCATE on table public."maintenance_orders" to "postgres" with grant option;

grant REFERENCES on table public."maintenance_orders" to "postgres" with grant option;

grant TRIGGER on table public."maintenance_orders" to "postgres" with grant option;

grant TRUNCATE on table public."maintenance_orders" to "anon";

grant REFERENCES on table public."maintenance_orders" to "anon";

grant TRIGGER on table public."maintenance_orders" to "anon";

grant INSERT on table public."maintenance_orders" to "authenticated";

grant SELECT on table public."maintenance_orders" to "authenticated";

grant UPDATE on table public."maintenance_orders" to "authenticated";

grant TRUNCATE on table public."maintenance_orders" to "authenticated";

grant REFERENCES on table public."maintenance_orders" to "authenticated";

grant TRIGGER on table public."maintenance_orders" to "authenticated";

grant TRUNCATE on table public."maintenance_orders" to "service_role";

grant REFERENCES on table public."maintenance_orders" to "service_role";

grant TRIGGER on table public."maintenance_orders" to "service_role";

grant INSERT on table public."vehicles" to "postgres" with grant option;

grant SELECT on table public."vehicles" to "postgres" with grant option;

grant UPDATE on table public."vehicles" to "postgres" with grant option;

grant DELETE on table public."vehicles" to "postgres" with grant option;

grant TRUNCATE on table public."vehicles" to "postgres" with grant option;

grant REFERENCES on table public."vehicles" to "postgres" with grant option;

grant TRIGGER on table public."vehicles" to "postgres" with grant option;

grant TRUNCATE on table public."vehicles" to "anon";

grant REFERENCES on table public."vehicles" to "anon";

grant TRIGGER on table public."vehicles" to "anon";

grant INSERT on table public."vehicles" to "authenticated";

grant SELECT on table public."vehicles" to "authenticated";

grant UPDATE on table public."vehicles" to "authenticated";

grant DELETE on table public."vehicles" to "authenticated";

grant TRUNCATE on table public."vehicles" to "authenticated";

grant REFERENCES on table public."vehicles" to "authenticated";

grant TRIGGER on table public."vehicles" to "authenticated";

grant INSERT on table public."vehicles" to "service_role";

grant SELECT on table public."vehicles" to "service_role";

grant UPDATE on table public."vehicles" to "service_role";

grant DELETE on table public."vehicles" to "service_role";

grant TRUNCATE on table public."vehicles" to "service_role";

grant REFERENCES on table public."vehicles" to "service_role";

grant TRIGGER on table public."vehicles" to "service_role";

grant INSERT on table public."articles" to "postgres" with grant option;

grant SELECT on table public."articles" to "postgres" with grant option;

grant UPDATE on table public."articles" to "postgres" with grant option;

grant DELETE on table public."articles" to "postgres" with grant option;

grant TRUNCATE on table public."articles" to "postgres" with grant option;

grant REFERENCES on table public."articles" to "postgres" with grant option;

grant TRIGGER on table public."articles" to "postgres" with grant option;

grant TRUNCATE on table public."articles" to "anon";

grant REFERENCES on table public."articles" to "anon";

grant TRIGGER on table public."articles" to "anon";

grant INSERT on table public."articles" to "authenticated";

grant SELECT on table public."articles" to "authenticated";

grant UPDATE on table public."articles" to "authenticated";

grant DELETE on table public."articles" to "authenticated";

grant TRUNCATE on table public."articles" to "authenticated";

grant REFERENCES on table public."articles" to "authenticated";

grant TRIGGER on table public."articles" to "authenticated";

grant TRUNCATE on table public."articles" to "service_role";

grant REFERENCES on table public."articles" to "service_role";

grant TRIGGER on table public."articles" to "service_role";

grant INSERT on table public."vehicle_types" to "postgres" with grant option;

grant SELECT on table public."vehicle_types" to "postgres" with grant option;

grant UPDATE on table public."vehicle_types" to "postgres" with grant option;

grant DELETE on table public."vehicle_types" to "postgres" with grant option;

grant TRUNCATE on table public."vehicle_types" to "postgres" with grant option;

grant REFERENCES on table public."vehicle_types" to "postgres" with grant option;

grant TRIGGER on table public."vehicle_types" to "postgres" with grant option;

grant TRUNCATE on table public."vehicle_types" to "anon";

grant REFERENCES on table public."vehicle_types" to "anon";

grant TRIGGER on table public."vehicle_types" to "anon";

grant INSERT on table public."vehicle_types" to "authenticated";

grant SELECT on table public."vehicle_types" to "authenticated";

grant UPDATE on table public."vehicle_types" to "authenticated";

grant DELETE on table public."vehicle_types" to "authenticated";

grant TRUNCATE on table public."vehicle_types" to "authenticated";

grant REFERENCES on table public."vehicle_types" to "authenticated";

grant TRIGGER on table public."vehicle_types" to "authenticated";

grant TRUNCATE on table public."vehicle_types" to "service_role";

grant REFERENCES on table public."vehicle_types" to "service_role";

grant TRIGGER on table public."vehicle_types" to "service_role";

grant INSERT on table public."vehicle_brands" to "postgres" with grant option;

grant SELECT on table public."vehicle_brands" to "postgres" with grant option;

grant UPDATE on table public."vehicle_brands" to "postgres" with grant option;

grant DELETE on table public."vehicle_brands" to "postgres" with grant option;

grant TRUNCATE on table public."vehicle_brands" to "postgres" with grant option;

grant REFERENCES on table public."vehicle_brands" to "postgres" with grant option;

grant TRIGGER on table public."vehicle_brands" to "postgres" with grant option;

grant TRUNCATE on table public."vehicle_brands" to "anon";

grant REFERENCES on table public."vehicle_brands" to "anon";

grant TRIGGER on table public."vehicle_brands" to "anon";

grant INSERT on table public."vehicle_brands" to "authenticated";

grant SELECT on table public."vehicle_brands" to "authenticated";

grant UPDATE on table public."vehicle_brands" to "authenticated";

grant DELETE on table public."vehicle_brands" to "authenticated";

grant TRUNCATE on table public."vehicle_brands" to "authenticated";

grant REFERENCES on table public."vehicle_brands" to "authenticated";

grant TRIGGER on table public."vehicle_brands" to "authenticated";

grant TRUNCATE on table public."vehicle_brands" to "service_role";

grant REFERENCES on table public."vehicle_brands" to "service_role";

grant TRIGGER on table public."vehicle_brands" to "service_role";

grant INSERT on table public."vehicle_models" to "postgres" with grant option;

grant SELECT on table public."vehicle_models" to "postgres" with grant option;

grant UPDATE on table public."vehicle_models" to "postgres" with grant option;

grant DELETE on table public."vehicle_models" to "postgres" with grant option;

grant TRUNCATE on table public."vehicle_models" to "postgres" with grant option;

grant REFERENCES on table public."vehicle_models" to "postgres" with grant option;

grant TRIGGER on table public."vehicle_models" to "postgres" with grant option;

grant TRUNCATE on table public."vehicle_models" to "anon";

grant REFERENCES on table public."vehicle_models" to "anon";

grant TRIGGER on table public."vehicle_models" to "anon";

grant INSERT on table public."vehicle_models" to "authenticated";

grant SELECT on table public."vehicle_models" to "authenticated";

grant UPDATE on table public."vehicle_models" to "authenticated";

grant DELETE on table public."vehicle_models" to "authenticated";

grant TRUNCATE on table public."vehicle_models" to "authenticated";

grant REFERENCES on table public."vehicle_models" to "authenticated";

grant TRIGGER on table public."vehicle_models" to "authenticated";

grant TRUNCATE on table public."vehicle_models" to "service_role";

grant REFERENCES on table public."vehicle_models" to "service_role";

grant TRIGGER on table public."vehicle_models" to "service_role";

grant INSERT on table public."vehicle_areas" to "postgres" with grant option;

grant SELECT on table public."vehicle_areas" to "postgres" with grant option;

grant UPDATE on table public."vehicle_areas" to "postgres" with grant option;

grant DELETE on table public."vehicle_areas" to "postgres" with grant option;

grant TRUNCATE on table public."vehicle_areas" to "postgres" with grant option;

grant REFERENCES on table public."vehicle_areas" to "postgres" with grant option;

grant TRIGGER on table public."vehicle_areas" to "postgres" with grant option;

grant TRUNCATE on table public."vehicle_areas" to "anon";

grant REFERENCES on table public."vehicle_areas" to "anon";

grant TRIGGER on table public."vehicle_areas" to "anon";

grant INSERT on table public."vehicle_areas" to "authenticated";

grant SELECT on table public."vehicle_areas" to "authenticated";

grant UPDATE on table public."vehicle_areas" to "authenticated";

grant DELETE on table public."vehicle_areas" to "authenticated";

grant TRUNCATE on table public."vehicle_areas" to "authenticated";

grant REFERENCES on table public."vehicle_areas" to "authenticated";

grant TRIGGER on table public."vehicle_areas" to "authenticated";

grant TRUNCATE on table public."vehicle_areas" to "service_role";

grant REFERENCES on table public."vehicle_areas" to "service_role";

grant TRIGGER on table public."vehicle_areas" to "service_role";

grant INSERT on table public."vehicle_locations" to "postgres" with grant option;

grant SELECT on table public."vehicle_locations" to "postgres" with grant option;

grant UPDATE on table public."vehicle_locations" to "postgres" with grant option;

grant DELETE on table public."vehicle_locations" to "postgres" with grant option;

grant TRUNCATE on table public."vehicle_locations" to "postgres" with grant option;

grant REFERENCES on table public."vehicle_locations" to "postgres" with grant option;

grant TRIGGER on table public."vehicle_locations" to "postgres" with grant option;

grant TRUNCATE on table public."vehicle_locations" to "anon";

grant REFERENCES on table public."vehicle_locations" to "anon";

grant TRIGGER on table public."vehicle_locations" to "anon";

grant INSERT on table public."vehicle_locations" to "authenticated";

grant SELECT on table public."vehicle_locations" to "authenticated";

grant UPDATE on table public."vehicle_locations" to "authenticated";

grant DELETE on table public."vehicle_locations" to "authenticated";

grant TRUNCATE on table public."vehicle_locations" to "authenticated";

grant REFERENCES on table public."vehicle_locations" to "authenticated";

grant TRIGGER on table public."vehicle_locations" to "authenticated";

grant TRUNCATE on table public."vehicle_locations" to "service_role";

grant REFERENCES on table public."vehicle_locations" to "service_role";

grant TRIGGER on table public."vehicle_locations" to "service_role";

grant INSERT on table public."article_types" to "postgres" with grant option;

grant SELECT on table public."article_types" to "postgres" with grant option;

grant UPDATE on table public."article_types" to "postgres" with grant option;

grant DELETE on table public."article_types" to "postgres" with grant option;

grant TRUNCATE on table public."article_types" to "postgres" with grant option;

grant REFERENCES on table public."article_types" to "postgres" with grant option;

grant TRIGGER on table public."article_types" to "postgres" with grant option;

grant TRUNCATE on table public."article_types" to "anon";

grant REFERENCES on table public."article_types" to "anon";

grant TRIGGER on table public."article_types" to "anon";

grant INSERT on table public."article_types" to "authenticated";

grant SELECT on table public."article_types" to "authenticated";

grant UPDATE on table public."article_types" to "authenticated";

grant DELETE on table public."article_types" to "authenticated";

grant TRUNCATE on table public."article_types" to "authenticated";

grant REFERENCES on table public."article_types" to "authenticated";

grant TRIGGER on table public."article_types" to "authenticated";

grant TRUNCATE on table public."article_types" to "service_role";

grant REFERENCES on table public."article_types" to "service_role";

grant TRIGGER on table public."article_types" to "service_role";

grant INSERT on table public."article_companies" to "postgres" with grant option;

grant SELECT on table public."article_companies" to "postgres" with grant option;

grant UPDATE on table public."article_companies" to "postgres" with grant option;

grant DELETE on table public."article_companies" to "postgres" with grant option;

grant TRUNCATE on table public."article_companies" to "postgres" with grant option;

grant REFERENCES on table public."article_companies" to "postgres" with grant option;

grant TRIGGER on table public."article_companies" to "postgres" with grant option;

grant TRUNCATE on table public."article_companies" to "anon";

grant REFERENCES on table public."article_companies" to "anon";

grant TRIGGER on table public."article_companies" to "anon";

grant INSERT on table public."article_companies" to "authenticated";

grant SELECT on table public."article_companies" to "authenticated";

grant UPDATE on table public."article_companies" to "authenticated";

grant DELETE on table public."article_companies" to "authenticated";

grant TRUNCATE on table public."article_companies" to "authenticated";

grant REFERENCES on table public."article_companies" to "authenticated";

grant TRIGGER on table public."article_companies" to "authenticated";

grant TRUNCATE on table public."article_companies" to "service_role";

grant REFERENCES on table public."article_companies" to "service_role";

grant TRIGGER on table public."article_companies" to "service_role";

grant INSERT on table public."vehicle_recommended_articles" to "postgres" with grant option;

grant SELECT on table public."vehicle_recommended_articles" to "postgres" with grant option;

grant UPDATE on table public."vehicle_recommended_articles" to "postgres" with grant option;

grant DELETE on table public."vehicle_recommended_articles" to "postgres" with grant option;

grant TRUNCATE on table public."vehicle_recommended_articles" to "postgres" with grant option;

grant REFERENCES on table public."vehicle_recommended_articles" to "postgres" with grant option;

grant TRIGGER on table public."vehicle_recommended_articles" to "postgres" with grant option;

grant TRUNCATE on table public."vehicle_recommended_articles" to "anon";

grant REFERENCES on table public."vehicle_recommended_articles" to "anon";

grant TRIGGER on table public."vehicle_recommended_articles" to "anon";

grant INSERT on table public."vehicle_recommended_articles" to "authenticated";

grant SELECT on table public."vehicle_recommended_articles" to "authenticated";

grant UPDATE on table public."vehicle_recommended_articles" to "authenticated";

grant DELETE on table public."vehicle_recommended_articles" to "authenticated";

grant TRUNCATE on table public."vehicle_recommended_articles" to "authenticated";

grant REFERENCES on table public."vehicle_recommended_articles" to "authenticated";

grant TRIGGER on table public."vehicle_recommended_articles" to "authenticated";

grant TRUNCATE on table public."vehicle_recommended_articles" to "service_role";

grant REFERENCES on table public."vehicle_recommended_articles" to "service_role";

grant TRIGGER on table public."vehicle_recommended_articles" to "service_role";

grant INSERT on table public."stock_lots" to "postgres" with grant option;

grant SELECT on table public."stock_lots" to "postgres" with grant option;

grant UPDATE on table public."stock_lots" to "postgres" with grant option;

grant DELETE on table public."stock_lots" to "postgres" with grant option;

grant TRUNCATE on table public."stock_lots" to "postgres" with grant option;

grant REFERENCES on table public."stock_lots" to "postgres" with grant option;

grant TRIGGER on table public."stock_lots" to "postgres" with grant option;

grant TRUNCATE on table public."stock_lots" to "anon";

grant REFERENCES on table public."stock_lots" to "anon";

grant TRIGGER on table public."stock_lots" to "anon";

grant INSERT on table public."stock_lots" to "authenticated";

grant SELECT on table public."stock_lots" to "authenticated";

grant UPDATE on table public."stock_lots" to "authenticated";

grant DELETE on table public."stock_lots" to "authenticated";

grant TRUNCATE on table public."stock_lots" to "authenticated";

grant REFERENCES on table public."stock_lots" to "authenticated";

grant TRIGGER on table public."stock_lots" to "authenticated";

grant TRUNCATE on table public."stock_lots" to "service_role";

grant REFERENCES on table public."stock_lots" to "service_role";

grant TRIGGER on table public."stock_lots" to "service_role";

grant INSERT on table public."areas" to "postgres" with grant option;

grant SELECT on table public."areas" to "postgres" with grant option;

grant UPDATE on table public."areas" to "postgres" with grant option;

grant DELETE on table public."areas" to "postgres" with grant option;

grant TRUNCATE on table public."areas" to "postgres" with grant option;

grant REFERENCES on table public."areas" to "postgres" with grant option;

grant TRIGGER on table public."areas" to "postgres" with grant option;

grant TRUNCATE on table public."areas" to "anon";

grant REFERENCES on table public."areas" to "anon";

grant TRIGGER on table public."areas" to "anon";

grant INSERT on table public."areas" to "authenticated";

grant SELECT on table public."areas" to "authenticated";

grant UPDATE on table public."areas" to "authenticated";

grant DELETE on table public."areas" to "authenticated";

grant TRUNCATE on table public."areas" to "authenticated";

grant REFERENCES on table public."areas" to "authenticated";

grant TRIGGER on table public."areas" to "authenticated";

grant SELECT on table public."areas" to "service_role";

grant TRUNCATE on table public."areas" to "service_role";

grant REFERENCES on table public."areas" to "service_role";

grant TRIGGER on table public."areas" to "service_role";

grant INSERT on table public."profile_areas" to "postgres" with grant option;

grant SELECT on table public."profile_areas" to "postgres" with grant option;

grant UPDATE on table public."profile_areas" to "postgres" with grant option;

grant DELETE on table public."profile_areas" to "postgres" with grant option;

grant TRUNCATE on table public."profile_areas" to "postgres" with grant option;

grant REFERENCES on table public."profile_areas" to "postgres" with grant option;

grant TRIGGER on table public."profile_areas" to "postgres" with grant option;

grant TRUNCATE on table public."profile_areas" to "anon";

grant REFERENCES on table public."profile_areas" to "anon";

grant TRIGGER on table public."profile_areas" to "anon";

grant INSERT on table public."profile_areas" to "authenticated";

grant SELECT on table public."profile_areas" to "authenticated";

grant UPDATE on table public."profile_areas" to "authenticated";

grant DELETE on table public."profile_areas" to "authenticated";

grant TRUNCATE on table public."profile_areas" to "authenticated";

grant REFERENCES on table public."profile_areas" to "authenticated";

grant TRIGGER on table public."profile_areas" to "authenticated";

grant INSERT on table public."profile_areas" to "service_role";

grant SELECT on table public."profile_areas" to "service_role";

grant UPDATE on table public."profile_areas" to "service_role";

grant DELETE on table public."profile_areas" to "service_role";

grant TRUNCATE on table public."profile_areas" to "service_role";

grant REFERENCES on table public."profile_areas" to "service_role";

grant TRIGGER on table public."profile_areas" to "service_role";

grant INSERT on table public."push_subscriptions" to "postgres" with grant option;

grant SELECT on table public."push_subscriptions" to "postgres" with grant option;

grant UPDATE on table public."push_subscriptions" to "postgres" with grant option;

grant DELETE on table public."push_subscriptions" to "postgres" with grant option;

grant TRUNCATE on table public."push_subscriptions" to "postgres" with grant option;

grant REFERENCES on table public."push_subscriptions" to "postgres" with grant option;

grant TRIGGER on table public."push_subscriptions" to "postgres" with grant option;

grant TRUNCATE on table public."push_subscriptions" to "anon";

grant REFERENCES on table public."push_subscriptions" to "anon";

grant TRIGGER on table public."push_subscriptions" to "anon";

grant INSERT on table public."push_subscriptions" to "authenticated";

grant SELECT on table public."push_subscriptions" to "authenticated";

grant UPDATE on table public."push_subscriptions" to "authenticated";

grant DELETE on table public."push_subscriptions" to "authenticated";

grant TRUNCATE on table public."push_subscriptions" to "authenticated";

grant REFERENCES on table public."push_subscriptions" to "authenticated";

grant TRIGGER on table public."push_subscriptions" to "authenticated";

grant TRUNCATE on table public."push_subscriptions" to "service_role";

grant REFERENCES on table public."push_subscriptions" to "service_role";

grant TRIGGER on table public."push_subscriptions" to "service_role";

grant INSERT on table public."google_drive_connections" to "postgres" with grant option;

grant SELECT on table public."google_drive_connections" to "postgres" with grant option;

grant UPDATE on table public."google_drive_connections" to "postgres" with grant option;

grant DELETE on table public."google_drive_connections" to "postgres" with grant option;

grant TRUNCATE on table public."google_drive_connections" to "postgres" with grant option;

grant REFERENCES on table public."google_drive_connections" to "postgres" with grant option;

grant TRIGGER on table public."google_drive_connections" to "postgres" with grant option;

grant TRUNCATE on table public."google_drive_connections" to "service_role";

grant REFERENCES on table public."google_drive_connections" to "service_role";

grant TRIGGER on table public."google_drive_connections" to "service_role";

grant INSERT on table public."google_drive_oauth_states" to "postgres" with grant option;

grant SELECT on table public."google_drive_oauth_states" to "postgres" with grant option;

grant UPDATE on table public."google_drive_oauth_states" to "postgres" with grant option;

grant DELETE on table public."google_drive_oauth_states" to "postgres" with grant option;

grant TRUNCATE on table public."google_drive_oauth_states" to "postgres" with grant option;

grant REFERENCES on table public."google_drive_oauth_states" to "postgres" with grant option;

grant TRIGGER on table public."google_drive_oauth_states" to "postgres" with grant option;

grant TRUNCATE on table public."google_drive_oauth_states" to "service_role";

grant REFERENCES on table public."google_drive_oauth_states" to "service_role";

grant TRIGGER on table public."google_drive_oauth_states" to "service_role";

grant INSERT on table public."document_library_items" to "postgres" with grant option;

grant SELECT on table public."document_library_items" to "postgres" with grant option;

grant UPDATE on table public."document_library_items" to "postgres" with grant option;

grant DELETE on table public."document_library_items" to "postgres" with grant option;

grant TRUNCATE on table public."document_library_items" to "postgres" with grant option;

grant REFERENCES on table public."document_library_items" to "postgres" with grant option;

grant TRIGGER on table public."document_library_items" to "postgres" with grant option;

grant TRUNCATE on table public."document_library_items" to "anon";

grant REFERENCES on table public."document_library_items" to "anon";

grant TRIGGER on table public."document_library_items" to "anon";

grant INSERT on table public."document_library_items" to "authenticated";

grant SELECT on table public."document_library_items" to "authenticated";

grant UPDATE on table public."document_library_items" to "authenticated";

grant DELETE on table public."document_library_items" to "authenticated";

grant TRUNCATE on table public."document_library_items" to "authenticated";

grant REFERENCES on table public."document_library_items" to "authenticated";

grant TRIGGER on table public."document_library_items" to "authenticated";

grant TRUNCATE on table public."document_library_items" to "service_role";

grant REFERENCES on table public."document_library_items" to "service_role";

grant TRIGGER on table public."document_library_items" to "service_role";

revoke all on function public."can_access_company"(target uuid) from PUBLIC, anon, authenticated, service_role;

grant execute on function public."can_access_company"(target uuid) to PUBLIC;

grant execute on function public."can_access_company"(target uuid) to "postgres";

revoke all on function public."can_access_location"(target uuid) from PUBLIC, anon, authenticated, service_role;

grant execute on function public."can_access_location"(target uuid) to PUBLIC;

grant execute on function public."can_access_location"(target uuid) to "postgres";

revoke all on function public."current_role"() from PUBLIC, anon, authenticated, service_role;

grant execute on function public."current_role"() to PUBLIC;

grant execute on function public."current_role"() to "postgres";

revoke all on function public."get_admin_users_snapshot"() from PUBLIC, anon, authenticated, service_role;

grant execute on function public."get_admin_users_snapshot"() to "postgres";

grant execute on function public."get_admin_users_snapshot"() to "authenticated";

revoke all on function public."get_stock_snapshot"() from PUBLIC, anon, authenticated, service_role;

grant execute on function public."get_stock_snapshot"() to "postgres";

grant execute on function public."get_stock_snapshot"() to "authenticated";

revoke all on function public."import_stock_rows"(p_company_name text, p_rows jsonb, p_quantity_mode text) from PUBLIC, anon, authenticated, service_role;

grant execute on function public."import_stock_rows"(p_company_name text, p_rows jsonb, p_quantity_mode text) to PUBLIC;

grant execute on function public."import_stock_rows"(p_company_name text, p_rows jsonb, p_quantity_mode text) to "postgres";

grant execute on function public."import_stock_rows"(p_company_name text, p_rows jsonb, p_quantity_mode text) to "authenticated";

revoke all on function public."is_general_admin"() from PUBLIC, anon, authenticated, service_role;

grant execute on function public."is_general_admin"() to PUBLIC;

grant execute on function public."is_general_admin"() to "postgres";

revoke all on function public."is_super_admin"() from PUBLIC, anon, authenticated, service_role;

grant execute on function public."is_super_admin"() to PUBLIC;

grant execute on function public."is_super_admin"() to "postgres";

revoke all on function public."move_stock"(p_article uuid, p_company uuid, p_from uuid, p_to uuid, p_quantity numeric, p_reason text, p_vehicle uuid) from PUBLIC, anon, authenticated, service_role;

grant execute on function public."move_stock"(p_article uuid, p_company uuid, p_from uuid, p_to uuid, p_quantity numeric, p_reason text, p_vehicle uuid) to PUBLIC;

grant execute on function public."move_stock"(p_article uuid, p_company uuid, p_from uuid, p_to uuid, p_quantity numeric, p_reason text, p_vehicle uuid) to "postgres";

grant execute on function public."move_stock"(p_article uuid, p_company uuid, p_from uuid, p_to uuid, p_quantity numeric, p_reason text, p_vehicle uuid) to "authenticated";

revoke all on function public."repair_recipient_candidates"(p_company_name text, p_location_names text[]) from PUBLIC, anon, authenticated, service_role;

grant execute on function public."repair_recipient_candidates"(p_company_name text, p_location_names text[]) to "postgres";

grant execute on function public."repair_recipient_candidates"(p_company_name text, p_location_names text[]) to "authenticated";

revoke all on function public."rls_auto_enable"() from PUBLIC, anon, authenticated, service_role;

grant execute on function public."rls_auto_enable"() to PUBLIC;

grant execute on function public."rls_auto_enable"() to "postgres";

revoke all on function public."set_imported_articles_company_scope"(p_codes jsonb, p_scope text) from PUBLIC, anon, authenticated, service_role;

grant execute on function public."set_imported_articles_company_scope"(p_codes jsonb, p_scope text) to PUBLIC;

grant execute on function public."set_imported_articles_company_scope"(p_codes jsonb, p_scope text) to "postgres";

grant execute on function public."set_imported_articles_company_scope"(p_codes jsonb, p_scope text) to "authenticated";

revoke all on function public."set_stock_balance"(p_article_id uuid, p_location_id uuid, p_quantity numeric, p_average_cost numeric, p_currency text, p_positions jsonb, p_expected_version bigint) from PUBLIC, anon, authenticated, service_role;

grant execute on function public."set_stock_balance"(p_article_id uuid, p_location_id uuid, p_quantity numeric, p_average_cost numeric, p_currency text, p_positions jsonb, p_expected_version bigint) to PUBLIC;

grant execute on function public."set_stock_balance"(p_article_id uuid, p_location_id uuid, p_quantity numeric, p_average_cost numeric, p_currency text, p_positions jsonb, p_expected_version bigint) to "postgres";

grant execute on function public."set_stock_balance"(p_article_id uuid, p_location_id uuid, p_quantity numeric, p_average_cost numeric, p_currency text, p_positions jsonb, p_expected_version bigint) to "authenticated";

revoke all on sequence public."audit_log_id_seq" from PUBLIC, anon, authenticated, service_role;

grant USAGE on sequence public."audit_log_id_seq" to "postgres";

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types) values ('manuales-archivos','manuales-archivos',false,null,null);

alter publication supabase_realtime add table public."maintenance_orders";

-- El webhook con Authorization se configura por separado; su secreto no se exporta.

commit;

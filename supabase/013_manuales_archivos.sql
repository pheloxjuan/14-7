-- Gestion Phelox - biblioteca privada de manuales y archivos.
-- Pueden leer mecanicos, administradores generales y superadministradores.
-- Solo los administradores pueden organizar y cargar contenido.

begin;

create table if not exists public.document_library_items (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references public.document_library_items(id) on delete cascade,
  item_type text not null check (item_type in ('folder','file')),
  name text not null check (length(trim(name)) > 0),
  storage_path text,
  mime_type text,
  size_bytes bigint not null default 0 check (size_bytes >= 0),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (item_type = 'folder' and storage_path is null) or
    (item_type = 'file' and storage_path is not null)
  )
);

create unique index if not exists document_library_unique_name
  on public.document_library_items (
    coalesce(parent_id, '00000000-0000-0000-0000-000000000000'::uuid),
    lower(name)
  );

create unique index if not exists document_library_storage_path_unique
  on public.document_library_items(storage_path)
  where storage_path is not null;

create index if not exists document_library_parent_idx
  on public.document_library_items(parent_id, item_type, name);

alter table public.document_library_items enable row level security;

drop policy if exists document_library_read on public.document_library_items;
create policy document_library_read
  on public.document_library_items for select to authenticated
  using (public.current_role() in ('superadministrador','administrador_general','mecanico'));

drop policy if exists document_library_admin_insert on public.document_library_items;
create policy document_library_admin_insert
  on public.document_library_items for insert to authenticated
  with check (
    public.current_role() in ('superadministrador','administrador_general')
    and created_by = auth.uid()
  );

drop policy if exists document_library_admin_update on public.document_library_items;
create policy document_library_admin_update
  on public.document_library_items for update to authenticated
  using (public.current_role() in ('superadministrador','administrador_general'))
  with check (public.current_role() in ('superadministrador','administrador_general'));

drop policy if exists document_library_admin_delete on public.document_library_items;
create policy document_library_admin_delete
  on public.document_library_items for delete to authenticated
  using (public.current_role() in ('superadministrador','administrador_general'));

grant select, insert, update, delete on public.document_library_items to authenticated;

insert into storage.buckets (id, name, public)
values ('manuales-archivos', 'manuales-archivos', false)
on conflict (id) do update set public = false;

drop policy if exists manuales_archivos_read on storage.objects;
create policy manuales_archivos_read
  on storage.objects for select to authenticated
  using (
    bucket_id = 'manuales-archivos'
    and public.current_role() in ('superadministrador','administrador_general','mecanico')
  );

drop policy if exists manuales_archivos_admin_insert on storage.objects;
create policy manuales_archivos_admin_insert
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'manuales-archivos'
    and public.current_role() in ('superadministrador','administrador_general')
  );

drop policy if exists manuales_archivos_admin_update on storage.objects;
create policy manuales_archivos_admin_update
  on storage.objects for update to authenticated
  using (
    bucket_id = 'manuales-archivos'
    and public.current_role() in ('superadministrador','administrador_general')
  )
  with check (
    bucket_id = 'manuales-archivos'
    and public.current_role() in ('superadministrador','administrador_general')
  );

drop policy if exists manuales_archivos_admin_delete on storage.objects;
create policy manuales_archivos_admin_delete
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'manuales-archivos'
    and public.current_role() in ('superadministrador','administrador_general')
  );

commit;

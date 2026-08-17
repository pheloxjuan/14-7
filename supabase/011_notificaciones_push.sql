-- Suscripciones Web Push por usuario y dispositivo.
-- Cada usuario solamente puede administrar sus propios dispositivos.

begin;

create table if not exists public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  user_agent text,
  active boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists push_subscriptions_user_active_idx
  on public.push_subscriptions(user_id,active);

alter table public.push_subscriptions enable row level security;

drop policy if exists push_subscriptions_read_own on public.push_subscriptions;
drop policy if exists push_subscriptions_insert_own on public.push_subscriptions;
drop policy if exists push_subscriptions_update_own on public.push_subscriptions;
drop policy if exists push_subscriptions_delete_own on public.push_subscriptions;

create policy push_subscriptions_read_own on public.push_subscriptions
  for select to authenticated using (user_id=auth.uid());
create policy push_subscriptions_insert_own on public.push_subscriptions
  for insert to authenticated with check (user_id=auth.uid());
create policy push_subscriptions_update_own on public.push_subscriptions
  for update to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
create policy push_subscriptions_delete_own on public.push_subscriptions
  for delete to authenticated using (user_id=auth.uid());

grant select,insert,update,delete on table public.push_subscriptions to authenticated;

commit;

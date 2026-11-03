-- Poulplan, hébergé avec les autres applications Poulapp.
-- Mêmes conventions que Poulpoints : enregistrements par utilisateur,
-- accès sur invitation (poulapp_access, app_id = 'poulplan'), pierres
-- tombales (pas de suppression réelle par les clients), révision serveur.
--
-- Une ligne par enregistrement (événement, catégorie, anniversaire, filtre
-- enregistré). `data` contient l'enregistrement complet et les versions de
-- ses champs (fusion champ par champ côté app) ; le serveur ne l'interprète
-- pas, ce qui permettra plus tard de le chiffrer de bout en bout.
-- `rev` vient d'une séquence : un appareil récupère les changements avec
-- « rev > dernière révision vue » (avec recouvrement, voir DECISIONS.md).
-- Idempotent : peut être relancé.

begin;

create schema if not exists private;

create sequence if not exists public.poulplan_rev_seq;

create table if not exists public.poulplan_records (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  entity text not null
    check (entity in ('event', 'category', 'birthday', 'saved_filter')),
  id text not null check (char_length(id) between 1 and 200),
  data jsonb not null default '{}'::jsonb
    check (jsonb_typeof(data) = 'object' and octet_length(data::text) <= 262144),
  deleted boolean not null default false,
  rev bigint not null default nextval('public.poulplan_rev_seq'),
  updated_at timestamptz not null default now(),
  primary key (user_id, entity, id),
  constraint poulplan_record_data_id check (deleted or data->>'id' = id)
);

create index if not exists poulplan_records_changes
  on public.poulplan_records (user_id, rev);

-- Révision et horodatage contrôlés par le serveur ; propriétaire et clé
-- immuables.
create or replace function private.poulplan_records_touch()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if TG_OP = 'UPDATE' then
    new.user_id := old.user_id;
    new.entity := old.entity;
    new.id := old.id;
  end if;
  new.rev := nextval('public.poulplan_rev_seq');
  new.updated_at := clock_timestamp();
  return new;
end;
$$;

drop trigger if exists poulplan_records_touch on public.poulplan_records;
create trigger poulplan_records_touch
  before insert or update on public.poulplan_records
  for each row execute function private.poulplan_records_touch();

alter table public.poulplan_records enable row level security;
revoke all on table public.poulplan_records from public, anon, authenticated;
grant select, insert, update on table public.poulplan_records to authenticated;
revoke all on sequence public.poulplan_rev_seq from public, anon, authenticated;
grant usage on sequence public.poulplan_rev_seq to authenticated;
-- Pas de suppression réelle par les clients : deleted = true, pour qu'un
-- appareil resté hors ligne ne fasse pas réapparaître un enregistrement.

drop policy if exists "Poulplan record read by approved owner"
  on public.poulplan_records;
create policy "Poulplan record read by approved owner"
  on public.poulplan_records for select to authenticated
  using (user_id = (select auth.uid()) and exists (
    select 1 from public.poulapp_access a
    where a.user_id = (select auth.uid()) and a.app_id = 'poulplan'
  ));

drop policy if exists "Poulplan record insert by approved owner"
  on public.poulplan_records;
create policy "Poulplan record insert by approved owner"
  on public.poulplan_records for insert to authenticated
  with check (user_id = (select auth.uid()) and exists (
    select 1 from public.poulapp_access a
    where a.user_id = (select auth.uid()) and a.app_id = 'poulplan'
  ));

drop policy if exists "Poulplan record update by approved owner"
  on public.poulplan_records;
create policy "Poulplan record update by approved owner"
  on public.poulplan_records for update to authenticated
  using (user_id = (select auth.uid()) and exists (
    select 1 from public.poulapp_access a
    where a.user_id = (select auth.uid()) and a.app_id = 'poulplan'
  ))
  with check (user_id = (select auth.uid()) and exists (
    select 1 from public.poulapp_access a
    where a.user_id = (select auth.uid()) and a.app_id = 'poulplan'
  ));

-- Envoi groupé avec contrôle de concurrence optimiste (pas d'UPSERT
-- inconditionnel).
--
-- p_records : tableau JSON de {entity, id, data, deleted, base_rev}.
-- base_rev = révision serveur sur laquelle l'appareil a fondé sa
-- modification (null pour un enregistrement que l'appareil croit nouveau).
-- Une ligne modifiée entre-temps sur le serveur n'est pas écrasée : elle
-- revient avec conflict = true ; l'app la récupère, fusionne et renvoie.
-- SECURITY INVOKER : la RLS ci-dessus s'applique.
create or replace function public.poulplan_push(p_records jsonb)
returns table (entity text, id text, rev bigint, conflict boolean)
language plpgsql
security invoker
set search_path = ''
as $$
#variable_conflict use_column
declare
  r record;
  current_rev bigint;
  new_rev bigint;
begin
  if not exists (
    select 1 from public.poulapp_access a
    where a.user_id = (select auth.uid()) and a.app_id = 'poulplan'
  ) then
    raise exception 'poulplan: access not granted' using errcode = '42501';
  end if;

  for r in
    select * from jsonb_to_recordset(p_records)
      as x(entity text, id text, data jsonb, deleted boolean, base_rev bigint)
  loop
    select pr.rev into current_rev
      from public.poulplan_records pr
      where pr.user_id = (select auth.uid())
        and pr.entity = r.entity and pr.id = r.id
      for update;

    if found and current_rev is distinct from r.base_rev then
      entity := r.entity; id := r.id; rev := current_rev; conflict := true;
      return next;
    elsif found then
      update public.poulplan_records pr
        set data = r.data, deleted = coalesce(r.deleted, false)
        where pr.user_id = (select auth.uid())
          and pr.entity = r.entity and pr.id = r.id
        returning pr.rev into new_rev;
      entity := r.entity; id := r.id; rev := new_rev; conflict := false;
      return next;
    else
      insert into public.poulplan_records (entity, id, data, deleted)
        values (r.entity, r.id, r.data, coalesce(r.deleted, false))
        returning poulplan_records.rev into new_rev;
      entity := r.entity; id := r.id; rev := new_rev; conflict := false;
      return next;
    end if;
  end loop;
end;
$$;

revoke all on function public.poulplan_push(jsonb) from public, anon;
grant execute on function public.poulplan_push(jsonb) to authenticated;

commit;

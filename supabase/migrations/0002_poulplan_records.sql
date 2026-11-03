-- Poulplan — données synchronisées.
--
-- Une ligne par enregistrement (événement, catégorie, anniversaire, filtre
-- enregistré). `data` contient l'enregistrement complet et les versions de
-- ses champs (fusion champ par champ côté app) ; le serveur ne l'interprète
-- pas, ce qui permettra plus tard de le chiffrer de bout en bout.
-- `rev` augmente à chaque écriture : un appareil récupère les changements
-- avec « rev > dernière révision vue ».
-- Idempotent : peut être relancé.

create sequence if not exists public.poulplan_rev_seq;

create table if not exists public.poulplan_records (
  user_id    uuid        not null default auth.uid()
                         references auth.users (id) on delete cascade,
  entity     text        not null
                         check (entity in ('event', 'category', 'birthday', 'saved_filter')),
  id         text        not null check (length(id) between 1 and 200),
  data       jsonb       not null,
  deleted    boolean     not null default false,
  rev        bigint      not null default nextval('public.poulplan_rev_seq'),
  updated_at timestamptz not null default now(),
  primary key (user_id, entity, id)
);

create index if not exists poulplan_records_user_rev
  on public.poulplan_records (user_id, rev);

alter table public.poulplan_records enable row level security;

-- Uniquement ses propres lignes, et seulement si l'accès « poulplan » a été
-- accordé : un compte autorisé pour Poulpoints seul ne voit rien ici.
drop policy if exists "poulplan_records_select" on public.poulplan_records;
create policy "poulplan_records_select"
  on public.poulplan_records for select to authenticated
  using (user_id = (select auth.uid()) and public.poulapp_has_access('poulplan'));

drop policy if exists "poulplan_records_insert" on public.poulplan_records;
create policy "poulplan_records_insert"
  on public.poulplan_records for insert to authenticated
  with check (user_id = (select auth.uid()) and public.poulapp_has_access('poulplan'));

drop policy if exists "poulplan_records_update" on public.poulplan_records;
create policy "poulplan_records_update"
  on public.poulplan_records for update to authenticated
  using (user_id = (select auth.uid()) and public.poulapp_has_access('poulplan'))
  with check (user_id = (select auth.uid()) and public.poulapp_has_access('poulplan'));

-- Suppression réelle (purge des données cloud depuis l'app).
drop policy if exists "poulplan_records_delete" on public.poulplan_records;
create policy "poulplan_records_delete"
  on public.poulplan_records for delete to authenticated
  using (user_id = (select auth.uid()) and public.poulapp_has_access('poulplan'));

-- Nouvelle révision à chaque écriture ; propriétaire et clé immuables.
create or replace function public.poulplan_records_touch()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    new.user_id := old.user_id;
    new.entity := old.entity;
    new.id := old.id;
  end if;
  new.rev := nextval('public.poulplan_rev_seq');
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists poulplan_records_touch on public.poulplan_records;
create trigger poulplan_records_touch
  before insert or update on public.poulplan_records
  for each row execute function public.poulplan_records_touch();

-- Envoi groupé avec contrôle de concurrence optimiste.
--
-- p_records : tableau JSON de {entity, id, data, deleted, base_rev}.
-- base_rev = révision serveur sur laquelle l'appareil a fondé sa
-- modification (null pour un enregistrement que l'appareil croit nouveau).
-- Une ligne modifiée entre-temps sur le serveur n'est pas écrasée : elle
-- revient avec conflict = true, l'app la récupère, fusionne et renvoie.
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
  if not public.poulapp_has_access('poulplan') then
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

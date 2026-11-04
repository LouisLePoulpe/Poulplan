-- Poulplan — types de données ajoutés en v0.7.0 (pièces jointes) et v0.8.0
-- (trajets mémorisés) : la table les refusait, ce qui bloquait toute la synchro.
-- Idempotent : peut être relancé.

begin;

alter table public.poulplan_records
  drop constraint if exists poulplan_records_entity_check;

alter table public.poulplan_records
  add constraint poulplan_records_entity_check
  check (entity in (
    'event', 'category', 'birthday', 'saved_filter', 'attachment', 'route'
  ));

commit;

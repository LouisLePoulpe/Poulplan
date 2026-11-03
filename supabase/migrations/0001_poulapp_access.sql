-- Poulapp — contrôle d'accès commun à toutes les apps (Poulpoints, Poulplan…).
--
-- DÉJÀ INSTALLÉ dans le projet Poulapp (script 001_poulapp_access de
-- Poulpoints) : ne pas relancer. Ce fichier reproduit la même définition
-- pour une installation neuve ou un auto-hébergement.
-- L'inscription publique doit être désactivée dans Supabase Auth.

begin;

create table if not exists public.poulapp_access (
  user_id uuid not null references auth.users(id) on delete cascade,
  app_id text not null check (app_id ~ '^[a-z][a-z0-9_]{1,49}$'),
  approved_at timestamptz not null default now(),
  primary key (user_id, app_id)
);

alter table public.poulapp_access enable row level security;
revoke all on table public.poulapp_access from public, anon, authenticated;
grant select on table public.poulapp_access to authenticated;

drop policy if exists "Users may read only their own application approvals"
  on public.poulapp_access;
create policy "Users may read only their own application approvals"
  on public.poulapp_access for select to authenticated
  using (user_id = (select auth.uid()));

-- Accorder l'accès à Poulplan (administrateur uniquement) :
-- insert into public.poulapp_access (user_id, app_id)
-- select id, 'poulplan' from auth.users where email = 'votre@adresse.fr'
-- on conflict do nothing;

commit;

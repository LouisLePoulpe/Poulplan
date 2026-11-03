-- Poulapp — contrôle d'accès commun à toutes les apps (Poulpoints, Poulplan…).
-- Idempotent : peut être relancé.
--
-- La table `poulapp_access` existe déjà dans le projet Poulapp (créée pour
-- Poulpoints) avec les colonnes user_id, app_id, approved_at et une politique
-- de lecture de ses propres lignes : ce script ne la modifie pas. Il la crée
-- seulement si elle est absente (installation neuve / auto-hébergement).

create table if not exists public.poulapp_access (
  user_id     uuid        not null references auth.users (id) on delete cascade,
  app_id      text        not null,
  approved_at timestamptz not null default now(),
  primary key (user_id, app_id)
);

alter table public.poulapp_access enable row level security;

-- Politique de lecture, seulement s'il n'y en a aucune (le projet Poulapp a
-- déjà « Users may read only their own application approvals »).
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'poulapp_access'
  ) then
    create policy "Users may read only their own application approvals"
      on public.poulapp_access for select
      to authenticated
      using (user_id = (select auth.uid()));
  end if;
end;
$$;

-- Vrai si l'utilisateur connecté a accès à l'app p_app.
-- SECURITY DEFINER pour pouvoir être appelée depuis les politiques RLS des
-- autres tables sans dépendre de leurs droits.
create or replace function public.poulapp_has_access(p_app text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.poulapp_access
    where user_id = (select auth.uid()) and app_id = p_app
  );
$$;

revoke all on function public.poulapp_has_access(text) from public, anon;
grant execute on function public.poulapp_has_access(text) to authenticated;

-- Poulapp — contrôle d'accès commun à toutes les apps (Poulpoints, Poulplan…).
-- Idempotent : peut être relancé. Si la table existe déjà (créée pour une
-- autre app), vérifiez qu'elle a bien les colonnes user_id (uuid) et app
-- (text) : le reste du script ne la modifie pas.

create table if not exists public.poulapp_access (
  user_id    uuid        not null references auth.users (id) on delete cascade,
  app        text        not null check (app ~ '^[a-z][a-z0-9_]*$'),
  granted_at timestamptz not null default now(),
  primary key (user_id, app)
);

alter table public.poulapp_access enable row level security;

-- Chacun peut seulement lire ses propres autorisations. Aucune politique
-- d'écriture : les accès s'accordent depuis le tableau de bord Supabase
-- (rôle postgres / service_role, jamais depuis une app).
drop policy if exists "poulapp_access_read_own" on public.poulapp_access;
create policy "poulapp_access_read_own"
  on public.poulapp_access for select
  to authenticated
  using (user_id = (select auth.uid()));

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
    where user_id = (select auth.uid()) and app = p_app
  );
$$;

revoke all on function public.poulapp_has_access(text) from public, anon;
grant execute on function public.poulapp_has_access(text) to authenticated;

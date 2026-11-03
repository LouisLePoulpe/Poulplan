-- Vérifications après installation (à lancer dans l'éditeur SQL).

-- 1. RLS activée sur les tables Poulapp/Poulplan (attendu : true partout).
select relname, relrowsecurity
from pg_class
where relname in ('poulapp_access', 'poulplan_records');

-- 2. Politiques en place (attendu : 1 sur poulapp_access, 4 sur poulplan_records).
select tablename, policyname, cmd
from pg_policies
where tablename in ('poulapp_access', 'poulplan_records')
order by tablename, policyname;

-- 3. Comptes autorisés pour Poulplan.
select u.email, a.app_id, a.approved_at
from public.poulapp_access a
join auth.users u on u.id = a.user_id
where a.app_id = 'poulplan';

-- 4. Bucket privé des pièces jointes (attendu : public = false).
select id, public from storage.buckets where id = 'poulplan-attachments';

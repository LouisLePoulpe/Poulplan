-- Vérifications après installation (à lancer dans l'éditeur SQL).
-- Une seule requête, un seul tableau de résultats.

select 'RLS activée' as controle, relname as objet, relrowsecurity::text as valeur
from pg_class
where relname in ('poulapp_access', 'poulplan_records') and relkind = 'r'
union all
select 'politique', tablename || ' : ' || policyname, cmd
from pg_policies
where tablename in ('poulapp_access', 'poulplan_records')
   or policyname like 'Poulplan attachment%'
union all
select 'fonction', proname, 'ok'
from pg_proc where proname in ('poulplan_push', 'poulplan_records_touch')
union all
select 'bucket', id, 'public = ' || public::text
from storage.buckets where id = 'poulplan-attachments'
union all
select 'accès poulplan', u.email, a.approved_at::text
from public.poulapp_access a join auth.users u on u.id = a.user_id
where a.app_id = 'poulplan'
order by 1, 2;

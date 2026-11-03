-- Poulplan — stockage privé des pièces jointes (utilisé à partir de v0.7.0).
-- Chemin des fichiers : <user_id>/<id de l'événement>/<nom du fichier>.
-- Les fichiers (pas les enregistrements) peuvent être supprimés : nettoyage
-- d'espace et pièces jointes retirées.
-- Idempotent : peut être relancé.

begin;

insert into storage.buckets (id, name, public)
values ('poulplan-attachments', 'poulplan-attachments', false)
on conflict (id) do update set public = false;

drop policy if exists "Poulplan attachment read by approved owner" on storage.objects;
create policy "Poulplan attachment read by approved owner"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'poulplan-attachments'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and exists (
      select 1 from public.poulapp_access a
      where a.user_id = (select auth.uid()) and a.app_id = 'poulplan'
    )
  );

drop policy if exists "Poulplan attachment insert by approved owner" on storage.objects;
create policy "Poulplan attachment insert by approved owner"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'poulplan-attachments'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and exists (
      select 1 from public.poulapp_access a
      where a.user_id = (select auth.uid()) and a.app_id = 'poulplan'
    )
  );

drop policy if exists "Poulplan attachment update by approved owner" on storage.objects;
create policy "Poulplan attachment update by approved owner"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'poulplan-attachments'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and exists (
      select 1 from public.poulapp_access a
      where a.user_id = (select auth.uid()) and a.app_id = 'poulplan'
    )
  );

drop policy if exists "Poulplan attachment delete by approved owner" on storage.objects;
create policy "Poulplan attachment delete by approved owner"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'poulplan-attachments'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and exists (
      select 1 from public.poulapp_access a
      where a.user_id = (select auth.uid()) and a.app_id = 'poulplan'
    )
  );

commit;

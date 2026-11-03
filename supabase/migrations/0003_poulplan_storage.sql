-- Poulplan — stockage privé des pièces jointes (utilisé à partir de v0.7.0).
-- Chemin des fichiers : <user_id>/<id de l'événement>/<nom du fichier>.
-- Idempotent : peut être relancé.

insert into storage.buckets (id, name, public)
values ('poulplan-attachments', 'poulplan-attachments', false)
on conflict (id) do update set public = false;

drop policy if exists "poulplan_attachments_select" on storage.objects;
create policy "poulplan_attachments_select"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'poulplan-attachments'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and public.poulapp_has_access('poulplan')
  );

drop policy if exists "poulplan_attachments_insert" on storage.objects;
create policy "poulplan_attachments_insert"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'poulplan-attachments'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and public.poulapp_has_access('poulplan')
  );

drop policy if exists "poulplan_attachments_update" on storage.objects;
create policy "poulplan_attachments_update"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'poulplan-attachments'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and public.poulapp_has_access('poulplan')
  );

drop policy if exists "poulplan_attachments_delete" on storage.objects;
create policy "poulplan_attachments_delete"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'poulplan-attachments'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and public.poulapp_has_access('poulplan')
  );

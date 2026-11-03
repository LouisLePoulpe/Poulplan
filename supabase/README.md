# Cloud Poulapp — installation de Poulplan dans Supabase

Le cloud est **facultatif** : sans compte, Poulplan fonctionne entièrement en local.
Ces scripts s'installent dans le projet Supabase **mutualisé** de Poulapp.
Ils sont idempotents : on peut les relancer sans casse.

| Fichier | Rôle |
|---|---|
| `migrations/0001_poulapp_access.sql` | Table commune `poulapp_access` — **déjà installée** dans le projet Poulapp (script de Poulpoints), à ne pas relancer |
| `migrations/0002_poulplan_records.sql` | Table `poulplan_records` (RLS par utilisateur **et** accès `app_id = 'poulplan'`, pierres tombales), révisions, fonction d'envoi `poulplan_push()` |
| `migrations/0003_poulplan_storage.sql` | Bucket privé `poulplan-attachments` (pièces jointes, v0.7) et ses politiques |
| `verify.sql` | Requêtes de vérification après installation |

## 1. Réglages d'authentification (tableau de bord)

1. **Authentication → Sign In / Providers → Email** : activé (connexion e-mail + mot de passe).
2. **Authentication → Sign In / Providers** : désactiver **« Allow new users to sign up »** (inscription publique fermée).
3. Les autres fournisseurs (Google, Apple…) restent **désactivés** : aucun service propriétaire.

## 2. Créer le schéma (SQL Editor)

Dans **SQL Editor**, exécuter (un onglet « New » par fichier) :

1. ~~`0001_poulapp_access.sql`~~ : déjà en place dans le projet Poulapp.
2. `migrations/0002_poulplan_records.sql`
3. `migrations/0003_poulplan_storage.sql`

## 3. Créer le compte et accorder l'accès

1. **Authentication → Users → Add user → Create new user** : e-mail + mot de passe, cocher **Auto Confirm User**.
   (Si le compte Poulapp existe déjà pour une autre app, le réutiliser.)
2. Dans **SQL Editor**, accorder l'accès à Poulplan (remplacer l'adresse) :

   ```sql
   insert into public.poulapp_access (user_id, app_id)
   select id, 'poulplan' from auth.users where email = 'votre@adresse.fr'
   on conflict do nothing;
   ```

3. Lancer `verify.sql` et vérifier :
   - « RLS activée » = `true` pour les 2 tables ;
   - 1 politique sur `poulapp_access`, 3 sur `poulplan_records` (lecture, ajout, modification), 4 « Poulplan attachment » ;
   - les fonctions `poulplan_push` et `poulplan_records_touch` ;
   - le bucket `poulplan-attachments` avec `public = false` ;
   - votre adresse dans « accès poulplan ».

## 4. Ce qu'il faut me transmettre

Dans **Project Settings → API** (ou **Data API**) :

- **Project URL** : `https://xxxxxxxx.supabase.co`
- **anon / public key** (clé publique)

⚠️ **Jamais** la clé `service_role` (ni la « secret key ») : elle contourne toutes les règles de sécurité.

Ces deux valeurs vont dans un fichier `.env` local à la racine (modèle : `.env.example`), **ignoré par git**. Elles ne sont jamais écrites dans le code ni dans le dépôt public.

## Sécurité — récapitulatif

- Chaque ligne de `poulplan_records` appartient à un utilisateur (`user_id`), et les politiques RLS exigent `user_id = auth.uid()` **et** une ligne `poulapp_access` avec `app_id = 'poulplan'` (mêmes conventions que Poulpoints).
- Pas de suppression réelle par les clients (`deleted = true`), droits accordés explicitement (`select, insert, update` seulement).
  Un compte autorisé seulement pour Poulpoints ne voit donc aucun événement Poulplan.
- `poulapp_access` n'est modifiable que depuis le tableau de bord : aucune app ne peut s'accorder un accès.
- Le contenu (`data`) est un JSON opaque pour le serveur, ce qui laisse la porte ouverte à un chiffrement de bout en bout.
- Auto-hébergement : ces scripts ne dépendent que de PostgreSQL et des schémas `auth`/`storage` standards de Supabase.

# Cloud Poulapp — installation de Poulplan dans Supabase

Le cloud est **facultatif** : sans compte, Poulplan fonctionne entièrement en local.
Ces scripts s'installent dans le projet Supabase **mutualisé** de Poulapp.
Ils sont idempotents : on peut les relancer sans casse.

| Fichier | Rôle |
|---|---|
| `migrations/0001_poulapp_access.sql` | Table commune `poulapp_access` (accès par application) + fonction `poulapp_has_access()` |
| `migrations/0002_poulplan_records.sql` | Table `poulplan_records` (RLS par utilisateur **et** accès « poulplan »), révisions, fonction d'envoi `poulplan_push()` |
| `migrations/0003_poulplan_storage.sql` | Bucket privé `poulplan-attachments` (pièces jointes, v0.7) et ses politiques |
| `verify.sql` | Requêtes de vérification après installation |

## 1. Réglages d'authentification (tableau de bord)

1. **Authentication → Sign In / Providers → Email** : activé (connexion e-mail + mot de passe).
2. **Authentication → Sign In / Providers** : désactiver **« Allow new users to sign up »** (inscription publique fermée).
3. Les autres fournisseurs (Google, Apple…) restent **désactivés** : aucun service propriétaire.

## 2. Créer le schéma (SQL Editor)

Dans **SQL Editor**, exécuter dans l'ordre le contenu de :

1. `migrations/0001_poulapp_access.sql` — si `poulapp_access` existe déjà (créée pour Poulpoints), le script la laisse intacte ; vérifier simplement qu'elle a les colonnes `user_id uuid` et `app text`.
2. `migrations/0002_poulplan_records.sql`
3. `migrations/0003_poulplan_storage.sql`

## 3. Créer le compte et accorder l'accès

1. **Authentication → Users → Add user → Create new user** : e-mail + mot de passe, cocher **Auto Confirm User**.
   (Si le compte Poulapp existe déjà pour une autre app, le réutiliser.)
2. Dans **SQL Editor**, accorder l'accès à Poulplan (remplacer l'adresse) :

   ```sql
   insert into public.poulapp_access (user_id, app)
   select id, 'poulplan' from auth.users where email = 'votre@adresse.fr'
   on conflict do nothing;
   ```

3. Lancer `verify.sql` et vérifier :
   - `relrowsecurity = true` pour les 2 tables ;
   - 1 politique sur `poulapp_access`, 4 sur `poulplan_records` ;
   - votre adresse dans la liste des comptes autorisés ;
   - le bucket `poulplan-attachments` avec `public = false`.

## 4. Ce qu'il faut me transmettre

Dans **Project Settings → API** (ou **Data API**) :

- **Project URL** : `https://xxxxxxxx.supabase.co`
- **anon / public key** (clé publique)

⚠️ **Jamais** la clé `service_role` (ni la « secret key ») : elle contourne toutes les règles de sécurité.

Ces deux valeurs vont dans un fichier `.env` local à la racine (modèle : `.env.example`), **ignoré par git**. Elles ne sont jamais écrites dans le code ni dans le dépôt public.

## Sécurité — récapitulatif

- Chaque ligne de `poulplan_records` appartient à un utilisateur (`user_id`), et les politiques RLS exigent `user_id = auth.uid()` **et** `poulapp_has_access('poulplan')`.
  Un compte autorisé seulement pour Poulpoints ne voit donc aucun événement Poulplan.
- `poulapp_access` n'est modifiable que depuis le tableau de bord : aucune app ne peut s'accorder un accès.
- Le contenu (`data`) est un JSON opaque pour le serveur, ce qui laisse la porte ouverte à un chiffrement de bout en bout.
- Auto-hébergement : ces scripts ne dépendent que de PostgreSQL et des schémas `auth`/`storage` standards de Supabase.

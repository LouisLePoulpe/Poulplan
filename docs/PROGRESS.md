# Avancement

Dernière mise à jour : 2026-11-03

| Jalon | État |
|---|---|
| Conception / cahier des charges | Terminé (`SPEC.md`) |
| v0.1.0 Fondations | **Terminé** — critères vérifiés sur Linux et Pixel 10 |
| v0.2.0 Événements | **Terminé** — vérifié sous Linux et par tests ; contrôle sur Pixel à refaire (appareil débranché) |
| v0.3.0 Calendrier avancé | En cours |
| v0.4.0 → v1.0.0 | À faire |

## Reprendre le travail à froid
```bash
export PATH=$HOME/flutter/bin:$HOME/Android/Sdk/platform-tools:$PATH
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze && flutter test
flutter run -d linux            # ou -d 58021FDCR009YL (Pixel 10)
```
- Captures limitées à la fenêtre de l'app (mode debug) : `tool/app_screenshot.sh <URL du Dart VM Service> <fichier.png> [view=day|week|month|year|agenda] [day=2026-11-03] [route=/settings]`.
  Sur Android, donner un chemin `/data/data/org.poulapp.poulplan/cache/shot.png` puis
  `adb exec-out run-as org.poulapp.poulplan cat cache/shot.png > shot.png`.
- Icônes / écran d'accueil : `dart run tool/gen_icons.dart && dart run flutter_launcher_icons && dart run flutter_native_splash:create`.
- Après un changement de schéma Drift : incrémenter `schemaVersion`, écrire la migration, puis `dart run drift_dev make-migrations`.
- **Avant `flutter run` sur un appareil**, vérifier la version installée (`adb shell dumpsys package org.poulapp.poulplan | grep versionCode`) : en cas de « downgrade », `flutter run` désinstalle l'app et ses données sans demander.

## Architecture (rappel)
- `lib/domain/` : Dart pur (entités, `Day`, grille du mois, répartition des événements par jour). Aucun import Flutter.
- `lib/data/` : Drift (`db/`), dépôts (`repositories/`), providers Riverpod (`providers.dart`).
- `lib/features/<fonction>/` : `presentation/` (écrans) et `providers/`.
- `lib/core/` : thème, routage (go_router), fuseaux, outils de debug. `lib/l10n/` : ARB français + code généré (commité).

## v0.1.0 — Fondations
Mini-plan : créer le projet Android + Linux → schéma Drift v1 (événements, catégories, paramètres) → domaine testé d'abord (jours, grille, jours couverts par un événement, changement d'heure) → vue Mois + Paramètres → identité visuelle → vérification sur les deux plateformes.

- Fait :
  - projet `org.poulapp.poulplan` (Android + Linux), structure en couches ;
  - schéma Drift v1 (UUID, suppression logique `deletedAt`, horodatages ms UTC), 4 catégories par défaut, schéma figé dans `drift_schemas/` ;
  - vue Mois : navigation précédent/suivant/aujourd'hui, glissement horizontal, raccourcis clavier (←/→, PgPréc/PgSuiv, T, Ctrl+,), jour courant, événements multi-jours, « +n » si débordement ;
  - Paramètres : thème clair/sombre/système, premier jour de semaine (lundi/samedi/dimanche), à propos, licences ;
  - interface en français via intl/ARB ;
  - icône adaptative Android (dont monochrome), écran d'accueil Android 12+, icônes hicolor Linux et fichier `.desktop` (`linux/packaging/`), icône de fenêtre ;
  - barre de titre système sous Linux (plus d'en-tête GTK dessiné par l'app) ;
  - détection du fuseau : plugin, puis repli `TZ` → `/etc/localtime` → `/etc/timezone` (systemd absent dans distrobox/Flatpak).
- Testé :
  - 34 tests verts : `Day`, grille du mois, jours couverts par un événement (minuit, multi-jours, fuseau d'affichage, passage à l'heure d'été et d'hiver), dépôts, paramètres, widget « événement inséré → visible dans la vue Mois », navigation, paramètres ;
  - `flutter analyze` : 0 problème ;
  - Linux (KDE/Wayland, distrobox) : démarrage, base créée dans `~/.local/share/org.poulapp.poulplan/poulplan.db`, 3 événements insérés **directement en SQLite** visibles après redémarrage à chaud (capture vérifiée) ;
  - Pixel 10 (Android 17) : démarrage, vue Mois, insertion via le menu debug → événements visibles, dont multi-jours et passage de minuit (capture vérifiée).
- Non testé :
  - thème clair sur appareil réel (couvert seulement par un test de widget) ;
  - icône dans le lanceur Android et dans le menu KDE (le `.desktop` n'est installé qu'avec le Flatpak, en v1.0).
- Cassé / limites :
  - aucun problème bloquant ;
  - dans le conteneur, `/etc/localtime` vaut `Etc/UTC` : l'app y affiche donc l'heure UTC, ce qui est cohérent avec le système du conteneur.

## v0.2.0 — Événements
Mini-plan : domaine d'abord (placement horaire en colonnes, chevauchements, déplacement à heure murale constante, brouillon d'édition) → dépôts (dupliquer, restaurer, catégories) → écran unique à 5 vues + éditeur + création rapide + glisser-déposer → tests d'interface → vérification.

- Fait :
  - vues Jour, Semaine (grille horaire, ligne « journée entière », ligne de l'heure courante), Mois, Année, Agenda (« Afficher plus ») ;
  - navigation : barre en bas sur téléphone, rail latéral à partir de 840 px ; balayage horizontal ; raccourcis clavier (←/→, PgPréc/PgSuiv, T, N, 1–5, Ctrl+,) ;
  - création rapide (bouton +, toucher un créneau, appui long ou clic droit sur un jour) → « Plus d'options » vers l'éditeur ;
  - éditeur complet : titre, journée entière, début/fin, fuseau (recherche IANA), catégorie, couleur propre, lieu, visio, libre/occupé, description, alerte de chevauchement, Ctrl+S / Échap ;
  - modifier, dupliquer, supprimer (avec « Annuler »), menu contextuel (clic droit / appui long en agenda) ;
  - glisser-déposer : vers un autre jour (mois, ligne journée entière), vers une autre heure (jour/semaine, pas de 15 min) ;
  - chevauchements signalés (icône ⚠) pour les événements « occupé » ;
  - gestion des catégories (créer, renommer, recolorer, supprimer).
- Testé :
  - 77 tests verts à la clôture du jalon, dont 12 tests d'interface : 5 vues, création rapide, titre vide refusé, édition/duplication/suppression/annulation, éditeur multi-jours, fin avant début refusée, glisser-déposer mois et jour, chevauchements, mise en page étroite, paramètres et catégories ;
  - persistance : test sur fichier (fermeture/réouverture) et redémarrage réel sous Linux (événements de la v0.1 toujours présents) ;
  - Linux : captures des 5 vues et de l'éditeur ;
  - CI GitHub verte (analyse, tests, builds Linux et Android).
- Non testé :
  - **Pixel** : appareil débranché pendant ce jalon → glisser-déposer tactile et éditeur à vérifier sur l'appareil ;
  - interactions souris réelles sous Linux (pas d'injection d'entrées sous Wayland depuis le conteneur) : couvertes uniquement par les tests d'interface.
- Corrigé en cours de route : double-tap sur les cellules du mois qui retardait de 300 ms l'ouverture d'un événement ; bandeaux « supprimé » mis en file derrière le précédent ; horodatages en microsecondes non relus à l'identique.

## Journal
- 2026-11-03 : dépôt initialisé (CLAUDE.md, spec, roadmap, CI, licence GPL-3.0).
- 2026-11-03 : v0.2.0 tagué (Pixel non revérifié, débranché).
- 2026-11-03 : v0.1.0. Incident : au premier `flutter run` sur le Pixel, une ancienne app `org.poulapp.poulplan` (versionCode 3, d'origine inconnue) bloquait l'installation ; `flutter run` l'a **désinstallée automatiquement** avec ses données, sans confirmation. L'ancienne base Linux `~/.local/share/org.poulapp.poulplan/poulplan.sqlite` est conservée intacte (non utilisée).

# Avancement

Dernière mise à jour : 2026-11-04

| Jalon | État |
|---|---|
| Conception / cahier des charges | Terminé (`SPEC.md`) |
| v0.1.0 Fondations | **Terminé** — critères vérifiés sur Linux et Pixel 10 |
| v0.2.0 Événements | **Terminé** — vérifié sous Linux, par tests et sur le Pixel (glisser-déposer tactile réel) |
| v0.3.0 Calendrier avancé | **Terminé** — vérifié sous Linux, par tests et sur le Pixel |
| v0.4.0 Cloud Poulapp | **Terminé** — validé par Louis : connexion et synchro Linux ↔ Pixel |
| v0.5.0 Notifications | **Terminé** — validé par Louis : Pixel (déverrouillé, verrouillé) et Linux (KDE) |
| v0.6.0 Intégrations | **Terminé** — validé par Louis le 2026-11-04 (widgets Android et KDE, actions, barre système), version 0.6.4 |
| v0.7.0 Fonctions complémentaires | **Terminé** — validé par Louis le 2026-11-04 (tests E1–E6), version 0.7.1 |
| v0.8.0 Navigation | **Terminé** — validé par Louis le 2026-11-08 (cartes, trajets, widgets 0.8.3) |
| v1.0.0 Version stable | **Terminé** — validé par Louis le 2026-11-08 (rapport : `docs/RAPPORT_V1.md`) |

## Reprendre le travail à froid
```bash
export PATH=$HOME/flutter/bin:$HOME/Android/Sdk/platform-tools:$PATH
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze && flutter test
flutter run -d linux --dart-define-from-file=.env   # ou -d 58021FDCR009YL (Pixel 10)
# sans --dart-define-from-file : version sans cloud (comme F-Droid)
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

## v0.3.0 — Calendrier avancé
Mini-plan : tests de récurrence d'abord (RRULE, dates invalides, DST, COUNT/UNTIL) → moteur → jours fériés et règle par série → dépliage avec exceptions → coupure de série → schéma v2 + migration testée → dépôts (portées, recherche) → interface → vérification.

- Fait :
  - récurrences quotidiennes/hebdo/mensuelles/annuelles, intervalle, jours de semaine, « n-ième / dernier jour X du mois », « n-ième jour X de tel mois », fin jamais / après N / jusqu'au ; préréglages + dialogue « Personnaliser » ; description en français ;
  - exceptions : modifier/supprimer **cette occurrence**, **cette occurrence et les suivantes** (coupure de série), **toutes** ; glisser-déposer d'une occurrence avec choix de la portée ; « Annuler » après suppression ;
  - jours fériés français calculés (Pâques), option Alsace-Moselle ; règle par série (sans effet / sauter / jour ouvré suivant / précédent) ;
  - vacances scolaires zones A, B, C, Corse (2024 → 2028) embarquées, affichées selon la zone choisie ;
  - anniversaires saisis à la main (âge affiché, 29 février fêté le 28 les années non bissextiles) ;
  - recherche insensible aux accents (Ctrl+F) avec filtres catégories et période, filtres enregistrables ;
  - schéma Drift v2 avec migration v1 → v2 (testée par drift + test d'intégrité des données).
- Testé :
  - 163 tests verts : 29 tests de règles (dont dernier vendredi, tous les 3 jours, 29 février, 31 du mois, COUNT/UNTIL, performance sur 130 ans), dépliage (changement d'heure, exceptions, occurrence déplacée, fériés), coupure de série, fériés 2026 et Pâques, portées d'édition/suppression en base, recherche, **recherche et affichage d'un mois sur 10 000 événements (< 500 ms, en pratique quelques ms)**, 8 tests d'interface v0.3 ;
  - Linux, base réelle v1 migrée en v2 au démarrage sans erreur ; capture : série hebdomadaire avec règle « sauter » qui saute bien le 11 novembre, vacances de la Toussaint zone A, fériés affichés.
- Non testé :
  - **Pixel** (toujours débranché) : v0.2 et v0.3 à vérifier sur l'appareil ;
  - vacances scolaires des DOM-TOM (non embarquées).
- Limites connues :
  - les règles RRULE exotiques (BYSETPOS, BYWEEKNO, BYYEARDAY, BYHOUR…) ne sont pas gérées : une règle illisible est affichée comme un événement simple ;
  - « cette occurrence et les suivantes » supprime les exceptions postérieures à la coupure ;
  - les « Début des vacances d'été » publiés sans date de fin s'affichent sur un seul jour.

## v0.4.0 — Cloud Poulapp
Mini-plan : scripts SQL alignés sur Poulpoints (fait avec Louis) → tests d'abord (horloge hybride, fusion par champ, conflits) → schéma v3 (métadonnées de synchro, conflits) → enregistreur de changements dans les dépôts → moteur (tirer, fusionner, pousser avec concurrence optimiste) → serveur simulé + scénario deux appareils → client Supabase, connexion, écrans → vérification.

- Fait :
  - Supabase installé par Louis (tables `poulplan_records`, fonction `poulplan_push`, bucket privé, accès accordé) ; vérifié par `verify.sql` ;
  - chaque écriture locale date ses champs modifiés (horloge logique hybride) et marque l'enregistrement « à envoyer » (file persistante = `sync_meta.dirty`) ;
  - synchro : tirage par révision avec recouvrement, fusion champ par champ, vrais conflits stockés pour l'utilisateur, envoi conditionnel (`base_rev`), nouvelle tentative après conflit ;
  - connexion facultative e-mail + mot de passe (paquet `supabase` pur Dart, MIT), vérification `poulapp_access`, session restaurée par le jeton de rafraîchissement ;
  - déclencheurs : connexion, 3 s après une modification, toutes les 5 min, retour au premier plan ; erreurs réseau sans effet sur l'usage local ;
  - écrans Compte Poulapp et Conflits (choisir « Cet appareil » / « Autre appareil ») ; icône d'état avec pastille de conflits.
- Testé :
  - 193 tests verts dont 15 de fusion/horloge et **12 tests deux appareils** (serveur simulé fidèle à `poulplan_push`) : création, suppression, champs différents fusionnés, même champ = conflit, choix de l'utilisateur propagé, suppression contre modification, hors ligne → file conservée → redémarrage → envoi, app utilisable cloud coupé, séries avec exceptions, envoi par lots, relecture du recouvrement sans effet ;
  - migrations v1→v2→v3 (drift + intégrité) ; base v1 réelle du Pixel migrée en v3 sans perte ;
  - serveur réel, clé publique seule : lecture `poulplan_records` refusée (401), `poulplan_push` refusé (« permission denied ») ;
  - Linux : écran Compte avec configuration cloud ; Pixel : vues, éditeur, glisser-déposer tactile réel.
- Testé par Louis : connexion réelle et synchro entre Linux et le Pixel ✅ (après ajout de la permission INTERNET en release). Conflit réel volontaire non signalé comme testé.
- Limites connues :
  - jeton de rafraîchissement stocké en clair dans la base locale (chiffrement / stockage sécurisé prévu en v0.7 avec le verrouillage) ;
  - pas de détection de connectivité : nouvel essai toutes les 5 min et au retour au premier plan ;
  - les paramètres (thème, zone scolaire…) ne sont pas synchronisés (choix volontaire : propres à chaque appareil).

## v0.5.0 — Notifications
Mini-plan : tests d'abord (calcul des déclenchements) → rappels sur l'événement (schéma v4) → service de notifications (Android + Linux) → programmateur → éditeur et paramètres → vérification → **arrêt : tests manuels**.

- Fait :
  - plusieurs rappels par événement (minutes avant ; journée entière : relatif à 9 h, « la veille à 9 h »…), synchronisés comme les autres champs ; rappel par défaut (10 min) pour les nouveaux événements avec horaire ;
  - Android : `flutter_local_notifications` (BSD-3), alarmes exactes (`USE_EXACT_ALARM`), re-planification après redémarrage/mise à jour (récepteur du greffon), notifications persistantes avec « C'est noté » / « Reporter 10 min » (aussi app fermée), ouverture de l'événement au toucher, permission demandée une fois au premier lancement ;
  - Linux : notifications D-Bus « critiques » (restent affichées sous KDE) avec boutons, vérification toutes les 30 s, rappels manqués (24 h) affichés au lancement, application **unique** qui **reste en arrière-plan** quand on ferme la fenêtre (paramètre), lancement `--background` et démarrage de session (fichier XDG autostart), « Quitter Poulplan » ;
  - paramètres « Rappels » : autorisation, rappel par défaut, notification de test (Android : une immédiate + une alarme système dans 1 min).
- Testé :
  - 205 tests verts dont 10 sur le calcul (journée entière au changement d'heure, séries, identifiants stables, rappels manqués), texte des notifications, éditeur de rappels ;
  - migration v1→v4 (drift + intégrité) ; correction : l'étape v1→v2 passée en SQL brut (sinon cassée par les colonnes ajoutées ensuite) ;
  - **Linux réel** : notification de test acceptée par KDE (D-Bus) ; rappel d'un événement inséré en base affiché à l'heure par le programmateur ; second lancement → réactive l'instance existante (code 0) ;
  - **Pixel réel** : build release installé ; alarme exacte vérifiée dans `dumpsys alarm` (`RTC_WAKEUP`, fenêtre 0, autorisée par `USE_EXACT_ALARM`) ; récepteur de démarrage déclaré.
- Corrigé en cours de route : `getNotificationAppLaunchDetails()` non implémenté sous Linux faisait échouer le démarrage du programmateur (aucun rappel Linux n'aurait sonné).
- Testé par Louis : notifications Pixel écran déverrouillé et verrouillé ✅, notifications Linux ✅. Non signalés comme testés : app fermée, redémarrage du téléphone, boutons « Reporter », démarrage de session Linux.
- Limites connues :
  - seuls les rappels des **30 prochains jours** sont confiés à Android (re-calculés à chaque ouverture et modification) : sans ouvrir l'app pendant plus de 30 jours, les rappels suivants ne sont pas programmés (piste : tâche périodique WorkManager) ;
  - un rappel reporté sous Linux est perdu si l'app est quittée pendant le report ;
  - sur Android 14+, l'utilisateur peut balayer une notification « persistante » (règle du système).

## v0.6.0 — Intégrations
Mini-plan : instantané commun pour les widgets (tests d'abord) → exportateur (fichier sous Linux, home_widget sous Android) → widgets Android natifs (Kotlin) → icône de zone de notification Linux → plasmoïde KDE → ouverture directe d'un événement → vérification.

- Fait :
  - instantané `widget.json` / préférences Android : prochains événements (20) et jours occupés (3 couleurs/jour), exporté 2 s après tout changement, relu par les widgets qui recalculent « aujourd'hui » eux-mêmes ;
  - Android : widgets « À venir » (6 lignes, clic → événement) et « Mois » (dessiné en Kotlin, jour courant, points de couleur), `updatePeriodMillis` 30 min ;
  - Linux : icône StatusNotifierItem en Dart pur via D-Bus (pas de bibliothèque native), menu dbusmenu Ouvrir/Quitter, infobulle « Prochain : … » ;
  - plasmoïde Plasma 6 `linux/plasmoid/org.poulapp.poulplan.upcoming` (lecture du fichier toutes les minutes, commande de lancement configurable) ;
  - ouverture directe : `poulplan://event/<id>` (Android), `poulplan --open-event=<id>` (Linux, transmis à l'instance existante par action GApplication).
- Corrigé en cours de route : **sous Linux en distrobox, tous les horaires s'affichaient en UTC** (`/etc/localtime` est une copie, `/etc/timezone` périmé à `Etc/UTC`, et le greffon de fuseau renvoyait cette valeur) → fuseau reconnu par le contenu de `/etc/localtime` et toute réponse validée contre l'horloge locale.
- Testé :
  - 225 tests verts (instantané, liens, infobulle, détection du fuseau dont le cas distrobox) ;
  - Linux réel : icône enregistrée auprès de KDE (`StatusNotifierWatcher`), infobulle lue par D-Bus, `widget.json` écrit, `--open-event=<id>` ouvre l'éditeur sur l'événement (capture), horaires corrigés en heure de Paris ;
  - builds release Linux et Android (widgets compris).
- Non testé : affichage réel des widgets Android (Pixel débranché), plasmoïde (pas d'outil QML dans le conteneur), menu de l'icône (clics) → tests manuels.
- Limites : le widget « Mois » montre le mois en cours seulement ; le plasmoïde lit le fichier toutes les minutes (pas d'événement immédiat).

## v0.7.0 — Fonctions complémentaires
Mini-plan (dans l'ordre, un commit par étape) :
1. Sauvegarde = archive zip (`poulplan-backup`, version 1) des enregistrements tels que synchronisés (codecs de synchro) + fichiers des pièces jointes ; restauration par **fusion** (rien n'est effacé localement), enregistrée comme modification locale pour partir en synchro. Tests d'abord (aller-retour, fusion, archive invalide).
2. Export ICS des événements (RRULE, exceptions, annulations) et import VCF des anniversaires (tests d'abord), import des anniversaires des contacts Android (canal Kotlin, permission READ_CONTACTS demandée à l'usage).
3. Sauvegardes locales automatiques (1/jour, 7 conservées) et cloud (Storage privé `<uid>/backups/`, 5 conservées), écran Sauvegardes : sauvegarder, restaurer (fichier, liste locale, cloud), exporter.
4. Pièces jointes : table `attachments` synchronisée (métadonnées) + table locale des fichiers, copie locale, envoi/récupération Storage, « garder hors ligne », ouverture (FileProvider Android, xdg-open Linux).
5. Verrouillage facultatif : PIN (haché, salé) partout, biométrie Android (`local_auth`), au lancement et après 5 min en arrière-plan.
6. Nettoyage d'espace : tailles (base, pièces jointes, sauvegardes), suppression des anciennes sauvegardes et des copies locales récupérables, alerte quand l'espace libre est faible.

- Fait :
  - sauvegardes zip (`poulplan-backup.json` + `files/<id>`), restauration par fusion enregistrée pour la synchro, automatiques (1/jour, 7 locales, 5 cloud dans `<uid>/backups/`), écran Sauvegardes et export ;
  - export ICS (TZID IANA sans VTIMEZONE, UNTIL converti en UTC, EXDATE/RECURRENCE-ID, VALARM), import VCF 2.1/3.0/4.0 (quoted-printable, lignes repliées, années omises) et contacts Android (READ_CONTACTS à l'usage), sans doublons ;
  - pièces jointes : tables `attachments` (synchronisée) et `attachment_files` (locale), schéma v5, transfert Storage après chaque synchro, « garder sur cet appareil », ouverture (FileProvider / xdg-open), 25 Mo max ;
  - verrouillage par code (PBKDF2-HMAC-SHA256, 20 000 itérations, sel aléatoire), biométrie Android (`local_auth`, `FlutterFragmentActivity`), délai réglable, 5 essais puis 30 s ;
  - espace de stockage et proposition de nettoyage (SnackBar au démarrage, une fois par semaine, sous 500 Mo libres) ;
  - demande de Louis : dates de début et de fin des répétitions dans l'éditeur.
- Testé : 273 tests verts (sauvegarde aller-retour, fusion, archive invalide, ICS, vCard, PIN dont vecteur RFC, transfert des pièces jointes avec serveur simulé, écran de verrouillage, éditeur) ; sous Linux réel : sauvegarde automatique locale **et** cloud effectuées 30 s après le démarrage, écrans Sauvegardes, Paramètres et Espace de stockage (captures).
- Non testé : tout sur le Pixel (ADB « unauthorized » au moment du déploiement), restauration sur un autre appareil, ouverture réelle des pièces jointes, biométrie, import des contacts, sélecteurs de fichiers natifs → tests manuels E1–E6.
- Limites : pièces jointes d'un événement supprimé conservées (non visibles) ; widgets et notifications visibles malgré le verrouillage ; le code oublié n'est pas récupérable (données récupérables par la synchro ou une sauvegarde).

## v0.8.0 — Navigation
Mini-plan (option A, détails dans `DECISIONS.md`) :
1. Domaine, tests d'abord : décodage des réponses Nominatim/OSRM/BRouter (polyline, GeoJSON), liste des tuiles d'une zone, modèle de trajet.
2. Schéma v6 : coordonnées sur l'événement, table `routes` synchronisée (géométrie, durée, distance, profil), table locale des zones de carte.
3. Éditeur : « Localiser » le lieu (Nominatim), section Trajet (profil, calcul, durée/distance, mini-carte) ; paramètre « Adresse de départ ».
4. Page Carte (fond OpenFreeMap, marqueur, trajet, attribution).
5. Zones hors ligne (téléchargement d'une zone limitée, liste, suppression) et recalcul hors ligne Android via BRouter.
6. Vérification : trajet calculé en ligne puis consulté hors ligne (critère du jalon).

- Fait :
  - schéma v6 : coordonnées du lieu sur l'événement, table `routes` synchronisée (géométrie en polyline encodée), table locale `map_zones` ;
  - recherche de lieu Nominatim (sur action, 1/s, User-Agent), trajets OSRM FOSSGIS (voiture, vélo, à pied), trajet mémorisé affiché dans l'éditeur (durée, distance, mini-carte) et en plein écran ;
  - carte vectorielle OpenFreeMap (`flutter_map` + `flutter_map_vector_tiles`, noms en français), source de tuiles locale d'abord : zones téléchargées (6000 tuiles max, 2 requêtes à la fois, reprise possible) puis cache des lieux vus (150 Mo) ;
  - hors ligne Android : service AIDL de l'app BRouter (`IBRouterService`), réponse GeoJSON ou GPX ;
  - paramètres « Cartes et trajets » : adresse de départ, zones, état de BRouter.
- Corrigé : depuis la 0.7, la synchro se terminait en erreur à cause d'une dépendance circulaire (transfert des pièces jointes) — les données passaient, l'état affiché et l'envoi des fichiers non.
- Testé : 297 tests (décodage polyline/OSRM/BRouter/Nominatim, tuiles d'une zone, téléchargement et reprise d'une zone, source locale d'abord, trajets mémorisés et synchronisés, section Trajet de l'éditeur) ; services réels interrogés (Nominatim, OSRM voiture/vélo/pied à Lyon, TileJSON OpenFreeMap) ; carte réelle affichée sous Linux (capture).
- Non testé : Pixel (absent d'ADB), BRouter réel, téléchargement réel d'une zone, consultation hors ligne réelle → tests F1–F5.
- Limites : pas de géolocalisation (point de départ = adresse) ; sous Linux pas de recalcul hors ligne ; glyphes de police non encore vus indisponibles hors ligne (rare).

## v1.0.0 — Version stable
Mini-plan : audit des licences → performances (gros volume) → accessibilité → F-Droid (fastlane, SQLite depuis la source) → Flatpak (manifeste, AppStream) → README et captures → rapport final.

- Fait : audit (`docs/LICENSES.md`, `tool/license_audit.dart` : 120 paquets BSD/MIT/Apache/MPL ; Gradle sans Google Play ni Firebase) ; tests de performance (`test/perf/`) ; accessibilité (`test/features/accessibility_test.dart`, cibles 48 dp, libellés des couleurs, contraste des jours hors du mois, étiquettes du mois exclues de la sémantique au profit de la case du jour) ; fiche F-Droid FR/EN, recette et SQLite depuis la source (`docs/PUBLICATION.md`) ; manifeste Flatpak + AppStream validés ; README avec captures d'un calendrier de démonstration (`tool/demo_data.dart`, `POULPLAN_DATA_DIR`) ; version 1.0.0 installée sur Pixel et PC.
- Non testé : construction Flatpak, recette F-Droid réelle, lecteurs d'écran → `docs/RAPPORT_V1.md`.

## Journal
- 2026-11-08 : v1.0.0 validée par Louis (« Oui, tague ») et taguée, CI verte. Restent avant publication : construction Flatpak, demande F-Droid, essais avec lecteur d'écran (voir `docs/RAPPORT_V1.md`).
- 2026-11-08 : v1.0.0 préparée (performances, accessibilité, F-Droid, Flatpak, README, rapport final) ; installée Pixel + PC ; tag en attente de la validation de Louis.
- 2026-11-08 : v0.8.0 validée par Louis (« je valide les fonctions cartes », widgets 0.8.3 « C'est bon ») et taguée.
- 2026-11-08 : 0.8.3 — retours de Louis : mode clair ✅ ; centrage Android pas fiable → la liste gardait sa position d'une mise à jour à l'autre (adaptateur conservé par le lanceur), or le calcul suppose un départ en haut : le nombre de types de vues alterne 1/2 à chaque mise à jour, ce qui donne un nouvel adaptateur et un départ en haut à chaque fois. KDE : boutons poussés en haut à droite (espace extensible). Installée Pixel + KDE (plasmashell relancé, pas d'erreur).
- 2026-11-08 : 0.8.2 — widgets Android (demande de Louis) : bouton « Ouvrir Poulplan » à gauche du bouton « + » (widgets Journée et À venir), widget Journée centré sur la ligne de l'heure actuelle, thème clair des trois widgets (suit le thème du système ; couleurs dans `values/widget_colors.xml` et `values-night/`). **Non testé sur appareil** (aucun Android ici, seule la CI compile) : à vérifier sur le Pixel — bouton, centrage (précision visée : une demi-heure), bascule clair/sombre du système avec les trois widgets (Mois : deux images, `layout-night`). Limites : le centrage dépend du défilement natif d'Android (il peut ne pas se recentrer si la liste a été déplacée à la main avant la mise à jour) ; avant Android 12, le texte des widgets est mis à jour au thème à la prochaine actualisation seulement.
- 2026-11-08 : 0.8.2 (suite, KDE) — même demande pour les widgets KDE : bouton « Ouvrir Poulplan » (icône de l'app) à côté du + (Journée et À venir), frise Journée centrée sur l'heure actuelle (laissée tranquille 2 min après un défilement manuel). Plasmoïdes installés, plasmashell relancé, pas d'erreur QML dans le journal. La même demande avait été traitée en parallèle par une autre session pour Android : sa version (poussée) est gardée ; ma variante Android est conservée dans la branche locale `widgets-0.8.2-local` (non poussée).
- 2026-11-04 : 0.8.1 — synchro du Pixel en échec : le serveur refusait les types `attachment` et `route` (contrainte de la table) et tout le lot échouait → script `supabase/migrations/0004_poulplan_new_entities.sql` (à exécuter par Louis), envoi par type (un type refusé ne bloque plus les autres). Trouvé en lisant la requête : la récupération se faisait par révision **décroissante** (`order()` de postgrest est décroissant par défaut) → corrigé, test sur la requête envoyée ; c'est la cause probable du bug de catégorie de la 0.7.1.
- 2026-11-04 : v0.8.0 codée (cartes, lieux, trajets, zones hors ligne, BRouter) ; correction de la synchro (dépendance circulaire des pièces jointes) ; arrêt pour les tests F1–F5.
- 2026-11-04 : 0.7.2 — la barre « supprimé / Annuler » ne se fermait jamais (Flutter garde par défaut les barres avec bouton) → fermeture après 6 s (test). Déployée sur le PC ; Pixel non détecté par ADB.
- 2026-11-04 : v0.8.0 : option A choisie par Louis (fond OpenFreeMap, trajets OSRM FOSSGIS mémorisés, recalcul hors ligne via l'app BRouter sur Android).
- 2026-11-04 : v0.7.0 validée par Louis (« Tout m'a l'air bon ») et taguée. Prochaine étape : v0.8.0, arrêt pour le choix du moteur de cartes/routage.
- 2026-11-04 : 0.7.1 — sur le Pixel, la synchro échouait (clé étrangère) : l'événement « Planning et démarrage » arrivait sans sa catégorie « 6 Month ». La catégorie manquante est maintenant récupérée dans le cloud, sinon l'événement est rangé sans catégorie localement (tests ajoutés). Cause exacte du « trou » non établie (base du Pixel illisible en release). Déployée Pixel + PC, plus d'erreur de synchro au lancement.
- 2026-11-04 : v0.7.0 codée (sauvegardes, export ICS, import VCF/contacts, pièces jointes, verrouillage, espace de stockage) + dates de début/fin des répétitions (demande de Louis) ; arrêt pour les tests manuels E1–E6.
- 2026-11-03 : dépôt initialisé (CLAUDE.md, spec, roadmap, CI, licence GPL-3.0).
- 2026-11-04 : 0.6.3 — retours de Louis sur la 0.6.2 : Android, ouvrir un événement → page d'erreur et + sans effet (Flutter routait lui-même les liens poulplan:// : `flutter_deeplinking_enabled=false`) ; KDE, aucune action (commande de lancement non configurée → actions envoyées par D-Bus à l'app, commande en secours) ; widget Journée redessiné en frise horaire avec ligne de l'heure (Android 12+ et KDE).
- 2026-11-04 : 0.6.4 — retours sur la 0.6.3 : Android OK (+, ouverture, heures, ligne). Widget Journée Android défilant sur 24 h (une ligne de liste par heure, 52 dp, se cale sur l'heure courante), événements en pleine largeur partagée seulement par groupe de chevauchement (largeur par poids de layout, plus de dépendance à la taille déclarée par le lanceur). Linux : l'entrée de menu pointait vers un dossier absent → `tool/install_linux_dev.sh` (copie du bundle, commande `~/.local/bin/poulplan` via distrobox, entrée de menu, icônes, widgets KDE) ; autostart via `distrobox enter` dans un conteneur ; widgets KDE en secours sur `~/.local/bin/poulplan` puis Flatpak. À vérifier par Louis : rendu du widget défilant, widgets KDE après redémarrage de plasmashell.
- 2026-11-04 : v0.6.0 validée par Louis (« ça fonctionne ») et taguée. Prochaine étape : v0.7.0 (pièces jointes, import/export, sauvegardes, verrouillage).
- 2026-11-04 : 0.6.2 — widget « Journée » (Android et KDE, demande de Louis), bouton + (nouvel événement) et ouverture de l'app depuis tous les widgets, aperçus dans le sélecteur Android ; menu « Quitter » de l'icône vérifié par D-Bus.
- 2026-11-04 : retours v0.6 de Louis : widget Mois ✅, widget À venir ❌ (`<View>` interdit dans un widget), plasmoïde qui déborde ❌, demandes : « Journée », barres multi-jours continues, retrait des événements de démo → corrigé en 0.6.1 (`cc1ab21`) ; mes 8 événements de démonstration supprimés (suppression synchronisée).
- 2026-11-04 : v0.6.0 codée ; bug d'affichage en UTC sous Linux découvert et corrigé.
- 2026-11-03 : tour 2 des tests manuels : création rapide avec clavier ✅, notifications Pixel déverrouillé/verrouillé ✅, chiffres AZERTY ✅, synchro partout ✅ ; traits de grille et notifications Linux ✅ après correction (grille dessinée d'un seul tenant, `07e99da`) et arrêt de l'ancienne instance. v0.4.0 et v0.5.0 taguées.
- 2026-11-03 : tour 1 des tests manuels de Louis : synchro Linux ✅ ; connexion Pixel ❌ (pas de permission INTERNET en release), notification de test Pixel ❌ (icône supprimée par la minification), pas de demande d'autorisation au lancement ❌, création rapide chevauchée par le clavier ❌, traits de grille discontinus ❌, chiffres impossibles à taper (AZERTY sans Maj) ❌, pas de rappel pour un événement créé moins de 10 min avant ❌ → tous corrigés en 0.5.1 (`52a62bb`), tour 2 à faire.
- 2026-11-03 : v0.5.0 codée ; arrêt pour les tests manuels (cloud + notifications).
- 2026-11-03 : v0.4.0 codée (Supabase installé avec Louis) ; tag en attente du test réel de connexion.
- 2026-11-03 : v0.3.0 tagué ; arrêt au point prévu avant v0.4.0 (Supabase).
- 2026-11-03 : v0.2.0 tagué (Pixel non revérifié, débranché).
- 2026-11-03 : v0.1.0. Incident : au premier `flutter run` sur le Pixel, une ancienne app `org.poulapp.poulplan` (versionCode 3, d'origine inconnue) bloquait l'installation ; `flutter run` l'a **désinstallée automatiquement** avec ses données, sans confirmation. L'ancienne base Linux `~/.local/share/org.poulapp.poulplan/poulplan.sqlite` est conservée intacte (non utilisée).

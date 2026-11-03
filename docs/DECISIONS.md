# Décisions d'architecture

Une ligne par décision : date — décision — raison.

- 2026-11-03 — Flutter + Drift + Riverpod — réutilisation du code Android/Linux, cohérent avec Poulpoints.
- 2026-11-03 — Fichiers générés Drift (`*.g.dart`) commités — builds F-Droid/CI sans étape supplémentaire.
- 2026-11-03 — Licence GPL-3.0 — compatibilité F-Droid, esprit open source de Poulapp.
- 2026-11-03 — Instants stockés en ms UTC + fuseau IANA de saisie ; événements « journée entière » en dates flottantes (minuit UTC, fin exclusive) — un changement de fuseau ou d'heure ne décale jamais une journée entière ; les requêtes par plage restent indexables.
- 2026-11-03 — Identifiants UUID v4 et suppression logique (`deletedAt`) dès le schéma v1 ; catégories par défaut à identifiant fixe — préparer la synchro sans migration lourde ni doublons entre appareils.
- 2026-11-03 — Arithmétique de dates via une classe `Day` (calculs en UTC) et conversion d'affichage injectable (`LocalTime`) — tests de fuseaux déterministes, aucune dérive au changement d'heure.
- 2026-11-03 — Base `poulplan.db` dans le dossier support de l'app (et non `Documents/` par défaut de drift_flutter, ni `poulplan.sqlite` déjà utilisé par une ancienne base étrangère au dépôt).
- 2026-11-03 — Riverpod sans génération de code (providers écrits à la main) — moins d'étapes de build, code généré limité à Drift et l10n.
- 2026-11-03 — Fuseau sous Linux : plugin `flutter_timezone`, puis repli `TZ` → `/etc/localtime` → `/etc/timezone` — `timedatectl` (systemd) est absent dans distrobox et les bacs à sable.
- 2026-11-03 — Linux : barre de titre système (GTK sans `GtkHeaderBar`) — décorations serveur de KWin, évite les soucis rencontrés dans Poulpoints.
- 2026-11-03 — Moteur de récurrence écrit dans le projet (v0.3) plutôt que le paquet `rrule` — maîtrise des fuseaux, du changement d'heure et des exceptions.
- 2026-11-03 — Glisser-déposer : `Draggable` à la souris (bureau), `LongPressDraggable` au toucher (Android) — le défilement reste possible au doigt.
- 2026-11-03 — Déplacement d'un événement à heure murale constante dans son propre fuseau ; une heure inexistante (printemps) est repoussée après le saut, une heure ambiguë (automne) prend sa première occurrence.
- 2026-11-03 — Récurrences : règle RRULE (sous-ensemble RFC 5545) stockée sur l'événement maître et dépliée à l'affichage ; dates invalides ignorées (31 avril, 29 février) comme la RFC ; occurrences identifiées par `<idSérie>@<début d'origine UTC ms>`.
- 2026-11-03 — Exceptions de série = lignes séparées (`seriesId` + `originalStartUtc`, `cancelled` pour une suppression) plutôt qu'une liste EXDATE dans le maître — fusion de synchro plus simple (pas de conflit sur un champ liste).
- 2026-11-03 — « Cette occurrence et les suivantes » = coupure de la série (UNTIL ou COUNT partagé) et nouveau maître ; les exceptions postérieures à la coupure sont supprimées.
- 2026-11-03 — Jours fériés français calculés (Pâques par l'algorithme grégorien anonyme), option Alsace-Moselle ; règle par série : aucune / sauter / jour ouvré suivant / précédent.
- 2026-11-03 — Vacances scolaires : extrait embarqué (`assets/data/school_holidays_fr.json`) des données ouvertes de l'Éducation nationale (Licence Ouverte 2.0), régénéré par `tool/update_school_holidays.dart` — aucun accès réseau à l'exécution.
- 2026-11-03 — Recherche : colonne `searchText` normalisée (minuscules, sans accents) + `LIKE` par mot, plutôt que FTS5 — insensible aux accents, sans dépendre des options de compilation de SQLite.
- 2026-11-03 — Cloud : une table générique `poulplan_records` (entity, id, data jsonb, deleted, rev) plutôt qu'une table par entité — schéma serveur stable quand l'app évolue, contenu opaque compatible avec un futur chiffrement de bout en bout.
- 2026-11-03 — Synchro : révision serveur monotone (`rev`, séquence) pour récupérer les changements ; envoi par `poulplan_push` avec concurrence optimiste (`base_rev`) — pas d'écrasement silencieux ; fusion champ par champ côté app, intervention de l'utilisateur seulement si le même champ a changé des deux côtés.
- 2026-11-03 — Accès cloud : mêmes conventions que Poulpoints (table existante `poulapp_access(user_id, app_id, approved_at)`) — RLS `user_id = auth.uid()` et `exists(poulapp_access … app_id = 'poulplan')`, droits explicites `select/insert/update`, pas de suppression réelle côté client (pierres tombales), fonctions internes dans le schéma `private`.
- 2026-11-03 — Récupération des changements par `rev` (séquence) avec recouvrement : l'app redemande une marge de révisions déjà vues, car une transaction plus ancienne peut être validée après une plus récente ; fusion idempotente, donc sans effet de bord.
- 2026-11-03 — Configuration Supabase (URL + clé anon) dans `.env` local ignoré par git, jamais dans le code.
- 2026-11-03 — Client cloud : paquet `supabase` pur Dart plutôt que `supabase_flutter` — pas de greffons natifs (liens profonds, stockage) inutiles pour une connexion par mot de passe ; meilleur pour F-Droid.
- 2026-11-03 — Session cloud : seul le jeton de rafraîchissement est conservé (table `settings`), jamais le mot de passe ; à protéger en v0.7 (stockage sécurisé/verrouillage).
- 2026-11-03 — Versions par champ : horloge logique hybride (`ms:compteur:appareil`, triable comme texte), données de suivi dans `sync_meta` plutôt que dans chaque table — schéma métier inchangé, file d'envoi persistante = lignes `dirty`.
- 2026-11-03 — Catégories par défaut créées avec `createdAt = 0` — identiques sur tous les appareils, donc jamais en conflit une fois synchronisées.
- 2026-11-03 — Configuration cloud injectée à la compilation (`--dart-define-from-file=.env`) ; sans elle (CI, F-Droid), l'écran Compte indique que la version n'est pas reliée au cloud.
- À traiter en v1.0 : `sqlite3` 3.x télécharge par défaut des bibliothèques SQLite précompilées (hook de build) ; pour F-Droid, compiler depuis la source (`hooks: user_defines: sqlite3: source: source`) ou utiliser la bibliothèque système.
- À décider : moteur de cartes/routage libre hors ligne (jalon v0.8.0).
- 2026-11-03 — Rappels Linux : l'application elle-même, unique (GApplication), reste en arrière-plan quand la fenêtre est fermée et peut démarrer cachée (`--background`, fichier XDG autostart ; portail Background en Flatpak) — pas de service systemd séparé, un seul code de rappels.
- 2026-11-03 — Rappels Android : `USE_EXACT_ALARM` (application calendrier) + `SCHEDULE_EXACT_ALARM` jusqu'à l'API 32 ; 30 jours de rappels confiés au système, recalculés à chaque modification ; permission de notifications demandée une seule fois au premier lancement.
- 2026-11-03 — Rappels « journée entière » calculés à heure murale (J-n à 9 h) et non en soustrayant des minutes — « la veille à 9 h » reste à 9 h au changement d'heure.

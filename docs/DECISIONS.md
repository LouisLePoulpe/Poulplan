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
- À traiter en v1.0 : `sqlite3` 3.x télécharge par défaut des bibliothèques SQLite précompilées (hook de build) ; pour F-Droid, compiler depuis la source (`hooks: user_defines: sqlite3: source: source`) ou utiliser la bibliothèque système.
- À décider : moteur de cartes/routage libre hors ligne (jalon v0.8.0).
- À décider : stratégie exacte de rappels sous Linux (démon en arrière-plan vs service utilisateur systemd).

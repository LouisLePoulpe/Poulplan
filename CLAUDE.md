# Poulplan — instructions pour Claude Code

Poulplan est le calendrier personnel de l'écosystème **Poulapp** (Android + Linux), développé en Flutter.
Propriétaire : Louis (francophone, style direct et pratique). **Réponds en français**, code et identifiants en anglais.

## À lire avant de coder
- `docs/SPEC.md` : cahier des charges validé (source de vérité fonctionnelle).
- `docs/ROADMAP.md` : jalons v0.1.0 → v1.0.0 avec critères de validation. Suis l'ordre, un jalon à la fois.
- `docs/PROGRESS.md` : état réel d'avancement. **Mets-le à jour à la fin de chaque session** (ce qui est fait, testé, cassé).

## Règles non négociables (décisions déjà validées)
- **Local-first** : toute donnée est écrite d'abord en SQLite (Drift). L'app doit être 100 % utilisable sans compte ni Internet. Une panne Supabase ne doit jamais bloquer la lecture/édition locale.
- **Un seul calendrier personnel**, privé, sans partage.
- **Aucune synchro** avec Google/Outlook/CalDAV, **aucun lien** avec Poulpoints, **aucune intégration** au calendrier système Android.
- **Cloud = Supabase Poulapp uniquement**, facultatif. Un projet Supabase est mutualisé entre apps : tables préfixées `poulplan_`, RLS par utilisateur, table `poulapp_access` pour l'accès par application, inscription publique désactivée. Aucune clé secrète dans le dépôt (le `anon key` est public, jamais la `service_role`).
- **Open source, compatible F-Droid** : licence GPL-3.0, aucune dépendance propriétaire (pas de Google Play Services, pas de Firebase, pas de pub/tracking). Vérifie la licence de chaque nouvelle dépendance avant de l'ajouter.
- Thèmes clair/sombre/système. Identité visuelle : logo jaune fourni par Louis (horloge + calendrier + 4 saisons) — ne pas inventer de logo, utiliser un placeholder tant qu'il n'est pas dans `assets/`.
- Langue de l'interface : français d'abord (intl prêt pour d'autres langues).

## Stack
Dart / Flutter · SQLite via **Drift** · état : **Riverpod** · Supabase (Auth, PostgreSQL, Storage privé) · Kotlin seulement si Flutter ne suffit pas (widgets, alarmes exactes) · Linux : Flatpak, cible KDE Plasma/Bazzite · cartes : OpenStreetMap, moteur libre à choisir (décision à documenter dans `docs/DECISIONS.md`).

## Commandes
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # code généré Drift
flutter analyze                                            # doit être à 0 problème
flutter test
flutter run -d linux                                       # ou -d <appareil Android>
```
Les fichiers générés (`*.g.dart`) sont **commités**, pour que F-Droid et la CI construisent sans étape magique.

## Méthode de travail
1. Avant de coder un jalon : relis sa section dans `ROADMAP.md`, propose un plan court, puis implémente.
2. Écris les **tests unitaires** pour la logique métier (récurrences, fuseaux horaires, fusion de conflits de synchro) : c'est là que les bugs coûtent cher.
3. `flutter analyze` et `flutter test` doivent passer avant chaque commit. Corrige les causes, ne désactive pas les règles.
4. Commits petits et en français, préfixe conventionnel (`feat:`, `fix:`, `test:`, `docs:`, `chore:`). Un jalon terminé = tag `vX.Y.Z`.
5. Ne marque un jalon comme terminé que si ses critères de validation de `ROADMAP.md` sont vérifiés. Dis clairement ce que tu n'as pas pu tester (ex. : notifications sur appareil réel).
6. Toute décision d'architecture non triviale → une ligne datée dans `docs/DECISIONS.md`.
7. Ne fais pas de grosse refonte non demandée ; ne change pas le périmètre fonctionnel sans en parler à Louis.

## Pièges connus à surveiller
- Récurrences : stocker la règle (RRULE-like) + exceptions, **ne pas** matérialiser des années d'occurrences ; fuseaux horaires et passage à l'heure d'été/hiver à tester.
- Notifications Android : alarmes exactes, redémarrage de l'appareil (re-planification), optimisation de batterie ; sous Linux, rappels via le démon en arrière-plan/zone de notification.
- Wayland/KDE : la barre de titre personnalisée a déjà posé problème dans Poulpoints (abandonnée) — garder la barre de titre système.
- Synchro : file d'opérations locale persistante, résolution par champ quand c'est possible, intervention de l'utilisateur uniquement pour les vrais conflits.

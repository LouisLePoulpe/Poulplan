# Publication

## F-Droid

Métadonnées de la fiche : `fastlane/metadata/android/{fr-FR,en-US}` (titre,
descriptions, icône 512 px, captures, notes de version par `versionCode`).

Ce qui rend le dépôt compatible :
- aucune dépendance propriétaire (audit : `docs/LICENSES.md` pour Dart ;
  côté Android, `./gradlew :app:dependencies` ne contient que AndroidX,
  Kotlin, Gson, Guava — Apache-2.0 — aucun Google Play Services ni Firebase) ;
- **SQLite compilé depuis la source** pour F-Droid : par défaut, le paquet
  `sqlite3` télécharge des bibliothèques précompilées ; la recette fournit le
  fichier `sqlite3.c` officiel et active `source: source` (vérifié : builds
  Linux et Android sans téléchargement, `.so` pour arm64, armv7, x86_64) ;
- sans fichier `.env`, la version construite n'a pas de cloud (aucune clé,
  pas d'anti-fonctionnalité `NonFreeNet` : les seuls services réseau sont
  OpenFreeMap, Nominatim et OSRM de FOSSGIS, libres et utilisés à la demande).

Recette à proposer à `fdroiddata` (`metadata/org.poulapp.poulplan.yml`),
`versionCode` et `commit` à mettre à jour à chaque version :

```yaml
Categories:
  - Time
License: GPL-3.0-or-later
AuthorName: Louis Le Poulpe
SourceCode: https://github.com/LouisLePoulpe/Poulplan
IssueTracker: https://github.com/LouisLePoulpe/Poulplan/issues

AutoName: Poulplan

RepoType: git
Repo: https://github.com/LouisLePoulpe/Poulplan.git

Builds:
  - versionName: 1.0.0
    versionCode: 19
    commit: v1.0.0
    output: build/app/outputs/flutter-apk/app-release.apk
    srclibs:
      - flutter@3.47.7
    prebuild:
      # SQLite 3.53.4 (version du paquet sqlite3 3.5.2), compilé depuis la source.
      - curl -fLo sqlite.zip https://sqlite.org/2026/sqlite-amalgamation-3530400.zip
      - echo "1e71ddf93849c6a6ecf58b827c0692073d2dd7ee40196158068f7b29f422e87d  sqlite.zip" | sha256sum -c
      - unzip -j sqlite.zip '*/sqlite3.c' -d .sqlite
      - printf '\nhooks:\n  user_defines:\n    sqlite3:\n      source: source\n      path: .sqlite/sqlite3.c\n' >> pubspec.yaml
      - export PUB_CACHE=$(pwd)/.pub-cache
      - $$flutter$$/bin/flutter config --no-analytics
      - $$flutter$$/bin/flutter pub get
    scandelete:
      - .pub-cache
    build:
      - export PUB_CACHE=$(pwd)/.pub-cache
      - $$flutter$$/bin/flutter build apk --release

AutoUpdateMode: Version
UpdateCheckMode: Tags ^v[0-9.]+$
CurrentVersion: 1.0.0
CurrentVersionCode: 19
```

À vérifier lors de la soumission : la version de Flutter disponible dans
`srclibs`, et la construction reproductible (comparer l'APK de F-Droid avec
celui de la CI ; les fichiers générés `*.g.dart` sont commités pour que la
construction ne dépende pas de `build_runner`).

Signature : la version de développement est signée avec la clé de débogage ;
F-Droid signe avec sa propre clé. Une diffusion hors F-Droid demanderait une
clé de publication (à créer par Louis, jamais dans le dépôt).

## Flatpak (Linux)

Fichiers : `linux/packaging/org.poulapp.poulplan.yml` (manifeste),
`org.poulapp.poulplan.metainfo.xml` (fiche AppStream, validée par
`appstreamcli validate`), `org.poulapp.poulplan.desktop` (validé par
`desktop-file-validate`), icônes.

```bash
flutter build linux --release --dart-define-from-file=.env   # sans .env : sans cloud
flatpak install --user flathub org.gnome.Sdk//51 org.flatpak.Builder
flatpak run org.flatpak.Builder --user --install --force-clean build-flatpak linux/packaging/org.poulapp.poulplan.yml
flatpak run org.poulapp.poulplan
```

Le manifeste empaquette le bundle construit par Flutter (comme la plupart des
applications Flutter) ; une publication sur Flathub demanderait en plus de
construire depuis la source dans le bac à sable (outil `flatpak-flutter`).
Les widgets KDE lancent `flatpak run org.poulapp.poulplan` quand l'application
n'est pas déjà ouverte.

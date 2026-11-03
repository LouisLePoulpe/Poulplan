# Poulplan

Calendrier personnel **local-first** de l'écosystème **Poulapp** — Android et Linux, open source (GPL-3.0), utilisable sans compte ni connexion, synchronisation cloud facultative.

> État : en démarrage. Voir [`docs/PROGRESS.md`](docs/PROGRESS.md).

- Cahier des charges : [`docs/SPEC.md`](docs/SPEC.md)
- Feuille de route (v0.1.0 → v1.0.0) : [`docs/ROADMAP.md`](docs/ROADMAP.md)
- Décisions d'architecture : [`docs/DECISIONS.md`](docs/DECISIONS.md)
- Instructions pour Claude Code : [`CLAUDE.md`](CLAUDE.md)

## Développement

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter run -d linux
```

## Licence

GPL-3.0 — voir [`LICENSE`](LICENSE).

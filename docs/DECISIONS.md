# Décisions d'architecture

Une ligne par décision : date — décision — raison.

- 2026-11-03 — Flutter + Drift + Riverpod — réutilisation du code Android/Linux, cohérent avec Poulpoints.
- 2026-11-03 — Fichiers générés Drift (`*.g.dart`) commités — builds F-Droid/CI sans étape supplémentaire.
- 2026-11-03 — Licence GPL-3.0 — compatibilité F-Droid, esprit open source de Poulapp.
- À décider : moteur de cartes/routage libre hors ligne (jalon v0.8.0).
- À décider : stratégie exacte de rappels sous Linux (démon en arrière-plan vs service utilisateur systemd).

# Feuille de route Poulplan

Chaque version doit être **testable** avant de passer à la suivante. Un jalon est terminé quand tous ses critères sont cochés dans `PROGRESS.md`.

## v0.1.0 — Fondations
- Projet Flutter Android + Linux, structure en couches (`data/`, `domain/`, `features/`, `core/`).
- SQLite local via Drift : schéma initial (événements, catégories, paramètres), migrations versionnées.
- Première **vue mensuelle** (navigation mois précédent/suivant, jour courant, événements affichés).
- Écran paramètres (thème clair/sombre/système, premier jour de semaine).
- Identité visuelle Poulplan (placeholder si logo absent).
- **Validation :** l'app démarre sur Linux et Android ; un événement inséré en base apparaît dans la vue mensuelle ; `flutter analyze` à 0 ; tests de base verts.

## v0.2.0 — Événements
- Création / modification / suppression, catégories et couleurs, événements journée entière et multi-jours, chevauchements signalés.
- Vues **Jour, Semaine, Année, Agenda** (en plus du mois).
- Glisser-déposer, duplication, création rapide.
- **Validation :** CRUD complet sur les 5 vues ; persistance après redémarrage ; tests des cas multi-jours et fuseaux horaires.

## v0.3.0 — Calendrier avancé
- Récurrences (quotidienne/hebdo/mensuelle/annuelle, règles personnalisées) et exceptions (une occurrence / série / suivantes).
- Jours fériés (règle par série), vacances scolaires, anniversaires manuels.
- Recherche avancée et filtres enregistrables.
- **Validation :** batterie de tests de récurrence (dernier vendredi du mois, tous les 3 jours, 29 février, changement d'heure) ; recherche performante sur plusieurs milliers d'événements.

## v0.4.0 — Cloud Poulapp
- Connexion facultative (Supabase Auth), contrôle d'accès `poulapp_access`.
- Synchronisation bidirectionnelle local-first : file d'opérations persistante, reprise après hors-ligne, résolution de conflits.
- Scripts SQL Supabase (tables `poulplan_*`, RLS) versionnés dans `supabase/`.
- **Validation :** scénario deux appareils (création/modif/suppression, hors-ligne puis reprise) sans perte de données ; l'app fonctionne normalement sans compte et Supabase coupé.

## v0.5.0 — Notifications
- Rappels multiples, snooze, persistants jusqu'à validation ; Android + Linux ; indépendants du cloud.
- Re-planification après redémarrage de l'appareil.
- **Validation :** test sur appareil réel (écran verrouillé, app fermée, redémarrage).

## v0.6.0 — Intégrations
- Widgets Android (mensuel, prochains événements) ; widget KDE Plasma ; intégration zone de notification Linux.
- **Validation :** mise à jour automatique des widgets, ouverture directe de l'événement.

## v0.7.0 — Fonctions complémentaires
- Pièces jointes (stockage local + Storage privé cloud, sélection pour le hors ligne), import VCF/contacts, export, sauvegardes locales automatiques et cloud, restauration, verrouillage PIN/biométrie, nettoyage d'espace.
- **Validation :** cycle sauvegarde → restauration complet sur un autre appareil.

## v0.8.0 — Navigation
- Lieu sur un événement, temps de trajet, cartes OSM hors ligne, itinéraires mémorisés/recalculables.
- Choix du moteur de routage libre documenté dans `DECISIONS.md` avant implémentation.
- **Validation :** trajet calculé en ligne puis consultable hors ligne.

## v1.0.0 — Version stable
- Tests complets, corrections, optimisations (démarrage, fluidité sur gros volumes), accessibilité de base.
- Préparation publication : métadonnées F-Droid (fastlane), Flatpak, audit des dépendances/licences, build reproductible, README et captures d'écran.

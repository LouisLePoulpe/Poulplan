# Poulplan — cahier des charges

Calendrier personnel de l'écosystème Poulapp. Android · Linux · open source · hors connexion · cloud facultatif.

Objectif : remplacer un agenda traditionnel avec des fonctions avancées (récurrences complexes, notifications, recherche, widgets, anniversaires, vacances scolaires, pièces jointes, déplacements), tout en restant simple à utiliser au quotidien, sans devenir une application surchargée.

## 1. Contexte Poulapp
Poulapp est un écosystème d'applications libres, gratuites, respectueuses de la vie privée, indépendantes des grands services propriétaires. Principes : open source, hors connexion, cloud facultatif, vie privée, multiplateforme, gratuit (ni publicité, ni abonnement imposé). Les apps (Poulpoints, Poulpécule, Poulpause, Poulplan…) partagent une infrastructure cloud commune mais gardent des données et fonctions indépendantes. Objectif de publication : F-Droid.

## 2. Périmètre validé
| Fonction | Choix |
|---|---|
| Calendriers | Un seul calendrier personnel |
| Partage | Aucun, calendrier privé |
| Compte utilisateur | Facultatif |
| Cloud | Poulapp uniquement |
| Google / Outlook / CalDAV | Pas de synchronisation |
| Relation avec Poulpoints | Aucune (pas de synchro événements ↔ tâches) |
| Android | Application autonome, sans intégration au calendrier système |
| Linux | Application adaptée à KDE et Bazzite |

## 3. Interface
- Cinq vues : **Jour, Semaine, Mois, Année, Agenda chronologique**.
- Création rapide d'événement, édition complète, glisser-déposer, duplication.
- Thèmes clair / sombre / système.
- Raccourcis clavier sous Linux.

## 4. Événements
Titre, description, catégorie et couleur personnalisées, date et heure, fuseau horaire, lieu, lien de visioconférence, pièces jointes, statut libre/occupé.
Événements sur toute la journée et sur plusieurs jours. Chevauchements autorisés mais signalés visuellement.

## 5. Récurrences et exceptions
- Quotidienne, hebdomadaire, mensuelle, annuelle, règles personnalisables (ex. chaque lundi et jeudi, tous les 3 jours, dernier vendredi du mois, chaque année à une date précise).
- Modifier : une seule occurrence, la série entière, ou cette occurrence et les suivantes.
- Règle de gestion des jours fériés configurable par série.

## 6. Notifications et rappels
- Rappels multiples, personnalisables, reportables (snooze), visibles jusqu'à validation.
- Fonctionnent sur Android et Linux même application fermée (dans les limites de l'OS).
- Indépendants du cloud : un rappel local se déclenche sans Internet.

## 7. Recherche et informations complémentaires
Recherche avancée avec filtres enregistrables ; jours fériés ; vacances scolaires ; anniversaires saisis manuellement ; import facultatif depuis les contacts Android ou des fichiers VCF.

## 8. Cartes et déplacements
Associer un lieu à un événement ; calculer le temps de trajet. Hors ligne : téléchargement de zones, conservation des itinéraires déjà calculés, recalcul possible dans les zones disposant des données de routage. Moteur technique définitif **à sélectionner** (OpenStreetMap, moteur libre).

## 9. Widgets
| Android | Linux |
|---|---|
| Calendrier mensuel | Widget de bureau KDE Plasma |
| Liste des événements à venir | Intégration à la zone de notification |
| Actualisation automatique | Notifications et rappels locaux |

## 10. Synchronisation et données
Approche **local-first** :
1. Modification locale enregistrée immédiatement sur l'appareil.
2. File de synchronisation conservée jusqu'au transfert réussi.
3. Envoi automatique au Cloud Poulapp quand le réseau est disponible.
4. Les autres appareils récupèrent et fusionnent avec leurs modifications locales.

Conflit (même événement modifié hors ligne sur deux appareils) : fusion automatique des changements compatibles ; demande à l'utilisateur uniquement si le conflit ne peut pas être résolu de façon fiable.
Aussi : sauvegardes locales automatiques, sauvegarde cloud, exports manuels, pièces jointes sélectionnables pour le hors ligne, propositions de nettoyage quand l'espace manque.

## 11. Sécurité
Verrouillage facultatif par PIN ou biométrie. Chiffrement classique au départ, avec possibilité d'ajouter plus tard un vrai chiffrement de bout en bout (à garder possible dans le modèle de données).

## 12. Cloud Poulapp (Supabase)
| Élément | Décision |
|---|---|
| Fournisseur | Supabase, offre gratuite visée |
| Base | PostgreSQL |
| Authentification | Un compte Poulapp commun |
| Autorisation | Accès limité aux comptes explicitement autorisés (table `poulapp_access`) |
| Inscription publique | Désactivée pour le cloud privé |
| Isolation | Données séparées par application et par utilisateur |
| Sécurité | Politiques RLS, stockage privé |
| Mode sans compte | Disponible |
| Évolution | Architecture portable, auto-hébergement possible |

Les apps sont publiques mais le cloud personnel reste privé : une personne qui installe Poulplan depuis F-Droid l'utilise localement sans accès à l'infrastructure Poulapp. Autoriser Poulpoints ne doit pas permettre de lire les événements de Poulplan.

## 13. Architecture technique
| Composant | Solution |
|---|---|
| Langage / framework | Dart / Flutter |
| Base locale | SQLite / Drift |
| Cloud | Supabase PostgreSQL + Auth + Storage privé (pièces jointes) |
| Android natif | Kotlin si nécessaire ; synchro/rappels en arrière-plan via mécanismes Android adaptés |
| Distribution Linux | Flatpak |
| Widgets KDE | Plasma / QML |
| Cartographie | Données OpenStreetMap, moteur libre à déterminer |
| Licence | GPL-3.0 (compatible F-Droid) |

## 14. Identité visuelle
Famille Poulapp : poulpe stylisé (poulpe rouge = référence commune, chaque app a sa couleur : Poulpoints bleu, Poulpécule vert). **Poulplan : logo jaune fourni par Louis = référence officielle** (horloge, calendrier, symboles des quatre saisons). Fichiers originaux à placer dans `assets/branding/`.

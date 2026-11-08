# Rapport final — Poulplan 1.0.0 (2026-11-08)

## Ce qui fonctionne (validé par Louis sur Pixel 10 et KDE/Bazzite)

| Jalon | Contenu | Validation |
|---|---|---|
| v0.1–0.3 | Calendrier (jour, semaine, mois, année, agenda), éditeur, glisser-déposer, catégories, répétitions et exceptions, jours fériés, vacances scolaires, anniversaires, recherche et filtres | Linux et Pixel |
| v0.4 | Synchro cloud Poulapp facultative (Supabase, fusion par champ, conflits) | Linux ↔ Pixel |
| v0.5 | Rappels multiples, report, application fermée (Android : alarmes exactes ; Linux : zone de notification) | Pixel (verrouillé/déverrouillé), KDE |
| v0.6 | Widgets Android (Journée défilante, À venir, Mois) et KDE (Journée, À venir), icône de notification, ouverture directe d'un événement | Pixel, KDE |
| v0.7 | Sauvegardes locales/cloud automatiques, restauration sur un autre appareil, export ICS, import VCF/contacts, pièces jointes, verrouillage code/biométrie, espace de stockage | Tests E1–E6 |
| v0.8 | Lieux (Nominatim), trajets OSRM mémorisés et synchronisés, carte OpenFreeMap, zones hors ligne, BRouter (Android) | Tests F1–F5 |
| 1.0 | Widgets : bouton Ouvrir, centrage sur l'heure, thème clair ; performances, accessibilité, publication | Widgets validés ; reste ci-dessous |

Qualité : `flutter analyze` à 0, **306 tests** (logique métier : récurrences,
fuseaux et heure d'été, fusion de synchro, sauvegardes, ICS/vCard, PIN,
cartes ; widgets ; migrations de schéma v1 → v6 ; performance ; accessibilité),
CI verte.

Performances mesurées (5000 événements + 200 séries) : un mois (2200
occurrences) en ~36 ms, une semaine en ~7 ms, une recherche en ~4 ms.

Accessibilité : cibles tactiles de 48 dp, libellés, contraste WCAG AA (règles
Flutter `androidTapTargetGuideline`, `labeledTapTargetGuideline`,
`textContrastGuideline`) sur le calendrier, l'éditeur et les paramètres ;
texte à 200 % sans débordement sur un écran de téléphone.

## Non testé (à faire par Louis avant de publier)

1. **Construction Flatpak** : manifeste et fiche AppStream validés
   (`appstreamcli`, `desktop-file-validate`), mais la construction n'a pas été
   lancée (outil `org.flatpak.Builder` et SDK GNOME 51 absents du PC) — voir
   `docs/PUBLICATION.md`.
2. **Construction par F-Droid** : la compilation de SQLite depuis la source
   est vérifiée localement (Linux + APK) ; la recette elle-même n'a pas
   tourné sur l'infrastructure F-Droid (version de Flutter disponible,
   reproductibilité).
3. **Lecteur d'écran réel** (TalkBack, Orca) : seules les règles automatiques
   ont été vérifiées.
4. **Gros volume réel sur le téléphone** : les mesures de performance sont
   faites dans les tests (base en mémoire), pas sur le Pixel.
5. **Rappels après redémarrage du téléphone** et **optimisation de batterie**
   agressive sur d'autres marques que Google.

## Limites connues

- Android : widgets rafraîchis toutes les 30 min app fermée (ligne
  « maintenant » ; widget Mois au changement de thème).
- Rappels Android programmés 30 jours à l'avance (recalculés à chaque
  ouverture ou modification).
- Linux : pas de recalcul de trajet hors ligne (BRouter = Android).
- Pas de géolocalisation (le greffon courant dépend de Google Play Services) :
  point de départ = adresse réglée.
- Widgets et notifications visibles même app verrouillée ; code oublié non
  récupérable (données récupérables par la synchro ou une sauvegarde).
- Jeton de session cloud stocké en clair dans la base locale.
- Pièces jointes d'un événement supprimé conservées (invisibles).
- Interface en français seulement (intl prêt pour d'autres langues).

## Avant de publier

- Choisir le compte et créer la clé de signature hors F-Droid (jamais dans le
  dépôt) si une diffusion directe d'APK est voulue.
- Ouvrir la demande d'inclusion sur `fdroiddata` avec la recette de
  `docs/PUBLICATION.md`.
- Construire et essayer le Flatpak (commandes dans `docs/PUBLICATION.md`).
- Relire la fiche (`fastlane/`, `linux/packaging/org.poulapp.poulplan.metainfo.xml`)
  et les captures (`docs/screenshots/`, calendrier de démonstration).

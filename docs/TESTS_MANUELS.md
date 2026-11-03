# Tests manuels — v0.4.0 (cloud) et v0.5.0 (notifications)

## Tour 2 (version 0.5.1) — après les retours du tour 1

Corrigé depuis le tour 1 :
- **Connexion impossible sur le Pixel** : la version release Android n'avait pas la permission Internet ; une erreur réseau est maintenant affichée comme telle.
- **Pas de notification de test sur le Pixel** : l'icône de notification était supprimée par l'optimisation des builds release.
- **Pas de demande d'autorisation au lancement** : demandée trop tôt (avant l'affichage). ⚠️ Sur ton Pixel, la demande a déjà été « consommée » au tour 1 et tu as accordé l'autorisation depuis les paramètres : il n'y aura donc pas de nouvelle demande, c'est normal.
- **Création rapide qui se chevauche avec le clavier** : le dialogue défile et « Plus d'options » est passé au-dessus des boutons.
- **Traits du calendrier discontinus** (Linux) : traits d'un pixel physique.
- **Impossible de taper des chiffres** (Linux) : nouvelle saisie d'heure au clavier ; la rangée du haut AZERTY **sans Maj** (`&é"'(-è_çà`) est acceptée comme chiffres, ainsi que le pavé numérique.
- **Pas de notification pour les événements** (Linux) : un événement créé moins de 10 minutes avant son début avait un rappel « 10 min avant » déjà passé, jamais affiché. Désormais, un rappel déjà passé s'affiche aussitôt si l'événement n'est pas terminé.

Avant de commencer :
- **Linux** : l'ancienne version tourne encore en arrière-plan (fenêtre fermée). La quitter d'abord : Paramètres → Rappels → **Quitter Poulplan** (ou `pkill -f bundle/poulplan`), puis lancer la nouvelle avec la même commande.
- **Pixel** : le brancher en USB, je réinstalle la version 0.5.1 (ou `adb install -r build/app/outputs/flutter-apk/app-release.apk` depuis le dossier du projet).

À refaire en priorité : **C** (connexion sur le Pixel), **A2** à **A6**, **B** en entier.

---

À faire par Louis sur le Pixel 10 et sous Linux (KDE). Cocher chaque ligne, noter ce qui ne va pas (capture bienvenue).
Les versions à tester sont déjà installées / construites :

- **Pixel** : version release 0.5.0 installée (icône Poulplan).
- **Linux** (dans la distrobox « claude ») :
  ```bash
  ~/dev/Poulplan/build/linux/x64/release/bundle/poulplan
  ```

---

## A. Notifications sur le Pixel

### A1. Autorisation
- [ ] Au premier lancement, Android demande l'autorisation d'envoyer des notifications → **Autoriser**.
- [ ] Paramètres de l'app → section **Rappels** : « Notifications autorisées » est affiché.
  (Si refusé par erreur : bouton **Autoriser** au même endroit.)

### A2. Test rapide, écran verrouillé
- [ ] Paramètres → Rappels → **Tester les notifications** : une notification « Poulplan — notification de test » apparaît tout de suite.
- [ ] **Verrouiller l'écran aussitôt** et attendre 1 minute : la notification « Poulplan — rappel de test (1 min) » arrive écran verrouillé (son/vibration selon le mode du téléphone).
- [ ] Elle reste affichée tant qu'on ne la valide pas (balayer peut la masquer sur Android 14+, c'est une limite du système).

### A3. Boutons de la notification
- [ ] Créer un événement qui commence dans **3 minutes**, avec le rappel par défaut remplacé par **« À l'heure de début »** (ou « 5 min avant »).
- [ ] À l'heure du rappel : la notification affiche le titre, « Aujourd'hui à HH:MM » et le lieu s'il y en a un.
- [ ] Toucher **Reporter 10 min** : la notification disparaît et revient 10 minutes plus tard.
- [ ] Toucher **C'est noté** : elle disparaît pour de bon.
- [ ] Toucher le corps de la notification : l'app s'ouvre directement sur l'événement.

### A4. Application fermée
- [ ] Créer un événement dans 5 minutes avec un rappel « À l'heure de début ».
- [ ] Fermer complètement l'app (écran des apps récentes → balayer Poulplan).
- [ ] Le rappel arrive quand même à l'heure.
- [ ] Toucher **Reporter 10 min** avec l'app fermée : le rappel revient 10 min plus tard.

### A5. Redémarrage du téléphone
- [ ] Créer un événement dans 10 minutes avec un rappel « À l'heure de début ».
- [ ] Redémarrer le Pixel, le déverrouiller, **ne pas ouvrir Poulplan**.
- [ ] Le rappel arrive à l'heure.

### A6. Récurrence et modification
- [ ] Créer un événement hebdomadaire qui commence dans 5 minutes (rappel à l'heure) : le rappel arrive.
- [ ] Déplacer un événement qui avait un rappel (glisser-déposer) : le rappel suit la nouvelle heure ; supprimer un événement : son rappel ne sonne plus.

### A7. Économie de batterie (facultatif mais utile)
- [ ] Paramètres Android → Applications → Poulplan → Batterie : noter le mode (« Optimisée » par défaut). Refaire A4 en laissant le téléphone posé, écran éteint, 30 min avant le rappel : il doit arriver à l'heure (les alarmes exactes passent le mode Doze).

---

## B. Notifications sous Linux (KDE)

- [ ] Lancer Poulplan (commande ci-dessus). Paramètres → Rappels → **Tester les notifications** : une notification KDE « Poulplan — notification de test » apparaît, avec les boutons **C'est noté** et **Reporter 10 min**, et **reste** dans la zone de notification.
- [ ] Créer un événement dans 3 minutes avec un rappel « À l'heure de début » : la notification arrive à l'heure.
- [ ] **Reporter 10 min** : elle revient 10 min plus tard. **C'est noté** : elle disparaît. Cliquer la notification : la fenêtre s'ouvre sur l'événement.
- [ ] **Fermer la fenêtre** (croix de la barre de titre) : Poulplan continue de tourner (option « Continuer en arrière-plan », activée par défaut) ; un rappel programmé arrive quand même.
- [ ] Relancer Poulplan depuis la commande / le menu : **la même fenêtre réapparaît** (pas de deuxième instance).
- [ ] Paramètres → Rappels → **Quitter Poulplan** : l'application se ferme vraiment.
- [ ] Rappels manqués : quitter Poulplan, attendre l'heure d'un rappel, relancer → le rappel manqué s'affiche (jusqu'à 24 h en arrière).
- [ ] (Si tu veux) **Lancer à l'ouverture de session** : activer, se déconnecter/reconnecter → Poulplan tourne sans fenêtre et affiche les rappels.
  Note : depuis la distrobox, le fichier de démarrage lance le binaire construit dans le conteneur ; le vrai test se fera avec le Flatpak (v1.0).

---

## C. Cloud Poulapp (v0.4.0)

Sur **Linux** et sur le **Pixel** :

- [ ] Paramètres → **Compte Poulapp** → se connecter avec ton compte Poulapp (`louislepoulpe@ik.me`) : « Connecté au cloud Poulapp », puis « Synchronisé à HH:MM ».
- [ ] Les événements existants de chaque appareil apparaissent sur l'autre après synchronisation (bouton **Synchroniser maintenant** si besoin ; sinon automatique sous quelques secondes après une modification).
- [ ] Créer un événement sur Linux → il apparaît sur le Pixel. Le modifier sur le Pixel → la modification arrive sur Linux. Le supprimer → il disparaît des deux.
- [ ] **Hors ligne** : mettre le Pixel en mode avion, modifier le **lieu** d'un événement ; sur Linux modifier le **titre** du même événement. Réactiver le réseau → les deux changements sont gardés, sans conflit.
- [ ] **Vrai conflit** : même manipulation mais en modifiant le **titre** des deux côtés → l'icône nuage affiche une pastille ; Compte Poulapp → **conflits à résoudre** → choisir une version → elle s'impose sur les deux appareils.
- [ ] Se déconnecter : les données restent sur l'appareil ; l'app fonctionne normalement.
- [ ] Un compte **sans** accès Poulplan (s'il en existe un, par ex. réservé à Poulpoints) est refusé avec « Ce compte n'a pas accès à Poulplan ».

---

## Retour attendu
Pour chaque section : ✅ / ❌ + description. Les échecs seront corrigés avant les tags v0.4.0 et v0.5.0.

---

# Tests manuels — v0.6.0 (intégrations)

Préparation :
- **Linux** : quitter l'instance en cours (icône Poulplan de la zone de notification → **Quitter**, ou Paramètres → Rappels → **Quitter Poulplan**), puis relancer `~/dev/Poulplan/build/linux/x64/release/bundle/poulplan`.
- **Pixel** : le brancher ; j'installe la 0.6.0 (ou `adb install -r build/app/outputs/flutter-apk/app-release.apk`).

## D1. Heure sous Linux (bug trouvé et corrigé)
- [ ] Un même événement affiche **la même heure** sous Linux et sur le Pixel (avant : une heure de moins sous Linux, affichage en UTC).

## D2. Zone de notification Linux
- [ ] Une icône Poulplan (logo jaune) apparaît dans la zone de notification KDE.
- [ ] Le survol affiche « Prochain : <titre> — Aujourd'hui à HH:MM ».
- [ ] Clic gauche : la fenêtre s'affiche (même après l'avoir fermée).
- [ ] Clic droit : menu **Ouvrir Poulplan** / **Quitter** ; Quitter ferme vraiment l'application (l'icône disparaît).

## D3. Widget KDE Plasma (plasmoïde)
- [ ] Installer (sur Bazzite, hors distrobox) :
  ```bash
  kpackagetool6 -t Plasma/Applet -i ~/dev/Poulplan/linux/plasmoid/org.poulapp.poulplan.upcoming
  ```
  (mise à jour plus tard : `-u` au lieu de `-i`).
- [ ] Clic droit sur le bureau ou le tableau de bord → **Ajouter des composants graphiques** → « Poulplan — À venir ».
- [ ] Configurer le composant → **Commande de lancement** :
  `distrobox enter claude -- /home/LouisLePoulpe/dev/Poulplan/build/linux/x64/release/bundle/poulplan`
- [ ] La liste montre les prochains événements (titre, « Aujourd'hui à… », lieu, couleur).
- [ ] Créer / modifier un événement dans Poulplan : le widget se met à jour en moins d'une minute.
- [ ] Cliquer sur un événement du widget : Poulplan s'ouvre **directement sur cet événement**.

## D4. Widgets Android
- [ ] Appui long sur l'écran d'accueil → **Widgets** → Poulplan : ajouter **À venir** et **Mois**.
- [ ] « À venir » : prochains événements avec « Aujourd'hui / Demain / date », heure, lieu, barre de couleur.
- [ ] « Mois » : mois en cours, jour courant en jaune, points de couleur sous les jours occupés ; redimensionner le widget → le dessin s'adapte.
- [ ] Créer / modifier / supprimer un événement dans l'app : les deux widgets se mettent à jour.
- [ ] Toucher un événement du widget « À venir » : l'app s'ouvre **directement sur l'événement** (aussi app fermée).
- [ ] Toucher le widget « Mois » : l'app s'ouvre.
- [ ] Le lendemain (ou après minuit) sans ouvrir l'app : « Aujourd'hui / Demain » et le jour en jaune sont à jour (rafraîchissement toutes les 30 min).

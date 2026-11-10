// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Poulplan';

  @override
  String get today => 'Aujourd\'hui';

  @override
  String get settings => 'Paramètres';

  @override
  String get settingsAppearance => 'Apparence';

  @override
  String get settingsTheme => 'Thème';

  @override
  String get themeSystem => 'Système';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get settingsCalendar => 'Calendrier';

  @override
  String get settingsFirstDayOfWeek => 'Premier jour de la semaine';

  @override
  String get settingsAbout => 'À propos';

  @override
  String get aboutDescription =>
      'Calendrier personnel de l\'écosystème Poulapp. Libre (GPL-3.0), utilisable sans compte ni connexion.';

  @override
  String get aboutLicenses => 'Licences des composants';

  @override
  String moreEvents(int count) {
    return '+$count';
  }

  @override
  String get allDay => 'Toute la journée';

  @override
  String get debugInsertDemo => 'Insérer des événements de démonstration';

  @override
  String get debugDemoInserted => 'Événements de démonstration ajoutés';

  @override
  String get previous => 'Précédent';

  @override
  String get next => 'Suivant';

  @override
  String get viewDay => 'Jour';

  @override
  String get viewWeek => 'Semaine';

  @override
  String get viewMonth => 'Mois';

  @override
  String get viewYear => 'Année';

  @override
  String get viewAgenda => 'Agenda';

  @override
  String agendaFrom(String day) {
    return 'À partir du $day';
  }

  @override
  String agendaEmpty(String day) {
    return 'Aucun événement jusqu\'au $day.';
  }

  @override
  String get agendaShowMore => 'Afficher plus';

  @override
  String get allDayShort => 'Jour.';

  @override
  String get newEvent => 'Nouvel événement';

  @override
  String get editEvent => 'Modifier l\'événement';

  @override
  String get eventNotFound => 'Cet événement n\'existe plus.';

  @override
  String get moreOptions => 'Plus d\'options';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String get edit => 'Modifier';

  @override
  String get duplicate => 'Dupliquer';

  @override
  String get delete => 'Supprimer';

  @override
  String get undo => 'Annuler';

  @override
  String eventDeleted(String title) {
    return '« $title » supprimé';
  }

  @override
  String get eventDuplicated => 'Événement dupliqué';

  @override
  String get overlapWarning => 'Chevauche un autre événement';

  @override
  String overlapsWith(String titles) {
    return 'Chevauche : $titles';
  }

  @override
  String get fieldTitle => 'Titre';

  @override
  String get fieldStart => 'Début';

  @override
  String get fieldEnd => 'Fin';

  @override
  String get fieldTimeZone => 'Fuseau horaire';

  @override
  String get searchTimeZone => 'Rechercher (ex. Paris, New York)';

  @override
  String get fieldCategory => 'Catégorie';

  @override
  String get noCategory => 'Aucune';

  @override
  String get fieldColor => 'Couleur';

  @override
  String get colorFromCategory => 'Couleur de la catégorie';

  @override
  String get fieldLocation => 'Lieu';

  @override
  String get fieldVideoLink => 'Lien de visioconférence';

  @override
  String get fieldDescription => 'Description';

  @override
  String get busy => 'Occupé';

  @override
  String get free => 'Libre';

  @override
  String get errorEmptyTitle => 'Le titre est obligatoire';

  @override
  String get errorEndBeforeStart => 'La fin doit être après le début';

  @override
  String get errorUnknownTimeZone => 'Fuseau horaire inconnu';

  @override
  String get categories => 'Catégories';

  @override
  String get newCategory => 'Nouvelle catégorie';

  @override
  String get editCategory => 'Modifier la catégorie';

  @override
  String get fieldName => 'Nom';

  @override
  String get errorEmptyName => 'Le nom est obligatoire';

  @override
  String deleteCategoryTitle(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get deleteCategoryBody =>
      'Les événements de cette catégorie sont conservés et reprennent la couleur par défaut.';

  @override
  String get settingsCategoriesSubtitle =>
      'Noms et couleurs des catégories d\'événements';

  @override
  String get ok => 'OK';

  @override
  String get search => 'Rechercher';

  @override
  String get searchHint => 'Rechercher un événement';

  @override
  String get searchPrompt => 'Saisissez un mot ou choisissez un filtre.';

  @override
  String get searchNoResults => 'Aucun résultat.';

  @override
  String get saveFilter => 'Enregistrer le filtre';

  @override
  String get periodAll => 'Tout';

  @override
  String get periodUpcoming => 'À venir';

  @override
  String get periodPast => 'Passé';

  @override
  String get periodCustom => 'Période…';

  @override
  String get scopeEditTitle => 'Modifier l\'événement récurrent';

  @override
  String get scopeDeleteTitle => 'Supprimer l\'événement récurrent';

  @override
  String get scopeThis => 'Cet événement';

  @override
  String get scopeFollowing => 'Cet événement et les suivants';

  @override
  String get scopeAll => 'Tous les événements';

  @override
  String get fieldRecurrence => 'Répétition';

  @override
  String get recurrenceNone => 'Ne se répète pas';

  @override
  String get recurrenceCustom => 'Personnaliser…';

  @override
  String get recurrenceEvery => 'Tous les';

  @override
  String get unitDays => 'jours';

  @override
  String get unitWeeks => 'semaines';

  @override
  String get unitMonths => 'mois';

  @override
  String get unitYears => 'ans';

  @override
  String monthlyOnDay(int day) {
    return 'le $day du mois';
  }

  @override
  String monthlyOnLast(String weekday) {
    return 'le dernier $weekday du mois';
  }

  @override
  String get recurrenceEnds => 'Fin';

  @override
  String get recurrenceNever => 'Jamais';

  @override
  String get recurrenceAfter => 'Après';

  @override
  String get recurrenceTimes => 'fois';

  @override
  String get recurrenceUntil => 'Jusqu\'au';

  @override
  String get fieldHolidayRule => 'Jours fériés';

  @override
  String get holidayRuleNone => 'Sans effet';

  @override
  String get holidayRuleSkip => 'Sauter';

  @override
  String get holidayRuleNext => 'Jour ouvré suivant';

  @override
  String get holidayRulePrevious => 'Jour ouvré précédent';

  @override
  String get settingsHolidays => 'Jours fériés et vacances';

  @override
  String get settingsShowHolidays => 'Afficher les jours fériés';

  @override
  String get settingsAlsaceMoselle => 'Alsace-Moselle';

  @override
  String get settingsAlsaceMoselleSubtitle =>
      'Ajoute le Vendredi saint et la Saint-Étienne';

  @override
  String get settingsSchoolZone => 'Vacances scolaires';

  @override
  String get noSchoolZone => 'Aucune';

  @override
  String schoolZone(String zone) {
    return 'Zone $zone';
  }

  @override
  String get birthdays => 'Anniversaires';

  @override
  String get newBirthday => 'Nouvel anniversaire';

  @override
  String get editBirthday => 'Modifier l\'anniversaire';

  @override
  String get birthdaysEmpty =>
      'Aucun anniversaire. Ajoutez-en avec le bouton +.';

  @override
  String get fieldBirthYear => 'Année de naissance (facultatif)';

  @override
  String get errorInvalidYear => 'Année invalide';

  @override
  String get cloud => 'Cloud Poulapp';

  @override
  String get account => 'Compte Poulapp';

  @override
  String get accountSubtitle =>
      'Synchronisation facultative entre vos appareils';

  @override
  String get cloudNotConfigured =>
      'Cette version de Poulplan n\'est pas reliée au cloud Poulapp. Toutes vos données restent sur cet appareil.';

  @override
  String get signInExplanation =>
      'Connectez-vous pour synchroniser votre calendrier entre vos appareils. Sans compte, Poulplan fonctionne entièrement sur cet appareil.';

  @override
  String get fieldEmail => 'Adresse e-mail';

  @override
  String get fieldPassword => 'Mot de passe';

  @override
  String get signIn => 'Se connecter';

  @override
  String get signInNoAccess => 'Ce compte n\'a pas accès à Poulplan.';

  @override
  String get signInWrongCredentials => 'Adresse ou mot de passe incorrect.';

  @override
  String get signInNetworkError =>
      'Connexion impossible. Vérifiez le réseau et réessayez.';

  @override
  String get signedInPoulapp => 'Connecté au cloud Poulapp';

  @override
  String get syncInProgress => 'Synchronisation…';

  @override
  String get syncOffline =>
      'Hors ligne — les modifications seront envoyées plus tard';

  @override
  String syncDoneAt(String time) {
    return 'Synchronisé à $time';
  }

  @override
  String get syncNotYet => 'Pas encore synchronisé';

  @override
  String syncPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modifications en attente',
      one: '1 modification en attente',
      zero: 'Aucune modification en attente',
    );
    return '$_temp0';
  }

  @override
  String get syncNow => 'Synchroniser maintenant';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get signOutBody =>
      'Vos données restent sur cet appareil. Les modifications faites hors connexion seront envoyées à la prochaine connexion.';

  @override
  String conflictsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count conflits à résoudre',
      one: '1 conflit à résoudre',
    );
    return '$_temp0';
  }

  @override
  String get conflictsTitle => 'Conflits de synchronisation';

  @override
  String get conflictsNone => 'Aucun conflit.';

  @override
  String get conflictsExplanation =>
      'Ces informations ont été modifiées différemment sur deux appareils. Choisissez la version à garder ; la plus récente est affichée en attendant.';

  @override
  String conflictField(String field) {
    return '$field modifié des deux côtés';
  }

  @override
  String get conflictDeletion =>
      'Supprimé sur un appareil, modifié sur l\'autre';

  @override
  String get conflictThisDevice => 'Cet appareil';

  @override
  String get conflictOtherDevice => 'Autre appareil';

  @override
  String get conflictDeleted => 'Supprimé';

  @override
  String get conflictKept => 'Conservé';

  @override
  String get fieldReminders => 'Rappels';

  @override
  String get addReminder => 'Ajouter un rappel';

  @override
  String get reminderBefore => 'avant';

  @override
  String get unitMinutes => 'minutes';

  @override
  String get unitHours => 'heures';

  @override
  String get settingsReminders => 'Rappels';

  @override
  String get settingsDefaultReminder => 'Rappel par défaut';

  @override
  String get settingsDefaultReminderSubtitle =>
      'Ajouté aux nouveaux événements avec horaire';

  @override
  String get noReminder => 'Aucun';

  @override
  String get notificationsAllowed => 'Notifications autorisées';

  @override
  String get notificationsDenied => 'Notifications non autorisées';

  @override
  String get notificationsAllow => 'Autoriser';

  @override
  String get notificationsTest => 'Tester les notifications';

  @override
  String get notificationsTestSubtitleAndroid =>
      'Une notification tout de suite, une autre dans 1 minute (à tester écran verrouillé)';

  @override
  String get notificationsTestSubtitle =>
      'Affiche une notification tout de suite';

  @override
  String get notificationsTestSent => 'Notification de test envoyée';

  @override
  String get settingsRunInBackground => 'Continuer en arrière-plan';

  @override
  String get settingsRunInBackgroundSubtitle =>
      'Fermer la fenêtre garde Poulplan actif pour les rappels';

  @override
  String get settingsAutostart => 'Lancer à l\'ouverture de session';

  @override
  String get settingsAutostartSubtitle =>
      'Poulplan démarre sans fenêtre pour afficher les rappels';

  @override
  String get quitApp => 'Quitter Poulplan';

  @override
  String get quitAppSubtitle =>
      'Plus aucun rappel tant que l\'application n\'est pas relancée';

  @override
  String signInServerError(String message) {
    return 'Le serveur a refusé la connexion : $message';
  }

  @override
  String get enterTime => 'Saisir une heure';

  @override
  String get timeHour => 'Heure';

  @override
  String get timeMinute => 'Minute';

  @override
  String get invalidTime => 'Heure invalide (00:00 à 23:59)';

  @override
  String get dataSection => 'Données';

  @override
  String get backupsTitle => 'Sauvegardes et export';

  @override
  String get backupsSubtitle =>
      'Sauvegardes automatiques, restauration, export ICS';

  @override
  String get backupAuto => 'Sauvegarde automatique quotidienne';

  @override
  String backupAutoSubtitle(int count) {
    return 'Les $count dernières sont gardées sur cet appareil';
  }

  @override
  String get backupCloudAuto => 'Aussi dans le cloud Poulapp';

  @override
  String backupCloudAutoSubtitle(int count) {
    return 'Les $count dernières, quand vous êtes connecté';
  }

  @override
  String get backupNow => 'Sauvegarder maintenant';

  @override
  String get backupNowCloud => 'Sauvegarder dans le cloud';

  @override
  String get backupLocalList => 'Sur cet appareil';

  @override
  String get backupCloudList => 'Dans le cloud';

  @override
  String get backupNone => 'Aucune sauvegarde';

  @override
  String get backupRestore => 'Restaurer';

  @override
  String get backupRestoreFile => 'Restaurer depuis un fichier…';

  @override
  String get backupExport => 'Exporter une sauvegarde…';

  @override
  String get exportIcs => 'Exporter le calendrier (ICS)…';

  @override
  String get backupRestoreConfirmTitle => 'Restaurer cette sauvegarde ?';

  @override
  String backupRestoreConfirmBody(
    String date,
    String device,
    int events,
    int birthdays,
  ) {
    return 'Sauvegarde du $date ($device) : $events événements, $birthdays anniversaires.\n\nLes éléments de la sauvegarde remplacent ceux qui existent ici ; rien d\'autre n\'est supprimé. Si vous êtes connecté, ils seront synchronisés.';
  }

  @override
  String backupRestored(int count) {
    return '$count éléments restaurés';
  }

  @override
  String get backupDone => 'Sauvegarde effectuée';

  @override
  String get backupInvalid =>
      'Ce fichier n\'est pas une sauvegarde Poulplan valide';

  @override
  String operationFailed(String error) {
    return 'Échec : $error';
  }

  @override
  String get fileSaved => 'Fichier enregistré';

  @override
  String backupLast(String date) {
    return 'Dernière sauvegarde : $date';
  }

  @override
  String get backupNever => 'Aucune sauvegarde pour l\'instant';

  @override
  String get importVcf => 'Importer un fichier VCF…';

  @override
  String get importContacts => 'Importer depuis les contacts';

  @override
  String importDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count anniversaires ajoutés',
      one: '1 anniversaire ajouté',
      zero: 'Aucun nouvel anniversaire',
    );
    return '$_temp0';
  }

  @override
  String get importContactsDenied => 'Accès aux contacts refusé';

  @override
  String get attachments => 'Pièces jointes';

  @override
  String get attachmentAdd => 'Ajouter un fichier';

  @override
  String attachmentTooBig(int max) {
    return 'Fichier trop volumineux ($max Mo maximum)';
  }

  @override
  String get attachmentUnavailable =>
      'Fichier indisponible : il n\'est pas sur cet appareil et le cloud n\'est pas joignable';

  @override
  String get attachmentNoApp => 'Aucune application pour ouvrir ce fichier';

  @override
  String get attachmentKeepOffline => 'Garder sur cet appareil';

  @override
  String get attachmentOnDevice => 'Sur cet appareil';

  @override
  String get attachmentInCloud => 'Dans le cloud';

  @override
  String get attachmentKept => 'Gardée sur cet appareil';

  @override
  String get attachmentPending => 'Ajoutée à l\'enregistrement';

  @override
  String get recurrenceStartDate => 'Début de la répétition';

  @override
  String get recurrenceEndDate => 'Fin de la répétition';

  @override
  String recurrenceEndCount(int count) {
    return 'Après $count fois';
  }

  @override
  String get recurrenceNoEnd => 'Sans fin';

  @override
  String get lockTitle => 'Poulplan est verrouillé';

  @override
  String get lockEnterPin => 'Code';

  @override
  String get lockUnlock => 'Déverrouiller';

  @override
  String get lockWrongPin => 'Code incorrect';

  @override
  String lockBlocked(int seconds) {
    return 'Trop d\'essais : réessayez dans $seconds s';
  }

  @override
  String get lockBiometric =>
      'Empreinte, visage ou verrouillage de l\'appareil';

  @override
  String get lockBiometricReason => 'Déverrouiller Poulplan';

  @override
  String get securitySection => 'Sécurité';

  @override
  String get lockSetting => 'Verrouillage par code';

  @override
  String get lockSettingSubtitle =>
      'Code de 4 à 8 chiffres demandé à l\'ouverture';

  @override
  String get lockBiometricSetting => 'Déverrouillage biométrique';

  @override
  String get lockDelaySetting => 'Verrouiller après';

  @override
  String get lockDelayImmediate => 'Immédiatement';

  @override
  String lockDelayMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get lockNewPin => 'Nouveau code';

  @override
  String get lockConfirmPin => 'Confirmer le code';

  @override
  String get lockPinMismatch => 'Les codes ne correspondent pas';

  @override
  String get lockPinInvalid => '4 à 8 chiffres';

  @override
  String get lockForgotHint =>
      'Sans ce code, l\'application ne s\'ouvre plus : après réinstallation, seules la synchronisation cloud ou une sauvegarde exportée rendent les données.';

  @override
  String get lockCurrentPin => 'Code actuel';

  @override
  String get lockNow => 'Verrouiller maintenant';

  @override
  String get storageTitle => 'Espace de stockage';

  @override
  String get storageSubtitle => 'Place utilisée et nettoyage';

  @override
  String get storageDatabase => 'Calendrier (base de données)';

  @override
  String get storageAttachments => 'Pièces jointes sur cet appareil';

  @override
  String get storageBackups => 'Sauvegardes locales';

  @override
  String get storageFree => 'Espace libre sur l\'appareil';

  @override
  String get storageTotal => 'Total utilisé par Poulplan';

  @override
  String get storageFreeAttachments =>
      'Libérer les pièces jointes déjà dans le cloud';

  @override
  String storageFreeAttachmentsSubtitle(String size) {
    return '$size — téléchargées de nouveau à l\'ouverture';
  }

  @override
  String get storageDeleteOldBackups => 'Supprimer les anciennes sauvegardes';

  @override
  String storageDeleteOldBackupsSubtitle(String size) {
    return '$size — la plus récente est gardée';
  }

  @override
  String storageFreed(String size) {
    return '$size libérés';
  }

  @override
  String storageLow(String size) {
    return 'Espace presque plein : Poulplan peut libérer $size';
  }

  @override
  String get storageClean => 'Nettoyer';

  @override
  String get storageNothing => 'Rien à libérer pour l\'instant';

  @override
  String get placeSearch => 'Trouver sur la carte';

  @override
  String get placeSearchHint => 'Adresse, lieu, ville…';

  @override
  String get placeSearchNone => 'Aucun résultat';

  @override
  String get placeSearchFailed =>
      'Recherche impossible : vérifiez la connexion';

  @override
  String get placeFound => 'Position trouvée sur la carte';

  @override
  String get placeClear => 'Oublier la position';

  @override
  String get routeTitle => 'Trajet';

  @override
  String routeFrom(String place) {
    return 'Départ : $place';
  }

  @override
  String get routeNoStart => 'Choisir un point de départ';

  @override
  String get routeCompute => 'Calculer le trajet';

  @override
  String get routeRecompute => 'Recalculer';

  @override
  String routeSummary(String duration, String distance) {
    return '$duration · $distance';
  }

  @override
  String routeComputedOnline(String date) {
    return 'Calculé le $date, en ligne';
  }

  @override
  String routeComputedOffline(String date) {
    return 'Calculé le $date, hors ligne (BRouter)';
  }

  @override
  String routeFailed(String error) {
    return 'Trajet impossible à calculer : $error';
  }

  @override
  String get routeOffline =>
      'Pas de connexion et pas de calcul hors ligne disponible';

  @override
  String get routePlaceChanged => 'Le lieu a changé depuis le calcul';

  @override
  String get routeNeedsPlace =>
      'Trouvez le lieu sur la carte pour calculer un trajet';

  @override
  String get routeSaveFirst =>
      'Enregistrez l\'événement pour calculer un trajet';

  @override
  String get travelCar => 'Voiture';

  @override
  String get travelBike => 'Vélo';

  @override
  String get travelFoot => 'À pied';

  @override
  String get mapTitle => 'Carte';

  @override
  String get mapsSettings => 'Cartes et trajets';

  @override
  String get mapsSettingsSubtitle => 'Adresse de départ, cartes hors ligne';

  @override
  String get homePlace => 'Adresse de départ';

  @override
  String get homePlaceNone => 'Aucune (à choisir pour chaque trajet)';

  @override
  String get offlineZones => 'Cartes hors ligne';

  @override
  String get offlineZoneAdd => 'Télécharger une zone';

  @override
  String get offlineZoneNone =>
      'Aucune zone téléchargée : les lieux déjà affichés restent visibles hors ligne';

  @override
  String offlineZoneTiles(int count, String size) {
    return '$count tuiles · $size';
  }

  @override
  String get offlineZoneIncomplete =>
      'Téléchargement incomplet : toucher pour reprendre';

  @override
  String get offlineZonePick => 'Cadrez la zone à garder hors ligne';

  @override
  String get offlineZoneName => 'Nom de la zone';

  @override
  String get offlineZoneDownload => 'Télécharger';

  @override
  String offlineZoneTooLarge(int count, int max) {
    return 'Zone trop grande ($count tuiles, $max au plus) : zoomez';
  }

  @override
  String offlineZoneEstimate(int count) {
    return '$count tuiles';
  }

  @override
  String offlineZoneProgress(int done, int total) {
    return 'Téléchargement : $done / $total';
  }

  @override
  String get offlineZoneDone => 'Zone téléchargée';

  @override
  String get brouterTitle => 'Calcul des trajets hors ligne';

  @override
  String get brouterInstalled =>
      'BRouter est installé : les trajets se calculent aussi sans connexion, dans les zones dont BRouter a les données';

  @override
  String get brouterMissing =>
      'Installez l\'application libre BRouter (F-Droid) et ses données de votre région pour calculer des trajets sans connexion';

  @override
  String get mapUnavailable =>
      'Fond de carte indisponible hors ligne pour l\'instant';

  @override
  String colorNumber(int number) {
    return 'Couleur $number';
  }

  @override
  String get openNavigation => 'Ouvrir dans le GPS';

  @override
  String get openNavigationWeb => 'Itinéraire sur OpenStreetMap';

  @override
  String get noNavigationApp =>
      'Aucune application de navigation installée (OsmAnd, Organic Maps…)';
}

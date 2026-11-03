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
}

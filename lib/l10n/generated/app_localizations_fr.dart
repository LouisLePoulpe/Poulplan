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
}

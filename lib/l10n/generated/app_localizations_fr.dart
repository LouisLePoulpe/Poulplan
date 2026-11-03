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
  String get previousMonth => 'Mois précédent';

  @override
  String get nextMonth => 'Mois suivant';

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
}

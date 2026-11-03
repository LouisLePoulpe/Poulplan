import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('fr')];

  /// No description provided for @appTitle.
  ///
  /// In fr, this message translates to:
  /// **'Poulplan'**
  String get appTitle;

  /// No description provided for @today.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get today;

  /// No description provided for @settings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get settings;

  /// No description provided for @settingsAppearance.
  ///
  /// In fr, this message translates to:
  /// **'Apparence'**
  String get settingsAppearance;

  /// No description provided for @settingsTheme.
  ///
  /// In fr, this message translates to:
  /// **'Thème'**
  String get settingsTheme;

  /// No description provided for @themeSystem.
  ///
  /// In fr, this message translates to:
  /// **'Système'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In fr, this message translates to:
  /// **'Clair'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In fr, this message translates to:
  /// **'Sombre'**
  String get themeDark;

  /// No description provided for @settingsCalendar.
  ///
  /// In fr, this message translates to:
  /// **'Calendrier'**
  String get settingsCalendar;

  /// No description provided for @settingsFirstDayOfWeek.
  ///
  /// In fr, this message translates to:
  /// **'Premier jour de la semaine'**
  String get settingsFirstDayOfWeek;

  /// No description provided for @settingsAbout.
  ///
  /// In fr, this message translates to:
  /// **'À propos'**
  String get settingsAbout;

  /// No description provided for @aboutDescription.
  ///
  /// In fr, this message translates to:
  /// **'Calendrier personnel de l\'écosystème Poulapp. Libre (GPL-3.0), utilisable sans compte ni connexion.'**
  String get aboutDescription;

  /// No description provided for @aboutLicenses.
  ///
  /// In fr, this message translates to:
  /// **'Licences des composants'**
  String get aboutLicenses;

  /// No description provided for @moreEvents.
  ///
  /// In fr, this message translates to:
  /// **'+{count}'**
  String moreEvents(int count);

  /// No description provided for @allDay.
  ///
  /// In fr, this message translates to:
  /// **'Toute la journée'**
  String get allDay;

  /// No description provided for @debugInsertDemo.
  ///
  /// In fr, this message translates to:
  /// **'Insérer des événements de démonstration'**
  String get debugInsertDemo;

  /// No description provided for @debugDemoInserted.
  ///
  /// In fr, this message translates to:
  /// **'Événements de démonstration ajoutés'**
  String get debugDemoInserted;

  /// No description provided for @previous.
  ///
  /// In fr, this message translates to:
  /// **'Précédent'**
  String get previous;

  /// No description provided for @next.
  ///
  /// In fr, this message translates to:
  /// **'Suivant'**
  String get next;

  /// No description provided for @viewDay.
  ///
  /// In fr, this message translates to:
  /// **'Jour'**
  String get viewDay;

  /// No description provided for @viewWeek.
  ///
  /// In fr, this message translates to:
  /// **'Semaine'**
  String get viewWeek;

  /// No description provided for @viewMonth.
  ///
  /// In fr, this message translates to:
  /// **'Mois'**
  String get viewMonth;

  /// No description provided for @viewYear.
  ///
  /// In fr, this message translates to:
  /// **'Année'**
  String get viewYear;

  /// No description provided for @viewAgenda.
  ///
  /// In fr, this message translates to:
  /// **'Agenda'**
  String get viewAgenda;

  /// No description provided for @agendaFrom.
  ///
  /// In fr, this message translates to:
  /// **'À partir du {day}'**
  String agendaFrom(String day);

  /// No description provided for @agendaEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun événement jusqu\'au {day}.'**
  String agendaEmpty(String day);

  /// No description provided for @agendaShowMore.
  ///
  /// In fr, this message translates to:
  /// **'Afficher plus'**
  String get agendaShowMore;

  /// No description provided for @allDayShort.
  ///
  /// In fr, this message translates to:
  /// **'Jour.'**
  String get allDayShort;

  /// No description provided for @newEvent.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel événement'**
  String get newEvent;

  /// No description provided for @editEvent.
  ///
  /// In fr, this message translates to:
  /// **'Modifier l\'événement'**
  String get editEvent;

  /// No description provided for @eventNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Cet événement n\'existe plus.'**
  String get eventNotFound;

  /// No description provided for @moreOptions.
  ///
  /// In fr, this message translates to:
  /// **'Plus d\'options'**
  String get moreOptions;

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get save;

  /// No description provided for @edit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get edit;

  /// No description provided for @duplicate.
  ///
  /// In fr, this message translates to:
  /// **'Dupliquer'**
  String get duplicate;

  /// No description provided for @delete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get delete;

  /// No description provided for @undo.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get undo;

  /// No description provided for @eventDeleted.
  ///
  /// In fr, this message translates to:
  /// **'« {title} » supprimé'**
  String eventDeleted(String title);

  /// No description provided for @eventDuplicated.
  ///
  /// In fr, this message translates to:
  /// **'Événement dupliqué'**
  String get eventDuplicated;

  /// No description provided for @overlapWarning.
  ///
  /// In fr, this message translates to:
  /// **'Chevauche un autre événement'**
  String get overlapWarning;

  /// No description provided for @overlapsWith.
  ///
  /// In fr, this message translates to:
  /// **'Chevauche : {titles}'**
  String overlapsWith(String titles);

  /// No description provided for @fieldTitle.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get fieldTitle;

  /// No description provided for @fieldStart.
  ///
  /// In fr, this message translates to:
  /// **'Début'**
  String get fieldStart;

  /// No description provided for @fieldEnd.
  ///
  /// In fr, this message translates to:
  /// **'Fin'**
  String get fieldEnd;

  /// No description provided for @fieldTimeZone.
  ///
  /// In fr, this message translates to:
  /// **'Fuseau horaire'**
  String get fieldTimeZone;

  /// No description provided for @searchTimeZone.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher (ex. Paris, New York)'**
  String get searchTimeZone;

  /// No description provided for @fieldCategory.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get fieldCategory;

  /// No description provided for @noCategory.
  ///
  /// In fr, this message translates to:
  /// **'Aucune'**
  String get noCategory;

  /// No description provided for @fieldColor.
  ///
  /// In fr, this message translates to:
  /// **'Couleur'**
  String get fieldColor;

  /// No description provided for @colorFromCategory.
  ///
  /// In fr, this message translates to:
  /// **'Couleur de la catégorie'**
  String get colorFromCategory;

  /// No description provided for @fieldLocation.
  ///
  /// In fr, this message translates to:
  /// **'Lieu'**
  String get fieldLocation;

  /// No description provided for @fieldVideoLink.
  ///
  /// In fr, this message translates to:
  /// **'Lien de visioconférence'**
  String get fieldVideoLink;

  /// No description provided for @fieldDescription.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get fieldDescription;

  /// No description provided for @busy.
  ///
  /// In fr, this message translates to:
  /// **'Occupé'**
  String get busy;

  /// No description provided for @free.
  ///
  /// In fr, this message translates to:
  /// **'Libre'**
  String get free;

  /// No description provided for @errorEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Le titre est obligatoire'**
  String get errorEmptyTitle;

  /// No description provided for @errorEndBeforeStart.
  ///
  /// In fr, this message translates to:
  /// **'La fin doit être après le début'**
  String get errorEndBeforeStart;

  /// No description provided for @errorUnknownTimeZone.
  ///
  /// In fr, this message translates to:
  /// **'Fuseau horaire inconnu'**
  String get errorUnknownTimeZone;

  /// No description provided for @categories.
  ///
  /// In fr, this message translates to:
  /// **'Catégories'**
  String get categories;

  /// No description provided for @newCategory.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle catégorie'**
  String get newCategory;

  /// No description provided for @editCategory.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la catégorie'**
  String get editCategory;

  /// No description provided for @fieldName.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get fieldName;

  /// No description provided for @errorEmptyName.
  ///
  /// In fr, this message translates to:
  /// **'Le nom est obligatoire'**
  String get errorEmptyName;

  /// No description provided for @deleteCategoryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer « {name} » ?'**
  String deleteCategoryTitle(String name);

  /// No description provided for @deleteCategoryBody.
  ///
  /// In fr, this message translates to:
  /// **'Les événements de cette catégorie sont conservés et reprennent la couleur par défaut.'**
  String get deleteCategoryBody;

  /// No description provided for @settingsCategoriesSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Noms et couleurs des catégories d\'événements'**
  String get settingsCategoriesSubtitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

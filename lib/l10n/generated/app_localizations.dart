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

  /// No description provided for @ok.
  ///
  /// In fr, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @search.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get search;

  /// No description provided for @searchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un événement'**
  String get searchHint;

  /// No description provided for @searchPrompt.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez un mot ou choisissez un filtre.'**
  String get searchPrompt;

  /// No description provided for @searchNoResults.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat.'**
  String get searchNoResults;

  /// No description provided for @saveFilter.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer le filtre'**
  String get saveFilter;

  /// No description provided for @periodAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout'**
  String get periodAll;

  /// No description provided for @periodUpcoming.
  ///
  /// In fr, this message translates to:
  /// **'À venir'**
  String get periodUpcoming;

  /// No description provided for @periodPast.
  ///
  /// In fr, this message translates to:
  /// **'Passé'**
  String get periodPast;

  /// No description provided for @periodCustom.
  ///
  /// In fr, this message translates to:
  /// **'Période…'**
  String get periodCustom;

  /// No description provided for @scopeEditTitle.
  ///
  /// In fr, this message translates to:
  /// **'Modifier l\'événement récurrent'**
  String get scopeEditTitle;

  /// No description provided for @scopeDeleteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer l\'événement récurrent'**
  String get scopeDeleteTitle;

  /// No description provided for @scopeThis.
  ///
  /// In fr, this message translates to:
  /// **'Cet événement'**
  String get scopeThis;

  /// No description provided for @scopeFollowing.
  ///
  /// In fr, this message translates to:
  /// **'Cet événement et les suivants'**
  String get scopeFollowing;

  /// No description provided for @scopeAll.
  ///
  /// In fr, this message translates to:
  /// **'Tous les événements'**
  String get scopeAll;

  /// No description provided for @fieldRecurrence.
  ///
  /// In fr, this message translates to:
  /// **'Répétition'**
  String get fieldRecurrence;

  /// No description provided for @recurrenceNone.
  ///
  /// In fr, this message translates to:
  /// **'Ne se répète pas'**
  String get recurrenceNone;

  /// No description provided for @recurrenceCustom.
  ///
  /// In fr, this message translates to:
  /// **'Personnaliser…'**
  String get recurrenceCustom;

  /// No description provided for @recurrenceEvery.
  ///
  /// In fr, this message translates to:
  /// **'Tous les'**
  String get recurrenceEvery;

  /// No description provided for @unitDays.
  ///
  /// In fr, this message translates to:
  /// **'jours'**
  String get unitDays;

  /// No description provided for @unitWeeks.
  ///
  /// In fr, this message translates to:
  /// **'semaines'**
  String get unitWeeks;

  /// No description provided for @unitMonths.
  ///
  /// In fr, this message translates to:
  /// **'mois'**
  String get unitMonths;

  /// No description provided for @unitYears.
  ///
  /// In fr, this message translates to:
  /// **'ans'**
  String get unitYears;

  /// No description provided for @monthlyOnDay.
  ///
  /// In fr, this message translates to:
  /// **'le {day} du mois'**
  String monthlyOnDay(int day);

  /// No description provided for @monthlyOnLast.
  ///
  /// In fr, this message translates to:
  /// **'le dernier {weekday} du mois'**
  String monthlyOnLast(String weekday);

  /// No description provided for @recurrenceEnds.
  ///
  /// In fr, this message translates to:
  /// **'Fin'**
  String get recurrenceEnds;

  /// No description provided for @recurrenceNever.
  ///
  /// In fr, this message translates to:
  /// **'Jamais'**
  String get recurrenceNever;

  /// No description provided for @recurrenceAfter.
  ///
  /// In fr, this message translates to:
  /// **'Après'**
  String get recurrenceAfter;

  /// No description provided for @recurrenceTimes.
  ///
  /// In fr, this message translates to:
  /// **'fois'**
  String get recurrenceTimes;

  /// No description provided for @recurrenceUntil.
  ///
  /// In fr, this message translates to:
  /// **'Jusqu\'au'**
  String get recurrenceUntil;

  /// No description provided for @fieldHolidayRule.
  ///
  /// In fr, this message translates to:
  /// **'Jours fériés'**
  String get fieldHolidayRule;

  /// No description provided for @holidayRuleNone.
  ///
  /// In fr, this message translates to:
  /// **'Sans effet'**
  String get holidayRuleNone;

  /// No description provided for @holidayRuleSkip.
  ///
  /// In fr, this message translates to:
  /// **'Sauter'**
  String get holidayRuleSkip;

  /// No description provided for @holidayRuleNext.
  ///
  /// In fr, this message translates to:
  /// **'Jour ouvré suivant'**
  String get holidayRuleNext;

  /// No description provided for @holidayRulePrevious.
  ///
  /// In fr, this message translates to:
  /// **'Jour ouvré précédent'**
  String get holidayRulePrevious;

  /// No description provided for @settingsHolidays.
  ///
  /// In fr, this message translates to:
  /// **'Jours fériés et vacances'**
  String get settingsHolidays;

  /// No description provided for @settingsShowHolidays.
  ///
  /// In fr, this message translates to:
  /// **'Afficher les jours fériés'**
  String get settingsShowHolidays;

  /// No description provided for @settingsAlsaceMoselle.
  ///
  /// In fr, this message translates to:
  /// **'Alsace-Moselle'**
  String get settingsAlsaceMoselle;

  /// No description provided for @settingsAlsaceMoselleSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Ajoute le Vendredi saint et la Saint-Étienne'**
  String get settingsAlsaceMoselleSubtitle;

  /// No description provided for @settingsSchoolZone.
  ///
  /// In fr, this message translates to:
  /// **'Vacances scolaires'**
  String get settingsSchoolZone;

  /// No description provided for @noSchoolZone.
  ///
  /// In fr, this message translates to:
  /// **'Aucune'**
  String get noSchoolZone;

  /// No description provided for @schoolZone.
  ///
  /// In fr, this message translates to:
  /// **'Zone {zone}'**
  String schoolZone(String zone);

  /// No description provided for @birthdays.
  ///
  /// In fr, this message translates to:
  /// **'Anniversaires'**
  String get birthdays;

  /// No description provided for @newBirthday.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel anniversaire'**
  String get newBirthday;

  /// No description provided for @editBirthday.
  ///
  /// In fr, this message translates to:
  /// **'Modifier l\'anniversaire'**
  String get editBirthday;

  /// No description provided for @birthdaysEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun anniversaire. Ajoutez-en avec le bouton +.'**
  String get birthdaysEmpty;

  /// No description provided for @fieldBirthYear.
  ///
  /// In fr, this message translates to:
  /// **'Année de naissance (facultatif)'**
  String get fieldBirthYear;

  /// No description provided for @errorInvalidYear.
  ///
  /// In fr, this message translates to:
  /// **'Année invalide'**
  String get errorInvalidYear;

  /// No description provided for @cloud.
  ///
  /// In fr, this message translates to:
  /// **'Cloud Poulapp'**
  String get cloud;

  /// No description provided for @account.
  ///
  /// In fr, this message translates to:
  /// **'Compte Poulapp'**
  String get account;

  /// No description provided for @accountSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Synchronisation facultative entre vos appareils'**
  String get accountSubtitle;

  /// No description provided for @cloudNotConfigured.
  ///
  /// In fr, this message translates to:
  /// **'Cette version de Poulplan n\'est pas reliée au cloud Poulapp. Toutes vos données restent sur cet appareil.'**
  String get cloudNotConfigured;

  /// No description provided for @signInExplanation.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous pour synchroniser votre calendrier entre vos appareils. Sans compte, Poulplan fonctionne entièrement sur cet appareil.'**
  String get signInExplanation;

  /// No description provided for @fieldEmail.
  ///
  /// In fr, this message translates to:
  /// **'Adresse e-mail'**
  String get fieldEmail;

  /// No description provided for @fieldPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get fieldPassword;

  /// No description provided for @signIn.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get signIn;

  /// No description provided for @signInNoAccess.
  ///
  /// In fr, this message translates to:
  /// **'Ce compte n\'a pas accès à Poulplan.'**
  String get signInNoAccess;

  /// No description provided for @signInWrongCredentials.
  ///
  /// In fr, this message translates to:
  /// **'Adresse ou mot de passe incorrect.'**
  String get signInWrongCredentials;

  /// No description provided for @signInNetworkError.
  ///
  /// In fr, this message translates to:
  /// **'Connexion impossible. Vérifiez le réseau et réessayez.'**
  String get signInNetworkError;

  /// No description provided for @signedInPoulapp.
  ///
  /// In fr, this message translates to:
  /// **'Connecté au cloud Poulapp'**
  String get signedInPoulapp;

  /// No description provided for @syncInProgress.
  ///
  /// In fr, this message translates to:
  /// **'Synchronisation…'**
  String get syncInProgress;

  /// No description provided for @syncOffline.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne — les modifications seront envoyées plus tard'**
  String get syncOffline;

  /// No description provided for @syncDoneAt.
  ///
  /// In fr, this message translates to:
  /// **'Synchronisé à {time}'**
  String syncDoneAt(String time);

  /// No description provided for @syncNotYet.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore synchronisé'**
  String get syncNotYet;

  /// No description provided for @syncPending.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune modification en attente} =1{1 modification en attente} other{{count} modifications en attente}}'**
  String syncPending(int count);

  /// No description provided for @syncNow.
  ///
  /// In fr, this message translates to:
  /// **'Synchroniser maintenant'**
  String get syncNow;

  /// No description provided for @signOut.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get signOut;

  /// No description provided for @signOutBody.
  ///
  /// In fr, this message translates to:
  /// **'Vos données restent sur cet appareil. Les modifications faites hors connexion seront envoyées à la prochaine connexion.'**
  String get signOutBody;

  /// No description provided for @conflictsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 conflit à résoudre} other{{count} conflits à résoudre}}'**
  String conflictsCount(int count);

  /// No description provided for @conflictsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Conflits de synchronisation'**
  String get conflictsTitle;

  /// No description provided for @conflictsNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucun conflit.'**
  String get conflictsNone;

  /// No description provided for @conflictsExplanation.
  ///
  /// In fr, this message translates to:
  /// **'Ces informations ont été modifiées différemment sur deux appareils. Choisissez la version à garder ; la plus récente est affichée en attendant.'**
  String get conflictsExplanation;

  /// No description provided for @conflictField.
  ///
  /// In fr, this message translates to:
  /// **'{field} modifié des deux côtés'**
  String conflictField(String field);

  /// No description provided for @conflictDeletion.
  ///
  /// In fr, this message translates to:
  /// **'Supprimé sur un appareil, modifié sur l\'autre'**
  String get conflictDeletion;

  /// No description provided for @conflictThisDevice.
  ///
  /// In fr, this message translates to:
  /// **'Cet appareil'**
  String get conflictThisDevice;

  /// No description provided for @conflictOtherDevice.
  ///
  /// In fr, this message translates to:
  /// **'Autre appareil'**
  String get conflictOtherDevice;

  /// No description provided for @conflictDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Supprimé'**
  String get conflictDeleted;

  /// No description provided for @conflictKept.
  ///
  /// In fr, this message translates to:
  /// **'Conservé'**
  String get conflictKept;

  /// No description provided for @fieldReminders.
  ///
  /// In fr, this message translates to:
  /// **'Rappels'**
  String get fieldReminders;

  /// No description provided for @addReminder.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un rappel'**
  String get addReminder;

  /// No description provided for @reminderBefore.
  ///
  /// In fr, this message translates to:
  /// **'avant'**
  String get reminderBefore;

  /// No description provided for @unitMinutes.
  ///
  /// In fr, this message translates to:
  /// **'minutes'**
  String get unitMinutes;

  /// No description provided for @unitHours.
  ///
  /// In fr, this message translates to:
  /// **'heures'**
  String get unitHours;

  /// No description provided for @settingsReminders.
  ///
  /// In fr, this message translates to:
  /// **'Rappels'**
  String get settingsReminders;

  /// No description provided for @settingsDefaultReminder.
  ///
  /// In fr, this message translates to:
  /// **'Rappel par défaut'**
  String get settingsDefaultReminder;

  /// No description provided for @settingsDefaultReminderSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Ajouté aux nouveaux événements avec horaire'**
  String get settingsDefaultReminderSubtitle;

  /// No description provided for @noReminder.
  ///
  /// In fr, this message translates to:
  /// **'Aucun'**
  String get noReminder;

  /// No description provided for @notificationsAllowed.
  ///
  /// In fr, this message translates to:
  /// **'Notifications autorisées'**
  String get notificationsAllowed;

  /// No description provided for @notificationsDenied.
  ///
  /// In fr, this message translates to:
  /// **'Notifications non autorisées'**
  String get notificationsDenied;

  /// No description provided for @notificationsAllow.
  ///
  /// In fr, this message translates to:
  /// **'Autoriser'**
  String get notificationsAllow;

  /// No description provided for @notificationsTest.
  ///
  /// In fr, this message translates to:
  /// **'Tester les notifications'**
  String get notificationsTest;

  /// No description provided for @notificationsTestSubtitleAndroid.
  ///
  /// In fr, this message translates to:
  /// **'Une notification tout de suite, une autre dans 1 minute (à tester écran verrouillé)'**
  String get notificationsTestSubtitleAndroid;

  /// No description provided for @notificationsTestSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Affiche une notification tout de suite'**
  String get notificationsTestSubtitle;

  /// No description provided for @notificationsTestSent.
  ///
  /// In fr, this message translates to:
  /// **'Notification de test envoyée'**
  String get notificationsTestSent;

  /// No description provided for @settingsRunInBackground.
  ///
  /// In fr, this message translates to:
  /// **'Continuer en arrière-plan'**
  String get settingsRunInBackground;

  /// No description provided for @settingsRunInBackgroundSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Fermer la fenêtre garde Poulplan actif pour les rappels'**
  String get settingsRunInBackgroundSubtitle;

  /// No description provided for @settingsAutostart.
  ///
  /// In fr, this message translates to:
  /// **'Lancer à l\'ouverture de session'**
  String get settingsAutostart;

  /// No description provided for @settingsAutostartSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Poulplan démarre sans fenêtre pour afficher les rappels'**
  String get settingsAutostartSubtitle;

  /// No description provided for @quitApp.
  ///
  /// In fr, this message translates to:
  /// **'Quitter Poulplan'**
  String get quitApp;

  /// No description provided for @quitAppSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Plus aucun rappel tant que l\'application n\'est pas relancée'**
  String get quitAppSubtitle;

  /// No description provided for @signInServerError.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur a refusé la connexion : {message}'**
  String signInServerError(String message);

  /// No description provided for @enterTime.
  ///
  /// In fr, this message translates to:
  /// **'Saisir une heure'**
  String get enterTime;

  /// No description provided for @timeHour.
  ///
  /// In fr, this message translates to:
  /// **'Heure'**
  String get timeHour;

  /// No description provided for @timeMinute.
  ///
  /// In fr, this message translates to:
  /// **'Minute'**
  String get timeMinute;

  /// No description provided for @invalidTime.
  ///
  /// In fr, this message translates to:
  /// **'Heure invalide (00:00 à 23:59)'**
  String get invalidTime;
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

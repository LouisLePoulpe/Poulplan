import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/editing/event_draft.dart';
import '../../features/birthdays/presentation/birthdays_page.dart';
import '../../features/calendar/presentation/calendar_page.dart';
import '../../features/categories/presentation/categories_page.dart';
import '../../features/event_editor/presentation/event_editor_page.dart';
import '../../features/search/presentation/search_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/backup/presentation/backup_page.dart';
import '../../features/storage/presentation/storage_page.dart';
import '../../data/maps/map_tiles.dart';
import '../../features/maps/presentation/event_map_page.dart';
import '../../features/maps/presentation/maps_settings_page.dart';
import '../../features/maps/presentation/zone_page.dart';
import '../../features/sync/presentation/account_page.dart';
import '../../features/sync/presentation/conflicts_page.dart';

abstract final class Routes {
  static const home = '/';
  static const settings = '/settings';
  static const categories = '/settings/categories';
  static const birthdays = '/settings/birthdays';
  static const backups = '/settings/backups';
  static const storage = '/settings/storage';
  static const maps = '/settings/maps';
  static const mapZone = '/settings/maps/zone';
  static String eventMap(String id) => '/map/$id';
  static const search = '/search';
  static const account = '/settings/account';
  static const conflicts = '/settings/account/conflicts';
  static const newEvent = '/event/new';
  static String event(String id) => '/event/$id';
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = createRouter();
  ref.onDispose(router.dispose);
  return router;
});

GoRouter createRouter() => GoRouter(
  routes: [
    GoRoute(
      path: Routes.home,
      builder: (context, state) => const CalendarPage(),
    ),
    GoRoute(
      path: Routes.settings,
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: Routes.categories,
      builder: (context, state) => const CategoriesPage(),
    ),
    GoRoute(
      path: Routes.birthdays,
      builder: (context, state) => const BirthdaysPage(),
    ),
    GoRoute(
      path: Routes.backups,
      builder: (context, state) => const BackupPage(),
    ),
    GoRoute(
      path: Routes.storage,
      builder: (context, state) => const StoragePage(),
    ),
    GoRoute(
      path: Routes.maps,
      builder: (context, state) => const MapsSettingsPage(),
    ),
    GoRoute(
      path: Routes.mapZone,
      builder: (context, state) => ZonePage(resume: state.extra as MapZone?),
    ),
    GoRoute(
      path: '/map/:id',
      builder: (context, state) =>
          EventMapPage(eventId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: Routes.account,
      builder: (context, state) => const AccountPage(),
    ),
    GoRoute(
      path: Routes.conflicts,
      builder: (context, state) => const ConflictsPage(),
    ),
    GoRoute(
      path: Routes.search,
      builder: (context, state) => const SearchPage(),
    ),
    GoRoute(
      path: Routes.newEvent,
      builder: (context, state) =>
          EventEditorPage(initial: state.extra as EventDraft?),
    ),
    GoRoute(
      path: '/event/:id',
      builder: (context, state) =>
          EventEditorPage(eventId: state.pathParameters['id']),
    ),
  ],
);

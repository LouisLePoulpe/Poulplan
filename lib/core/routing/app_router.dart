import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/editing/event_draft.dart';
import '../../features/calendar/presentation/calendar_page.dart';
import '../../features/categories/presentation/categories_page.dart';
import '../../features/event_editor/presentation/event_editor_page.dart';
import '../../features/settings/presentation/settings_page.dart';

abstract final class Routes {
  static const home = '/';
  static const settings = '/settings';
  static const categories = '/settings/categories';
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

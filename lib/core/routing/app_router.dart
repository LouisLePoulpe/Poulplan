import 'package:go_router/go_router.dart';

import '../../features/calendar/presentation/month_view_page.dart';
import '../../features/settings/presentation/settings_page.dart';

abstract final class Routes {
  static const home = '/';
  static const settings = '/settings';
}

GoRouter createRouter() => GoRouter(
  routes: [
    GoRoute(
      path: Routes.home,
      builder: (context, state) => const MonthViewPage(),
    ),
    GoRoute(
      path: Routes.settings,
      builder: (context, state) => const SettingsPage(),
    ),
  ],
);

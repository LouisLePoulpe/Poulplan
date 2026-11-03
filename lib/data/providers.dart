import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/app_settings.dart';
import '../domain/entities/event_category.dart';
import 'db/app_database.dart';
import '../domain/entities/birthday.dart';
import 'repositories/birthday_repository.dart';
import 'repositories/category_repository.dart';
import 'repositories/saved_filter_repository.dart';
import 'repositories/event_repository.dart';
import 'repositories/settings_repository.dart';

/// Overridden in `main()` (real file) and in tests (in-memory database).
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final eventRepositoryProvider = Provider(
  (ref) => EventRepository(ref.watch(databaseProvider)),
);

final categoryRepositoryProvider = Provider(
  (ref) => CategoryRepository(ref.watch(databaseProvider)),
);

final settingsRepositoryProvider = Provider(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);

final settingsStreamProvider = StreamProvider<AppSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).watch(),
);

/// Current settings, falling back to defaults while loading.
final settingsProvider = Provider<AppSettings>(
  (ref) => ref.watch(settingsStreamProvider).value ?? AppSettings.defaults,
);

final categoriesProvider = StreamProvider<List<EventCategory>>(
  (ref) => ref.watch(categoryRepositoryProvider).watchAll(),
);

final birthdayRepositoryProvider = Provider(
  (ref) => BirthdayRepository(ref.watch(databaseProvider)),
);

final birthdaysProvider = StreamProvider<List<Birthday>>(
  (ref) => ref.watch(birthdayRepositoryProvider).watchAll(),
);

final savedFilterRepositoryProvider = Provider(
  (ref) => SavedFilterRepository(ref.watch(databaseProvider)),
);

final savedFiltersProvider = StreamProvider<List<SavedFilter>>(
  (ref) => ref.watch(savedFilterRepositoryProvider).watchAll(),
);

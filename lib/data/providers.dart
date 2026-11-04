import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../domain/entities/attachment.dart';
import 'repositories/attachment_repository.dart';
import 'repositories/route_repository.dart';

import '../domain/entities/app_settings.dart';
import '../domain/entities/event_category.dart';
import 'db/app_database.dart';
import '../domain/entities/birthday.dart';
import '../domain/sync/hlc.dart';
import 'sync/change_recorder.dart';
import 'repositories/birthday_repository.dart';
import 'repositories/category_repository.dart';
import 'repositories/saved_filter_repository.dart';
import 'repositories/event_repository.dart';
import 'repositories/settings_repository.dart';

/// Overridden in `main()` (real file) and in tests (in-memory database).
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

/// Where this device keeps its files (application support directory);
/// overridden in `main()`, a temporary directory otherwise (tests).
final appDirectoryProvider = Provider<Directory>(
  (ref) => Directory.systemTemp.createTempSync('poulplan'),
);

final attachmentRepositoryProvider = Provider(
  (ref) => AttachmentRepository(
    ref.watch(databaseProvider),
    directory: Directory(
      p.join(ref.watch(appDirectoryProvider).path, 'attachments'),
    ),
    recorder: ref.watch(changeRecorderProvider),
  ),
);

final routeRepositoryProvider = Provider(
  (ref) => RouteRepository(
    ref.watch(databaseProvider),
    recorder: ref.watch(changeRecorderProvider),
  ),
);

final attachmentsProvider = StreamProvider.family<List<Attachment>, String>(
  (ref, eventId) =>
      ref.watch(attachmentRepositoryProvider).watchForEvent(eventId),
);

/// This device's clock; overridden in `main()` with the persisted one.
final hlcClockProvider = Provider<HlcClock>((ref) => HlcClock('local'));

final changeRecorderProvider = Provider<ChangeRecorder>((ref) {
  final recorder = ChangeRecorder(
    ref.watch(databaseProvider),
    ref.watch(hlcClockProvider),
  );
  ref.onDispose(recorder.dispose);
  return recorder;
});

final eventRepositoryProvider = Provider(
  (ref) => EventRepository(
    ref.watch(databaseProvider),
    recorder: ref.watch(changeRecorderProvider),
  ),
);

final categoryRepositoryProvider = Provider(
  (ref) => CategoryRepository(
    ref.watch(databaseProvider),
    recorder: ref.watch(changeRecorderProvider),
  ),
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
  (ref) => BirthdayRepository(
    ref.watch(databaseProvider),
    recorder: ref.watch(changeRecorderProvider),
  ),
);

final birthdaysProvider = StreamProvider<List<Birthday>>(
  (ref) => ref.watch(birthdayRepositoryProvider).watchAll(),
);

final savedFilterRepositoryProvider = Provider(
  (ref) => SavedFilterRepository(
    ref.watch(databaseProvider),
    recorder: ref.watch(changeRecorderProvider),
  ),
);

final savedFiltersProvider = StreamProvider<List<SavedFilter>>(
  (ref) => ref.watch(savedFilterRepositoryProvider).watchAll(),
);

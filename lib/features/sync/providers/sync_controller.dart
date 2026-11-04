import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase/supabase.dart';

import '../../../core/config/cloud_config.dart';
import '../../../data/attachments/attachment_transfer.dart';
import '../../../data/cloud/cloud_session.dart';
import '../../../data/cloud/supabase_remote.dart';
import '../../../data/db/app_database.dart';
import '../../../data/providers.dart';
import '../../../data/sync/conflict_resolver.dart';
import '../../../data/sync/sync_engine.dart';

enum SyncPhase { disabled, signedOut, idle, syncing, offline }

@immutable
class SyncStatus {
  const SyncStatus({
    required this.phase,
    this.email,
    this.lastSync,
    this.lastError,
  });

  const SyncStatus.disabled() : this(phase: SyncPhase.disabled);

  final SyncPhase phase;
  final String? email;
  final DateTime? lastSync;
  final String? lastError;

  bool get signedIn =>
      phase == SyncPhase.idle ||
      phase == SyncPhase.syncing ||
      phase == SyncPhase.offline;

  SyncStatus copyWith({
    SyncPhase? phase,
    String? Function()? email,
    DateTime? lastSync,
    String? Function()? lastError,
  }) => SyncStatus(
    phase: phase ?? this.phase,
    email: email != null ? email() : this.email,
    lastSync: lastSync ?? this.lastSync,
    lastError: lastError != null ? lastError() : this.lastError,
  );
}

/// Cloud session, only when this build has a cloud configuration.
final cloudSessionProvider = Provider<CloudSession?>((ref) {
  if (!CloudConfig.isConfigured) return null;
  final session = CloudSession(
    ref.watch(databaseProvider),
    SupabaseClient(CloudConfig.url, CloudConfig.anonKey),
  );
  ref.onDispose(session.dispose);
  return session;
});

final conflictResolverProvider = Provider(
  (ref) => ConflictResolver(
    ref.watch(databaseProvider),
    ref.watch(changeRecorderProvider),
  ),
);

final syncConflictsProvider = StreamProvider<List<SyncConflictRow>>(
  (ref) => ref.watch(conflictResolverProvider).watchAll(),
);

final pendingChangesProvider = StreamProvider<int>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.selectOnly(db.syncMeta)
        ..addColumns([db.syncMeta.recordId])
        ..where(db.syncMeta.dirty.equals(true)))
      .watch()
      .map((rows) => rows.length);
});

/// File transfers of the attachments, when signed in.
final attachmentTransferProvider = Provider<AttachmentTransfer?>((ref) {
  ref.watch(syncControllerProvider.select((s) => s.signedIn));
  final session = ref.watch(cloudSessionProvider);
  final user = session?.client.auth.currentUser;
  if (session == null || !session.isSignedIn || user == null) return null;
  return AttachmentTransfer(
    ref.watch(attachmentRepositoryProvider),
    SupabaseAttachmentRemote(session.client),
    userId: user.id,
  );
});

/// Drives the optional cloud synchronization: after sign-in, a few seconds
/// after each local change, every few minutes and when the app comes back
/// to the foreground. Failures never block local use.
class SyncController extends Notifier<SyncStatus> {
  static const _debounce = Duration(seconds: 3);
  static const _period = Duration(minutes: 5);

  CloudSession? _session;
  SyncEngine? _engine;
  Timer? _debounceTimer;
  Timer? _periodic;
  bool _running = false;
  bool _again = false;

  @override
  SyncStatus build() {
    _session = ref.watch(cloudSessionProvider);
    if (_session == null) return const SyncStatus.disabled();
    final recorder = ref.watch(changeRecorderProvider);
    _engine = SyncEngine(
      ref.watch(databaseProvider),
      SupabaseRemote(_session!.client),
      recorder,
    );
    final changes = recorder.changes.listen((_) => _schedule());
    final lifecycle = AppLifecycleListener(onResume: syncNow);
    _periodic = Timer.periodic(_period, (_) => syncNow());
    ref.onDispose(() {
      changes.cancel();
      lifecycle.dispose();
      _periodic?.cancel();
      _debounceTimer?.cancel();
    });
    Future.microtask(_restore);
    return const SyncStatus(phase: SyncPhase.signedOut);
  }

  Future<void> _restore() async {
    if (await _session!.restore()) {
      state = state.copyWith(
        phase: SyncPhase.idle,
        email: () => _session!.email,
      );
      await syncNow();
    }
  }

  void _schedule() {
    if (!state.signedIn) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, syncNow);
  }

  Future<void> signIn(String email, String password) async {
    await _session!.signIn(email, password);
    state = state.copyWith(
      phase: SyncPhase.idle,
      email: () => _session!.email,
      lastError: () => null,
    );
    await syncNow();
  }

  /// Local data stays on the device.
  Future<void> signOut() async {
    await _session?.signOut();
    state = const SyncStatus(phase: SyncPhase.signedOut);
  }

  Future<void> syncNow() async {
    if (!state.signedIn || _engine == null) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    state = state.copyWith(phase: SyncPhase.syncing);
    try {
      do {
        _again = false;
        await _engine!.sync();
      } while (_again);
      await ref.read(attachmentTransferProvider)?.run();
      state = state.copyWith(
        phase: SyncPhase.idle,
        lastSync: DateTime.now(),
        lastError: () => null,
      );
    } catch (error) {
      debugPrint('Sync failed: $error');
      state = state.copyWith(
        phase: SyncPhase.offline,
        lastError: () => '$error',
      );
    } finally {
      _running = false;
    }
  }
}

final syncControllerProvider = NotifierProvider<SyncController, SyncStatus>(
  SyncController.new,
);

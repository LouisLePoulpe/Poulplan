import 'dart:async';

import 'package:supabase/supabase.dart';

import '../db/app_database.dart';

/// The account is valid but was not granted access to Poulplan in
/// `poulapp_access`.
class NoPoulplanAccessException implements Exception {
  const NoPoulplanAccessException();
}

/// Optional connection to the Poulapp cloud.
///
/// Only the refresh token is kept (in the local database), never the
/// password.
class CloudSession {
  CloudSession(this._db, this.client) {
    _subscription = client.auth.onAuthStateChange.listen(_onAuthState);
  }

  final AppDatabase _db;
  final SupabaseClient client;
  late final StreamSubscription<AuthState> _subscription;

  static const _tokenKey = 'cloud_refresh_token';

  String? get email => client.auth.currentUser?.email;

  bool get isSignedIn => client.auth.currentSession != null;

  Stream<AuthState> get changes => client.auth.onAuthStateChange;

  Future<void> _onAuthState(AuthState state) async {
    final token = state.session?.refreshToken;
    if (state.event == AuthChangeEvent.signedOut) {
      await (_db.delete(
        _db.settings,
      )..where((s) => s.key.equals(_tokenKey))).go();
    } else if (token != null) {
      await _db
          .into(_db.settings)
          .insertOnConflictUpdate(
            SettingsCompanion.insert(key: _tokenKey, value: token),
          );
    }
  }

  /// Restores the previous session, if any. Network errors are ignored
  /// (the app stays usable offline; the next attempt will retry).
  Future<bool> restore() async {
    final row = await (_db.select(
      _db.settings,
    )..where((s) => s.key.equals(_tokenKey))).getSingleOrNull();
    if (row == null) return false;
    try {
      await client.auth.setSession(row.value);
      return true;
    } on AuthException {
      await signOut();
      return false;
    }
  }

  Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(email: email, password: password);
    if (!await hasAccess()) {
      await signOut();
      throw const NoPoulplanAccessException();
    }
  }

  Future<bool> hasAccess() async {
    final row = await client
        .from('poulapp_access')
        .select('app_id')
        .eq('app_id', 'poulplan')
        .maybeSingle();
    return row != null;
  }

  Future<void> signOut() async {
    try {
      await client.auth.signOut();
    } catch (_) {
      // Offline: the local session is cleared anyway.
    }
    await (_db.delete(
      _db.settings,
    )..where((s) => s.key.equals(_tokenKey))).go();
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await client.dispose();
  }
}

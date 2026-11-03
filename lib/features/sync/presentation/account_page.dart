import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase/supabase.dart' show AuthException;

import '../../../core/format/formatters.dart';
import '../../../core/routing/app_router.dart';
import '../../../data/cloud/cloud_session.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../providers/sync_controller.dart';

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final status = ref.watch(syncControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.account)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              switch (status.phase) {
                SyncPhase.disabled => _Message(
                  icon: Icons.cloud_off_outlined,
                  text: l10n.cloudNotConfigured,
                ),
                SyncPhase.signedOut => const _SignInForm(),
                _ => _SignedIn(status: status),
              },
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, size: 48),
      const SizedBox(height: 16),
      Text(text, textAlign: TextAlign.center),
    ],
  );
}

class _SignInForm extends ConsumerStatefulWidget {
  const _SignInForm();

  @override
  ConsumerState<_SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends ConsumerState<_SignInForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(syncControllerProvider.notifier)
          .signIn(_email.text.trim(), _password.text);
    } on NoPoulplanAccessException {
      _error = l10n.signInNoAccess;
    } on AuthException {
      _error = l10n.signInWrongCredentials;
    } catch (_) {
      _error = l10n.signInNetworkError;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.signInExplanation),
          const SizedBox(height: 16),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(labelText: l10n.fieldEmail),
          ),
          TextField(
            controller: _password,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(labelText: l10n.fieldPassword),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.signIn),
          ),
        ],
      ),
    );
  }
}

class _SignedIn extends ConsumerWidget {
  const _SignedIn({required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final pending = ref.watch(pendingChangesProvider).value ?? 0;
    final conflicts = ref.watch(syncConflictsProvider).value ?? const [];
    final controller = ref.read(syncControllerProvider.notifier);
    final last = status.lastSync;
    final state = switch (status.phase) {
      SyncPhase.syncing => l10n.syncInProgress,
      SyncPhase.offline => l10n.syncOffline,
      _ when last != null => l10n.syncDoneAt(formatClock(last)),
      _ => l10n.syncNotYet,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.account_circle_outlined),
          title: Text(status.email ?? ''),
          subtitle: Text(l10n.signedInPoulapp),
        ),
        ListTile(
          leading: Icon(syncIcon(status.phase)),
          title: Text(state),
          subtitle: Text(l10n.syncPending(pending)),
          trailing: status.phase == SyncPhase.syncing
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
        ),
        if (conflicts.isNotEmpty)
          Card(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: ListTile(
              leading: const Icon(Icons.merge_type),
              title: Text(l10n.conflictsCount(conflicts.length)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.conflicts),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.sync),
          label: Text(l10n.syncNow),
          onPressed: status.phase == SyncPhase.syncing
              ? null
              : controller.syncNow,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.logout),
          label: Text(l10n.signOut),
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(l10n.signOut),
                content: Text(l10n.signOutBody),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(l10n.signOut),
                  ),
                ],
              ),
            );
            if (confirmed == true) await controller.signOut();
          },
        ),
      ],
    );
  }
}

IconData syncIcon(SyncPhase phase) => switch (phase) {
  SyncPhase.syncing => Icons.cloud_sync_outlined,
  SyncPhase.offline => Icons.cloud_off_outlined,
  SyncPhase.idle => Icons.cloud_done_outlined,
  _ => Icons.cloud_outlined,
};

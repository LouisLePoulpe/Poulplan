import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../l10n/generated/app_localizations.dart';

/// Searchable list of IANA time zones.
Future<String?> showTimeZonePicker(BuildContext context, String current) =>
    showDialog<String>(
      context: context,
      builder: (context) => _TimeZoneDialog(current: current),
    );

class _TimeZoneDialog extends StatefulWidget {
  const _TimeZoneDialog({required this.current});

  final String current;

  @override
  State<_TimeZoneDialog> createState() => _TimeZoneDialogState();
}

class _TimeZoneDialogState extends State<_TimeZoneDialog> {
  late final List<String> _all =
      tz.timeZoneDatabase.locations.keys
          .where((name) => name.contains('/') && !name.startsWith('Etc/'))
          .toList()
        ..sort();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final normalized = _query.toLowerCase().replaceAll(' ', '_');
    final matches = _all
        .where((z) => z.toLowerCase().contains(normalized))
        .toList();
    return AlertDialog(
      title: Text(l10n.fieldTimeZone),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 420,
        height: 480,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.searchTimeZone,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: matches.length,
                itemBuilder: (context, i) => ListTile(
                  dense: true,
                  title: Text(matches[i].replaceAll('_', ' ')),
                  selected: matches[i] == widget.current,
                  onTap: () => Navigator.of(context).pop(matches[i]),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}

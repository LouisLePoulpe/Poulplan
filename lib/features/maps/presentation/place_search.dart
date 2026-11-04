import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/geo/geo.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../maps_providers.dart';

/// Looks an address up (Nominatim, on demand) and returns the chosen place.
Future<Place?> showPlaceSearch(BuildContext context, {String initial = ''}) =>
    showDialog<Place>(
      context: context,
      builder: (context) => _PlaceSearchDialog(initial: initial),
    );

class _PlaceSearchDialog extends ConsumerStatefulWidget {
  const _PlaceSearchDialog({required this.initial});

  final String initial;

  @override
  ConsumerState<_PlaceSearchDialog> createState() => _PlaceSearchDialogState();
}

class _PlaceSearchDialogState extends ConsumerState<_PlaceSearchDialog> {
  late final _query = TextEditingController(text: widget.initial);
  List<Place>? _results;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial.trim().isNotEmpty) _search();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final text = _query.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final results = await ref.read(geoServiceProvider).search(text);
      if (mounted) setState(() => _results = results);
    } catch (_) {
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context).placeSearchFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final results = _results;
    return AlertDialog(
      title: Text(l10n.placeSearch),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _query,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.placeSearchHint,
                errorText: _error,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _search,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (results != null && results.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(l10n.placeSearchNone),
              ),
            if (results != null && results.isNotEmpty)
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final place in results)
                      ListTile(
                        leading: const Icon(Icons.place_outlined),
                        title: Text(place.label),
                        onTap: () => Navigator.pop(context, place),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              '© OpenStreetMap (Nominatim)',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}

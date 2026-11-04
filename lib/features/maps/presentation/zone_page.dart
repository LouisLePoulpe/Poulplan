import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/maps/map_tiles.dart';
import '../../../domain/geo/geo.dart';
import '../../../domain/geo/tiles.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../maps_providers.dart';
import 'poulplan_map.dart';

/// Frame an area and download it for offline use (or resume [resume]).
class ZonePage extends ConsumerStatefulWidget {
  const ZonePage({super.key, this.resume});

  final MapZone? resume;

  @override
  ConsumerState<ZonePage> createState() => _ZonePageState();
}

class _ZonePageState extends ConsumerState<ZonePage> {
  final _map = MapController();
  final _name = TextEditingController();
  GeoBounds? _bounds;
  (int, int)? _progress;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.resume != null) {
      _name.text = widget.resume!.name;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _download(widget.resume!),
      );
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _download(MapZone? existing) async {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(mapZoneRepositoryProvider);
    setState(() {
      _error = null;
      _progress = (0, 1);
    });
    try {
      final template = await ref.read(tileTemplateProvider.future);
      if (template == null) throw StateError('offline');
      final zone =
          existing ??
          await repository.create(
            _name.text.trim().isEmpty ? l10n.offlineZones : _name.text.trim(),
            _bounds!,
          );
      await repository.download(
        zone,
        urlTemplate: template,
        progress: (done, total) {
          if (mounted) setState(() => _progress = (done, total));
        },
      );
      ref.invalidate(mapStyleProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.offlineZoneDone)));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _progress = null;
          _error = l10n.operationFailed('$e');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bounds = _bounds;
    final count = bounds == null
        ? null
        : countTiles(bounds, minZoom: 0, maxZoom: OpenFreeMap.maxZoom);
    final tooLarge = count != null && count > maxZoneTiles;
    final progress = _progress;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.offlineZoneAdd)),
      body: Column(
        children: [
          Expanded(
            child: PoulplanMap(
              controller: _map,
              destination: ref.watch(homePlaceProvider)?.point,
              onMoved: (bounds) {
                if (mounted) setState(() => _bounds = bounds);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.offlineZonePick),
                TextField(
                  controller: _name,
                  decoration: InputDecoration(labelText: l10n.offlineZoneName),
                ),
                const SizedBox(height: 8),
                if (progress != null) ...[
                  LinearProgressIndicator(value: progress.$1 / progress.$2),
                  Text(l10n.offlineZoneProgress(progress.$1, progress.$2)),
                ] else ...[
                  if (count != null)
                    Text(
                      tooLarge
                          ? l10n.offlineZoneTooLarge(count, maxZoneTiles)
                          : l10n.offlineZoneEstimate(count),
                      style: TextStyle(
                        color: tooLarge
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                    ),
                  if (_error != null)
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.download),
                    label: Text(l10n.offlineZoneDownload),
                    onPressed: bounds == null || tooLarge
                        ? null
                        : () => _download(null),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

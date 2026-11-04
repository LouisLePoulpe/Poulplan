import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/formatters.dart';
import '../../../core/platform/offline_router.dart';
import '../../../core/routing/app_router.dart';
import '../../../data/maps/map_tiles.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../backup/presentation/backup_page.dart' show formatBytes;
import '../maps_providers.dart';
import 'place_search.dart';

/// Null where offline routes do not exist (Linux).
final _brouterProvider = FutureProvider<bool?>(
  (ref) async => Platform.isAndroid ? OfflineRouter.available() : null,
);

/// « Cartes et trajets »: start address, offline zones, BRouter.
class MapsSettingsPage extends ConsumerWidget {
  const MapsSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final home = ref.watch(homePlaceProvider);
    final zones = ref.watch(mapZonesProvider).value ?? const [];
    final brouter = ref.watch(_brouterProvider).value;
    final locale = localeOf(context);
    final theme = Theme.of(context);

    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mapsSettings)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: Text(l10n.homePlace),
            subtitle: Text(home?.label ?? l10n.homePlaceNone),
            trailing: home == null
                ? null
                : IconButton(
                    tooltip: l10n.placeClear,
                    icon: const Icon(Icons.close),
                    onPressed: () =>
                        ref.read(homePlaceProvider.notifier).set(null),
                  ),
            onTap: () async {
              final place = await showPlaceSearch(context);
              if (place != null) {
                await ref.read(homePlaceProvider.notifier).set(place);
              }
            },
          ),
          section(l10n.offlineZones),
          if (zones.isEmpty)
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.offlineZoneNone),
            ),
          for (final zone in zones)
            ListTile(
              leading: Icon(
                zone.complete ? Icons.map_outlined : Icons.downloading,
              ),
              title: Text(zone.name),
              subtitle: Text(
                zone.complete
                    ? l10n.offlineZoneTiles(
                        zone.tileCount,
                        formatBytes(zone.bytes, locale),
                      )
                    : l10n.offlineZoneIncomplete,
              ),
              onTap: zone.complete
                  ? null
                  : () => context.push(Routes.mapZone, extra: zone),
              trailing: IconButton(
                tooltip: l10n.delete,
                icon: const Icon(Icons.delete_outline),
                onPressed: () =>
                    ref.read(mapZoneRepositoryProvider).delete(zone.id),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.add_location_alt_outlined),
            title: Text(l10n.offlineZoneAdd),
            onTap: () => context.push(Routes.mapZone),
          ),
          if (brouter != null) ...[
            section(l10n.brouterTitle),
            ListTile(
              leading: Icon(
                brouter ? Icons.check_circle_outline : Icons.download_outlined,
              ),
              title: Text(
                brouter ? l10n.brouterInstalled : l10n.brouterMissing,
              ),
            ),
          ],
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('© ${OpenFreeMap.attribution}'),
          ),
        ],
      ),
    );
  }
}

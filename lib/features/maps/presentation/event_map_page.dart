import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../../domain/geo/routing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../maps_providers.dart';
import 'poulplan_map.dart';

/// Full screen map of an event's place and remembered route.
class EventMapPage extends ConsumerWidget {
  const EventMapPage({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final event = ref.watch(_eventProvider(eventId)).value;
    final route = ref.watch(routeForEventProvider(eventId)).value;
    final destination = event?.placePoint ?? route?.destination;
    return Scaffold(
      appBar: AppBar(
        title: Text(event?.title ?? l10n.mapTitle),
        bottom: route == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    l10n.routeSummary(
                      formatDuration(route.result.durationSeconds),
                      formatDistance(route.result.distanceMeters),
                    ),
                  ),
                ),
              ),
      ),
      body: event == null && route == null
          ? const Center(child: CircularProgressIndicator())
          : PoulplanMap(
              destination: destination,
              origin: route?.origin,
              route: route?.result.points ?? const [],
            ),
    );
  }
}

final _eventProvider = FutureProvider.family(
  (ref, String id) => ref.watch(eventRepositoryProvider).findById(id),
);

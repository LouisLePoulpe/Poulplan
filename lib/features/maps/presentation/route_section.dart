import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/format/formatters.dart';
import '../../../core/platform/offline_router.dart';
import '../../../core/routing/app_router.dart';
import '../../../data/providers.dart';
import '../../../domain/geo/geo.dart';
import '../../../domain/geo/routing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../maps_providers.dart';
import 'place_search.dart';
import 'poulplan_map.dart';

IconData travelIcon(TravelMode mode) => switch (mode) {
  TravelMode.car => Icons.directions_car_outlined,
  TravelMode.bike => Icons.directions_bike_outlined,
  TravelMode.foot => Icons.directions_walk_outlined,
};

/// « Trajet » in the editor: remembered route to the event's place.
class RouteSection extends ConsumerStatefulWidget {
  const RouteSection({
    super.key,
    required this.eventId,
    required this.destination,
  });

  /// Saved event (series master), null for a new event.
  final String? eventId;
  final GeoPoint? destination;

  @override
  ConsumerState<RouteSection> createState() => _RouteSectionState();
}

class _RouteSectionState extends ConsumerState<RouteSection> {
  TravelMode? _mode;
  Place? _origin;
  bool _busy = false;

  void _show(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _compute(TravelMode mode, Place origin) async {
    final l10n = AppLocalizations.of(context);
    final destination = widget.destination!;
    setState(() => _busy = true);
    try {
      RouteResult result;
      var engine = 'osrm';
      try {
        result = await ref
            .read(geoServiceProvider)
            .route(origin.point, destination, mode);
      } on RoutingException {
        // Offline (or server down): BRouter, when installed.
        if (!await OfflineRouter.available()) {
          if (mounted) _show(l10n.routeOffline);
          return;
        }
        result = await OfflineRouter.route(origin.point, destination, mode);
        engine = 'brouter';
      }
      await ref
          .read(routeRepositoryProvider)
          .save(
            eventId: widget.eventId!,
            mode: mode,
            origin: origin,
            destination: destination,
            result: result,
            engine: engine,
          );
    } catch (e) {
      if (mounted) _show(l10n.routeFailed('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final eventId = widget.eventId;
    final destination = widget.destination;
    Widget header(String? hint) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.route_outlined),
      title: Text(l10n.routeTitle),
      subtitle: hint == null ? null : Text(hint),
    );
    if (destination == null) return header(l10n.routeNeedsPlace);
    if (eventId == null) return header(l10n.routeSaveFirst);

    final stored = ref.watch(routeForEventProvider(eventId)).value;
    final home = ref.watch(homePlaceProvider);
    final origin =
        _origin ??
        (stored == null ? null : Place(stored.originLabel, stored.origin)) ??
        home;
    final mode = _mode ?? stored?.mode ?? TravelMode.car;
    final date = DateFormat("d MMM 'à' HH:mm", localeOf(context));
    final moved = stored != null && stored.destination != destination;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header(null),
        Padding(
          padding: const EdgeInsets.only(left: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<TravelMode>(
                segments: [
                  for (final (m, label) in [
                    (TravelMode.car, l10n.travelCar),
                    (TravelMode.bike, l10n.travelBike),
                    (TravelMode.foot, l10n.travelFoot),
                  ])
                    ButtonSegment(
                      value: m,
                      icon: Icon(travelIcon(m)),
                      label: Text(label),
                    ),
                ],
                selected: {mode},
                onSelectionChanged: (s) => setState(() => _mode = s.single),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.trip_origin),
                title: Text(
                  origin == null
                      ? l10n.routeNoStart
                      : l10n.routeFrom(origin.label),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () async {
                  final place = await showPlaceSearch(context);
                  if (place != null) setState(() => _origin = place);
                },
              ),
              if (stored != null) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(travelIcon(stored.mode)),
                  title: Text(
                    l10n.routeSummary(
                      formatDuration(stored.result.durationSeconds),
                      formatDistance(stored.result.distanceMeters),
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: Text(
                    moved
                        ? l10n.routePlaceChanged
                        : stored.engine == 'brouter'
                        ? l10n.routeComputedOffline(
                            date.format(stored.computedAt.toLocal()),
                          )
                        : l10n.routeComputedOnline(
                            date.format(stored.computedAt.toLocal()),
                          ),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 180,
                    child: PoulplanMap(
                      key: ValueKey(stored.id),
                      destination: destination,
                      origin: stored.origin,
                      route: stored.result.points,
                      interactive: false,
                      onTap: () => context.push(Routes.eventMap(eventId)),
                    ),
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.alt_route),
                    label: Text(
                      stored == null ? l10n.routeCompute : l10n.routeRecompute,
                    ),
                    onPressed: _busy || origin == null
                        ? null
                        : () => _compute(mode, origin),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

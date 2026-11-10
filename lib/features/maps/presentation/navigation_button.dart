import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/platform/file_exchange.dart';
import '../../../domain/geo/geo.dart';
import '../../../domain/geo/navigation_link.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Opens the event's place in a navigation app (Android: `geo:` link and
/// the apps installed; Linux: the route on openstreetmap.org).
class NavigationButton extends StatelessWidget {
  const NavigationButton({
    super.key,
    this.point,
    this.address,
    this.label,
    this.compact = false,
  });

  final GeoPoint? point;
  final String? address;
  final String? label;

  /// Icon only (app bars).
  final bool compact;

  Uri? get _uri => Platform.isAndroid
      ? geoUri(point: point, address: address, label: label)
      : webDirectionsUri(point: point, address: address);

  Future<void> _open(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    try {
      await FileExchange.openUri(_uri!, title: l10n.openNavigation);
    } on PlatformException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              e.code == 'NO_APP'
                  ? l10n.noNavigationApp
                  : l10n.operationFailed(e.message ?? e.code),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_uri == null) return const SizedBox.shrink();
    final text = Platform.isAndroid
        ? l10n.openNavigation
        : l10n.openNavigationWeb;
    if (compact) {
      return IconButton(
        tooltip: text,
        icon: const Icon(Icons.navigation_outlined),
        onPressed: () => _open(context),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        icon: const Icon(Icons.navigation_outlined),
        label: Text(text),
        onPressed: () => _open(context),
      ),
    );
  }
}

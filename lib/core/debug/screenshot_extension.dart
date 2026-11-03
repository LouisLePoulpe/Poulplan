import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/calendar/day.dart';
import '../../features/calendar/providers/calendar_providers.dart';
import '../routing/app_router.dart';

/// Debug-only VM service extension used to check the app without touching
/// the rest of the desktop:
///
/// `ext.poulplan.screenshot` with optional `route` (go_router location),
/// `view` (day|week|month|year|agenda) and `day` (yyyy-MM-dd), then writes a
/// PNG of the app's own window to `path`.
void registerDebugExtensions(ProviderContainer container) {
  if (!kDebugMode) return;
  developer.registerExtension('ext.poulplan.screenshot', (
    method,
    params,
  ) async {
    final path = params['path'];
    if (path == null) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.invalidParams,
        'Missing "path"',
      );
    }
    final route = params['route'];
    if (route != null) container.read(routerProvider).go(route);
    final view = params['view'];
    if (view != null) {
      container
          .read(calendarViewProvider.notifier)
          .select(CalendarViewType.values.byName(view));
    }
    final day = params['day'];
    if (day != null) {
      container.read(focusedDayProvider.notifier).set(Day.parse(day));
    }
    // Let routes, streams and animations settle.
    for (var i = 0; i < 20; i++) {
      SchedulerBinding.instance.scheduleFrame();
      await SchedulerBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }

    final view0 = RendererBinding.instance.renderViews.first;
    final layer = view0.debugLayer! as OffsetLayer;
    // The root layer is in physical pixels.
    final image = await layer.toImage(
      Offset.zero & view0.flutterView.physicalSize,
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(path).writeAsBytes(bytes!.buffer.asUint8List());
    return developer.ServiceExtensionResponse.result(
      jsonEncode({'path': path, 'width': image.width, 'height': image.height}),
    );
  });
}

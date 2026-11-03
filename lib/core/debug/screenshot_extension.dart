import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// Debug-only VM service extension writing a PNG of the app's own window to
/// the `path` parameter, so that checks never capture the rest of the screen.
void registerScreenshotExtension() {
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
    final view = RendererBinding.instance.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    // The root layer is in physical pixels.
    final image = await layer.toImage(
      Offset.zero & view.flutterView.physicalSize,
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(path).writeAsBytes(bytes!.buffer.asUint8List());
    return developer.ServiceExtensionResponse.result(
      jsonEncode({'path': path, 'width': image.width, 'height': image.height}),
    );
  });
}

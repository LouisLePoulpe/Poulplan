// Generates the derived branding images from assets/branding/poulplan-logo.png.
//
// Usage: dart run tool/gen_icons.dart
// Then:  dart run flutter_launcher_icons && dart run flutter_native_splash:create
import 'dart:io';

import 'package:image/image.dart' as img;

const _source = 'assets/branding/poulplan-logo.png';
const _generated = 'assets/branding/generated';
const _linuxIcons = 'linux/packaging/icons/hicolor';
const _appId = 'org.poulapp.poulplan';

void main() {
  final logo = img.decodePng(File(_source).readAsBytesSync());
  if (logo == null) {
    stderr.writeln('Unable to decode $_source');
    exit(1);
  }
  Directory(_generated).createSync(recursive: true);

  // Adaptive icon: 108 dp canvas, only the central 66 dp are always visible.
  _write('$_generated/adaptive_foreground.png', _centered(logo, 1024, 0.60));
  _write(
    '$_generated/adaptive_monochrome.png',
    _centered(_lineArt(logo), 1024, 0.60),
  );

  // Android 12+ splash: the icon is masked by a circle of 2/3 of the canvas.
  _write('$_generated/splash_android12.png', _centered(logo, 1152, 0.62));
  // Pre-Android 12 splash and in-app logo.
  _write('$_generated/splash.png', _centered(logo, 768, 1.0));

  // Android notification small icon (white silhouette, 24 dp).
  const densities = {'mdpi': 24, 'hdpi': 36, 'xhdpi': 48, 'xxhdpi': 72};
  for (final MapEntry(key: density, value: size) in densities.entries) {
    final dir = Directory('android/app/src/main/res/drawable-$density')
      ..createSync(recursive: true);
    _write(
      '${dir.path}/ic_notification.png',
      _centered(_lineArt(logo), size, 1.0),
    );
  }

  for (final size in [64, 128, 256, 512]) {
    final dir = Directory('$_linuxIcons/${size}x$size/apps')
      ..createSync(recursive: true);
    _write('${dir.path}/$_appId.png', _centered(logo, size, 0.94));
  }
}

/// [logo] scaled to [ratio] of a transparent square [canvas].
img.Image _centered(img.Image logo, int canvas, double ratio) {
  final target = (canvas * ratio).round();
  final resized = img.copyResize(
    logo,
    width: target,
    height: target,
    interpolation: img.Interpolation.cubic,
  );
  final out = img.Image(width: canvas, height: canvas, numChannels: 4);
  final offset = (canvas - target) ~/ 2;
  return img.compositeImage(out, resized, dstX: offset, dstY: offset);
}

/// Keeps the dark brown strokes as opaque white, drops the yellow fills:
/// used by Android 13+ themed (monochrome) icons.
img.Image _lineArt(img.Image logo) {
  final out = img.Image(width: logo.width, height: logo.height, numChannels: 4);
  for (final p in logo) {
    final dark = p.a > 128 && p.luminanceNormalized < 0.55;
    if (dark) out.setPixelRgba(p.x, p.y, 255, 255, 255, 255);
  }
  return out;
}

void _write(String path, img.Image image) {
  File(path).writeAsBytesSync(img.encodePng(image));
  stdout.writeln('wrote $path');
}

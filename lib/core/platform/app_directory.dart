import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Where Poulplan keeps its data: the application support directory, or
/// `POULPLAN_DATA_DIR` when set (demo data for the screenshots, tests on a
/// copy) — never mixed with the real calendar.
Future<Directory> appDataDirectory() async {
  final override = Platform.environment['POULPLAN_DATA_DIR'];
  if (override != null && override.isNotEmpty) {
    return Directory(override).create(recursive: true);
  }
  return getApplicationSupportDirectory();
}

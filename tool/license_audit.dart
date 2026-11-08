// Lists the licence of every runtime dependency (Dart packages) from
// pubspec.lock and the pub cache, and flags anything not clearly free.
// Usage: dart run tool/license_audit.dart > docs/LICENSES.md
import 'dart:io';

const _kinds = <String, List<String>>{
  'BSD-3-Clause': ['Redistribution and use in source and binary forms', 'Neither the name'],
  'BSD-2-Clause': ['Redistribution and use in source and binary forms'],
  'MIT': ['Permission is hereby granted, free of charge'],
  'Apache-2.0': ['Apache License', 'Version 2.0'],
  'MPL-2.0': ['Mozilla Public License', '2.0'],
  'GPL-3.0': ['GNU GENERAL PUBLIC LICENSE', 'Version 3'],
  'LGPL': ['GNU LESSER GENERAL PUBLIC LICENSE'],
  'Zlib': ['This software is provided \'as-is\''],
  'Unlicense / domaine public': ['This is free and unencumbered software'],
};

String classify(String text) {
  for (final MapEntry(:key, :value) in _kinds.entries) {
    if (value.every(text.contains)) return key;
  }
  return '?';
}

Future<void> main() async {
  final runtime = (await Process.run('dart', [
    'pub', 'deps', '--style=list', '--no-dev',
  ])).stdout as String;
  final names = RegExp(r'^\s*- ([a-z0-9_]+) ', multiLine: true)
      .allMatches(runtime)
      .map((m) => m[1]!)
      .toSet();
  final lock = File('pubspec.lock').readAsStringSync();
  final entries = RegExp(
    r'^  ([a-z0-9_]+):\n(?:    .*\n)*?    source: (\w+)\n    version: "([^"]+)"',
    multiLine: true,
  ).allMatches(lock);
  final home = Platform.environment['PUB_CACHE'] ??
      '${Platform.environment['HOME']}/.pub-cache';
  final rows = <String>[];
  var unknown = 0;
  for (final m in entries) {
    final (name, source, version) = (m[1]!, m[2]!, m[3]!);
    if (!names.contains(name)) continue;
    String licence;
    if (source == 'sdk') {
      licence = 'BSD-3-Clause (SDK Flutter/Dart)';
    } else {
      final dir = Directory('$home/hosted/pub.dev/$name-$version');
      final file = ['LICENSE', 'LICENSE.md', 'LICENSE.txt', 'COPYING']
          .map((f) => File('${dir.path}/$f'))
          .where((f) => f.existsSync())
          .firstOrNull;
      licence = file == null ? '?' : classify(file.readAsStringSync());
    }
    if (licence == '?') unknown++;
    rows.add('| $name | $version | $licence |');
  }
  rows.sort();
  stdout
    ..writeln('# Licences des dépendances')
    ..writeln()
    ..writeln('Généré par `dart run tool/license_audit.dart` (dépendances '
        "d'exécution Dart uniquement ; Android : voir plus bas).")
    ..writeln()
    ..writeln('| Paquet | Version | Licence |')
    ..writeln('|---|---|---|')
    ..writeAll(rows, '\n')
    ..writeln()
    ..writeln()
    ..writeln('À vérifier à la main : $unknown.');
}

// Regenerates assets/data/school_holidays_fr.json from the French Ministry of
// Education open data ("Calendrier scolaire", Licence Ouverte 2.0):
// https://data.education.gouv.fr/explore/dataset/fr-en-calendrier-scolaire/
//
// Usage: dart run tool/update_school_holidays.dart
// The app never downloads anything at runtime: this file is bundled.
import 'dart:convert';
import 'dart:io';

const _zones = ['Zone A', 'Zone B', 'Zone C', 'Corse'];
const _firstSchoolYear = 2024;
const _output = 'assets/data/school_holidays_fr.json';

Future<void> main() async {
  final uri = Uri.https(
    'data.education.gouv.fr',
    '/api/explore/v2.1/catalog/datasets/fr-en-calendrier-scolaire/exports/json',
    {
      'where':
          'zones in (${_zones.map((z) => '"$z"').join(',')}) '
          'and start_date >= date\'$_firstSchoolYear-08-01\'',
    },
  );
  final client = HttpClient();
  final response = await (await client.getUrl(uri)).close();
  if (response.statusCode != 200) {
    stderr.writeln('HTTP ${response.statusCode} for $uri');
    exit(1);
  }
  final records =
      jsonDecode(await response.transform(utf8.decoder).join()) as List;
  client.close();

  final periods = <String, Map<String, String>>{};
  for (final r in records.cast<Map<String, dynamic>>()) {
    final population = r['population'] as String? ?? '-';
    if (population != '-' && population != 'Élèves') continue;
    final zone = (r['zones'] as String).replaceFirst('Zone ', '');
    final start = _parisDate(r['start_date'] as String);
    var end = _parisDate(r['end_date'] as String);
    // `end_date` is the day classes resume; one-day "ponts" have end == start.
    if (end == start) end = _nextDay(start);
    final name = (r['description'] as String).trim();
    final key = '$zone|$name|$start';
    periods[key] = {'zone': zone, 'name': name, 'start': start, 'end': end};
  }
  final sorted = periods.values.toList()
    ..sort(
      (a, b) => '${a['start']}${a['zone']}'.compareTo('${b['start']}${b['zone']}'),
    );
  final json = const JsonEncoder.withIndent(' ').convert({
    'source':
        'data.education.gouv.fr — fr-en-calendrier-scolaire (Licence Ouverte 2.0)',
    'generated': DateTime.now().toUtc().toIso8601String().substring(0, 10),
    'endExclusive': true,
    'periods': sorted,
  });
  File(_output)
    ..createSync(recursive: true)
    ..writeAsStringSync('$json\n');
  stdout.writeln('${sorted.length} periods written to $_output');
}

/// Dates are published as UTC instants of midnight in Paris.
String _parisDate(String iso) {
  final utc = DateTime.parse(iso).toUtc().add(const Duration(hours: 3));
  return utc.toIso8601String().substring(0, 10);
}

String _nextDay(String date) => DateTime.parse(
  '${date}T00:00:00Z',
).add(const Duration(days: 1)).toIso8601String().substring(0, 10);

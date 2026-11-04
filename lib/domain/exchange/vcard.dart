import 'dart:convert';

import 'package:meta/meta.dart';

/// A birthday read from a contact card.
@immutable
class VCardBirthday {
  const VCardBirthday({
    required this.name,
    required this.month,
    required this.day,
    this.year,
  });

  final String name;
  final int month;
  final int day;
  final int? year;

  @override
  bool operator ==(Object other) =>
      other is VCardBirthday &&
      other.name == name &&
      other.month == month &&
      other.day == day &&
      other.year == year;

  @override
  int get hashCode => Object.hash(name, month, day, year);

  @override
  String toString() => 'VCardBirthday($name, $day/$month/$year)';
}

/// Birthdays of the cards of a .vcf file (vCard 2.1, 3.0 and 4.0); cards
/// without a name or a valid BDAY are skipped.
List<VCardBirthday> parseVCardBirthdays(String text) {
  final result = <VCardBirthday>[];
  String? fn;
  String? n;
  String? bday;
  for (final line in _unfold(text)) {
    final colon = line.indexOf(':');
    if (colon < 0) continue;
    final head = line.substring(0, colon);
    final params = head.split(';');
    final name = params.first.toUpperCase().split('.').last;
    var value = line.substring(colon + 1);
    if (params.any((p) => p.toUpperCase() == 'ENCODING=QUOTED-PRINTABLE')) {
      value = _quotedPrintable(value);
    }
    switch (name) {
      case 'BEGIN':
        fn = n = bday = null;
      case 'FN':
        fn = _unescape(value).trim();
      case 'N':
        final parts = value.split(';').map(_unescape).toList();
        n = [
          if (parts.length > 1) parts[1],
          parts[0],
        ].where((p) => p.trim().isNotEmpty).join(' ').trim();
      case 'BDAY':
        final omitYear = params.any(
          (p) => p.toUpperCase().startsWith('X-APPLE-OMIT-YEAR'),
        );
        bday = omitYear ? '--${value.trim().substring(5)}' : value.trim();
      case 'END':
        final displayName = (fn?.isNotEmpty ?? false) ? fn! : n ?? '';
        final date = bday == null ? null : parseBirthdayDate(bday);
        if (displayName.isNotEmpty && date != null) {
          result.add(
            VCardBirthday(
              name: displayName,
              month: date.month,
              day: date.day,
              year: date.year,
            ),
          );
        }
    }
  }
  return result;
}

/// `1996-04-12`, `19960412`, `--04-12`, `--0412`, with an optional time.
({int month, int day, int? year})? parseBirthdayDate(String text) {
  final match = RegExp(r'^(\d{4}|--)-?(\d{2})-?(\d{2})(T.*)?$')
      .firstMatch(text.trim());
  if (match == null) return null;
  final year = match[1] == '--' ? null : int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  // A leap year, so that 29 February stays valid without a year.
  final check = DateTime.utc(year ?? 2000, month, day);
  if (month < 1 || month > 12 || check.month != month || check.day != day) {
    return null;
  }
  return (month: month, day: day, year: year);
}

/// Logical lines: RFC folding (leading space or tab) and quoted-printable
/// soft breaks (`=` at the end of the line).
List<String> _unfold(String text) {
  final lines = <String>[];
  for (final raw in const LineSplitter().convert(text)) {
    if ((raw.startsWith(' ') || raw.startsWith('\t')) && lines.isNotEmpty) {
      lines.last += raw.substring(1);
    } else if (lines.isNotEmpty &&
        lines.last.endsWith('=') &&
        lines.last.toUpperCase().contains('QUOTED-PRINTABLE')) {
      lines.last = lines.last.substring(0, lines.last.length - 1) + raw;
    } else {
      lines.add(raw);
    }
  }
  return lines;
}

String _quotedPrintable(String value) {
  final bytes = <int>[];
  for (var i = 0; i < value.length; i++) {
    if (value[i] == '=' && i + 2 < value.length) {
      final code = int.tryParse(value.substring(i + 1, i + 3), radix: 16);
      if (code != null) {
        bytes.add(code);
        i += 2;
        continue;
      }
    }
    bytes.addAll(utf8.encode(value[i]));
  }
  return utf8.decode(bytes, allowMalformed: true);
}

String _unescape(String s) => s
    .replaceAll(r'\n', '\n')
    .replaceAll(r'\N', '\n')
    .replaceAll(r'\,', ',')
    .replaceAll(r'\;', ';')
    .replaceAll(r'\\', r'\');

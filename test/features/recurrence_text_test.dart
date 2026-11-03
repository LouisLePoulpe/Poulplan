import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:poulplan/domain/calendar/day.dart';
import 'package:poulplan/domain/recurrence/recurrence_rule.dart';
import 'package:poulplan/features/event_editor/presentation/recurrence_text.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  String describe(String rule, [Day? start]) =>
      describeRule(RecurrenceRule.parse(rule), start ?? Day(2026, 7, 14), 'fr');

  test('daily', () {
    expect(describe('FREQ=DAILY'), 'Tous les jours');
    expect(describe('FREQ=DAILY;INTERVAL=3'), 'Tous les 3 jours');
    expect(
      describe('FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR'),
      'Tous les jours de semaine',
    );
  });

  test('weekly', () {
    expect(describe('FREQ=WEEKLY'), 'Toutes les semaines le mardi');
    expect(
      describe('FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,TH'),
      'Toutes les 2 semaines le lundi et le jeudi',
    );
  });

  test('monthly', () {
    expect(describe('FREQ=MONTHLY'), 'Tous les mois le 14');
    expect(
      describe('FREQ=MONTHLY;BYDAY=-1FR'),
      'Tous les mois le dernier vendredi',
    );
    expect(describe('FREQ=MONTHLY;BYDAY=2TU'), 'Tous les mois le 2e mardi');
    expect(describe('FREQ=MONTHLY;BYDAY=1MO'), 'Tous les mois le 1er lundi');
    expect(
      describe('FREQ=MONTHLY;BYMONTHDAY=-1'),
      'Tous les mois le dernier jour',
    );
    expect(describe('FREQ=MONTHLY;INTERVAL=3'), 'Tous les 3 mois le 14');
  });

  test('yearly', () {
    expect(describe('FREQ=YEARLY'), 'Tous les ans le 14 juillet');
    expect(
      describe('FREQ=YEARLY;BYMONTH=11;BYDAY=4TH'),
      'Tous les ans le 4e jeudi de novembre',
    );
  });

  test('limits', () {
    expect(describe('FREQ=DAILY;COUNT=10'), 'Tous les jours, 10 fois');
    expect(
      describe('FREQ=WEEKLY;UNTIL=20271231'),
      "Toutes les semaines le mardi, jusqu'au 31 déc. 2027",
    );
  });

  test('presets built from the start day', () {
    final start = Day(2026, 11, 27); // last Friday of November 2026
    expect(monthlyByPosition(start).toString(), 'FREQ=MONTHLY;BYDAY=4FR');
    expect(monthlyByLastWeekday(start)?.toString(), 'FREQ=MONTHLY;BYDAY=-1FR');
    expect(monthlyByLastWeekday(Day(2026, 11, 20)), isNull);
  });
}

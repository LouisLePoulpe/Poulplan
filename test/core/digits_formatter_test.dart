import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poulplan/core/input/digits_formatter.dart';

void main() {
  TextEditingValue type(String text) =>
      const DigitsInputFormatter().formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        ),
      );

  test('keeps digits', () {
    expect(type('2045').text, '2045');
  });

  test('French AZERTY top row without Shift becomes digits', () {
    expect(type('&é"\'(-è_çà').text, '1234567890');
  });

  test('drops anything else and keeps the cursor at the end', () {
    final value = type('1h3o');
    expect(value.text, '13');
    expect(value.selection.baseOffset, 2);
  });
}

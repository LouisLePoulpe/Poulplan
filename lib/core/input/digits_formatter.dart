import 'package:flutter/services.dart';

/// Unshifted keys of the French AZERTY top row, which type digits only with
/// Shift: accepted as the digits they stand for.
const _azertyTopRow = {
  '&': '1',
  'é': '2',
  '"': '3',
  "'": '4',
  '(': '5',
  '-': '6',
  'è': '7',
  '_': '8',
  'ç': '9',
  'à': '0',
};

/// Digits only, also from the AZERTY top row without Shift.
class DigitsInputFormatter extends TextInputFormatter {
  const DigitsInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final buffer = StringBuffer();
    var cursor = newValue.selection.baseOffset;
    for (var i = 0; i < newValue.text.length; i++) {
      final char = newValue.text[i];
      final digit = RegExp(r'\d').hasMatch(char) ? char : _azertyTopRow[char];
      if (digit != null) {
        buffer.write(digit);
      } else if (i < newValue.selection.baseOffset) {
        cursor--;
      }
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor.clamp(0, text.length)),
    );
  }
}

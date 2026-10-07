import 'package:budget_manager/views/widgets/amount_field.dart';
import 'package:flutter_test/flutter_test.dart';

TextEditingValue typed(CashRegisterFormatter formatter, String text) =>
    formatter.formatEditUpdate(
        TextEditingValue.empty, TextEditingValue(text: text));

void main() {
  test('reads the digits as cents, whatever surrounds them', () {
    expect(CashRegisterFormatter.centsOf(''), 0);
    expect(CashRegisterFormatter.centsOf('0'), 0);
    expect(CashRegisterFormatter.centsOf('1234'), 1234);
    expect(CashRegisterFormatter.centsOf('12.34'), 1234);
    expect(CashRegisterFormatter.centsOf('1 234,50'), 123450);
    expect(CashRegisterFormatter.centsOf('007'), 7);
    // Digits past the twelfth are ignored, so the field cannot overflow.
    expect(CashRegisterFormatter.centsOf('1234567890123'), 123456789012);
  });

  test('shows the amount per locale, with the caret at the end', () {
    final english = CashRegisterFormatter('en');
    final polish = CashRegisterFormatter('pl');

    expect(typed(english, '1234').text, '12.34');
    expect(typed(english, '1234').selection.baseOffset, 5);
    expect(typed(english, '5').text, '0.05');
    expect(typed(english, '123450').text, '1,234.50');
    expect(typed(polish, '1234').text, '12,34');
    expect(typed(polish, '123450').text, '1 234,50');
    expect(english.zero, '0.00');
    expect(polish.zero, '0,00');
  });

  test('an empty field stays empty and Backspace drops the last digit', () {
    final formatter = CashRegisterFormatter('en');
    expect(typed(formatter, '').text, '');
    expect(typed(formatter, '0').text, '');
    // "12.34" with its last character removed: 123 cents.
    expect(typed(formatter, '12.3').text, '1.23');
    expect(typed(formatter, '1,234.5').text, '123.45');
    expect(formatter.text(0), '');
    expect(formatter.text(8640), '86.40');
  });
}

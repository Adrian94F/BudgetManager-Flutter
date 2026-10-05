import 'package:budget_manager/tools/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats money per locale with two decimals and the currency suffix', () {
    final polish = Formatters.money(1234.5, 'pl');
    final english = Formatters.money(1234.5, 'en');

    expect(polish, endsWith('zł'));
    expect(polish, contains('234,50'));
    expect(english, endsWith('zł'));
    expect(english, contains('1,234.50'));
    expect(Formatters.money(0, 'en'), contains('0.00'));
    expect(Formatters.money(-12.3, 'en'), contains('-12.30'));
  });
}

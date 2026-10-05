import 'package:budget_manager/tools/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats money per locale with the currency symbol', () {
    final polish = Formatters.money(1234.5, 'pl');
    final english = Formatters.money(1234.5, 'en');

    expect(polish, endsWith('zł'));
    expect(polish, contains('234,50'));
    expect(english, 'zł 1,234.50');
    expect(Formatters.money(0, 'en'), 'zł 0.00');
    expect(Formatters.money(-12.3, 'en'), '-zł 12.30');
  });

  test('follows the currency the server reports', () {
    expect(Formatters.money(1234.5, 'en', currency: 'EUR'), '€1,234.50');
    expect(Formatters.money(1234.5, 'pl', currency: 'EUR'), endsWith('€'));
    expect(Formatters.money(1234.5, 'en', currency: 'CHF'), 'CHF 1,234.50');
    expect(Formatters.money(1234.5, 'en', currency: 'USD'), r'$1,234.50');
  });

  test('rounds to whole units when asked', () {
    expect(Formatters.money(1234.5, 'en', decimalDigits: 0), 'zł 1,235');
    expect(Formatters.money(1234.4, 'en', decimalDigits: 0), 'zł 1,234');
    expect(
      Formatters.money(1234.5, 'pl', decimalDigits: 0),
      '1 235 zł',
    );
  });

  test('knows the symbol of a currency', () {
    expect(Formatters.currencySymbol('PLN', 'pl'), 'zł');
    expect(Formatters.currencySymbol('EUR', 'en'), '€');
    expect(Formatters.currencySymbol('CHF', 'en'), 'CHF');
  });
}

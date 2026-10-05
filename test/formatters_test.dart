import 'package:budget_manager/tools/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('currency formatter shows two decimals and the currency symbol', () {
    final text = Formatters.currencyFormatter.format(1234.5);
    expect(text, contains('zł'));
    expect(text, contains(',50'));
  });
}

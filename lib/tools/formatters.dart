import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../models/currency.dart';

/// Money formatting. Amounts follow the app locale for grouping and the
/// decimal separator and carry the user's currency as the server reports it
/// ("1 234,50 zł" in Polish; "zł 1,234.50" or "€1,234.50" in English).
class Formatters {
  Formatters._();

  static final Map<String, NumberFormat> _formats = {};

  // CLDR currency spacing, which intl skips: a letter-based symbol ("zł",
  // "CHF") gets a no-break space next to the digits, as on the web and iOS.
  static final _letterThenDigit = RegExp(r'(?<=\p{L})(?=\d)', unicode: true);
  static final _digitThenLetter = RegExp(r'(?<=\d)(?=\p{L})', unicode: true);

  static String money(double amount, String locale, {String currency = defaultCurrency}) {
    final format = _formats['$locale|$currency'] ??= NumberFormat.simpleCurrency(locale: locale, name: currency);
    return format.format(amount).replaceAll(_letterThenDigit, ' ').replaceAll(_digitThenLetter, ' ');
  }

  /// [money] in the locale of [context] and the currency of the nearest
  /// [CurrencyScope].
  static String moneyOf(BuildContext context, double amount) =>
      money(amount, Localizations.localeOf(context).toString(), currency: CurrencyScope.of(context));

  /// The symbol of [currency] in [locale] ("zł", "€"), or its code when the
  /// locale has no shorter form ("CHF").
  static String currencySymbol(String currency, String locale) =>
      NumberFormat.simpleCurrency(locale: locale, name: currency).currencySymbol;
}

/// The currency amounts are shown in, from the signed-in user's settings. The
/// app puts one above the navigator so every screen formats the same way and
/// follows a change made in the settings.
class CurrencyScope extends InheritedWidget {
  const CurrencyScope({super.key, required this.currency, required super.child});

  final String currency;

  static String of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CurrencyScope>()?.currency ?? defaultCurrency;

  @override
  bool updateShouldNotify(CurrencyScope oldWidget) => currency != oldWidget.currency;
}

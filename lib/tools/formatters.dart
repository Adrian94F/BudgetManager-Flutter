import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Money formatting. Amounts follow the app locale for grouping and the
/// decimal separator ("1 234,50 zł" in Polish, "1,234.50 zł" in English)
/// and always carry the currency suffix the web app uses; changing or
/// dropping the symbol is a one-line change here.
class Formatters {
  Formatters._();

  static const currencySymbol = 'zł';

  static final Map<String, NumberFormat> _byLocale = {};

  static String money(double amount, String locale) {
    final format = _byLocale[locale] ??= NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: 2);
    return '${format.format(amount)} $currencySymbol';
  }

  /// [money] in the locale of [context].
  static String moneyOf(BuildContext context, double amount) =>
      money(amount, Localizations.localeOf(context).toString());
}

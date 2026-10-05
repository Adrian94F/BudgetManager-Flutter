/// The server's default currency, used when a response carries none.
const defaultCurrency = 'PLN';

/// One entry of the server's currency list.
class CurrencyChoice {
  const CurrencyChoice({required this.code, required this.name});

  /// ISO 4217 code, e.g. `PLN`.
  final String code;

  /// Display name in the server's language, e.g. `Polish złoty`.
  final String name;

  factory CurrencyChoice.fromJson(Map<String, dynamic> json) {
    final code = json['code'] as String;
    return CurrencyChoice(code: code, name: json['name'] as String? ?? code);
  }
}

/// The `GET api/currency/` response: the user's currency and the codes the
/// server accepts.
class CurrencySettings {
  const CurrencySettings({required this.currency, required this.choices});

  final String currency;
  final List<CurrencyChoice> choices;

  factory CurrencySettings.fromJson(Map<String, dynamic> json) => CurrencySettings(
        currency: json['currency'] as String? ?? defaultCurrency,
        choices: (json['choices'] as List<dynamic>? ?? const [])
            .map((c) => CurrencyChoice.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

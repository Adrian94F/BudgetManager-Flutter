/// Parses a money value from the API.
///
/// GET responses carry floats (DRF converts Decimal with `float()`, and an
/// empty sum comes back as the int `0`), while POST responses carry strings
/// such as `"123.45"`. Both are accepted here.
double parseMoney(Object? value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value.replaceAll(',', '.')) ?? 0;
  }
  throw FormatException('Unexpected money value: $value');
}

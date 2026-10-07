import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../tools/formatters.dart';

/// Cash-register amount entry, as on the web: digits shift in from the right
/// and the field always shows a whole amount with two decimals ("12,34"
/// in Polish, "12.34" in English). There is no decimal key to find: typing
/// 1 2 3 4 gives 12.34, Backspace drops the last digit. The amount is kept
/// in cents, so nothing depends on the locale's separators.
class CashRegisterFormatter extends TextInputFormatter {
  CashRegisterFormatter(this.locale)
      : _format =
            NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: 2);

  /// Enough for any budget; further digits are ignored, as on the web.
  static const maxDigits = 12;

  final String locale;
  final NumberFormat _format;

  /// The cents the digits of [text] spell, whatever else it holds.
  static int centsOf(String text) {
    final digits =
        text.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0+'), '');
    if (digits.isEmpty) return 0;
    return int.parse(digits.substring(0, digits.length.clamp(0, maxDigits)));
  }

  /// [cents] as the field shows them; zero is an empty field.
  String text(int cents) => cents == 0 ? '' : _format.format(cents / 100);

  /// What an empty field hints at ("0,00").
  String get zero => _format.format(0);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final formatted = text(centsOf(newValue.text));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// The amount field of the expense and income forms: large figures, the
/// user's currency after them, cash-register entry. Reports the amount in
/// units through [onChanged] and submits with the keyboard's action key.
class AmountField extends StatefulWidget {
  const AmountField({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.onSubmitted,
    this.label,
    this.autofocus = false,
    this.enabled = true,
    this.selectAllOnFocus = false,
    this.border,
  });

  final double initialValue;
  final ValueChanged<double> onChanged;
  final VoidCallback? onSubmitted;
  final String? label;
  final bool autofocus;
  final bool enabled;

  /// Select the amount when the field first gets focus, so the first digit
  /// typed starts a new amount: for editing, where the old one is in place.
  final bool selectAllOnFocus;
  final InputBorder? border;

  @override
  State<AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<AmountField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late CashRegisterFormatter _formatter;
  late int _cents = (widget.initialValue * 100).round();
  String? _locale;
  bool _selectedOnce = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context).toString();
    if (locale == _locale) return;
    _locale = locale;
    _formatter = CashRegisterFormatter(locale);
    _controller.text = _formatter.text(_cents);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocus);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (!_focusNode.hasFocus || _selectedOnce) return;
    _selectedOnce = true;
    if (widget.selectAllOnFocus && _controller.text.isNotEmpty) {
      _controller.selection =
          TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
    }
  }

  void _toEnd() {
    _controller.selection =
        TextSelection.collapsed(offset: _controller.text.length);
  }

  void _changed(String text) {
    final cents = CashRegisterFormatter.centsOf(text);
    if (cents == _cents) return;
    _cents = cents;
    widget.onChanged(cents / 100);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final symbol =
        Formatters.currencySymbol(CurrencyScope.of(context), _locale!);
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      keyboardType: TextInputType.number,
      inputFormatters: [_formatter],
      textInputAction: TextInputAction.done,
      onChanged: _changed,
      onSubmitted:
          widget.onSubmitted == null ? null : (_) => widget.onSubmitted!(),
      onTap: _toEnd,
      style: theme.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: _formatter.zero,
        suffixText: symbol,
        suffixStyle: theme.textTheme.titleMedium
            ?.copyWith(color: scheme.onSurfaceVariant),
        prefixIcon: const Icon(Icons.payments_outlined),
        border: widget.border,
      ),
    );
  }
}

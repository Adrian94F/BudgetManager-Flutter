import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import '../api/api.dart';
import '../app/app_scope.dart';
import '../domain/domain.dart';
import '../models/models.dart';
import 'widgets/error_views.dart';

/// Full-screen dialog that edits a month's dates and the planned savings,
/// deletes a month that has no incomes or expenses, or creates a new month.
class MonthDetailsScreen extends StatefulWidget {
  const MonthDetailsScreen._({this.month, required this.start, required this.end});

  /// The month being edited; null when creating one.
  final Month? month;
  final DateTime start;
  final DateTime end;

  static Future<bool?> openEdit(BuildContext context, Month month) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MonthDetailsScreen._(month: month, start: month.startDate, end: month.endDate),
      ),
    );
  }

  /// Proposes the month after the newest one, or the current calendar month
  /// for an account without months.
  static Future<bool?> openCreate(BuildContext context) {
    final months = AppScope.of(context).months.data?.months ?? const <Month>[];
    final range = months.isEmpty ? BudgetRules.firstMonthRange() : BudgetRules.nextMonthRange(months.first);
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MonthDetailsScreen._(start: range.start, end: range.end),
      ),
    );
  }

  @override
  State<MonthDetailsScreen> createState() => _MonthDetailsScreenState();
}

class _MonthDetailsScreenState extends State<MonthDetailsScreen> {
  static const _savingsStep = 100;

  late DateTime _start;
  late DateTime _end;
  late final TextEditingController _savingsController;
  late final double _initialSavings;
  bool _busy = false;
  String? _error;

  bool get _isEditing => widget.month != null;

  @override
  void initState() {
    super.initState();
    _start = widget.start;
    _end = widget.end;
    _initialSavings = AppScope.of(context).months.data?.plannedSavings ?? 0;
    _savingsController = TextEditingController(text: _initialSavings.round().toString());
  }

  @override
  void dispose() {
    _savingsController.dispose();
    super.dispose();
  }

  /// Only the loaded month can be checked for content, and only an empty
  /// month may be deleted (the server refuses otherwise).
  bool get _canDelete {
    final data = AppScope.of(context).months.data;
    final month = widget.month;
    if (month == null || data == null || data.month?.id != month.id) return false;
    return data.incomes.isEmpty && data.expenses.isEmpty;
  }

  double? _parseSavings() => double.tryParse(_savingsController.text.replaceAll(',', '.').trim());

  void _adjustSavings(int delta) {
    final current = _parseSavings() ?? 0;
    final next = (current + delta).clamp(0, double.maxFinite).round();
    setState(() => _savingsController.text = next.toString());
  }

  Future<void> _pickDate({required bool start}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final months = AppScope.of(context).months;
    if (_end.isBefore(_start)) {
      setState(() => _error = l10n.invalidDateRange);
      return;
    }
    final savings = _isEditing ? _parseSavings() : null;
    if (_isEditing && (savings == null || savings < 0)) {
      setState(() => _error = l10n.invalidAmount);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_isEditing) {
        await months.updateMonth(id: widget.month!.id, start: _start, end: _end);
        if (savings != _initialSavings) await months.savePlannedSavings(savings!);
      } else {
        await months.createMonth(start: _start, end: _end);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.isNetwork ? l10n.errorServerUnavailable : e.message;
      });
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    final months = AppScope.of(context).months;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteMonth),
        content: Text(l10n.deleteMonthConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: Text(l10n.remove),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await months.deleteMonth(widget.month!.id);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.isNetwork ? l10n.errorServerUnavailable : e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(12.0));

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editMonth : l10n.newMonthTitle),
        actions: [
          TextButton(
            onPressed: _busy ? null : _save,
            child: Text(_isEditing ? l10n.save : l10n.add),
          ),
          const SizedBox(width: 8),
        ],
        bottom: _busy
            ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2))
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        children: [
          if (_error != null) ...[
            FormErrorBox(message: _error!),
            const SizedBox(height: 16),
          ],
          _DateField(
            label: l10n.startDate,
            value: DateFormat.yMMMMEEEEd(locale).format(_start),
            enabled: !_busy,
            border: border,
            onTap: () => _pickDate(start: true),
          ),
          const SizedBox(height: 16),
          _DateField(
            label: l10n.endDate,
            value: DateFormat.yMMMMEEEEd(locale).format(_end),
            enabled: !_busy,
            border: border,
            onTap: () => _pickDate(start: false),
          ),
          if (_isEditing) ...[
            const SizedBox(height: 32),
            Text(l10n.plannedSavings, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(l10n.plannedSavingsHint, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: _busy ? null : () => _adjustSavings(-_savingsStep),
                  icon: const Icon(Icons.remove_rounded),
                  tooltip: '-$_savingsStep',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _savingsController,
                    enabled: !_busy,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    style: theme.textTheme.titleLarge,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.savings_outlined),
                      border: border,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  onPressed: _busy ? null : () => _adjustSavings(_savingsStep),
                  icon: const Icon(Icons.add_rounded),
                  tooltip: '+$_savingsStep',
                ),
              ],
            ),
            const SizedBox(height: 40),
            Text(l10n.deleteMonthHint, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _canDelete && !_busy ? _delete : null,
              style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
              icon: const Icon(Icons.delete_outline_rounded),
              label: Text(l10n.deleteMonth),
            ),
          ],
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.border,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool enabled;
  final InputBorder border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextField(
      readOnly: true,
      enabled: enabled,
      controller: TextEditingController(text: value),
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.event_outlined),
        suffixIcon: const Icon(Icons.arrow_drop_down),
        border: border,
      ),
    );
  }
}

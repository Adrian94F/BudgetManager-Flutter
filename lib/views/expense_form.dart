import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import '../api/api.dart';
import '../app/app_scope.dart';
import '../domain/domain.dart';
import '../models/models.dart';
import 'widgets/error_views.dart';

/// Full-screen dialog to add or edit an expense. Opened with [expense] it
/// edits that expense; with [template] it prefills a copy; otherwise it
/// creates a new expense dated inside the month and suggests the most used
/// categories.
class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({
    super.key,
    this.expense,
    this.template,
    this.initialDate,
    this.initialCategoryId,
  });

  final Expense? expense;
  final Expense? template;
  final DateTime? initialDate;
  final int? initialCategoryId;

  static Future<bool?> open(
    BuildContext context, {
    Expense? expense,
    Expense? template,
    DateTime? initialDate,
    int? initialCategoryId,
  }) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ExpenseFormScreen(
          expense: expense,
          template: template,
          initialDate: initialDate,
          initialCategoryId: initialCategoryId,
        ),
      ),
    );
  }

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  late final TextEditingController _amountController;
  late final TextEditingController _commentController;
  late DateTime _date;
  int? _categoryId;
  late bool _isMonthly;
  late final List<int> _suggestedCategoryIds;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    final data = AppScope.of(context).months.data!;
    final month = data.month!;
    final source = widget.expense ?? widget.template;
    _amountController = TextEditingController(text: source == null ? '' : source.value.toStringAsFixed(2));
    _commentController = TextEditingController(text: source?.comment ?? '');
    _date = widget.expense?.date ?? widget.template?.date ?? widget.initialDate ?? BudgetRules.defaultEntryDate(month);
    // Only categories that still exist can be suggested or preselected.
    bool exists(int? id) => id != null && data.categoryById(id) != null;
    _suggestedCategoryIds =
        _isEditing ? const [] : BudgetRules.topCategoryIds(data.expenses).where(exists).toList();
    final preferred = [source?.categoryId, widget.initialCategoryId, _suggestedCategoryIds.firstOrNull];
    _categoryId = preferred.firstWhere(exists, orElse: () => data.categories.firstOrNull?.id);
    _isMonthly = source?.isMonthly ?? false;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final months = AppScope.of(context).months;
    final value = double.tryParse(_amountController.text.replaceAll(',', '.').trim());
    if (value == null || value < 0) {
      setState(() => _error = l10n.invalidAmount);
      return;
    }
    final categoryId = _categoryId;
    if (categoryId == null) {
      setState(() => _error = l10n.noCategories);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await months.saveExpense(
        id: widget.expense?.id,
        value: value,
        date: _date,
        categoryId: categoryId,
        comment: _commentController.text.trim(),
        isMonthly: _isMonthly,
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
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
    final data = AppScope.of(context).months.data!;
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(12.0));

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.expenseDetails : l10n.addExpense),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_isEditing ? l10n.save : l10n.add),
          ),
          const SizedBox(width: 8),
        ],
        bottom: _saving
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
          TextField(
            controller: _amountController,
            autofocus: !_isEditing,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            textInputAction: TextInputAction.next,
            style: theme.textTheme.titleLarge,
            decoration: InputDecoration(
              labelText: l10n.amount,
              prefixIcon: const Icon(Icons.payments_outlined),
              border: border,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            readOnly: true,
            enabled: !_saving,
            controller: TextEditingController(text: DateFormat.yMMMMEEEEd(locale).format(_date)),
            onTap: _pickDate,
            decoration: InputDecoration(
              labelText: l10n.date,
              prefixIcon: const Icon(Icons.event_outlined),
              suffixIcon: const Icon(Icons.arrow_drop_down),
              border: border,
            ),
          ),
          const SizedBox(height: 24),
          if (_suggestedCategoryIds.isNotEmpty) ...[
            Text(l10n.quickSelectCategory, style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: [
                for (final id in _suggestedCategoryIds)
                  if (data.categoryById(id) case final category?)
                    ChoiceChip(
                      label: Text(category.name),
                      selected: _categoryId == id,
                      onSelected: _saving ? null : (_) => setState(() => _categoryId = id),
                    ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          DropdownMenu<int>(
            key: ValueKey(_categoryId),
            initialSelection: _categoryId,
            enabled: !_saving,
            expandedInsets: EdgeInsets.zero,
            enableFilter: true,
            requestFocusOnTap: true,
            label: Text(l10n.category),
            leadingIcon: const Icon(Icons.category_outlined),
            inputDecorationTheme: InputDecorationTheme(border: border),
            dropdownMenuEntries: [
              for (final category in data.categories) DropdownMenuEntry(value: category.id, label: category.name),
            ],
            onSelected: (value) {
              if (value != null) setState(() => _categoryId = value);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _commentController,
            enabled: !_saving,
            textCapitalization: TextCapitalization.sentences,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l10n.comment,
              prefixIcon: const Icon(Icons.notes_outlined),
              border: border,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _isMonthly,
            onChanged: _saving ? null : (value) => setState(() => _isMonthly = value),
            secondary: const Icon(Icons.repeat_rounded),
            title: Text(l10n.recurrentExpense),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

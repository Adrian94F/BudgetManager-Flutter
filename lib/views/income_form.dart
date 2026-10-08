import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import '../api/api.dart';
import '../app/app_scope.dart';
import '../domain/domain.dart';
import '../models/models.dart';
import 'widgets/amount_field.dart';
import 'widgets/error_views.dart';
import 'widgets/quick_date_chips.dart';

/// Full-screen dialog to add or edit an income. Opened with [income] it
/// edits that income; with [template] it prefills a copy. A new income can
/// also be saved with "Save and add another", which keeps the dialog open
/// for the next one.
class IncomeFormScreen extends StatefulWidget {
  const IncomeFormScreen(
      {super.key, this.income, this.template, this.initialDate});

  final Income? income;
  final Income? template;
  final DateTime? initialDate;

  static Future<bool?> open(BuildContext context,
      {Income? income, Income? template, DateTime? initialDate}) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => IncomeFormScreen(
            income: income, template: template, initialDate: initialDate),
      ),
    );
  }

  @override
  State<IncomeFormScreen> createState() => _IncomeFormScreenState();
}

class _IncomeFormScreenState extends State<IncomeFormScreen> {
  late double _amount;
  late final TextEditingController _commentController;
  late DateTime _date;
  late bool _isSalary;
  final _amountFocus = FocusNode();

  /// Bumped for each income "Save and add another" saves, so the amount
  /// field starts over empty.
  int _entry = 0;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.income != null;

  @override
  void initState() {
    super.initState();
    final month = AppScope.of(context).months.month!;
    final source = widget.income ?? widget.template;
    _amount = source?.value ?? 0;
    _commentController = TextEditingController(text: source?.comment ?? '');
    _date = widget.income?.date ??
        widget.template?.date ??
        widget.initialDate ??
        BudgetRules.defaultEntryDate(month);
    _isSalary = source?.isSalary ?? false;
  }

  @override
  void dispose() {
    _commentController.dispose();
    _amountFocus.dispose();
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

  /// Saves the income and closes the dialog, or with [addAnother] keeps it
  /// open for the next income, as the web's "Save and add another": the
  /// date stays, the amount, the comment and the salary flag start over,
  /// and the amount field has the focus again.
  Future<void> _save({bool addAnother = false}) async {
    final l10n = AppLocalizations.of(context)!;
    final months = AppScope.of(context).months;
    final value = _amount;
    if (value <= 0) {
      setState(() => _error = l10n.invalidAmount);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await months.saveIncome(
        id: widget.income?.id,
        value: value,
        date: _date,
        comment: _commentController.text.trim(),
        isSalary: _isSalary,
      );
      if (!mounted) return;
      if (!addAnother) {
        Navigator.pop(context, true);
        return;
      }
      setState(() {
        _saving = false;
        _amount = 0;
        _commentController.clear();
        _isSalary = false;
        _entry++;
      });
      // After the rebuild: the field is enabled again only then, and a
      // disabled field cannot take the focus.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _amountFocus.requestFocus());
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(l10n.incomeAdded),
          duration: const Duration(seconds: 2),
        ));
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
    final border =
        OutlineInputBorder(borderRadius: BorderRadius.circular(12.0));

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.incomeDetails : l10n.addIncome),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_isEditing ? l10n.save : l10n.add),
          ),
          const SizedBox(width: 8),
        ],
        bottom: _saving
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2))
            : null,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            24, 16, 24, 16 + MediaQuery.paddingOf(context).bottom),
        children: [
          if (_error != null) ...[
            FormErrorBox(message: _error!),
            const SizedBox(height: 16),
          ],
          // Focus starts here: type the digits, press the action key, done.
          // Editing selects the old amount, so the first digit replaces it.
          AmountField(
            key: ValueKey(_entry),
            focusNode: _amountFocus,
            initialValue: _amount,
            onChanged: (value) => _amount = value,
            onSubmitted: _saving ? null : _save,
            label: l10n.amount,
            autofocus: true,
            selectAllOnFocus: _isEditing,
            enabled: !_saving,
            border: border,
          ),
          const SizedBox(height: 16),
          TextField(
            readOnly: true,
            enabled: !_saving,
            controller: TextEditingController(
                text: DateFormat.yMMMMEEEEd(locale).format(_date)),
            onTap: _pickDate,
            decoration: InputDecoration(
              labelText: l10n.date,
              prefixIcon: const Icon(Icons.event_outlined),
              suffixIcon: const Icon(Icons.arrow_drop_down),
              border: border,
            ),
          ),
          const SizedBox(height: 8),
          QuickDateChips(
            selected: _date,
            enabled: !_saving,
            onSelected: (day) => setState(() => _date = day),
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
            value: _isSalary,
            onChanged:
                _saving ? null : (value) => setState(() => _isSalary = value),
            secondary: const Icon(Icons.work_outline_rounded),
            title: Text(l10n.salary),
            contentPadding: EdgeInsets.zero,
          ),
          if (!_isEditing) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _saving ? null : () => _save(addAnother: true),
              icon: const Icon(Icons.playlist_add_rounded),
              label: Text(l10n.saveAndAddAnother),
            ),
          ],
        ],
      ),
    );
  }
}

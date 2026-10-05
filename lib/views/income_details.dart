import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api/api.dart';
import '../app/app_scope.dart';
import '../tools/dates.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

class IncomeDetails extends StatefulWidget {
  final Map<String, dynamic>? income;
  final int monthId;
  final DateTime? preferredDate;

  const IncomeDetails({
    super.key,
    this.income,
    required this.monthId,
    this.preferredDate,
  });

  @override
  State<StatefulWidget> createState() => _IncomeDetailsState();
}

class _IncomeDetailsState extends State<IncomeDetails> {
  late TextEditingController _valueController;
  late TextEditingController _dateController;
  late TextEditingController _commentController;
  bool _isSalary = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _valueController = TextEditingController(text: widget.income?['value']?.toString() ?? '');
    _dateController = TextEditingController(
      text: widget.income?['date'] ?? DateFormat("yyyy-MM-dd").format(widget.preferredDate ?? DateTime.now()),
    );
    _commentController = TextEditingController(text: widget.income?['comment'] ?? '');
    _isSalary = widget.income?['is_salary'] ?? false;
  }

  @override
  void dispose() {
    _valueController.dispose();
    _dateController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _saveIncome() async {
    // Basic validation
    if (_valueController.text.isEmpty || _dateController.text.isEmpty) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.pleaseFillAllFields;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = AppScope.of(context).api;
      final value = double.tryParse(_valueController.text.replaceAll(',', '.')) ?? 0.0;
      final date = Dates.parseApi(_dateController.text);
      final id = widget.income?['id'] as int?;
      if (id != null) {
        await api.updateIncome(
          id: id,
          monthId: widget.monthId,
          value: value,
          date: date,
          comment: _commentController.text,
          isSalary: _isSalary,
        );
      } else {
        await api.createIncome(
          monthId: widget.monthId,
          value: value,
          date: date,
          comment: _commentController.text,
          isSalary: _isSalary,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.isNetwork ? AppLocalizations.of(context)!.errorServerUnavailable : e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = AppLocalizations.of(context)!.errorSavingData;
        });
      }
    }
  }

  Future<void> _selectDate() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_dateController.text) ?? widget.preferredDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.income != null
            ? AppLocalizations.of(context)!.incomeDetails
            : AppLocalizations.of(context)!.addIncome),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: colorScheme.onErrorContainer, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 16),

            // Amount Field
            TextField(
              controller: _valueController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.amount,
                prefixIcon: const Icon(Icons.paid_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
              ),
            ),
            const SizedBox(height: 16),

            // Date Field
            TextField(
              controller: _dateController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.date,
                prefixIcon: const Icon(Icons.calendar_today_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
              ),
              onTap: _selectDate,
            ),
            const SizedBox(height: 16),

            // Comment Field
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.comment,
                prefixIcon: const Icon(Icons.notes_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
              ),
            ),
            const SizedBox(height: 8),

            // Salary Checkbox
            InkWell(
              onTap: () {
                setState(() => _isSalary = !_isSalary);
              },
              borderRadius: BorderRadius.circular(8.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Checkbox(
                      value: _isSalary,
                      onChanged: (bool? value) {
                        setState(() => _isSalary = value ?? false);
                      },
                    ),
                    Text(AppLocalizations.of(context)!.salary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Save/Add Button
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _saveIncome,
                icon: const Icon(Icons.save_alt_rounded),
                label: Text(
                  widget.income != null
                      ? AppLocalizations.of(context)!.save.toUpperCase()
                      : AppLocalizations.of(context)!.add.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

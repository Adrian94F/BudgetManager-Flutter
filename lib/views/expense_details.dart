import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api/api.dart';
import '../app/app_scope.dart';
import '../tools/dates.dart';
import '../tools/fading_text.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

class ExpenseDetails extends StatefulWidget {
  final Map<String, dynamic>? expense;
  final List<dynamic> categories;
  final List<int>? topCategories;
  final int monthId;
  final int? preferredCategoryId;
  final DateTime? preferredDate;

  const ExpenseDetails({
    super.key,
    this.expense,
    required this.categories,
    required this.monthId,
    this.preferredCategoryId,
    this.preferredDate,
    this.topCategories,
  });

  @override
  State<StatefulWidget> createState() => _ExpenseDetailsState();
}

class _ExpenseDetailsState extends State<ExpenseDetails> {
  late TextEditingController _valueController;
  late TextEditingController _dateController;
  late TextEditingController _commentController;
  late int _categoryId;
  bool _isRecurrent = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _valueController = TextEditingController(text: widget.expense?['value']?.toString() ?? '');
    _dateController = TextEditingController(
      text: widget.expense?['date'] ?? DateFormat("yyyy-MM-dd").format(widget.preferredDate ?? DateTime.now()),
    );
    _commentController = TextEditingController(text: widget.expense?['comment'] ?? '');
    _categoryId = widget.expense?['category'] ?? widget.preferredCategoryId ?? (widget.topCategories != null && widget.topCategories!.isNotEmpty ? widget.topCategories![0] : widget.categories.first['id']);
    _isRecurrent = widget.expense?['is_monthly'] ?? false;
  }

  @override
  void dispose() {
    _valueController.dispose();
    _dateController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _saveExpense() async {
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
      final id = widget.expense?['id'] as int?;
      if (id != null) {
        await api.updateExpense(
          id: id,
          monthId: widget.monthId,
          value: value,
          date: date,
          categoryId: _categoryId,
          comment: _commentController.text,
          isMonthly: _isRecurrent,
        );
      } else {
        await api.createExpense(
          monthId: widget.monthId,
          value: value,
          date: date,
          categoryId: _categoryId,
          comment: _commentController.text,
          isMonthly: _isRecurrent,
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
    List<dynamic> topCategoriesList = widget.categories
        .where((c) => widget.topCategories?.contains(c['id']) ?? false)
        .toList();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expense != null
            ? AppLocalizations.of(context)!.expenseDetails
            : AppLocalizations.of(context)!.addExpense),
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
            const SizedBox(height: 24),

            // Quick Select Categories
            if (topCategoriesList.isNotEmpty && widget.preferredCategoryId == null) ...[
              Text(
                AppLocalizations.of(context)!.quickSelectCategory,
                style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: topCategoriesList.map((category) {
                  bool isSelected = _categoryId == category['id'];
                  return ChoiceChip(
                    label: Text(category['name']),
                    selected: isSelected,
                    selectedColor: colorScheme.secondaryContainer,
                    onSelected: (_) {
                      setState(() {
                        _categoryId = category['id'];
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],

            // Category Dropdown
            DropdownButtonFormField<int>(
              initialValue: _categoryId,
              isExpanded: true,
              selectedItemBuilder: (BuildContext context) {
                return widget.categories.map<Widget>((item) {
                  return FadingText(item['name']);
                }).toList();
              },
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.category,
                prefixIcon: const Icon(Icons.category_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
              ),
              items: widget.categories.map((category) {
                return DropdownMenuItem<int>(
                  value: category['id'],
                  child: FadingText(category['name']),
                );
              }).toList(),
              onChanged: (int? newValue) {
                if (newValue != null) {
                  setState(() {
                    _categoryId = newValue;
                  });
                }
              },
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

            // Recurrent Expense Checkbox
            InkWell(
              onTap: () {
                setState(() => _isRecurrent = !_isRecurrent);
              },
              borderRadius: BorderRadius.circular(8.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Checkbox(
                      value: _isRecurrent,
                      onChanged: (bool? value) {
                        setState(() => _isRecurrent = value ?? false);
                      },
                    ),
                    Text(AppLocalizations.of(context)!.recurrentExpense),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Save/Add Button
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _saveExpense,
                icon: const Icon(Icons.save_alt_rounded),
                label: Text(
                  widget.expense != null
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

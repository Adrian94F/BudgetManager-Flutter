import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import '../api/api.dart';
import '../app/app_scope.dart';

class MonthDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> month;

  const MonthDetailsScreen({
    super.key,
    required this.month,
  });

  @override
  State<MonthDetailsScreen> createState() => _MonthDetailsScreenState();
}

class _MonthDetailsScreenState extends State<MonthDetailsScreen> {
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.parse(widget.month['start_date']);
    _endDate = DateTime.parse(widget.month['end_date']);
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    DateTime initial = isStartDate ? _startDate : _endDate;
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null && pickedDate != initial) {
      setState(() {
        if (isStartDate) {
          _startDate = pickedDate;
        } else {
          _endDate = pickedDate;
        }
      });
    }
  }

  Future<void> _saveMonthDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = AppScope.of(context).api;
      final id = widget.month['id'] as int?;
      if (id != null) {
        await api.updateMonth(id: id, start: _startDate, end: _endDate);
      } else {
        await api.createMonth(start: _startDate, end: _endDate);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.month['id'] != null
            ? AppLocalizations.of(context)!.monthDetails
            : AppLocalizations.of(context)!.newMonth
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
            ],
            Text(AppLocalizations.of(context)!.startDate),
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  side: BorderSide(color: Theme.of(context).dividerColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0))
              ),
              onPressed: () => _selectDate(context, true),
              child: Text(DateFormat.yMMMMd(Localizations.localeOf(context).languageCode).format(_startDate)),
            ),
            const SizedBox(height: 24),
            Text(AppLocalizations.of(context)!.endDate),
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  side: BorderSide(color: Theme.of(context).dividerColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0))
              ),
              onPressed: () => _selectDate(context, false),
              child: Text(DateFormat.yMMMMd(Localizations.localeOf(context).languageCode).format(_endDate)),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _isLoading ? null : _saveMonthDetails,
              child: _isLoading
                ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                : Text(
                  widget.month['id'] != null
                      ? AppLocalizations.of(context)!.save
                      : AppLocalizations.of(context)!.add
                )
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import '../services/auth_service.dart';
import '../tools/formatters.dart';
import 'income_details.dart';

class IncomesScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final Future<void> Function() refreshParent;

  const IncomesScreen({super.key, required this.data, required this.refreshParent});

  @override
  State<IncomesScreen> createState() => _IncomesScreenState();
}

class _IncomesScreenState extends State<IncomesScreen> {

  Widget _incomeListItemTitle(dynamic income) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          income['date'] ?? "",
          style: const TextStyle(color: Colors.grey, fontSize: 16.0),
        ),
        Text(
          Formatters.currencyFormatter.format(income['value']),
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
        )
      ],
    );
  }

  Widget? _incomeListItemSubtitle(dynamic income) {
    if ((income['comment'] == null || income['comment'].isEmpty) && income['is_salary'] == false) {
      return null;
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        if (income['is_salary'] == true)
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 4.0, right: 8.0),
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.light
                      ? Colors.grey.shade100
                      : Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Text(
                  AppLocalizations.of(context)!.salary,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        Flexible(
          child: Text(
            income['comment'],
            style: const TextStyle(fontStyle: FontStyle.italic)
          )
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final incomes = widget.data['incomes'] as List<dynamic>;
    incomes.sort((b, a) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));

    return ListView.builder(
      itemCount: incomes.length,
      padding: const EdgeInsets.only(bottom: 80),
      itemBuilder: (context, index) {
        final income = incomes[index];

        return Slidable(
            key: Key(income['id'].toString()),
            endActionPane: ActionPane(
              motion: const ScrollMotion(),
              children: [
                SlidableAction(
                  onPressed: (context) {
                    final incomeCopy = Map<String, dynamic>.from(income);
                    incomeCopy.remove('id');
                    _showIncomeDetailsDialog(incomeCopy);
                  },
                  foregroundColor: Colors.indigo,
                  backgroundColor: Theme.of(context).brightness == Brightness.light
                      ? Colors.white
                      : Colors.grey.shade900,
                  icon: Icons.copy_rounded,
                  label: AppLocalizations.of(context)!.copy,
                ),
                SlidableAction(
                  onPressed: (context) {
                    _showIncomeRemovalDialog(income);
                  },
                  foregroundColor: Colors.red,
                  backgroundColor: Theme.of(context).brightness == Brightness.light
                      ? Colors.white
                      : Colors.grey.shade900,
                  icon: Icons.delete,
                  label: AppLocalizations.of(context)!.remove,
                ),
              ],
            ),
            child: Builder(
                builder: (context) => InkWell(
                  child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0.0),
                      title: _incomeListItemTitle(income),
                      subtitle: _incomeListItemSubtitle(income)
                  ),
                  onTap: () {
                    final controller = Slidable.of(context)!;
                    final isClosed = controller.actionPaneType.value == ActionPaneType.none;
                    if (isClosed) {
                      _showIncomeDetailsDialog(income);
                    } else {
                      controller.close();
                    }
                  },
                )
            )
        );
      },
    );
  }

  void _showIncomeDetailsDialog(Map<String, dynamic>? income) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => IncomeDetails(
        income: income,
        monthId: widget.data['month']['id'],
        preferredDate: income != null ? DateTime.parse(income['date']) : DateTime.now(),
      ))
    ).then(
      (value) => setState(() {
        widget.refreshParent();
      })
    );
  }

  void _showIncomeRemovalDialog(Map<String, dynamic> income) {
    final title = AppLocalizations.of(context)!.alert;

    bool isLoading = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(title),
              content: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                    ),
                  Text(AppLocalizations.of(context)!.incomeRemoval)
                ],
              ),
              actions: isLoading
                  ? []
                  : [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppLocalizations.of(context)!.cancel),
                ),
                TextButton(
                  onPressed: () async {
                    setState(() {
                      isLoading = true;
                      errorMessage = null;
                    });

                    try {
                      final authService = AuthService();
                      final requestData = {
                        'id': income['id']
                      };

                      await authService.delete("income/", requestData);
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      widget.refreshParent();
                    } catch (e) {
                      setState(() {
                        isLoading = false;
                        errorMessage = AppLocalizations.of(context)!.errorSavingData;
                      });
                    }
                  },
                  child: Text(AppLocalizations.of(context)!.remove),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

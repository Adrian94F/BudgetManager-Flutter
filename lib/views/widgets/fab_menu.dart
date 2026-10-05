import 'package:flutter/material.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import '../../app/app_scope.dart';
import '../../domain/domain.dart';
import '../../tools/dates.dart';
import '../expense_form.dart';
import '../income_form.dart';
import '../month_details.dart';

enum FabType { full, expense, income }

/// The floating action button of a tab: a plain "add" on the expenses and
/// incomes tabs, and a menu sheet with every action on the summary tab.
class FabMenu extends StatelessWidget {
  const FabMenu({
    super.key,
    required this.onRefresh,
    this.fabType = FabType.full,
  });

  /// Reloads the month after a screen that still writes through the API
  /// directly has closed.
  final VoidCallback onRefresh;
  final FabType fabType;

  @override
  Widget build(BuildContext context) {
    final elevation = MediaQuery.of(context).orientation == Orientation.landscape ? 0.0 : 6.0;
    switch (fabType) {
      case FabType.expense:
        return buildAddExpenseFAB(context, elevation: elevation);
      case FabType.income:
        return buildAddIncomeFAB(context, elevation: elevation);
      case FabType.full:
        return buildFullFAB(context, elevation: elevation);
    }
  }

  void addExpenseFabAction(BuildContext context, {bool inModal = true}) {
    if (inModal) Navigator.pop(context);
    ExpenseFormScreen.open(context);
  }

  void addIncomeFabAction(BuildContext context, {bool inModal = true}) {
    if (inModal) Navigator.pop(context);
    IncomeFormScreen.open(context);
  }

  void monthDetailsFabAction(BuildContext context) {
    Navigator.pop(context);
    final raw = AppScope.of(context).months.rawJson!;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MonthDetailsScreen(month: raw['month'] as Map<String, dynamic>),
      ),
    ).then((_) => onRefresh());
  }

  void newMonthFabAction(BuildContext context) {
    Navigator.pop(context);
    // The proposal follows the newest month, as the web app does.
    final months = AppScope.of(context).months.data!.months;
    final range = months.isEmpty ? BudgetRules.firstMonthRange() : BudgetRules.nextMonthRange(months.first);
    final newMonth = {
      'id': null,
      'start_date': Dates.formatApi(range.start),
      'end_date': Dates.formatApi(range.end),
    };
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MonthDetailsScreen(month: newMonth),
      ),
    ).then((_) => onRefresh());
  }

  Widget buildAddExpenseButton(BuildContext context) {
    return FilledButton.icon(
      onPressed: () => addExpenseFabAction(context),
      icon: const Icon(Icons.arrow_upward_rounded),
      label: Text(AppLocalizations.of(context)!.addExpense),
    );
  }

  Widget buildAddIncomeButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => addIncomeFabAction(context),
      icon: const Icon(Icons.arrow_downward_rounded),
      label: Text(AppLocalizations.of(context)!.addIncome),
    );
  }

  Widget buildMonthDetailsButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => monthDetailsFabAction(context),
      icon: const Icon(Icons.edit_calendar),
      label: Text(AppLocalizations.of(context)!.monthDetails),
    );
  }

  Widget buildNewMonthButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => newMonthFabAction(context),
      icon: const Icon(Icons.calendar_month_rounded),
      label: Text(AppLocalizations.of(context)!.newMonth),
    );
  }

  Widget buildAddExpenseFAB(BuildContext context, {double elevation = 6}) {
    return FloatingActionButton(
      heroTag: 'add_expense_fab',
      onPressed: () => addExpenseFabAction(context, inModal: false),
      elevation: elevation,
      child: const Icon(Icons.add),
    );
  }

  Widget buildAddIncomeFAB(BuildContext context, {double elevation = 6}) {
    return FloatingActionButton(
      heroTag: 'add_income_fab',
      onPressed: () => addIncomeFabAction(context, inModal: false),
      elevation: elevation,
      child: const Icon(Icons.add),
    );
  }

  Widget buildFullFAB(BuildContext context, {double elevation = 6}) {
    return FloatingActionButton(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16.0)),
      ),
      elevation: elevation,
      onPressed: () {
        showModalBottomSheet(
          context: context,
          showDragHandle: true,
          builder: (BuildContext context) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      AppLocalizations.of(context)!.transactions,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      buildAddExpenseButton(context),
                      buildAddIncomeButton(context),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      AppLocalizations.of(context)!.month,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      buildMonthDetailsButton(context),
                      buildNewMonthButton(context),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
      child: const Icon(Icons.menu_rounded),
    );
  }
}

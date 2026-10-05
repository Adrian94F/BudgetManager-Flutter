import 'package:flutter/material.dart';

import 'package:budget_manager/l10n/app_localizations.dart';
import '../../domain/domain.dart';
import '../../models/models.dart';
import '../../tools/dates.dart';
import '../month_details.dart';
import '../expense_details.dart';
import '../income_details.dart';

enum FabType { full, expense, income }

class FabMenu extends StatelessWidget {
  final Map<String, dynamic> loadedData;
  final VoidCallback onRefresh;
  final FabType fabType;

  const FabMenu({
    super.key,
    required this.loadedData,
    required this.onRefresh,
    this.fabType = FabType.full,
  });

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
    if (inModal) {
      Navigator.pop(context);
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExpenseDetails(
          categories: loadedData['categories'],
          monthId: loadedData['month']['id'],
          topCategories: getTopNCategories(loadedData['expenses'], 5),
        ),
      ),
    ).then((_) => onRefresh());
  }

  void addIncomeFabAction(BuildContext context, {bool inModal = true}) {
    if (inModal) {
      Navigator.pop(context);
    }
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => IncomeDetails(
              income: null,
              monthId: loadedData['month']['id'],
              preferredDate: DateTime.now(),
            )))
        .then((_) => onRefresh());
  }

  void monthDetailsFabAction(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MonthDetailsScreen(
          month: loadedData['month'],
        ),
      ),
    ).then((_) => onRefresh());
  }

  void newMonthFabAction(BuildContext context) {
    Navigator.pop(context);
    // The proposal follows the newest month, as the web app does.
    final months = loadedData['months'] as List<dynamic>;
    final range = months.isEmpty
        ? BudgetRules.firstMonthRange()
        : BudgetRules.nextMonthRange(Month.fromJson(months.first as Map<String, dynamic>));
    final newMonth = {
      'id': null,
      'start_date': Dates.formatApi(range.start),
      'end_date': Dates.formatApi(range.end),
    };
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MonthDetailsScreen(
          month: newMonth,
        ),
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
      onPressed: () {
        addExpenseFabAction(context, inModal: false);
      },
      elevation: elevation,
      child: const Icon(Icons.add),
    );
  }

  Widget buildAddIncomeFAB(BuildContext context, {double elevation = 6}) {
    return FloatingActionButton(
      heroTag: 'add_income_fab',
      onPressed: () {
        addIncomeFabAction(context, inModal: false);
      },
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
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (BuildContext context) {
            final isVertical =
                MediaQuery.of(context).orientation == Orientation.portrait;
            return GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                color: Colors.transparent,
                child: DraggableScrollableSheet(
                  initialChildSize: isVertical ? 0.3 : 0.6,
                  minChildSize: 0.3,
                  maxChildSize: isVertical ? 0.4 : 0.6,
                  builder: (_, scrollController) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).canvasColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16.0),
                          topRight: Radius.circular(16.0),
                        ),
                      ),
                      child: SingleChildScrollView(
                        controller: scrollController,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Center(
                                child: Container(
                                  margin:
                                  const EdgeInsets.only(bottom: 16.0),
                                  height: 5.0,
                                  width: 40.0,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius:
                                    BorderRadius.circular(10.0),
                                  ),
                                ),
                              ),
                              Padding(
                                padding:
                                const EdgeInsets.only(bottom: 8.0),
                                child: Text(
                                  AppLocalizations.of(context)!
                                      .transactions,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ),
                              Row(
                                children: [
                                  buildAddExpenseButton(context),
                                  const SizedBox(width: 16),
                                  buildAddIncomeButton(context),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Padding(
                                padding:
                                const EdgeInsets.only(bottom: 8.0),
                                child: Text(
                                  AppLocalizations.of(context)!.month,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ),
                              Row(
                                children: [
                                  buildMonthDetailsButton(context),
                                  const SizedBox(width: 16),
                                  buildNewMonthButton(context),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
      child: const Icon(Icons.menu_rounded),
    );
  }

  static List<int> getTopNCategories(
      List<dynamic> expenses, int nOfCategories) {
    Map<int, int> categoryCounts = {};
    for (var expense in expenses) {
      if (!expense['is_monthly']) {
        int categoryId = expense['category'];
        categoryCounts[categoryId] = (categoryCounts[categoryId] ?? 0) + 1;
      }
    }
    List<MapEntry<int, int>> categoryCountsList =
    categoryCounts.entries.toList();
    categoryCountsList.sort((a, b) => b.value.compareTo(a.value));
    return categoryCountsList
        .take(nOfCategories)
        .map((entry) => entry.key)
        .toList();
  }
}

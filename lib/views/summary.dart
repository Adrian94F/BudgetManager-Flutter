import 'package:budget_manager/views/widgets/info_card.dart';
import 'package:flutter/material.dart';
import '../tools/formatters.dart';
import 'package:budget_manager/l10n/app_localizations.dart';
import '../views/widgets/month_burndown_chart.dart';
import '../views/chart_view.dart';

class Summary {
  final Map<String, dynamic> data;

  late DateTime startDate;
  late DateTime endDate;
  late double salarySum;
  late double otherIncomesSum;
  late double incomesSum;
  late double monthlyExpensesSum;
  late double regularExpensesSum;
  late double dailyExpensesBeforeTodaySum;
  late double todayExpensesSum;
  late double expensesSum;
  late double balance;

  Summary({required this.data}) {
    _calculate();
  }

  void _calculate() {
    startDate = DateTime.parse(data['month']['start_date']);
    endDate = DateTime.parse(data['month']['end_date']);

    var incomes = data['incomes'] as List<dynamic>;
    salarySum = 0.0;
    otherIncomesSum = 0.0;
    for (var income in incomes) {
      var value = income['value'];
      if (income['is_salary'] == true) {
        salarySum += value;
      } else {
        otherIncomesSum += value;
      }
    }
    incomesSum = salarySum + otherIncomesSum;

    var expenses = data['expenses'] as List<dynamic>;
    monthlyExpensesSum = 0.0;
    regularExpensesSum = 0.0;
    dailyExpensesBeforeTodaySum = 0.0;
    todayExpensesSum = 0.0;
    var today = DateTime.parse(
        "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}");
    for (var expense in expenses) {
      var value = expense['value'];
      if (expense['is_monthly'] == true) {
        monthlyExpensesSum += value;
      } else {
        regularExpensesSum += value;
        var expDate = DateTime.parse(expense['date']);
        if (expDate.isBefore(today)) {
          dailyExpensesBeforeTodaySum += value;
        }
        if (expDate.year == today.year &&
            expDate.month == today.month &&
            expDate.day == today.day) {
          todayExpensesSum += value;
        }
      }
    }
    expensesSum = monthlyExpensesSum + regularExpensesSum;
    balance = incomesSum - expensesSum;
  }
}

class SummaryScreen extends StatefulWidget {
  final Map<String, dynamic> data;

  const SummaryScreen({super.key, required this.data});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  @override
  Widget build(BuildContext context) {
    final summary = Summary(data: widget.data);
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.landscape) {
          return Row(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                  children: [
                    _buildBurndownChartCard(context, orientation: orientation),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(right: 32, top: 8.0, bottom: 8.0),
                  children: [
                    _buildBalanceCard(context, summary),
                    const SizedBox(height: 16),
                    _buildExpensesCard(
                        context,
                        summary.regularExpensesSum,
                        summary.monthlyExpensesSum,
                        summary.expensesSum),
                    const SizedBox(height: 16),
                    _buildIncomeCard(
                        context,
                        summary.salarySum,
                        summary.otherIncomesSum,
                        summary.incomesSum),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          );
        } else {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            children: [
              _buildBurndownChartCard(context, orientation: orientation),
              const SizedBox(height: 16),
              _buildBalanceCard(context, summary),
              const SizedBox(height: 16),
              _buildExpensesCard(
                  context,
                  summary.regularExpensesSum,
                  summary.monthlyExpensesSum,
                  summary.expensesSum),
              const SizedBox(height: 16),
              _buildIncomeCard(
                  context,
                  summary.salarySum,
                  summary.otherIncomesSum,
                  summary.incomesSum),
              const SizedBox(height: 70),
            ],
          );
        }
      },
    );
  }

  Widget _buildIncomeCard(BuildContext context, double salarySum, double otherIncomesSum, double total) {
    String title = AppLocalizations.of(context)!.incomes;
    double amount = total;
    List<Widget> children = [];

    if (salarySum > 0 && otherIncomesSum == 0) {
      title = AppLocalizations.of(context)!.salary;
      amount = salarySum;
    } else if (salarySum == 0 && otherIncomesSum > 0) {
      title = AppLocalizations.of(context)!.otherIncome;
      amount = otherIncomesSum;
    } else if (salarySum > 0 && otherIncomesSum > 0) {
      children.add(_buildDetailRow(AppLocalizations.of(context)!.salary, salarySum));
      children.add(_buildDetailRow(AppLocalizations.of(context)!.otherIncome, otherIncomesSum));
    }

    return InfoCard(
      icon: Icons.arrow_upward_rounded,
      title: title,
      amount: amount,
      isOutlined: true,
      children: children
    );
  }

  Widget _buildExpensesCard(BuildContext context, double regularSum, double monthlySum, double total) {
    String title = AppLocalizations.of(context)!.expenses;
    double amount = total;
    List<Widget> children = [];

    if (regularSum > 0 && monthlySum == 0) {
      title = AppLocalizations.of(context)!.dailyExpenses;
      amount = regularSum;
    } else if (regularSum == 0 && monthlySum > 0) {
      title = AppLocalizations.of(context)!.recurrentExpenses;
      amount = monthlySum;
    } else if (regularSum > 0 && monthlySum > 0) {
      children.add(_buildDetailRow(AppLocalizations.of(context)!.dailyExpenses, regularSum));
      children.add(_buildDetailRow(AppLocalizations.of(context)!.recurrentExpenses, monthlySum));
    }

    return InfoCard(
      icon: Icons.arrow_downward_rounded,
      title: title,
      amount: amount,
      isOutlined: true,
      children: children
    );
  }

  Widget _buildBurndownChartCard(BuildContext context, {Orientation orientation = Orientation.portrait}) {
    final startDate = DateTime.parse(widget.data['month']['start_date']);
    final endDate = DateTime.parse(widget.data['month']['end_date']);
    final incomes = widget.data['incomes'] as List<dynamic>;
    final expenses = widget.data['expenses'] as List<dynamic>;
    final isVertical = orientation == Orientation.portrait;

    return SizedBox(
      height: isVertical ? 200 : 300,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChartViewScreen(data: widget.data),
            ),
          );
        },
        child: AbsorbPointer(
          child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: MonthBurndownChart(
                incomes: incomes,
                expenses: expenses,
                startDate: startDate,
                endDate: endDate,
                isSimplified: true
              ),
            ),
          ),
      )
    );
  }

  Widget _buildBalanceCard(BuildContext context, Summary summary) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    final balance = summary.balance;
    final daysLeft = summary.endDate.difference(DateTime.now()).inDays + 1;
    final balanceBeforeToday = summary.incomesSum - summary.monthlyExpensesSum - summary.dailyExpensesBeforeTodaySum;
    final maxDailyExpenses = (daysLeft > 0) ? balanceBeforeToday / daysLeft : 0.0;
    final todayExpensesPercent = (maxDailyExpenses > 0) ? (summary.todayExpensesSum / maxDailyExpenses * 100) : 0.0;
    String spentTodayValue = Formatters.currencyFormatter.format(summary.todayExpensesSum);
    if (balanceBeforeToday > 0 && maxDailyExpenses > 0) {
      spentTodayValue += " (${todayExpensesPercent.round()}%)";
    }

    final children = <Widget>[];
    final isCurrent = DateTime.now().isAfter(summary.startDate) &&
        DateTime.now().isBefore(summary.endDate.add(const Duration(days: 1)));
    if (isCurrent) {
      if (balanceBeforeToday > 0) {
        children.add(_buildDetailRow(l10n.maxDailyExpense, maxDailyExpenses,
            valueColor: colorScheme.onPrimaryContainer));
      }
      children.add(_buildDetailRow(l10n.spentToday, spentTodayValue,
          isCurrency: false, valueColor: colorScheme.onPrimaryContainer));
      children.add(_buildDetailRow(l10n.daysLeft, daysLeft.toString(),
          isCurrency: false, valueColor: colorScheme.onPrimaryContainer));
    }

    return InfoCard(
        title: AppLocalizations.of(context)!.balance.toUpperCase(),
        amount: balance,
        isOutlined: false,
        color: balance >= 0
            ? isCurrent
              ? colorScheme.primaryContainer
              : brightness == Brightness.light
                ? Colors.green.shade100
                : Colors.green.shade900
            : colorScheme.errorContainer,
        textColor: balance >= 0
            ? isCurrent
              ? colorScheme.onPrimaryContainer
              : brightness == Brightness.light
                ? Colors.green.shade800
                : Colors.green.shade100
            : colorScheme.onErrorContainer,
        children: children,
    );
  }

  Widget _buildDetailRow(String name, dynamic value, {bool isCurrency = true, Color? valueColor}) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
      title: Text(name),
      trailing: Text(
        isCurrency ? Formatters.currencyFormatter.format(value) : value.toString(),
        style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          color: valueColor
        ),
      ),
    );
  }
}

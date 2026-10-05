import 'package:flutter/material.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import '../app/app_scope.dart';
import '../domain/domain.dart';
import '../models/models.dart';
import '../tools/formatters.dart';
import 'chart_view.dart';
import 'widgets/info_card.dart';
import 'widgets/month_burndown_chart.dart';

/// The month's figures: burndown, balance, expenses and incomes. The numbers
/// come from [MonthSummary], which applies the same rules as the server and
/// the iOS app.
class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key, this.onShowExpenses, this.onShowIncomes});

  final VoidCallback? onShowExpenses;
  final VoidCallback? onShowIncomes;

  @override
  Widget build(BuildContext context) {
    final months = AppScope.of(context).months;
    final data = months.data;
    final raw = months.rawJson;
    final month = data?.month;
    if (data == null || raw == null || month == null) return const SizedBox.shrink();
    final summary = months.summary;

    return OrientationBuilder(
      builder: (context, orientation) {
        final chart = _buildChartCard(context, raw, month, orientation);
        final cards = [
          _BalanceCard(summary: summary),
          const SizedBox(height: 16),
          _buildExpensesCard(context, summary),
          const SizedBox(height: 16),
          _buildIncomesCard(context, summary),
        ];
        if (orientation == Orientation.landscape) {
          return Row(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                  children: [chart],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(right: 32, top: 8.0, bottom: 8.0),
                  children: [...cards, const SizedBox(height: 16)],
                ),
              ),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          children: [chart, const SizedBox(height: 16), ...cards, const SizedBox(height: 70)],
        );
      },
    );
  }

  Widget _buildChartCard(BuildContext context, Map<String, dynamic> raw, Month month, Orientation orientation) {
    final isVertical = orientation == Orientation.portrait;
    return SizedBox(
      height: isVertical ? 200 : 300,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ChartViewScreen(data: raw)),
        ),
        child: AbsorbPointer(
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: MonthBurndownChart(
              incomes: raw['incomes'] as List<dynamic>,
              expenses: raw['expenses'] as List<dynamic>,
              startDate: month.startDate,
              endDate: month.endDate,
              isSimplified: true,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpensesCard(BuildContext context, MonthSummary summary) {
    final l10n = AppLocalizations.of(context)!;
    return InfoCard(
      icon: Icons.arrow_downward_rounded,
      title: l10n.expenses,
      amount: summary.allExpenses,
      isOutlined: true,
      onTap: onShowExpenses,
      children: summary.allExpenses == 0
          ? const []
          : [
              detailRow(l10n.dailyExpenses, Formatters.currencyFormatter.format(summary.dailyExpenses)),
              detailRow(l10n.recurrentExpenses, Formatters.currencyFormatter.format(summary.monthlyExpenses)),
            ],
    );
  }

  Widget _buildIncomesCard(BuildContext context, MonthSummary summary) {
    final l10n = AppLocalizations.of(context)!;
    return InfoCard(
      icon: Icons.arrow_upward_rounded,
      title: l10n.incomes,
      amount: summary.allIncomes,
      isOutlined: true,
      onTap: onShowIncomes,
      children: summary.allIncomes == 0
          ? const []
          : [
              detailRow(l10n.forDailyExpenses, Formatters.currencyFormatter.format(summary.incomesForDailyExpenses)),
              detailRow(l10n.salary, Formatters.currencyFormatter.format(summary.salaries)),
              detailRow(l10n.otherIncome, Formatters.currencyFormatter.format(summary.otherIncomes)),
            ],
    );
  }

  static Widget detailRow(String name, String value, {Color? valueColor}) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
      title: Text(name),
      trailing: Text(
        value,
        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: valueColor),
      ),
    );
  }
}

/// Balance after planned savings, with the savings and the actual balance
/// underneath when savings apply, and the day figures for the current month.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final money = Formatters.currencyFormatter.format;

    final Color background;
    final Color foreground;
    if (summary.balance < 0) {
      background = colorScheme.errorContainer;
      foreground = colorScheme.onErrorContainer;
    } else if (summary.isActual) {
      background = colorScheme.primaryContainer;
      foreground = colorScheme.onPrimaryContainer;
    } else {
      background = isLight ? Colors.green.shade100 : Colors.green.shade900;
      foreground = isLight ? Colors.green.shade800 : Colors.green.shade100;
    }

    final rows = <Widget>[];
    if (summary.plannedSavings > 0) {
      rows.add(SummaryScreen.detailRow(l10n.plannedSavings, money(summary.plannedSavings), valueColor: foreground));
      rows.add(SummaryScreen.detailRow(l10n.actualBalance, money(summary.actualBalance), valueColor: foreground));
    }
    if (summary.isActual) {
      final maxDaily = summary.maxDaily;
      if (maxDaily != null && maxDaily > 0) {
        rows.add(SummaryScreen.detailRow(l10n.maxDailyExpense, money(maxDaily), valueColor: foreground));
      }
      var spentToday = money(summary.todaySpendings);
      final percent = summary.todayPercent;
      if (percent != null) spentToday += ' (${percent.round()}%)';
      rows.add(SummaryScreen.detailRow(l10n.spentToday, spentToday, valueColor: foreground));
      rows.add(SummaryScreen.detailRow(l10n.daysLeft, '${summary.daysLeft}', valueColor: foreground));
    }

    return InfoCard(
      title: l10n.balance,
      amount: summary.balance,
      color: background,
      textColor: foreground,
      children: rows,
    );
  }
}

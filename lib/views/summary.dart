import 'package:flutter/material.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import '../app/app_scope.dart';
import '../app/theme.dart';
import '../domain/domain.dart';
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
    if (months.month == null) return const SizedBox.shrink();
    final summary = months.summary;

    return OrientationBuilder(
      builder: (context, orientation) {
        final chart = _buildChartCard(context, months.burndown, orientation);
        final cards = [
          _HeroBalance(summary: summary),
          const SizedBox(height: 16),
          _buildExpensesCard(context, summary),
          const SizedBox(height: 16),
          _buildIncomesCard(context, summary),
        ];
        if (orientation == Orientation.landscape) {
          // Two independent lists: neither takes the shell's primary controller.
          return Row(
            children: [
              Expanded(
                child: ListView(
                  primary: false,
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                  children: [chart],
                ),
              ),
              Expanded(
                child: ListView(
                  primary: false,
                  padding: const EdgeInsets.only(right: 32, top: 8.0, bottom: 8.0),
                  children: [...cards, const SizedBox(height: 16)],
                ),
              ),
            ],
          );
        }
        return ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 78 + MediaQuery.paddingOf(context).bottom),
          children: [chart, const SizedBox(height: 16), ...cards],
        );
      },
    );
  }

  Widget _buildChartCard(BuildContext context, BurndownSeries series, Orientation orientation) {
    final isVertical = orientation == Orientation.portrait;
    return SizedBox(
      height: isVertical ? 200 : 300,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ChartViewScreen()),
        ),
        child: AbsorbPointer(
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: MonthBurndownChart(series: series, isSimplified: true),
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
              detailRow(l10n.dailyExpenses, Formatters.moneyOf(context, summary.dailyExpenses)),
              detailRow(l10n.recurrentExpenses, Formatters.moneyOf(context, summary.monthlyExpenses)),
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
              detailRow(l10n.forDailyExpenses, Formatters.moneyOf(context, summary.incomesForDailyExpenses)),
              detailRow(l10n.salary, Formatters.moneyOf(context, summary.salaries)),
              detailRow(l10n.otherIncome, Formatters.moneyOf(context, summary.otherIncomes)),
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

/// The headline: balance after planned savings in display type, a status
/// pill (on track, over budget, or saved for a closed month), the savings
/// detail when it applies, and for the current month a meter of today's
/// spending against the daily allowance.
class _HeroBalance extends StatelessWidget {
  const _HeroBalance({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final budgetColors = BudgetColors.of(context);
    String money(double amount) => Formatters.moneyOf(context, amount);

    final (background, foreground, statusIcon, statusText) = switch ((summary.balance < 0, summary.isActual)) {
      (true, _) => (scheme.errorContainer, scheme.onErrorContainer, Icons.trending_down_rounded, l10n.statusOverBudget),
      (false, true) => (scheme.primaryContainer, scheme.onPrimaryContainer, Icons.check_circle_outline_rounded, l10n.statusOnTrack),
      (false, false) => (budgetColors.successContainer, budgetColors.onSuccessContainer, Icons.savings_outlined, l10n.statusSaved),
    };
    final secondary = foreground.withValues(alpha: 0.8);

    final maxDaily = summary.maxDaily;
    final hasAllowance = summary.isActual && maxDaily != null && maxDaily > 0;
    final overDaily = hasAllowance && summary.todaySpendings > maxDaily;
    final progress = hasAllowance ? (summary.todaySpendings / maxDaily).clamp(0.0, 1.0) : 0.0;
    var spentToday = money(summary.todaySpendings);
    if (summary.todayPercent != null) spentToday += ' (${summary.todayPercent!.round()}%)';

    return Card.filled(
      color: background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.balance.toUpperCase(),
                    style: theme.textTheme.labelLarge?.copyWith(color: foreground, letterSpacing: 0.8),
                  ),
                ),
                _StatusPill(icon: statusIcon, text: statusText, color: foreground),
              ],
            ),
            const SizedBox(height: 6),
            // A changed balance fades and rises in, instead of just snapping.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.centerLeft,
                children: [...previous, if (current != null) current],
              ),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.2), end: Offset.zero).animate(animation),
                  child: child,
                ),
              ),
              child: Text(
                money(summary.balance),
                key: ValueKey(summary.balance),
                style: theme.textTheme.displaySmall?.copyWith(color: foreground, fontWeight: FontWeight.w700, letterSpacing: -0.5),
              ),
            ),
            if (summary.plannedSavings > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${l10n.actualBalance} ${money(summary.actualBalance)} · ${l10n.plannedSavings} ${money(summary.plannedSavings)}',
                style: theme.textTheme.bodySmall?.copyWith(color: secondary),
              ),
            ],
            if (summary.isActual) ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: Text(l10n.spentToday, style: theme.textTheme.labelLarge?.copyWith(color: foreground))),
                  Text(spentToday, style: theme.textTheme.labelLarge?.copyWith(color: foreground, fontWeight: FontWeight.w600)),
                ],
              ),
              if (hasAllowance) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  color: overDaily ? scheme.error : scheme.primary,
                  backgroundColor: foreground.withValues(alpha: 0.12),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                [
                  if (hasAllowance) '${l10n.maxDaily} ${money(maxDaily)}',
                  l10n.daysLeftCount(summary.daysLeft),
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(color: secondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(text, style: theme.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

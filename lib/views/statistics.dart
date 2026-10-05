import 'dart:async';

import 'package:flutter/material.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import '../app/app_scope.dart';
import '../domain/domain.dart';
import '../models/models.dart';
import '../state/month_controller.dart';
import 'category_expenses.dart';
import 'widgets/cash_flow_chart.dart';
import 'widgets/error_views.dart';
import 'widgets/history_chart.dart';
import 'widgets/month_burndown_chart.dart';

/// The statistics of a month, and of all of them.
enum StatisticsView { burndown, cashFlow, history }

/// The month's statistics, full screen: the burndown with its legend, the
/// cash flow, or the month-over-month history, chosen with the segmented
/// switch at the top (the Expenses tab picks its list or table the same
/// way). Opened from the chart card on the Summary, so it starts on the
/// burndown. A category tapped in the cash flow opens its expenses above
/// this screen, so back returns to the diagram.
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  var _view = StatisticsView.burndown;

  void _showCategory(Category category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryExpensesScreen(category: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final services = AppScope.of(context);
    final months = services.months;
    final settings = services.settings;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.statistics)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Three labelled segments with icons want more room than a
                  // phone in portrait has; there the labels go alone.
                  final withIcons = constraints.maxWidth >= 480;
                  Icon? icon(IconData data) => withIcons ? Icon(data) : null;
                  return SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<StatisticsView>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: StatisticsView.burndown,
                          icon: icon(Icons.show_chart_rounded),
                          label: Text(l10n.burndown),
                        ),
                        ButtonSegment(
                          value: StatisticsView.cashFlow,
                          icon: icon(Icons.account_tree_outlined),
                          label: Text(l10n.cashFlow),
                        ),
                        ButtonSegment(
                          value: StatisticsView.history,
                          icon: icon(Icons.bar_chart_rounded),
                          label: Text(l10n.history),
                        ),
                      ],
                      selected: {_view},
                      onSelectionChanged: (selection) =>
                          setState(() => _view = selection.first),
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: Listenable.merge([months, settings]),
                builder: (context, _) => AnimatedSwitcher(
                  duration: Durations.short4,
                  child: KeyedSubtree(
                    key: ValueKey(_view),
                    child: switch (_view) {
                      StatisticsView.burndown => _BurndownView(
                          series: months.burndown,
                        ),
                      StatisticsView.cashFlow => _CashFlowView(
                          flow: months.cashFlow,
                          includeRecurring: settings.includeRecurringInFlow,
                          onIncludeRecurringChanged:
                              settings.setIncludeRecurringInFlow,
                          onCategoryTap: _showCategory,
                        ),
                      StatisticsView.history => _HistoryView(months: months),
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The full burndown with the daily and recurring expense bars and a legend.
class _BurndownView extends StatelessWidget {
  const _BurndownView({required this.series});

  final BurndownSeries series;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(child: MonthBurndownChart(series: series)),
          const SizedBox(height: 12),
          BurndownLegend(
            series: series,
            labels: (
              balance: l10n.balance,
              plan: l10n.plannedLine,
              daily: l10n.dailyExpenses,
              recurring: l10n.recurrentExpenses,
            ),
          ),
        ],
      ),
    );
  }
}

/// The cash flow diagram with, when the month has recurring expenses, the
/// switch that takes them in or out of the picture.
class _CashFlowView extends StatelessWidget {
  const _CashFlowView({
    required this.flow,
    required this.includeRecurring,
    required this.onIncludeRecurringChanged,
    required this.onCategoryTap,
  });

  final CashFlow flow;
  final bool includeRecurring;
  final ValueChanged<bool> onIncludeRecurringChanged;
  final ValueChanged<Category> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (flow.isEmpty) {
      return _EmptyState(
        icon: Icons.account_tree_outlined,
        title: l10n.noFlowData,
        hint: l10n.noFlowDataHint,
      );
    }
    final diagram = flow.diagram(includeRecurring: includeRecurring);
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            // A pinch stretches the expenses column, so more labels fit, and
            // one finger scrolls it; incomes and the budget stay put.
            child: CashFlowChart(
              diagram: diagram,
              includeRecurring: includeRecurring,
              onCategoryTap: onCategoryTap,
            ),
          ),
        ),
        if (flow.recurringExpenses > 0)
          // Right-aligned, by the switch, so the text reads with its control
          // however wide the window; the text toggles it too.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: MergeSemantics(
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => onIncludeRecurringChanged(!includeRecurring),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            l10n.includeRecurringExpenses,
                            style: Theme.of(context).textTheme.bodyLarge,
                            textAlign: TextAlign.end,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: includeRecurring,
                          onChanged: onIncludeRecurringChanged,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The month-over-month history: fetched when first shown (and again after
/// the month's data changed), then the chart with its legend.
class _HistoryView extends StatefulWidget {
  const _HistoryView({required this.months});

  final MonthController months;

  @override
  State<_HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<_HistoryView> {
  @override
  void initState() {
    super.initState();
    widget.months.addListener(_ensureLoaded);
    _ensureLoaded();
  }

  @override
  void didUpdateWidget(_HistoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.months != widget.months) {
      oldWidget.months.removeListener(_ensureLoaded);
      widget.months.addListener(_ensureLoaded);
      _ensureLoaded();
    }
  }

  @override
  void dispose() {
    widget.months.removeListener(_ensureLoaded);
    super.dispose();
  }

  /// Asks for the history whenever there is none and nothing is on its way,
  /// outside the controller's own notification.
  void _ensureLoaded() {
    final months = widget.months;
    if (months.history == null &&
        !months.isLoadingHistory &&
        months.historyError == null) {
      scheduleMicrotask(months.loadHistory);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final months = widget.months;
    final history = months.history;
    if (history == null) {
      final error = months.historyError;
      if (error != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ErrorBanner(error: error, onRetry: months.loadHistory),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    if (history.isEmpty) {
      return _EmptyState(icon: Icons.bar_chart_rounded, title: l10n.noHistory);
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(child: HistoryChart(history: history)),
          const SizedBox(height: 12),
          const HistoryLegend(),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, this.hint});

  final IconData icon;
  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (hint != null) ...[
              const SizedBox(height: 4),
              Text(
                hint!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

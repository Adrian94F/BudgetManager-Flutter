import 'package:flutter/material.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import '../app/app_scope.dart';
import '../domain/domain.dart';
import '../models/models.dart';
import 'widgets/cash_flow_chart.dart';
import 'widgets/month_burndown_chart.dart';
import 'widgets/vertical_zoom_view.dart';

/// The two statistics of a month.
enum StatisticsView { burndown, cashFlow }

/// The month's statistics, full screen: the burndown with its legend, or the
/// cash flow, chosen with the segmented switch at the top (the Expenses tab
/// picks its list or table the same way). Opened from the chart card on the
/// Summary, so it starts on the burndown.
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key, this.onShowCategory});

  /// Called with a category tapped in the cash flow, once this screen has
  /// closed, so the shell can show that category's expenses.
  final ValueChanged<Category>? onShowCategory;

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  var _view = StatisticsView.burndown;

  void _showCategory(Category category) {
    Navigator.pop(context);
    widget.onShowCategory?.call(category);
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
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<StatisticsView>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: StatisticsView.burndown,
                      icon: const Icon(Icons.show_chart_rounded),
                      label: Text(l10n.burndown),
                    ),
                    ButtonSegment(
                      value: StatisticsView.cashFlow,
                      icon: const Icon(Icons.account_tree_outlined),
                      label: Text(l10n.cashFlow),
                    ),
                  ],
                  selected: {_view},
                  onSelectionChanged: (selection) =>
                      setState(() => _view = selection.first),
                ),
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
    if (flow.isEmpty) return const _EmptyFlow();
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            // A pinch stretches the diagram upwards, so more labels fit, and one
            // finger scrolls it; the two variants cross-fade rather than snap.
            child: VerticalZoomView(
              child: AnimatedSwitcher(
                duration: Durations.medium1,
                child: CashFlowChart(
                  key: ValueKey(includeRecurring),
                  diagram: flow.diagram(includeRecurring: includeRecurring),
                  includeRecurring: includeRecurring,
                  onCategoryTap: onCategoryTap,
                ),
              ),
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

class _EmptyFlow extends StatelessWidget {
  const _EmptyFlow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_tree_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.noFlowData,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.noFlowDataHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

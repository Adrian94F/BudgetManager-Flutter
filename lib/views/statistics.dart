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
    final services = AppScope.of(context);
    final months = services.months;
    final settings = services.settings;
    return ListenableBuilder(
      listenable: Listenable.merge([months, settings]),
      builder: (context, _) {
        final flow = months.cashFlow;
        final recurringToggle =
            _view == StatisticsView.cashFlow && flow.recurringExpenses > 0;
        // The toggle fits the bar, with its text, only on a wide window,
        // centred between the back arrow and the view switch; a phone in
        // portrait shows it in a row above the diagram instead.
        final toggleInBar =
            recurringToggle && MediaQuery.sizeOf(context).width >= 700;
        return Scaffold(
          appBar: AppBar(
            // The bar holds the controls, so the charts get the height: the
            // view switch at the end and, on the cash flow of a wide window,
            // the recurring expenses toggle in the middle.
            centerTitle: true,
            title: toggleInBar
                ? _RecurringToggle(
                    value: settings.includeRecurringInFlow,
                    onChanged: settings.setIncludeRecurringInFlow,
                    alignment: AlignmentDirectional.center,
                  )
                : null,
            actions: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: _ViewSwitch(
                  view: _view,
                  onChanged: (view) => setState(() => _view = view),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: AnimatedSwitcher(
              duration: Durations.short4,
              child: KeyedSubtree(
                key: ValueKey(_view),
                child: switch (_view) {
                  StatisticsView.burndown => _BurndownView(
                      series: months.burndown,
                    ),
                  StatisticsView.cashFlow => _CashFlowView(
                      flow: flow,
                      includeRecurring: settings.includeRecurringInFlow,
                      onIncludeRecurringChanged: recurringToggle && !toggleInBar
                          ? settings.setIncludeRecurringInFlow
                          : null,
                      onCategoryTap: _showCategory,
                    ),
                  StatisticsView.history => _HistoryView(months: months),
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The segmented switch between the views, sized to the window: a phone in
/// portrait has room for the icons alone (named by their tooltips), a wider
/// window for the labels, a wide one for both.
class _ViewSwitch extends StatelessWidget {
  const _ViewSwitch({required this.view, required this.onChanged});

  final StatisticsView view;
  final ValueChanged<StatisticsView> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final width = MediaQuery.sizeOf(context).width;
    final withLabels = width >= 480;
    // Icons next to the labels only where the bar can also fit the
    // recurring toggle with its text beside them.
    final withIcons = !withLabels || width >= 900;
    ButtonSegment<StatisticsView> segment(
      StatisticsView value,
      IconData icon,
      String label,
    ) =>
        ButtonSegment(
          value: value,
          icon: withIcons ? Icon(icon) : null,
          label: withLabels ? Text(label) : null,
          tooltip: withLabels ? null : label,
        );
    return SegmentedButton<StatisticsView>(
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: [
        segment(
          StatisticsView.burndown,
          Icons.show_chart_rounded,
          l10n.burndown,
        ),
        segment(
          StatisticsView.cashFlow,
          Icons.account_tree_outlined,
          l10n.cashFlow,
        ),
        segment(StatisticsView.history, Icons.bar_chart_rounded, l10n.history),
      ],
      selected: {view},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

/// Whether the cash flow has the recurring expenses in, as a control in the
/// bar: its text with a switch where the bar has the room, otherwise a
/// toggle icon button named by its tooltip.
class _RecurringToggle extends StatelessWidget {
  const _RecurringToggle({
    required this.value,
    required this.onChanged,
    required this.alignment,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 260) {
          return Align(
            alignment: alignment,
            child: IconButton(
              isSelected: value,
              icon: const Icon(Icons.event_repeat_outlined),
              selectedIcon: const Icon(Icons.event_repeat),
              tooltip: l10n.includeRecurringExpenses,
              onPressed: () => onChanged(!value),
            ),
          );
        }
        return Align(
          alignment: alignment,
          child: MergeSemantics(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onChanged(!value),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        l10n.includeRecurringExpenses,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Switch(value: value, onChanged: onChanged),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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

/// The cash flow diagram, with the recurring expenses toggle in a row above
/// it when the bar has no room for it ([onIncludeRecurringChanged] set).
class _CashFlowView extends StatelessWidget {
  const _CashFlowView({
    required this.flow,
    required this.includeRecurring,
    required this.onIncludeRecurringChanged,
    required this.onCategoryTap,
  });

  final CashFlow flow;
  final bool includeRecurring;

  /// Shows the toggle above the diagram; null when the bar has it.
  final ValueChanged<bool>? onIncludeRecurringChanged;
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
    final chart = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      // A pinch stretches the expenses column, so more labels fit, and one
      // finger scrolls it; incomes and the budget stay put.
      child: CashFlowChart(
        diagram: flow.diagram(includeRecurring: includeRecurring),
        includeRecurring: includeRecurring,
        onCategoryTap: onCategoryTap,
      ),
    );
    final onChanged = onIncludeRecurringChanged;
    if (onChanged == null) return chart;
    return Column(
      children: [
        // Under the view switch, which sits at the bar's end.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
          child: _RecurringToggle(
            value: includeRecurring,
            onChanged: onChanged,
            alignment: AlignmentDirectional.centerEnd,
          ),
        ),
        Expanded(child: chart),
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

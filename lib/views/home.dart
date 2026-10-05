import 'package:flutter/material.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import '../api/api.dart';
import '../app/app_scope.dart';
import '../domain/domain.dart';
import '../models/models.dart';
import '../state/month_controller.dart';
import '../tools/dates.dart';
import 'expenses_list.dart';
import 'expenses_table.dart';
import 'incomes.dart';
import 'month_details.dart';
import 'month_picker_sheet.dart';
import 'settings.dart';
import 'summary.dart';
import 'widgets/error_views.dart';
import 'widgets/fab_menu.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _Tab {
  const _Tab(this.screen, this.fab);

  final Widget screen;
  final Widget? fab;
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _monthRelatedViews = 4;

  var _currentIndex = 0;
  int? _previousIndex;
  ExpensesFilter _filter = const ExpensesFilter();
  bool _wasInBackground = false;

  MonthController get _months => AppScope.of(context).months;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!_months.hasData && !_months.isBusy) {
      _months.load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Figures such as "spent today" go stale when the app sat in the
  /// background overnight, so the month is reloaded on return, after the
  /// session was refreshed. A brief inactive state (a dialog, the
  /// notification shade) does not count.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _wasInBackground = true;
    } else if (state == AppLifecycleState.resumed && _wasInBackground) {
      _wasInBackground = false;
      _refreshAfterBackground();
    }
  }

  Future<void> _refreshAfterBackground() async {
    final services = AppScope.of(context);
    try {
      if (await services.api.ensureSession()) await services.months.refresh();
    } on ApiException {
      // A rejected session already signed the user out through the client.
    }
  }

  void _openFilteredExpensesList(ExpensesFilter filter) {
    setState(() {
      _filter = filter;
      _previousIndex = _currentIndex;
      _currentIndex = 1;
    });
  }

  Future<void> _refresh() => _months.refresh();

  Future<void> _refreshHard() {
    setState(() => _filter = const ExpensesFilter());
    return _months.refresh();
  }

  void _selectMonth(int monthId) {
    setState(() => _filter = const ExpensesFilter());
    _months.selectMonth(monthId);
  }

  void _selectTab(int index) {
    setState(() {
      _filter = const ExpensesFilter();
      _previousIndex = null;
      _currentIndex = index;
    });
  }

  void _returnToPreviousTab() {
    setState(() {
      _currentIndex = _previousIndex!;
      _previousIndex = null;
    });
  }

  /// Opens the month form for a new month: the one after the newest, or the
  /// current calendar month for an account without months.
  Future<void> _createMonth() async {
    final months = _months.data?.months ?? const <Month>[];
    final range = months.isEmpty ? BudgetRules.firstMonthRange() : BudgetRules.nextMonthRange(months.first);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MonthDetailsScreen(month: {
          'id': null,
          'start_date': Dates.formatApi(range.start),
          'end_date': Dates.formatApi(range.end),
        }),
      ),
    );
    await _refresh();
  }

  void _showMonthPicker(MonthData data) {
    MonthPickerSheet.show(
      context,
      months: data.months,
      selectedId: data.month?.id,
      onSelect: _selectMonth,
      onCreate: _createMonth,
    );
  }

  @override
  Widget build(BuildContext context) {
    final months = _months;
    return ListenableBuilder(
      listenable: months,
      builder: (context, _) {
        final data = months.data;
        if (data == null) {
          final error = months.error;
          if (error != null && !months.isLoading) {
            return ErrorScreen(
              error: error,
              onRetry: months.refresh,
              onLogout: AppScope.of(context).auth.logout,
            );
          }
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return PopScope(
          canPop: _previousIndex == null,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && _previousIndex != null) _returnToPreviousTab();
          },
          child: LayoutBuilder(
            builder: (context, constraints) => _buildScaffold(context, constraints, months, data),
          ),
        );
      },
    );
  }

  Widget _buildScaffold(BuildContext context, BoxConstraints constraints, MonthController months, MonthData data) {
    final l10n = AppLocalizations.of(context)!;
    final month = data.month;
    final tabs = month == null ? null : _buildTabs(data);
    final isMonthTab = _currentIndex < _monthRelatedViews;

    final Widget content;
    if (tabs != null) {
      content = tabs[_currentIndex].screen;
    } else if (isMonthTab) {
      content = NoMonthView(message: data.message, onCreate: _createMonth);
    } else {
      content = const SettingsScreen();
    }
    final fab = tabs?[_currentIndex].fab;

    final appBar = AppBar(
      title: isMonthTab && month != null
          ? _MonthTitle(month: month, onTap: () => _showMonthPicker(data))
          : Text(_tabTitle(l10n), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      forceMaterialTransparency: true,
      leading: _previousIndex != null
          ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _returnToPreviousTab)
          : null,
      actions: isMonthTab && month != null ? _monthActions(l10n, months, data) : null,
      bottom: months.isRefreshing
          ? const PreferredSize(
              preferredSize: Size.fromHeight(2),
              child: LinearProgressIndicator(minHeight: 2),
            )
          : null,
    );

    final body = Column(
      children: [
        if (months.error != null) ErrorBanner(error: months.error!, onRetry: months.refresh),
        Expanded(child: RefreshIndicator(onRefresh: _refreshHard, child: content)),
      ],
    );

    if (constraints.maxWidth >= 600) {
      return Row(
        children: [
          _navigationRail(l10n, fab),
          Expanded(child: Scaffold(appBar: appBar, body: body)),
        ],
      );
    }
    return Scaffold(
      appBar: appBar,
      body: body,
      bottomNavigationBar: _bottomNavigation(l10n),
      floatingActionButton: fab,
    );
  }

  List<_Tab> _buildTabs(MonthData data) {
    return [
      _Tab(
        SummaryScreen(onShowExpenses: () => _selectTab(1), onShowIncomes: () => _selectTab(3)),
        FabMenu(onRefresh: _refresh),
      ),
      _Tab(
        ExpensesListView(data: data, filter: _filter),
        FabMenu(onRefresh: _refresh, fabType: FabType.expense),
      ),
      _Tab(
        ExpensesTableView(data: data, onOpenFiltered: _openFilteredExpensesList),
        null,
      ),
      _Tab(
        IncomesScreen(data: data),
        FabMenu(onRefresh: _refresh, fabType: FabType.income),
      ),
      const _Tab(SettingsScreen(), null),
    ];
  }

  String _tabTitle(AppLocalizations l10n) {
    final username = AppScope.of(context).auth.savedUsername;
    return switch (_currentIndex) {
      0 => username.isEmpty ? l10n.summary : l10n.summaryTitle(username),
      1 => l10n.expensesList,
      2 => l10n.expensesTable,
      3 => l10n.incomes,
      _ => l10n.settings,
    };
  }

  List<Widget> _monthActions(AppLocalizations l10n, MonthController months, MonthData data) {
    final previous = months.previousMonth;
    final next = months.nextMonth;
    return [
      IconButton(
        icon: const Icon(Icons.arrow_back_ios),
        tooltip: l10n.prevMonth,
        onPressed: previous == null ? null : () => _selectMonth(previous.id),
      ),
      IconButton(
        icon: const Icon(Icons.arrow_forward_ios),
        tooltip: l10n.nextMonth,
        onPressed: next == null ? null : () => _selectMonth(next.id),
      ),
      IconButton(
        icon: const Icon(Icons.calendar_month),
        tooltip: l10n.selectMonth,
        onPressed: () => _showMonthPicker(data),
      ),
    ];
  }

  NavigationRail _navigationRail(AppLocalizations l10n, Widget? fab) {
    return NavigationRail(
      selectedIndex: _currentIndex,
      onDestinationSelected: _selectTab,
      groupAlignment: 0,
      leading: fab ?? const SizedBox.square(dimension: 56),
      labelType: NavigationRailLabelType.selected,
      destinations: [
        NavigationRailDestination(icon: const Icon(Icons.home), label: Text(l10n.summary)),
        NavigationRailDestination(icon: const Icon(Icons.table_rows), label: Text(l10n.expensesListShort)),
        NavigationRailDestination(icon: const Icon(Icons.grid_view_sharp), label: Text(l10n.expensesTableShort)),
        NavigationRailDestination(icon: const Icon(Icons.download), label: Text(l10n.incomes)),
        NavigationRailDestination(icon: const Icon(Icons.settings_rounded), label: Text(l10n.settings)),
      ],
    );
  }

  NavigationBar _bottomNavigation(AppLocalizations l10n) {
    return NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: _selectTab,
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      destinations: [
        NavigationDestination(icon: const Icon(Icons.home), label: l10n.summary),
        NavigationDestination(icon: const Icon(Icons.table_rows), label: l10n.expensesListShort),
        NavigationDestination(icon: const Icon(Icons.grid_view_sharp), label: l10n.expensesTableShort),
        NavigationDestination(icon: const Icon(Icons.download), label: l10n.incomes),
        NavigationDestination(icon: const Icon(Icons.settings_rounded), label: l10n.settings),
      ],
    );
  }
}

/// Month name with its date range underneath; tapping opens the month picker.
class _MonthTitle extends StatelessWidget {
  const _MonthTitle({required this.month, required this.onTap});

  final Month month;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              month.title(locale),
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              month.rangeTitle(locale),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

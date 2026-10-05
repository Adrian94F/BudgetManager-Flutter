import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import '../api/api.dart';
import '../app/app_scope.dart';
import '../models/models.dart';
import '../state/month_controller.dart';
import 'expense_search.dart';
import 'expenses_list.dart';
import 'expenses_table.dart';
import 'incomes.dart';
import 'month_details.dart';
import 'month_picker_sheet.dart';
import 'settings.dart';
import 'summary.dart';
import 'widgets/error_views.dart';
import 'widgets/fab_menu.dart';
import 'widgets/month_app_bar.dart';

/// The signed-in shell: a collapsing top bar with the month's title, the
/// month picker and Settings, and three tabs below (Summary, Expenses as a
/// list or a table, Incomes).
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

enum _ExpensesView { list, table }

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _summaryTab = 0;
  static const _expensesTab = 1;
  static const _incomesTab = 2;

  var _currentIndex = _summaryTab;
  _ExpensesView _expensesView = _ExpensesView.list;
  ExpensesFilter _filter = const ExpensesFilter();
  bool _wasInBackground = false;

  /// Drives the header and the tab's list together (see `NestedScrollView`).
  final _scrollController = ScrollController();
  final _refreshKey = GlobalKey<RefreshIndicatorState>();

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
    _scrollController.dispose();
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

  /// From a table cell: the list narrowed to that day and/or category.
  /// Back returns to the table.
  void _openFilteredExpensesList(ExpensesFilter filter) {
    setState(() {
      _filter = filter;
      _expensesView = _ExpensesView.list;
    });
  }

  void _clearFilter() {
    setState(() {
      _filter = const ExpensesFilter();
      _expensesView = _ExpensesView.table;
    });
  }

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
      _currentIndex = index;
    });
  }

  /// A tap on the selected destination goes back to the top and reloads,
  /// as Android apps do; any other destination just switches the tab.
  Future<void> _onDestinationSelected(int index) async {
    if (index != _currentIndex) {
      _selectTab(index);
      return;
    }
    if (_scrollController.hasClients) {
      // The nested controller brings both the header and the list to the top.
      await _scrollController.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    }
    await _refreshKey.currentState?.show();
  }

  void _showExpenses(_ExpensesView view) {
    setState(() {
      _filter = const ExpensesFilter();
      _currentIndex = _expensesTab;
      _expensesView = view;
    });
  }

  /// A horizontal fling on the Summary moves one month: left for the next,
  /// right for the previous one, as on a calendar.
  void _onSummarySwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    const threshold = 250.0;
    final target = velocity <= -threshold
        ? _months.nextMonth
        : velocity >= threshold
            ? _months.previousMonth
            : null;
    if (target == null) return;
    HapticFeedback.selectionClick();
    _selectMonth(target.id);
  }

  void _createMonth() {
    MonthDetailsScreen.openCreate(context);
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

  void _openSettings() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
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
          canPop: !_filter.isActive,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && _filter.isActive) _clearFilter();
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
    final locale = Localizations.localeOf(context).toString();
    final month = data.month;
    final tabs = month == null ? null : _buildTabs(data);
    final content = tabs != null
        ? tabs[_currentIndex].screen
        : NoMonthView(message: data.message, onCreate: _createMonth);
    final fab = tabs?[_currentIndex].fab;
    final showSearch = month != null &&
        _currentIndex == _expensesTab &&
        _expensesView == _ExpensesView.list &&
        !_filter.isActive;

    // The header collapses as the tab's list scrolls under it; a tab with its
    // own scroll controllers (the table) simply keeps the header expanded.
    // The refresh indicator sits in the body: the pull happens on the tab's
    // list, whose notifications an indicator around the whole view would
    // not see (it only listens at depth 0).
    final body = NestedScrollView(
      controller: _scrollController,
      headerSliverBuilder: (context, _) => [
        MonthSliverAppBar(
          title: month?.title(locale) ?? 'Budget Manager',
          subtitle: month?.rangeTitle(locale),
          onTitleTap: month == null ? null : () => _showMonthPicker(data),
          leading: _filter.isActive
              ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _clearFilter)
              : null,
          actions: [
            if (showSearch) ExpenseSearchButton(data: data),
            IconButton(
              icon: const Icon(Icons.calendar_month_outlined),
              tooltip: l10n.selectMonth,
              onPressed: () => _showMonthPicker(data),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: l10n.settings,
              onPressed: _openSettings,
            ),
            const SizedBox(width: 4),
          ],
          showProgress: months.isRefreshing,
        ),
        if (months.error != null)
          SliverToBoxAdapter(child: ErrorBanner(error: months.error!, onRetry: months.refresh)),
      ],
      body: RefreshIndicator(key: _refreshKey, onRefresh: _refreshHard, child: content),
    );

    if (constraints.maxWidth >= 600) {
      return Row(
        children: [
          _navigationRail(l10n, fab),
          Expanded(child: Scaffold(body: body)),
        ],
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: _bottomNavigation(l10n),
      floatingActionButton: fab,
    );
  }

  List<_Tab> _buildTabs(MonthData data) {
    return [
      _Tab(
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: _onSummarySwipe,
          child: SummaryScreen(
            onShowExpenses: () => _showExpenses(_ExpensesView.list),
            onShowIncomes: () => _selectTab(_incomesTab),
          ),
        ),
        const FabMenu(),
      ),
      _Tab(
        _ExpensesTab(
          data: data,
          view: _expensesView,
          filter: _filter,
          onViewChanged: _showExpenses,
          onOpenFiltered: _openFilteredExpensesList,
          onClearFilter: _clearFilter,
        ),
        const FabMenu(fabType: FabType.expense),
      ),
      _Tab(
        IncomesScreen(data: data),
        const FabMenu(fabType: FabType.income),
      ),
    ];
  }

  NavigationRail _navigationRail(AppLocalizations l10n, Widget? fab) {
    return NavigationRail(
      selectedIndex: _currentIndex,
      onDestinationSelected: _onDestinationSelected,
      groupAlignment: 0,
      leading: fab ?? const SizedBox.square(dimension: 56),
      labelType: NavigationRailLabelType.all,
      destinations: [
        NavigationRailDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: Text(l10n.summary)),
        NavigationRailDestination(icon: const Icon(Icons.receipt_long_outlined), selectedIcon: const Icon(Icons.receipt_long), label: Text(l10n.expenses)),
        NavigationRailDestination(icon: const Icon(Icons.savings_outlined), selectedIcon: const Icon(Icons.savings), label: Text(l10n.incomes)),
      ],
    );
  }

  NavigationBar _bottomNavigation(AppLocalizations l10n) {
    return NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: _onDestinationSelected,
      destinations: [
        NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: l10n.summary),
        NavigationDestination(icon: const Icon(Icons.receipt_long_outlined), selectedIcon: const Icon(Icons.receipt_long), label: l10n.expenses),
        NavigationDestination(icon: const Icon(Icons.savings_outlined), selectedIcon: const Icon(Icons.savings), label: l10n.incomes),
      ],
    );
  }
}

/// The Expenses tab: a List / Table switch above the chosen view. While a
/// table drill-down filter is active the switch hides and the list shows
/// the filter chip instead.
class _ExpensesTab extends StatelessWidget {
  const _ExpensesTab({
    required this.data,
    required this.view,
    required this.filter,
    required this.onViewChanged,
    required this.onOpenFiltered,
    required this.onClearFilter,
  });

  final MonthData data;
  final _ExpensesView view;
  final ExpensesFilter filter;
  final ValueChanged<_ExpensesView> onViewChanged;
  final ValueChanged<ExpensesFilter> onOpenFiltered;
  final VoidCallback onClearFilter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        if (!filter.isActive)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_ExpensesView>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: _ExpensesView.list,
                    icon: const Icon(Icons.view_list_outlined),
                    label: Text(l10n.expensesListShort),
                  ),
                  ButtonSegment(
                    value: _ExpensesView.table,
                    icon: const Icon(Icons.grid_on_outlined),
                    label: Text(l10n.expensesTableShort),
                  ),
                ],
                selected: {view},
                onSelectionChanged: (selection) => onViewChanged(selection.first),
              ),
            ),
          ),
        Expanded(
          child: view == _ExpensesView.list
              ? ExpensesListView(data: data, filter: filter, onClearFilter: onClearFilter)
              : ExpensesTableView(data: data, onOpenFiltered: onOpenFiltered),
        ),
      ],
    );
  }
}

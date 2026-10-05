import 'package:flutter/material.dart';
import 'package:budget_manager/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../app/app_scope.dart';
import '../domain/domain.dart';
import '../models/models.dart';
import '../state/month_controller.dart';
import '../tools/dates.dart';
import 'expenses_list.dart';
import 'expenses_table.dart';
import 'incomes.dart';
import 'month_details.dart';
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

class _HomeScreenState extends State<HomeScreen> {
  static const _monthRelatedViews = 4;

  var _currentIndex = 0;
  int? _previousIndex;
  ExpensesFilter _filter = ExpensesFilter();
  ScrollCoords? _savedCoords;

  MonthController get _months => AppScope.of(context).months;

  @override
  void initState() {
    super.initState();
    if (!_months.hasData && !_months.isBusy) {
      _months.load();
    }
  }

  void _openFilteredExpensesList(ExpensesFilter filter) {
    setState(() {
      _filter = filter;
      _previousIndex = _currentIndex;
      _currentIndex = 1;
    });
  }

  void _saveTableCoords(ScrollCoords coords) {
    setState(() => _savedCoords = coords);
  }

  Future<void> _refresh() => _months.refresh();

  Future<void> _refreshHard() {
    setState(() {
      _filter = ExpensesFilter();
      _savedCoords = null;
    });
    return _months.refresh();
  }

  void _selectMonth(int monthId) {
    setState(() {
      _filter = ExpensesFilter();
      _savedCoords = null;
    });
    _months.selectMonth(monthId);
  }

  void _selectTab(int index) {
    setState(() {
      _filter = ExpensesFilter();
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

  Future<void> _createFirstMonth() async {
    final range = BudgetRules.firstMonthRange();
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

  @override
  Widget build(BuildContext context) {
    final months = _months;
    return ListenableBuilder(
      listenable: months,
      builder: (context, _) {
        final raw = months.rawJson;
        final data = months.data;
        if (raw == null || data == null) {
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
            builder: (context, constraints) => _buildScaffold(context, constraints, months, data, raw),
          ),
        );
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    BoxConstraints constraints,
    MonthController months,
    MonthData data,
    Map<String, dynamic> raw,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final month = data.month;
    final tabs = month == null ? null : _buildTabs(raw, month);
    final isMonthTab = _currentIndex < _monthRelatedViews;

    final Widget content;
    if (tabs != null) {
      content = tabs[_currentIndex].screen;
    } else if (isMonthTab) {
      content = NoMonthView(message: raw['message'] as String?, onCreate: _createFirstMonth);
    } else {
      content = const SettingsScreen();
    }
    final fab = tabs?[_currentIndex].fab;

    final title = isMonthTab && month != null ? _monthDates(month) : _tabTitle(l10n);
    final appBar = AppBar(
      title: Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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

  List<_Tab> _buildTabs(Map<String, dynamic> raw, Month month) {
    final expenses = raw['expenses'] as List<dynamic>;
    final categories = raw['categories'] as List<dynamic>;
    final monthRaw = raw['month'] as Map<String, dynamic>;
    return [
      _Tab(
        SummaryScreen(data: raw),
        FabMenu(loadedData: raw, onRefresh: _refresh),
      ),
      _Tab(
        ExpensesListView(
          expenses: expenses,
          categories: categories,
          filter: _filter,
          monthId: month.id,
          refreshParent: _refresh,
        ),
        FabMenu(loadedData: raw, onRefresh: _refresh, fabType: FabType.expense),
      ),
      _Tab(
        ExpensesTableView(
          expenses: expenses,
          categories: categories,
          month: monthRaw,
          refreshParent: _refresh,
          openFilteredListCallback: _openFilteredExpensesList,
          saveTableCoords: _saveTableCoords,
          scrollCoords: _savedCoords,
        ),
        null,
      ),
      _Tab(
        IncomesScreen(data: raw, refreshParent: _refresh),
        FabMenu(loadedData: raw, onRefresh: _refresh, fabType: FabType.income),
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

  String _monthDates(Month month, {bool withYear = true}) {
    final start = month.startDate;
    final end = month.endDate;
    if (start.year != end.year) {
      return '${DateFormat('d.MM.yyyy').format(start)}-${DateFormat('d.MM.yyyy').format(end)}';
    }
    final endFormat = withYear ? 'd.MM.yyyy' : 'd.MM';
    return '${DateFormat('d.MM').format(start)}-${DateFormat(endFormat).format(end)}';
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
        onPressed: () => _showMonthSelector(data),
      ),
    ];
  }

  void _showMonthSelector(MonthData data) {
    final selectedId = data.month?.id;
    final months = data.months;
    showDialog<void>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        final theme = Theme.of(context);
        return AlertDialog(
          title: Text(l10n.selectMonth),
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              shrinkWrap: true,
              itemCount: months.length,
              itemBuilder: (context, index) {
                final month = months[index];
                final year = month.startDate.year;
                final showYearHeader = index == 0 || months[index - 1].startDate.year != year;
                final yearEnds = index < months.length - 1 && months[index + 1].startDate.year != year;
                final isSelected = month.id == selectedId;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showYearHeader)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          '$year',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ListTile(
                      title: Text(
                        _monthDates(month, withYear: false),
                        style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                      ),
                      trailing: isSelected ? Icon(Icons.check_circle, color: theme.colorScheme.primary) : null,
                      onTap: () {
                        Navigator.pop(context);
                        _selectMonth(month.id);
                      },
                    ),
                    if (yearEnds) const Divider(indent: 16, endIndent: 16),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          ],
        );
      },
    );
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

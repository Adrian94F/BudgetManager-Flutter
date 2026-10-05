import 'package:flutter/material.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import '../api/api.dart';
import '../app/app_scope.dart';
import '../models/models.dart';
import '../state/month_controller.dart';
import 'expenses_list.dart';
import 'expenses_table.dart';
import 'incomes.dart';
import 'month_details.dart';
import 'month_picker_sheet.dart';
import 'settings.dart';
import 'summary.dart';
import 'widgets/error_views.dart';
import 'widgets/fab_menu.dart';

/// The signed-in shell: the month's title in the top bar with the month
/// picker and Settings beside it, and four tabs below (Summary, List, Table,
/// Incomes).
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
    final content = tabs != null
        ? tabs[_currentIndex].screen
        : NoMonthView(message: data.message, onCreate: _createMonth);
    final fab = tabs?[_currentIndex].fab;

    final appBar = AppBar(
      title: month != null
          ? _MonthTitle(month: month, onTap: () => _showMonthPicker(data))
          : const Text('Budget Manager', style: TextStyle(fontWeight: FontWeight.bold)),
      forceMaterialTransparency: true,
      leading: _previousIndex != null
          ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _returnToPreviousTab)
          : null,
      actions: [
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
        const FabMenu(),
      ),
      _Tab(
        ExpensesListView(data: data, filter: _filter),
        const FabMenu(fabType: FabType.expense),
      ),
      _Tab(
        ExpensesTableView(data: data, onOpenFiltered: _openFilteredExpensesList),
        null,
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
      onDestinationSelected: _selectTab,
      groupAlignment: 0,
      leading: fab ?? const SizedBox.square(dimension: 56),
      labelType: NavigationRailLabelType.selected,
      destinations: [
        NavigationRailDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: Text(l10n.summary)),
        NavigationRailDestination(icon: const Icon(Icons.receipt_long_outlined), selectedIcon: const Icon(Icons.receipt_long), label: Text(l10n.expensesListShort)),
        NavigationRailDestination(icon: const Icon(Icons.grid_on_outlined), selectedIcon: const Icon(Icons.grid_on), label: Text(l10n.expensesTableShort)),
        NavigationRailDestination(icon: const Icon(Icons.savings_outlined), selectedIcon: const Icon(Icons.savings), label: Text(l10n.incomes)),
      ],
    );
  }

  NavigationBar _bottomNavigation(AppLocalizations l10n) {
    return NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: _selectTab,
      destinations: [
        NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: l10n.summary),
        NavigationDestination(icon: const Icon(Icons.receipt_long_outlined), selectedIcon: const Icon(Icons.receipt_long), label: l10n.expensesListShort),
        NavigationDestination(icon: const Icon(Icons.grid_on_outlined), selectedIcon: const Icon(Icons.grid_on), label: l10n.expensesTableShort),
        NavigationDestination(icon: const Icon(Icons.savings_outlined), selectedIcon: const Icon(Icons.savings), label: l10n.incomes),
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

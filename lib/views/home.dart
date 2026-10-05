import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'widgets/rail_action.dart';

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

  /// Where the header stood before the table collapsed it; restored when
  /// another view takes over.
  double _headerOffsetBeforeTable = 0;

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

  bool get _isTableShown => _currentIndex == _expensesTab && _expensesView == _ExpensesView.table;

  /// Applies a change of tab or view and keeps the header in step with it.
  void _updateView(VoidCallback change) {
    final wasTable = _isTableShown;
    setState(change);
    _syncHeaderWithTable(wasTable: wasTable);
  }

  /// The table has its own scroll controllers and never moves the header,
  /// so the header collapses while the table shows (more rows on screen) and
  /// comes back to where it stood once another view takes over.
  void _syncHeaderWithTable({required bool wasTable}) {
    final isTable = _isTableShown;
    if (isTable == wasTable || !_scrollController.hasClients) return;
    if (isTable) {
      _headerOffsetBeforeTable = _scrollController.offset;
      _animateHeader(_scrollController.position.maxScrollExtent);
    } else {
      _animateHeader(_headerOffsetBeforeTable);
    }
  }

  void _animateHeader(double offset) {
    _scrollController.animateTo(offset, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
  }

  /// From a table cell: the list narrowed to that day and/or category.
  /// Back returns to the table.
  void _openFilteredExpensesList(ExpensesFilter filter) {
    _updateView(() {
      _filter = filter;
      _expensesView = _ExpensesView.list;
    });
  }

  void _clearFilter() {
    _updateView(() {
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
    _updateView(() {
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
    // The table keeps the header collapsed and scrolls on its own.
    if (_scrollController.hasClients && !_isTableShown) {
      // The nested controller brings both the header and the list to the top.
      await _scrollController.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    }
    await _refreshKey.currentState?.show();
  }

  void _showExpenses(_ExpensesView view) {
    _updateView(() {
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
    // Medium width and up gets a rail, which also takes the month picker and
    // Settings; a compact height (a phone in landscape) gets a one-line bar
    // instead of the large collapsing title.
    final useRail = constraints.maxWidth >= 600;
    final compactHeader = constraints.maxHeight < 480;
    final onExpenses = month != null && _currentIndex == _expensesTab && !_filter.isActive;
    // The List / Table switch sits in the bar when the window is wide enough
    // for it next to the title; on a phone it stays below the bar.
    final switchInBar = onExpenses && useRail;
    final showSearch = onExpenses && _expensesView == _ExpensesView.list;
    final tabs = month == null ? null : _buildTabs(data, showSwitch: !switchInBar);
    final content = tabs != null
        ? tabs[_currentIndex].screen
        : NoMonthView(message: data.message, onCreate: _createMonth);
    final fab = tabs?[_currentIndex].fab;
    final actionsWidth = (switchInBar ? 220.0 : 0.0) + (showSearch ? 48.0 : 0.0) + (useRail ? 0.0 : 96.0) + 4.0;

    // The header collapses as the tab's list scrolls under it; a tab with its
    // own scroll controllers (the table) simply keeps the header expanded.
    // The refresh indicator sits in the body: the pull happens on the tab's
    // list, whose notifications an indicator around the whole view would
    // not see (it only listens at depth 0).
    // The absorber takes the pinned toolbar out of the outer scroll range, so
    // a collapsed header stops at the toolbar instead of sliding the body
    // under it; _OverlapPadding keeps the body's top below the toolbar.
    final body = NestedScrollView(
      controller: _scrollController,
      headerSliverBuilder: (context, _) => [
        SliverOverlapAbsorber(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          sliver: MonthSliverAppBar(
            title: month?.title(locale) ?? 'Budget Manager',
            subtitle: month?.rangeTitle(locale),
            onTitleTap: month == null ? null : () => _showMonthPicker(data),
            leading: _filter.isActive
                ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _clearFilter)
                : null,
            actions: [
              if (showSearch) ExpenseSearchButton(data: data),
              if (switchInBar)
                Padding(
                  padding: const EdgeInsets.only(left: 4, right: 8),
                  child: _ExpensesViewSwitch(view: _expensesView, onChanged: _showExpenses, dense: true),
                ),
              if (!useRail) ...[
                _monthPickerButton(l10n, data),
                _settingsButton(l10n),
              ],
              const SizedBox(width: 4),
            ],
            actionsWidth: actionsWidth,
            showProgress: months.isRefreshing,
            compact: compactHeader,
          ),
        ),
        if (months.error != null)
          SliverToBoxAdapter(child: ErrorBanner(error: months.error!, onRetry: months.refresh)),
      ],
      body: Builder(
        builder: (context) => _OverlapPadding(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          child: RefreshIndicator(key: _refreshKey, onRefresh: _refreshHard, child: content),
        ),
      ),
    );

    if (useRail) {
      return Row(
        children: [
          _navigationRail(l10n, fab, data, height: constraints.maxHeight - MediaQuery.paddingOf(context).vertical),
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

  List<_Tab> _buildTabs(MonthData data, {required bool showSwitch}) {
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
          showSwitch: showSwitch,
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

  IconButton _monthPickerButton(AppLocalizations l10n, MonthData data) {
    return IconButton(
      icon: const Icon(Icons.calendar_month_outlined),
      tooltip: l10n.selectMonth,
      onPressed: () => _showMonthPicker(data),
    );
  }

  IconButton _settingsButton(AppLocalizations l10n) {
    return IconButton(
      icon: const Icon(Icons.settings_outlined),
      tooltip: l10n.settings,
      onPressed: _openSettings,
    );
  }

  /// Which labels the rail has room for in [height] (the window's height
  /// without the system insets): every one, with labels under the month
  /// picker and Settings as well (a tablet); only the selected destination's;
  /// or none (a phone in landscape). The figures are the Material 3 rail
  /// metrics: a labelled destination is 64 dp, an icon-only one 44 dp, the
  /// FAB block 72 dp, and the two actions at the bottom 128 dp with labels
  /// or 112 dp without.
  static NavigationRailLabelType _railLabelsFor(double height) {
    const fabBlock = 72.0;
    const labelled = 64.0;
    const iconOnly = 44.0;
    if (height >= fabBlock + 3 * labelled + 128) return NavigationRailLabelType.all;
    if (height >= fabBlock + labelled + 2 * iconOnly + 112) return NavigationRailLabelType.selected;
    return NavigationRailLabelType.none;
  }

  /// The rail of a wide window: the tab's FAB on top, the destinations, and
  /// the month picker with Settings pinned at the bottom. Labels follow the
  /// room there is ([_railLabelsFor]); the destinations scroll rather than
  /// overflow if the window is shorter than even the icon-only rail.
  Widget _navigationRail(AppLocalizations l10n, Widget? fab, MonthData data, {required double height}) {
    final labels = _railLabelsFor(height);
    final labelledActions = labels == NavigationRailLabelType.all;
    return NavigationRail(
      selectedIndex: _currentIndex,
      onDestinationSelected: _onDestinationSelected,
      groupAlignment: -1,
      leading: fab ?? const SizedBox.square(dimension: 56),
      labelType: labels,
      scrollable: true,
      trailingAtBottom: true,
      destinations: [
        NavigationRailDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: Text(l10n.summary)),
        NavigationRailDestination(icon: const Icon(Icons.receipt_long_outlined), selectedIcon: const Icon(Icons.receipt_long), label: Text(l10n.expenses)),
        NavigationRailDestination(icon: const Icon(Icons.savings_outlined), selectedIcon: const Icon(Icons.savings), label: Text(l10n.incomes)),
      ],
      trailing: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RailAction(
              icon: Icons.calendar_month_outlined,
              label: l10n.month,
              tooltip: l10n.selectMonth,
              showLabel: labelledActions,
              onPressed: () => _showMonthPicker(data),
            ),
            RailAction(
              icon: Icons.settings_outlined,
              label: l10n.settings,
              tooltip: l10n.settings,
              showLabel: labelledActions,
              onPressed: _openSettings,
            ),
          ],
        ),
      ),
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
    required this.showSwitch,
    required this.onViewChanged,
    required this.onOpenFiltered,
    required this.onClearFilter,
  });

  final MonthData data;
  final _ExpensesView view;
  final ExpensesFilter filter;

  /// False when the shell shows the List / Table switch in the bar instead.
  final bool showSwitch;
  final ValueChanged<_ExpensesView> onViewChanged;
  final ValueChanged<ExpensesFilter> onOpenFiltered;
  final VoidCallback onClearFilter;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!filter.isActive && showSwitch)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: _ExpensesViewSwitch(view: view, onChanged: onViewChanged),
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

/// The List / Table switch of the Expenses tab: full width below the bar on
/// a phone, a dense control inside the bar when the window is wide.
class _ExpensesViewSwitch extends StatelessWidget {
  const _ExpensesViewSwitch({required this.view, required this.onChanged, this.dense = false});

  final _ExpensesView view;
  final ValueChanged<_ExpensesView> onChanged;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SegmentedButton<_ExpensesView>(
      showSelectedIcon: false,
      style: dense ? const ButtonStyle(visualDensity: VisualDensity.compact) : null,
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
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

/// Keeps the body's top clear of the pinned toolbar. The absorber around
/// the header takes the toolbar's extent out of the outer scroll range,
/// which lays the body out under it; this pads the body by that extent, as
/// a `SliverOverlapInjector` does for a sliver body.
class _OverlapPadding extends SingleChildRenderObjectWidget {
  const _OverlapPadding({required this.handle, required super.child});

  final SliverOverlapAbsorberHandle handle;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderOverlapPadding(handle);

  @override
  void updateRenderObject(BuildContext context, _RenderOverlapPadding renderObject) => renderObject.handle = handle;
}

class _RenderOverlapPadding extends RenderShiftedBox {
  _RenderOverlapPadding(this._handle) : super(null);

  SliverOverlapAbsorberHandle _handle;

  set handle(SliverOverlapAbsorberHandle value) {
    if (value == _handle) return;
    if (attached) _handle.removeListener(markNeedsLayout);
    _handle = value;
    if (attached) _handle.addListener(markNeedsLayout);
    markNeedsLayout();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _handle.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    _handle.removeListener(markNeedsLayout);
    super.detach();
  }

  @override
  void performLayout() {
    // The header lays out before the body within the same frame, so the
    // absorbed extent is current here.
    final top = _handle.layoutExtent ?? 0.0;
    final child = this.child;
    if (child == null) {
      size = constraints.constrain(Size(0, top));
      return;
    }
    child.layout(constraints.deflate(EdgeInsets.only(top: top)), parentUsesSize: true);
    (child.parentData! as BoxParentData).offset = Offset(0, top);
    size = constraints.constrain(Size(child.size.width, child.size.height + top));
  }
}

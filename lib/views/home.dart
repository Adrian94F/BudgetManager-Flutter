import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:budget_manager/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:jiffy/jiffy.dart';

import '../services/auth_service.dart';
import 'expenses_list.dart';
import 'expenses_table.dart';
import 'incomes.dart';
import 'settings.dart';
import 'summary.dart';
import 'widgets/fab_menu.dart';

class HomeScreen extends StatefulWidget {
  final Future<void> Function(String) setThemeMode;

  const HomeScreen({super.key, required this.setThemeMode});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _storage = const FlutterSecureStorage();

  var _currentIndex = 0;
  int? _previousIndex;
  var _monthRelated = true;
  final _monthRelatedViews = 4;

  final List<ScreenData> _screens = [
    ScreenData(title: "Hello!"),
    ScreenData(title: "Expenses list"),
    ScreenData(title: "Expenses table"),
    ScreenData(title: "Incomes"),
    // ScreenData(title: "Statistics"),
    ScreenData(title: "Settings"),
  ];

  late Future<Map<String, dynamic>> _data;
  Map<String, dynamic> _loadedData = {};
  ExpensesFilter _filter = ExpensesFilter();
  ScrollCoords? _savedCoords;
  int? _currentMonthId;

  Future<void> _logout(BuildContext context) async {
    await _authService.logout();
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _loadUserName() async {
    String? login = await _storage.read(key: "login");
    if (login != null) {
      setState(() {
        _screens[0].title = AppLocalizations.of(context)!.summaryTitle(login);
        _screens[1].title = AppLocalizations.of(context)!.expensesList;
        _screens[2].title = AppLocalizations.of(context)!.expensesTable;
        _screens[3].title = AppLocalizations.of(context)!.incomes;
        // _screens[4].title = AppLocalizations.of(context)!.statistics;
        _screens[4].title = AppLocalizations.of(context)!.settings;
      });
    }
  }

  void _setScreensAndFABs() {
    final expenses = _loadedData['expenses'] as List<dynamic>;
    final categories = _loadedData['categories'] as List<dynamic>;
    final month = _loadedData['month'] as Map<String, dynamic>;

    _screens[0].screen = SummaryScreen(
        data: _loadedData
    );
    _screens[0].fab = FabMenu(
      loadedData: _loadedData,
      onRefresh: _handleRefresh,
    );

    _screens[1].screen = ExpensesListView(
        expenses: expenses,
        categories: categories,
        filter: _filter,
        monthId: month['id'],
        refreshParent: _handleRefresh
    );
    _screens[1].fab = FabMenu(
      loadedData: _loadedData,
      onRefresh: _handleRefresh,
      fabType: FabType.expense,
    );

    _screens[2].screen = ExpensesTableView(
      expenses: expenses,
      categories: categories,
      month: month,
      refreshParent: _handleRefresh,
      openFilteredListCallback: openFilteredExpensesList,
      saveTableCoords: saveTableCoords,
      scrollCoords: _savedCoords,
    );

    _screens[3].screen = IncomesScreen(
        data: _loadedData,
        refreshParent: _handleRefresh
    );
    _screens[3].fab = FabMenu(
      loadedData: _loadedData,
      onRefresh: _handleRefresh,
      fabType: FabType.income,
    );

    _screens[4].screen = SettingsScreen(
        setThemeMode: widget.setThemeMode
    );
  }

  void openFilteredExpensesList(ExpensesFilter filter) {
    // print("Opening filtered expenses list with filter: $filter");
    setState(() {
      _filter = filter;
      _setScreensAndFABs();
      _previousIndex = _currentIndex;
      _currentIndex = 1;
    });
  }

  void saveTableCoords(ScrollCoords coords) {
    setState(() {
      _savedCoords = coords;
    });
  }

  void _fetchData() {
      _data = _authService.get("month/${_currentMonthId == null ? '' : '?month_id=$_currentMonthId'}");
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserName();
    });
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || snapshot.hasError) {
          if (snapshot.hasError) {
            _logout(context);
          }
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else {
          _loadedData = snapshot.data!;

          return PopScope(
            canPop: _previousIndex == null,
            onPopInvokedWithResult: (bool didPop, Object? result) {
              if (didPop) return;
              if (_previousIndex != null) {
                setState(() {
                  _currentIndex = _previousIndex!;
                  _previousIndex = null;
                });
              }
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                return _buildBody(constraints);
              },
            ),
          );
        }
      },
    );
  }

  Widget _buildBody(BoxConstraints constraints) {
    var months = _loadedData['months'] as List<dynamic>;
    _setScreensAndFABs();

    var message = _loadedData['message'];
    var homeScreenChild = message == null
        ? _screens[_currentIndex].screen!
        : Center(
          child: Text(
            message,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          )
        );

    var currentStartDate = DateTime.parse(_loadedData['month']['start_date']);
    var currentEndDate = DateTime.parse(_loadedData['month']['end_date']);
    var monthDates = currentStartDate.year == currentEndDate.year
        ? "${DateFormat("d.MM").format(currentStartDate)}-${DateFormat("d.MM.yyyy").format(currentEndDate)}"
        : "${DateFormat("d.MM.yyyy").format(currentStartDate)}-${DateFormat("d.MM.yyyy").format(currentEndDate)}";

    final body = RefreshIndicator(
      onRefresh: _handleRefreshHard,
      child: homeScreenChild is Center
          ? ListView(
        children: [homeScreenChild],
      )
          : homeScreenChild,
    );

    if (constraints.maxWidth >= 600) {
      return Row(
        children: [
          _navigationRail(),
          Expanded(
            child: Scaffold(
              appBar: AppBar(
                title: Text(
                  _currentIndex < 4 ? monthDates : _screens[_currentIndex].title!,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                forceMaterialTransparency: true,
                actions: _monthMenu(context, _monthRelated, months),
                leading: _previousIndex != null
                    ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      _currentIndex = _previousIndex!;
                      _previousIndex = null;  // Clear the previous index
                    });
                  },
                )
                    : null,
              ),
              body: body,
            ),
          ),
        ],
      );
    } else {
      return Scaffold(
        body: RefreshIndicator(
          onRefresh: _handleRefreshHard,
          child: homeScreenChild is Center
              ? ListView(
            children: [homeScreenChild],
          )
              : homeScreenChild,
        ),
        appBar: AppBar(
          title: Text(
            _currentIndex < 4
                ? monthDates
                : _screens[_currentIndex].title!,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          forceMaterialTransparency: true,
          actions: _monthMenu(context, _monthRelated, months),
          leading: _previousIndex != null
              ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _currentIndex = _previousIndex!;
                    _previousIndex = null;  // Clear the previous index
                  });
                },
              )
              : null,
        ),
        bottomNavigationBar: _bottomNavigation(),
        floatingActionButton: _screens[_currentIndex].fab,
      );
    }
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _fetchData();
    });
  }

  Future<void> _handleRefreshHard() async {
    setState(() {
      _filter = ExpensesFilter();
      _savedCoords = null;
      _fetchData();
    });
  }

  NavigationRail _navigationRail() {
    return NavigationRail(
      selectedIndex: _currentIndex,
      onDestinationSelected: (index) {
        setState(() {
          _filter = ExpensesFilter();
          _monthRelated = index < _monthRelatedViews;
          _previousIndex = null;
          _currentIndex = index;
        });
      },
      groupAlignment: 0,
      leading: _screens[_currentIndex].fab ?? SizedBox.square(dimension: 56),
      labelType: NavigationRailLabelType.selected,
      destinations: [
        NavigationRailDestination(
          icon: const Icon(Icons.home),
          label: Text(AppLocalizations.of(context)!.summary),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.table_rows),
          label: Text(AppLocalizations.of(context)!.expensesListShort),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.grid_view_sharp),
          label: Text(AppLocalizations.of(context)!.expensesTableShort),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.download),
          label: Text(AppLocalizations.of(context)!.incomes),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.settings_rounded),
          label: Text(AppLocalizations.of(context)!.settings),
        ),
      ],
    );
  }

  NavigationBar _bottomNavigation() {
    return NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: (index) {
        setState(() {
          _filter = ExpensesFilter();
          _monthRelated = index < _monthRelatedViews;
          _previousIndex = null;
          _currentIndex = index;
        });
      },
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.home),
          label: AppLocalizations.of(context)!.summary,
        ),
        NavigationDestination(
          icon: const Icon(Icons.table_rows),
          label: AppLocalizations.of(context)!.expensesListShort,
        ),
        NavigationDestination(
          icon: const Icon(Icons.grid_view_sharp),
          label: AppLocalizations.of(context)!.expensesTableShort,
        ),
        NavigationDestination(
          icon: const Icon(Icons.download),
          label: AppLocalizations.of(context)!.incomes,
        ),
        // NavigationDestination(
        //   icon: const Icon(Icons.bar_chart_rounded),
        //   label: AppLocalizations.of(context)!.statistics,
        // ),
        NavigationDestination(
          icon: const Icon(Icons.settings_rounded),
          label: AppLocalizations.of(context)!.settings,
        ),
      ],
    );
  }

  void _selectMonth(int monthId) {
    setState(() {
      _currentMonthId = monthId;
      _savedCoords = null;
      _filter = ExpensesFilter();
      _fetchData();
    });
  }

  void _showMonthSelectorDialog(List<dynamic> months) {
    showDialog(context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.selectMonth),
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              shrinkWrap: true,
              itemCount: months.length,
              itemBuilder: (context, index) {
                final month = months[index];
                final date = DateTime.parse(month['start_date']);
                final jiffy = Jiffy.parseFromDateTime(date);

                final bool showYearHeader = index == 0 ||
                    Jiffy.parseFromDateTime(DateTime.parse(months[index - 1]['start_date'])).year != jiffy.year;

                final isSelected = (_currentMonthId == null && month['is_current'] == true) || month['id'] == _currentMonthId;

                var startDate = DateTime.parse(month['start_date']);
                var endDate = DateTime.parse(month['end_date']);
                var monthDates = startDate.year == endDate.year
                    ? "${DateFormat("d.MM").format(startDate)}-${DateFormat("d.MM").format(endDate)}"
                    : "${DateFormat("d.MM.yyyy").format(startDate)}-${DateFormat("d.MM.yyyy").format(endDate)}";

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showYearHeader)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          jiffy.year.toString(),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ListTile(
                      title: Text(
                        monthDates,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () {
                        _selectMonth(month['id']);
                        Navigator.pop(context);
                      },
                    ),
                    if (index < months.length - 1 && Jiffy.parseFromDateTime(DateTime.parse(months[index + 1]['start_date'])).year != jiffy.year)
                      const Divider(indent: 16, endIndent: 16),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
          ],
        );
      },
    );
  }


  int _getCurrentMonthIdx(List<dynamic> months) {
    var currentMonthIdx = months.indexWhere((month) => month['id'] == _currentMonthId);
    if (currentMonthIdx < 0) {
      currentMonthIdx = 0;
    }
    return currentMonthIdx;
  }

  List<Widget> _monthMenu(BuildContext context, bool isVisible, List<dynamic> months) {
    if (!isVisible || months.isEmpty) {
      return [];
    }

    var currentMonthIdx = _getCurrentMonthIdx(months);
    var nextMonthId = currentMonthIdx > 0 ? months[currentMonthIdx - 1]['id'] : null;
    var previousMonthId = currentMonthIdx < months.length - 1 ? months[currentMonthIdx + 1]['id'] : null;

    final localizations = AppLocalizations.of(context)!;

    Jiffy.now().localeCode;

    return [
      IconButton(
        icon: const Icon(Icons.arrow_back_ios),
        tooltip: localizations.nextMonth,
        onPressed: previousMonthId != null ? () => _selectMonth(previousMonthId) : null,
      ),
      IconButton(
        icon: const Icon(Icons.arrow_forward_ios),
        tooltip: localizations.prevMonth,
        onPressed: nextMonthId != null ? () => _selectMonth(nextMonthId) : null,
      ),
      IconButton(
        icon: const Icon(Icons.calendar_month),
        tooltip: localizations.monthDetails,
        onPressed: () => _showMonthSelectorDialog(months),
      ),
    ];
  }
}

class ScreenData {
  Widget? screen;
  String? title;
  Widget? fab;

  ScreenData({this.screen, this.title, this.fab});
}
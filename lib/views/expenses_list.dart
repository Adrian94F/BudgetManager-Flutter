import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../app/app_scope.dart';
import '../tools/formatters.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import 'expense_details.dart';

class ExpensesListView extends StatefulWidget {
  final List<dynamic> expenses;
  final List<dynamic> categories;
  final Future<void> Function() refreshParent;
  final int monthId;
  final ExpensesFilter filter;

  const ExpensesListView({super.key, required this.expenses, required this.categories, required this.filter, required this.monthId, required this.refreshParent});

  @override
  State<ExpensesListView> createState() => _ExpensesListViewState();
}

class _ExpensesListViewState extends State<ExpensesListView> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _itemKeys = {};

  @override
  void initState() {
    super.initState();

    widget.expenses.sort((a, b) {
      int dateCmp = DateTime.parse(b['date']).compareTo(DateTime.parse(a['date']));  // group by date
      if (dateCmp != 0) {
        return dateCmp;
      }
      int idCmp = (a['id']).compareTo((b['id']));  // sort by id
      return idCmp;
      // int categoryCmp = (a['category']).compareTo((b['category']));
      // if (categoryCmp != 0) {
      //   return categoryCmp;
      // }
      // int valueCmp = (a['value']).compareTo((b['value']));
      // return valueCmp;
    });

    for (int i = 0; i < widget.expenses.length; i++) {
      _itemKeys[i] = GlobalKey();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.filter.date == null && widget.filter.category == null) {
        _scrollToToday();
      }
    });
  }

  void _scrollToToday() {
    DateTime now = DateTime.now();
    int? targetIndex;

    for (int i = 0; i < widget.expenses.length; i++) {
      DateTime expenseDate = DateTime.parse(widget.expenses[i]['date']);

      if (expenseDate.year == now.year &&
          expenseDate.month == now.month &&
          expenseDate.day == now.day) {
        targetIndex = i;
        break;
      } else if (expenseDate.isBefore(now)) {
        targetIndex = i;
        break;
      }
    }

    if (targetIndex != null && _itemKeys.containsKey(targetIndex)) {
      final context = _itemKeys[targetIndex]!.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  String _getCategoryName(int categoryId) {
    final category = widget.categories.firstWhere(
          (element) => element['id'] == categoryId,
      orElse: () => {'name': '–'},
    );
    return category['name'];
  }

  Widget _dateHeader(DateTime date) {
    final dateFormat = DateFormat('d.MM');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20.0, 20.0, 8.0, 8.0),
          child: Text(
            dateFormat.format(date),
            style: const TextStyle(
              fontSize: 18.0,
              //fontStyle: FontStyle.italic,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Divider(
          height: 0,
        )
      ]
    );
  }

  Widget _expenseListItemTitle(dynamic expense) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                  margin: const EdgeInsets.only(right: 8.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.indigo.shade50
                        : Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Text(
                    _getCategoryName(expense['category']),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).brightness == Brightness.light
                            ? Colors.grey.shade900
                            : Colors.grey.shade100),
                  ),
                ),
              ),
            ],
          ),
        ),

        Text(
          Formatters.currencyFormatter.format(expense['value']),
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
        ),
      ],
    );
  }

  Container _monthlyExpenseTag() {
    return Container(
      margin: const EdgeInsetsDirectional.fromSTEB(0, 4, 8, 4),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? Colors.indigo.shade50
            : Colors.grey.shade900,
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Icon(
        Icons.repeat,
        size: 16,
        color: Theme.of(context).brightness == Brightness.light
            ? Colors.grey.shade900
            : Colors.grey.shade100,
      ),
    );
  }

  Widget? _expenseListItemSubtitle(dynamic expense) {
    if ((expense['comment'] == null || expense['comment'].isEmpty) && !expense['is_monthly']) {
      return null;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        if (expense['is_monthly'])
          _monthlyExpenseTag(),
        Flexible(
          child: Text(
            expense['comment'],
            style: const TextStyle(fontStyle: FontStyle.italic),
          )
        )
      ],
    );
  }

  Widget _expenseListItem(dynamic expense) {
    return Slidable(
      key: Key(expense['id'].toString()),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) {
              // get copy of expense without id
              final expenseCopy = Map<String, dynamic>.from(expense);
              expenseCopy.remove('id');
              _showExpenseDetailsDialog(expenseCopy);
            },
            foregroundColor: Colors.indigo,
            backgroundColor: Theme.of(context).brightness == Brightness.light
                ? Colors.white
                : Colors.grey.shade900,
            icon: Icons.copy_rounded,
            label: AppLocalizations.of(context)!.copy,
          ),
          SlidableAction(
            onPressed: (context) {
              _showExpenseRemovalDialog(expense);
            },
            foregroundColor: Colors.red.shade900,
            backgroundColor: Theme.of(context).brightness == Brightness.light
                ? Colors.white
                : Colors.grey.shade900,
            icon: Icons.delete_rounded,
            label: AppLocalizations.of(context)!.remove,
          ),
        ],
      ),
      child: Builder(
        builder: (context) => InkWell(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0.0),
            title: _expenseListItemTitle(expense),
            subtitle: _expenseListItemSubtitle(expense)
          ),
          onTap: () {
            final controller = Slidable.of(context)!;
            final isClosed = controller.actionPaneType.value == ActionPaneType.none;
            if (isClosed) {
              _showExpenseDetailsDialog(expense);
            } else {
              controller.close();
            }
          },
        )
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final filterTitleParts =
    "${AppLocalizations.of(context)!.filteredExpenses}: ${[
      if (widget.filter.date != null)
        DateFormat("d.MM.yyyy").format(widget.filter.date!),
      if (widget.filter.category != null)
        _getCategoryName(widget.filter.category!)
    ].join(", ")}";

    final filteredExpenses = widget.expenses.where((expense) {
      if (widget.filter.date != null && DateTime.parse(expense['date']).difference(widget.filter.date!).inDays != 0) {
        return false;
      }
      if (widget.filter.category != null && expense['category'] != widget.filter.category) {
        return false;
      }
      return true;
    }).toList();

    return (widget.filter.date != null || widget.filter.category != null)
      ? Scaffold(
        appBar: AppBar(
          title: Text(
            filterTitleParts,
            style: const TextStyle(fontSize: 16),
          ),
          forceMaterialTransparency: true,
        ),
        body: _buildExpensesList(filteredExpenses)
      )
      : _buildExpensesList(filteredExpenses);
  }

  Widget _buildExpensesList(List<dynamic> filteredExpenses) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: filteredExpenses.length,
      padding: const EdgeInsets.only(bottom: 80),
      itemBuilder: (context, index) {
        final expense = filteredExpenses[index];
        bool showDateHeader = (index == 0 || filteredExpenses[index - 1]['date'] != expense['date']) && widget.filter.date == null;

        return Column(
          key: _itemKeys[index],
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showDateHeader)
              _dateHeader(DateTime.parse(expense['date'])),
            _expenseListItem(expense)
          ],
        );
      },
    );
  }

  void _showExpenseDetailsDialog(Map<String, dynamic>? expense) {
    Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ExpenseDetails(
          expense: expense,
          categories: widget.categories,
          monthId: widget.monthId,
          preferredCategoryId: expense != null ? expense['category'] : widget.filter.category,
          preferredDate: expense != null ? DateTime.parse(expense['date']) : widget.filter.date,
        ))
    ).then(
      (value) => setState(() {
        widget.refreshParent();
      })
    );
  }

  void _showExpenseRemovalDialog(Map<String, dynamic> expense) async {
    final title = AppLocalizations.of(context)!.alert;
    final api = AppScope.of(context).api;

    bool isLoading = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(title),
              content: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                    ),
                  Text(AppLocalizations.of(context)!.expenseRemoval)
                ],
              ),
              actions: isLoading
                  ? []
                  : [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppLocalizations.of(context)!.cancel),
                ),
                TextButton(
                  onPressed: () async {
                    setState(() {
                      isLoading = true;
                      errorMessage = null;
                    });

                    try {
                      await api.deleteExpense(expense['id'] as int);
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      widget.refreshParent();
                    } catch (e) {
                      setState(() {
                        isLoading = false;
                        errorMessage = AppLocalizations.of(context)!.errorSavingData;
                      });
                    }
                  },
                  child: Text(AppLocalizations.of(context)!.remove),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class ExpensesFilter {
  DateTime? date;
  int? category;

  ExpensesFilter({this.date, this.category});
}

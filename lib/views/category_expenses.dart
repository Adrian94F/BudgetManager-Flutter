import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../models/models.dart';
import 'expenses_list.dart';

/// One category's expenses of the month on screen, as the list shows them,
/// opened from a category in the cash flow. It sits above the Statistics
/// screen, so back returns to the diagram as it was.
class CategoryExpensesScreen extends StatelessWidget {
  const CategoryExpensesScreen({super.key, required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final months = AppScope.of(context).months;
    return Scaffold(
      appBar: AppBar(title: Text(category.name)),
      body: ListenableBuilder(
        listenable: months,
        builder: (context, _) {
          final data = months.data;
          if (data == null) return const SizedBox.shrink();
          return ExpensesListView(
            data: data,
            filter: ExpensesFilter(category: category.id),
            // The bar names the category; a chip would say it twice.
            showFilterChip: false,
          );
        },
      ),
    );
  }
}

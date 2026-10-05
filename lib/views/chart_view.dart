import 'package:flutter/material.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import '../app/app_scope.dart';
import 'widgets/month_burndown_chart.dart';

/// Full-screen burndown with the daily and recurring expense bars and a legend.
class ChartViewScreen extends StatelessWidget {
  const ChartViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final months = AppScope.of(context).months;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.burndownChart)),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: months,
          builder: (context, _) {
            final series = months.burndown;
            return Padding(
              padding: const EdgeInsets.all(16.0),
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
          },
        ),
      ),
    );
  }
}

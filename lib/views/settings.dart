import 'package:flutter/material.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import '../app/app_scope.dart';
import 'app_settings.dart';
import 'budget_settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.settings),
              title: Text(l10n.appSettings),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AppSettingsScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: Text(l10n.budgetSettings),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BudgetSettings()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(l10n.logOut),
              onTap: () => AppScope.of(context).auth.logout(),
            ),
          ],
        ),
      ),
    );
  }
}

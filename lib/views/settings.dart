import 'package:budget_manager/views/budget_settings.dart';
import 'package:flutter/material.dart';
import 'package:budget_manager/services/auth_service.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import 'app_settings.dart';

class SettingsScreen extends StatelessWidget {
  final AuthService _authService = AuthService();
  final Future<void> Function(String) setThemeMode;

  SettingsScreen({super.key, required this.setThemeMode});

  Future<void> _logout(BuildContext context) async {
    await _authService.logout();
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.settings),
              title: Text(AppLocalizations.of(context)!.appSettings),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AppSettingsScreen(setThemeMode: setThemeMode,)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: Text(AppLocalizations.of(context)!.budgetSettings),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BudgetSettings()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(AppLocalizations.of(context)!.logOut),
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),
    );
  }
}

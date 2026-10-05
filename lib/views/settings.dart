import 'package:flutter/material.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import '../app/app_scope.dart';
import 'app_settings.dart';
import 'budget_settings.dart';
import 'change_password_screen.dart';

/// Settings, opened from the top bar: app settings, budget settings
/// (currency, categories), password and sign-out.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    void push(Widget screen) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: EdgeInsets.only(
            top: 8, bottom: 8 + MediaQuery.paddingOf(context).bottom),
        children: [
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(l10n.appSettings),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => push(const AppSettingsScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: Text(l10n.budgetSettings),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => push(const BudgetSettingsScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: Text(l10n.changePassword),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => push(const ChangePasswordScreen()),
          ),
          const Divider(indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: Text(l10n.logOut),
            onTap: () => AppScope.of(context).auth.logout(),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import '../app/app_scope.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final _serverController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _serverController.text = AppScope.of(context).settings.serverUrl ?? '';
  }

  @override
  void dispose() {
    _serverController.dispose();
    super.dispose();
  }

  Future<void> _saveServerUrl() async {
    final services = AppScope.of(context);
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final newUrl = _serverController.text.trim();
    if (newUrl.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.urlCannotBeEmpty)));
      return;
    }
    await services.settings.setServerUrl(newUrl);
    messenger.showSnackBar(SnackBar(content: Text(l10n.urlUpdated)));
    // A new server means a new account: back to the root, which shows the login.
    navigator.popUntil((route) => route.isFirst);
    await services.auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = AppScope.of(context).settings;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appSettings),
        centerTitle: true,
      ),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Text(
              l10n.appereance,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: Text(l10n.theme),
              trailing: DropdownButton<ThemeMode>(
                value: settings.themeMode,
                items: [
                  DropdownMenuItem(value: ThemeMode.light, child: Text(l10n.lightTheme)),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text(l10n.darkTheme)),
                  DropdownMenuItem(value: ThemeMode.system, child: Text(l10n.systemTheme)),
                ],
                onChanged: (value) {
                  if (value != null) settings.setThemeMode(value);
                },
              ),
            ),
            const SizedBox(height: 32),
            Text(
              l10n.connection,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _serverController,
              decoration: InputDecoration(
                labelText: l10n.serverUrl,
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saveServerUrl,
              child: Text(l10n.saveServerUrl),
            ),
          ],
        ),
      ),
    );
  }
}

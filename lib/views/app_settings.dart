import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import '../app/app_scope.dart';

/// Theme, dynamic colour and server URL.
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
    final theme = Theme.of(context);
    final settings = AppScope.of(context).settings;
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appSettings)),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          children: [
            _SectionTitle(l10n.appereance),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(value: ThemeMode.light, icon: const Icon(Icons.light_mode_outlined), label: Text(l10n.lightTheme)),
                  ButtonSegment(value: ThemeMode.dark, icon: const Icon(Icons.dark_mode_outlined), label: Text(l10n.darkTheme)),
                  ButtonSegment(value: ThemeMode.system, icon: const Icon(Icons.brightness_auto_outlined), label: Text(l10n.systemTheme)),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (selection) => settings.setThemeMode(selection.first),
              ),
            ),
            if (isAndroid)
              SwitchListTile(
                secondary: const Icon(Icons.wallpaper_outlined),
                title: Text(l10n.dynamicColor),
                subtitle: Text(l10n.dynamicColorHint),
                value: settings.useDynamicColor,
                onChanged: settings.setDynamicColor,
              ),
            const SizedBox(height: 16),
            _SectionTitle(l10n.language),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'system', icon: const Icon(Icons.language_outlined), label: Text(l10n.languageSystem)),
                  const ButtonSegment(value: 'en', label: Text('English')),
                  const ButtonSegment(value: 'pl', label: Text('Polski')),
                ],
                selected: {settings.locale?.languageCode ?? 'system'},
                onSelectionChanged: (selection) {
                  final value = selection.first;
                  settings.setLocale(value == 'system' ? null : Locale(value));
                },
              ),
            ),
            const SizedBox(height: 16),
            _SectionTitle(l10n.connection),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _serverController,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: l10n.serverUrl,
                      prefixIcon: const Icon(Icons.dns_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: _saveServerUrl,
                    child: Text(l10n.saveServerUrl),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Budget Manager',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
    );
  }
}

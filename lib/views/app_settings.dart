import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

class AppSettingsScreen extends StatefulWidget {
  final Future<void> Function(String) setThemeMode;

  const AppSettingsScreen({super.key, required this.setThemeMode});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final TextEditingController _serverController = TextEditingController();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String _currentTheme = "system";

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final theme = await _storage.read(key: "theme_mode") ?? "system";
    setState(() {
      _currentTheme = theme;
    });

    final serverUrl = await _storage.read(key: 'server_url');
    _serverController.text = serverUrl ?? '';
  }

  Future<void> _saveTheme(String theme) async {
    await _storage.write(key: "theme_mode", value: theme);
    widget.setThemeMode(theme);
  }

  Future<void> _saveServerUrl(BuildContext context) async {
    final newUrl = _serverController.text.trim();
    if (newUrl.isNotEmpty) {
      await _storage.write(key: 'server_url', value: newUrl);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.urlUpdated)),
      );
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.urlCannotBeEmpty)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.appSettings),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:
            _appearenceSettings() + _connectionSettings(),
        ),
      ),
    );
  }

  List<Widget> _appearenceSettings() {
    return [
      Text(
        AppLocalizations.of(context)!.appereance,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 16),
      ListTile(
        title: Text(AppLocalizations.of(context)!.theme),
        trailing: DropdownButton<String>(
          value: _currentTheme,
          items: [
            DropdownMenuItem(
              value: "light",
              child: Text(AppLocalizations.of(context)!.lightTheme),
            ),
            DropdownMenuItem(
              value: "dark",
              child: Text(AppLocalizations.of(context)!.darkTheme),
            ),
            DropdownMenuItem(
              value: "system",
              child: Text(AppLocalizations.of(context)!.systemTheme),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _currentTheme = value;
              });
              _saveTheme(value);
            }
          },
        ),
      ),
      const SizedBox(height: 32),
    ];
  }

  List<Widget> _connectionSettings() {
    return [
      Text(
        AppLocalizations.of(context)!.connection,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _serverController,
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context)!.serverUrl,
          border: const OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 16),
      ElevatedButton(
        onPressed: () => _saveServerUrl(context),
        child: Text(AppLocalizations.of(context)!.saveServerUrl),
      ),
      const SizedBox(height: 32),
    ];
  }
}

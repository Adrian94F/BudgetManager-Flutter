import 'package:flutter/material.dart';

import '../api/api.dart';

/// App settings kept on the device: theme, dynamic colour and server URL.
class SettingsController extends ChangeNotifier {
  SettingsController(this._session);

  final SessionStore _session;

  ThemeMode _themeMode = ThemeMode.system;
  bool _useDynamicColor = false;
  String? _serverUrl;

  ThemeMode get themeMode => _themeMode;
  bool get useDynamicColor => _useDynamicColor;

  /// The configured server URL, or null for the default server.
  String? get serverUrl => _serverUrl;

  Future<void> load() async {
    _themeMode = parseThemeMode(await _session.themeMode());
    _useDynamicColor = await _session.dynamicColor();
    _serverUrl = await _session.serverUrl();
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _session.setThemeMode(themeModeName(mode));
  }

  Future<void> setDynamicColor(bool enabled) async {
    _useDynamicColor = enabled;
    notifyListeners();
    await _session.setDynamicColor(enabled);
  }

  Future<void> setServerUrl(String? url) async {
    final trimmed = url?.trim();
    _serverUrl = trimmed == null || trimmed.isEmpty ? null : trimmed;
    notifyListeners();
    await _session.setServerUrl(_serverUrl);
  }

  static ThemeMode parseThemeMode(String? name) => switch (name) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static String themeModeName(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
}

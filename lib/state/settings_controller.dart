import 'package:flutter/material.dart';

import '../api/api.dart';

/// App settings kept on the device: theme, dynamic colour and language.
class SettingsController extends ChangeNotifier {
  SettingsController(this._session);

  final SessionStore _session;

  /// The languages the app ships; the picker lists them in this order.
  static const supportedLocales = [Locale('en'), Locale('pl')];

  ThemeMode _themeMode = ThemeMode.system;
  bool _useDynamicColor = false;
  Locale? _locale;

  ThemeMode get themeMode => _themeMode;
  bool get useDynamicColor => _useDynamicColor;

  /// The language chosen in the app, or null to follow the system (which on
  /// Android 13+ includes the per-app language setting).
  Locale? get locale => _locale;

  Future<void> load() async {
    _themeMode = parseThemeMode(await _session.themeMode());
    _useDynamicColor = await _session.dynamicColor();
    _locale = parseLocale(await _session.locale());
    notifyListeners();
  }

  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    notifyListeners();
    await _session.setLocale(locale?.toLanguageTag());
  }

  static Locale? parseLocale(String? languageTag) {
    if (languageTag == null || languageTag.isEmpty) return null;
    final language = languageTag.split(RegExp('[-_]')).first;
    for (final supported in supportedLocales) {
      if (supported.languageCode == language) return supported;
    }
    return null;
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

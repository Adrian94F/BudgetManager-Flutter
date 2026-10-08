import 'package:flutter/material.dart';

import '../api/api.dart';

/// App settings kept on the device: theme, dynamic colour, language,
/// whether the cash flow diagram includes the recurring expenses and which
/// categories it hides.
class SettingsController extends ChangeNotifier {
  SettingsController(this._session);

  final SessionStore _session;

  /// The languages the app ships; the picker lists them in this order.
  static const supportedLocales = [Locale('en'), Locale('pl')];

  ThemeMode _themeMode = ThemeMode.system;
  bool _useDynamicColor = false;
  Locale? _locale;
  bool _includeRecurringInFlow = true;
  Set<int> _hiddenFlowCategoryIds = const {};

  ThemeMode get themeMode => _themeMode;
  bool get useDynamicColor => _useDynamicColor;

  /// The language chosen in the app, or null to follow the system (which on
  /// Android 13+ includes the per-app language setting).
  Locale? get locale => _locale;

  /// Whether the cash flow diagram has the recurring expenses in (the web
  /// page's "Include monthly expenses" switch).
  bool get includeRecurringInFlow => _includeRecurringInFlow;

  /// The categories the cash flow diagram leaves out (the web page's
  /// "Categories" filter). Kept by id across months, as on the web, so a
  /// category hidden once stays hidden wherever it has spending.
  Set<int> get hiddenFlowCategoryIds => _hiddenFlowCategoryIds;

  Future<void> load() async {
    _themeMode = parseThemeMode(await _session.themeMode());
    _useDynamicColor = await _session.dynamicColor();
    _locale = parseLocale(await _session.locale());
    _includeRecurringInFlow = await _session.flowIncludesRecurring();
    _hiddenFlowCategoryIds =
        Set.unmodifiable(await _session.flowHiddenCategories());
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

  Future<void> setIncludeRecurringInFlow(bool enabled) async {
    _includeRecurringInFlow = enabled;
    notifyListeners();
    await _session.setFlowIncludesRecurring(enabled);
  }

  /// Hides the category [id] from the cash flow diagram, or shows it again.
  Future<void> setFlowCategoryHidden(int id, bool hidden) {
    final ids = {..._hiddenFlowCategoryIds};
    if (hidden) {
      ids.add(id);
    } else {
      ids.remove(id);
    }
    return _setHiddenFlowCategories(ids);
  }

  /// Shows every category in the cash flow diagram again ("Select all").
  Future<void> showAllFlowCategories() => _setHiddenFlowCategories({});

  Future<void> _setHiddenFlowCategories(Set<int> ids) async {
    _hiddenFlowCategoryIds = Set.unmodifiable(ids);
    notifyListeners();
    await _session.setFlowHiddenCategories(ids);
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

import 'key_value_store.dart';

/// Typed access to what the app keeps on the device: tokens, remembered
/// credentials and settings. The keys are the ones the app has always
/// used, so an upgrade keeps users logged in.
class SessionStore {
  SessionStore(this._store);

  final KeyValueStore _store;

  static const accessTokenKey = 'access_token';
  static const refreshTokenKey = 'refresh_token';
  static const usernameKey = 'login';
  static const passwordKey = 'password';
  static const themeModeKey = 'theme_mode';
  static const dynamicColorKey = 'dynamic_color';
  static const localeKey = 'locale';

  Future<String?> accessToken() => _store.read(accessTokenKey);

  Future<String?> refreshToken() => _store.read(refreshTokenKey);

  Future<bool> hasSession() async =>
      await accessToken() != null || await refreshToken() != null;

  /// Stores a new access token and, when the server rotated it, the new
  /// refresh token. The previous refresh token is blacklisted server-side,
  /// so dropping the rotated one would end the session at the next refresh.
  Future<void> saveTokens({required String access, String? refresh}) async {
    await _store.write(accessTokenKey, access);
    if (refresh != null) await _store.write(refreshTokenKey, refresh);
  }

  Future<void> clearTokens() async {
    await _store.delete(accessTokenKey);
    await _store.delete(refreshTokenKey);
  }

  Future<({String username, String password})?> savedCredentials() async {
    final username = await _store.read(usernameKey);
    final password = await _store.read(passwordKey);
    if (username == null || password == null) return null;
    return (username: username, password: password);
  }

  Future<String?> savedUsername() => _store.read(usernameKey);

  Future<void> saveCredentials({required String username, required String password}) async {
    await _store.write(usernameKey, username);
    await _store.write(passwordKey, password);
  }

  Future<void> clearCredentials() async {
    await _store.delete(usernameKey);
    await _store.delete(passwordKey);
  }

  Future<String?> themeMode() => _store.read(themeModeKey);

  Future<void> setThemeMode(String mode) => _store.write(themeModeKey, mode);

  Future<bool> dynamicColor() async => await _store.read(dynamicColorKey) == 'true';

  Future<void> setDynamicColor(bool enabled) => _store.write(dynamicColorKey, enabled.toString());

  /// A language tag such as `pl`, or null to follow the system.
  Future<String?> locale() => _store.read(localeKey);

  Future<void> setLocale(String? languageTag) =>
      languageTag == null ? _store.delete(localeKey) : _store.write(localeKey, languageTag);
}

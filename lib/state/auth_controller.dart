import 'package:flutter/foundation.dart';

import '../api/api.dart';

enum LoginFailure { invalidCredentials, serverUnavailable, other }

/// Login state: whether a session exists, the remembered credentials and
/// the outcome of the last login attempt.
class AuthController extends ChangeNotifier {
  AuthController({required ApiClient api, required SessionStore session})
      : _api = api,
        _session = session;

  final ApiClient _api;
  final SessionStore _session;

  bool _isLoggedIn = false;
  bool _isBusy = false;
  bool _sessionExpired = false;
  LoginFailure? _failure;
  String? _failureDetail;
  bool _rememberMe = false;
  String _savedUsername = '';
  String _savedPassword = '';

  bool get isLoggedIn => _isLoggedIn;
  bool get isBusy => _isBusy;

  /// True after the server rejected the session and the user was signed out.
  bool get sessionExpired => _sessionExpired;
  LoginFailure? get failure => _failure;

  /// The server's message behind a [LoginFailure.other].
  String? get failureDetail => _failureDetail;
  bool get rememberMe => _rememberMe;
  String get savedUsername => _savedUsername;
  String get savedPassword => _savedPassword;

  /// Reads the stored session and credentials. No network: the first frame
  /// is not delayed, and the first request refreshes the tokens if needed.
  Future<void> initialize() async {
    _isLoggedIn = await _session.hasSession();
    final credentials = await _session.savedCredentials();
    if (credentials != null) {
      _rememberMe = true;
      _savedUsername = credentials.username;
      _savedPassword = credentials.password;
    }
    notifyListeners();
  }

  /// Logs in and, when [rememberMe] is set, keeps the credentials for the
  /// silent re-login that runs after a rejected refresh. Returns success;
  /// the failure reason is in [failure].
  Future<bool> login(
      {required String username,
      required String password,
      required bool rememberMe}) async {
    _isBusy = true;
    _failure = null;
    _failureDetail = null;
    _sessionExpired = false;
    notifyListeners();
    try {
      await _api.login(username: username, password: password);
      _rememberMe = rememberMe;
      if (rememberMe) {
        await _session.saveCredentials(username: username, password: password);
        _savedUsername = username;
        _savedPassword = password;
      } else {
        await _session.clearCredentials();
        _savedUsername = '';
        _savedPassword = '';
      }
      _isLoggedIn = true;
      return true;
    } on ApiException catch (e) {
      _failure = e.isAuth
          ? LoginFailure.invalidCredentials
          : e.isNetwork
              ? LoginFailure.serverUnavailable
              : LoginFailure.other;
      _failureDetail = e.message;
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _api.logout();
    _isLoggedIn = false;
    _sessionExpired = false;
    notifyListeners();
  }

  /// Called by the API client once refresh and re-login have both failed.
  void markSessionExpired() {
    if (!_isLoggedIn) return;
    _isLoggedIn = false;
    _sessionExpired = true;
    notifyListeners();
  }
}

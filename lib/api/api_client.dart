import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import '../tools/dates.dart';
import 'api_exception.dart';
import 'session_store.dart';

/// The Budget Manager REST API, one method per endpoint.
///
/// Every call carries the Bearer token. A 401 triggers one shared
/// re-authentication (token refresh, then a silent re-login with the
/// remembered credentials) and the request is replayed once; the session is
/// cleared only when both fail with a definitive answer. A connection
/// problem surfaces as an [ApiException] of kind network and never logs the
/// user out.
class ApiClient {
  static const defaultBaseUrl = 'https://budget.frydmanski.cc';
  static const requestTimeout = Duration(seconds: 20);

  ApiClient({
    required this.session,
    http.Client? httpClient,
    this.onSessionExpired,
  }) : _http = httpClient ?? http.Client();

  final SessionStore session;
  final http.Client _http;

  /// Called when re-authentication failed and the tokens were cleared.
  final void Function()? onSessionExpired;

  Future<bool>? _reauthFuture;

  // MARK: - Session

  /// Logs in and stores the tokens. Throws an [ApiException] of kind auth
  /// for wrong credentials and of kind network when the server is unreachable.
  Future<void> login({required String username, required String password}) async {
    final response = await _send(
      'POST',
      'token/',
      body: {'username': username, 'password': password},
      authenticated: false,
    );
    final json = _decode(response) as Map<String, dynamic>;
    await session.saveTokens(access: json['access'] as String, refresh: json['refresh'] as String?);
  }

  /// Refreshes the session at launch or on resume. Returns whether the app
  /// should treat the user as logged in. A connection problem keeps the
  /// session: the next request will report the network error instead.
  Future<bool> ensureSession() async {
    if (!await session.hasSession()) return false;
    try {
      return await _reauthenticate();
    } on ApiException catch (e) {
      if (e.isNetwork) return true;
      rethrow;
    }
  }

  Future<void> logout() => session.clearTokens();

  // MARK: - Months

  Future<MonthData> fetchMonth({int? monthId}) async {
    final response = await _send(
      'GET',
      'month/',
      query: monthId == null ? null : {'month_id': '$monthId'},
    );
    return MonthData.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<void> createMonth({required DateTime start, required DateTime end}) =>
      _send('POST', 'month/', body: {
        'start_date': Dates.formatApi(start),
        'end_date': Dates.formatApi(end),
      });

  Future<void> updateMonth({required int id, required DateTime start, required DateTime end}) =>
      _send('POST', 'month/', body: {
        'id': id,
        'start_date': Dates.formatApi(start),
        'end_date': Dates.formatApi(end),
      });

  /// Deletes a month; the server refuses (400) when it still has expenses.
  Future<void> deleteMonth(int id) => _send('DELETE', 'month/', body: {'id': id});

  Future<void> savePlannedSavings(double value) =>
      _send('POST', 'planned-savings/', body: {'planned_savings': value});

  // MARK: - Incomes

  Future<void> createIncome({
    required int monthId,
    required double value,
    required DateTime date,
    String comment = '',
    required bool isSalary,
  }) =>
      _send('POST', 'income/', body: _incomeBody(null, monthId, value, date, comment, isSalary));

  Future<void> updateIncome({
    required int id,
    required int monthId,
    required double value,
    required DateTime date,
    String comment = '',
    required bool isSalary,
  }) =>
      _send('POST', 'income/', body: _incomeBody(id, monthId, value, date, comment, isSalary));

  Future<void> deleteIncome(int id) => _send('DELETE', 'income/', body: {'id': id});

  Map<String, dynamic> _incomeBody(int? id, int monthId, double value, DateTime date, String comment, bool isSalary) => {
        if (id != null) 'id': id,
        'month': monthId,
        'value': value,
        'date': Dates.formatApi(date),
        'comment': comment,
        'is_salary': isSalary,
      };

  // MARK: - Expenses

  Future<void> createExpense({
    required int monthId,
    required double value,
    required DateTime date,
    required int categoryId,
    String comment = '',
    required bool isMonthly,
  }) =>
      _send('POST', 'expense/', body: _expenseBody(null, monthId, value, date, categoryId, comment, isMonthly));

  Future<void> updateExpense({
    required int id,
    required int monthId,
    required double value,
    required DateTime date,
    required int categoryId,
    String comment = '',
    required bool isMonthly,
  }) =>
      _send('POST', 'expense/', body: _expenseBody(id, monthId, value, date, categoryId, comment, isMonthly));

  Future<void> deleteExpense(int id) => _send('DELETE', 'expense/', body: {'id': id});

  Map<String, dynamic> _expenseBody(
          int? id, int monthId, double value, DateTime date, int categoryId, String comment, bool isMonthly) =>
      {
        if (id != null) 'id': id,
        'month': monthId,
        'value': value,
        'date': Dates.formatApi(date),
        'category': categoryId,
        'comment': comment,
        'is_monthly': isMonthly,
      };

  // MARK: - Categories

  Future<List<Category>> fetchCategories() async {
    final response = await _send('GET', 'category/');
    final list = _decode(response) as List<dynamic>;
    return list.map((c) => Category.fromJson(c as Map<String, dynamic>)).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
  }

  Future<void> createCategory(String name) => _send('POST', 'category/', body: {'name': name});

  Future<void> updateCategory({required int id, required String name}) =>
      _send('POST', 'category/', body: {'id': id, 'name': name});

  /// Deletes a category together with every expense in it, in all months.
  Future<void> deleteCategory(int id) => _send('DELETE', 'category/', body: {'id': id});

  Future<void> reorderCategories(List<Category> ordered) => _send(
        'POST',
        'categories/order/',
        body: [
          for (var i = 0; i < ordered.length; i++) {'id': ordered[i].id, 'position': i + 1},
        ],
      );

  // MARK: - Account

  /// The user's currency and the codes the server accepts.
  Future<CurrencySettings> fetchCurrency() async {
    final response = await _send('GET', 'currency/');
    return CurrencySettings.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<void> setCurrency(String code) => _send('POST', 'currency/', body: {'currency': code});

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) =>
      _send('POST', 'change-password/', body: {
        'old_password': oldPassword,
        'new_password1': newPassword,
        'new_password2': newPasswordConfirmation,
      });

  // MARK: - Transport

  /// `https://host[/prefix]`, without a trailing slash or `/api`.
  static String normalizeBaseUrl(String? url) {
    var value = (url ?? '').trim();
    if (value.isEmpty) return defaultBaseUrl;
    if (!value.contains('://')) value = 'https://$value';
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    if (value.endsWith('/api')) value = value.substring(0, value.length - 4);
    return value;
  }

  Future<Uri> uriFor(String path, [Map<String, String>? query]) async {
    final base = normalizeBaseUrl(await session.serverUrl());
    final uri = Uri.parse('$base/api/$path');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
    bool allowRetry = true,
  }) async {
    final request = http.Request(method, await uriFor(path, query));
    request.headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    if (authenticated) {
      final token = await session.accessToken();
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
    }

    http.Response response;
    try {
      final streamed = await _http.send(request).timeout(requestTimeout);
      response = await http.Response.fromStream(streamed);
    } on SocketException catch (e) {
      throw ApiException.network(e.message);
    } on HandshakeException catch (e) {
      throw ApiException.network(e.message);
    } on http.ClientException catch (e) {
      throw ApiException.network(e.message);
    } on TimeoutException {
      throw ApiException.network('Timed out after ${requestTimeout.inSeconds}s');
    }

    if (response.statusCode == 401 && authenticated && allowRetry) {
      if (await _reauthenticate()) {
        return _send(method, path, body: body, query: query, authenticated: true, allowRetry: false);
      }
      throw ApiException.fromResponse(response);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromResponse(response);
    }
    return response;
  }

  Object? _decode(http.Response response) {
    if (response.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException catch (e) {
      throw ApiException(kind: ApiErrorKind.server, statusCode: response.statusCode, message: 'Unreadable response: ${e.message}');
    }
  }

  /// One re-authentication at a time: concurrent 401s wait for the same
  /// attempt, because the server rotates and blacklists refresh tokens and
  /// parallel refreshes would invalidate each other.
  Future<bool> _reauthenticate() {
    final inFlight = _reauthFuture;
    if (inFlight != null) return inFlight;
    final attempt = _performReauthentication();
    _reauthFuture = attempt;
    // Callers observe the error on `attempt` itself; the derived future
    // only resets the slot and must not surface the error a second time.
    attempt.whenComplete(() => _reauthFuture = null).ignore();
    return attempt;
  }

  Future<bool> _performReauthentication() async {
    if (await _refreshTokens()) return true;
    if (await _reloginWithSavedCredentials()) return true;
    await session.clearTokens();
    onSessionExpired?.call();
    return false;
  }

  /// False when the server rejected the refresh token; network errors propagate.
  Future<bool> _refreshTokens() async {
    final refresh = await session.refreshToken();
    if (refresh == null) return false;
    try {
      final response = await _send('POST', 'token/refresh/', body: {'refresh': refresh}, authenticated: false);
      final json = _decode(response) as Map<String, dynamic>;
      await session.saveTokens(access: json['access'] as String, refresh: json['refresh'] as String?);
      return true;
    } on ApiException catch (e) {
      if (e.isNetwork) rethrow;
      return false;
    }
  }

  Future<bool> _reloginWithSavedCredentials() async {
    final credentials = await session.savedCredentials();
    if (credentials == null) return false;
    try {
      await login(username: credentials.username, password: credentials.password);
      return true;
    } on ApiException catch (e) {
      if (e.isNetwork) rethrow;
      return false;
    }
  }
}

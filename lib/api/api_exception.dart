import 'dart:convert';

import 'package:http/http.dart' as http;

enum ApiErrorKind {
  /// No connection, DNS failure, timeout, TLS problem.
  network,

  /// 401: the credentials or the session are not valid.
  auth,

  /// 4xx other than 401: the server rejected the request.
  client,

  /// 5xx, or a response the app could not read.
  server,
}

/// A failed API call with the most useful message the server sent.
///
/// DRF answers with several envelopes: `{"detail": "..."}`, `{"error":
/// "..."}`, `{"non_field_errors": [...]}` or a dict of field errors such as
/// `{"category": ["Invalid category."]}`. [message] is the first message
/// found, in that order; [fieldErrors] keeps the per-field ones for forms.
class ApiException implements Exception {
  final ApiErrorKind kind;
  final int? statusCode;
  final String message;
  final Map<String, String> fieldErrors;

  /// A machine-readable reason the server adds where the app shows its own
  /// wording, e.g. `category_has_expenses`.
  final String? code;

  const ApiException({
    required this.kind,
    this.statusCode,
    required this.message,
    this.fieldErrors = const {},
    this.code,
  });

  ApiException.network(String detail)
      : this(kind: ApiErrorKind.network, message: detail);

  factory ApiException.fromResponse(http.Response response) {
    Object? decoded;
    try {
      decoded =
          jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
    } catch (_) {
      decoded = null;
    }
    final status = response.statusCode;
    final kind = status == 401
        ? ApiErrorKind.auth
        : status >= 500
            ? ApiErrorKind.server
            : ApiErrorKind.client;
    return ApiException(
      kind: kind,
      statusCode: status,
      message: extractMessage(decoded) ?? 'HTTP $status',
      fieldErrors: extractFieldErrors(decoded),
      code: decoded is Map && decoded['code'] is String
          ? decoded['code'] as String
          : null,
    );
  }

  bool get isNetwork => kind == ApiErrorKind.network;
  bool get isAuth => kind == ApiErrorKind.auth;

  static const _preferredKeys = [
    'detail',
    'error',
    'message',
    'non_field_errors'
  ];

  static String? extractMessage(Object? decoded) {
    if (decoded is Map) {
      for (final key in _preferredKeys) {
        final message = _firstMessage(decoded[key]);
        if (message != null) return message;
      }
      for (final value in decoded.values) {
        final message = _firstMessage(value);
        if (message != null) return message;
      }
      return null;
    }
    return _firstMessage(decoded);
  }

  static Map<String, String> extractFieldErrors(Object? decoded) {
    if (decoded is! Map) return const {};
    final errors = <String, String>{};
    for (final entry in decoded.entries) {
      final key = entry.key.toString();
      if (_preferredKeys.contains(key)) continue;
      final message = _firstMessage(entry.value);
      if (message != null) errors[key] = message;
    }
    return errors;
  }

  static String? _firstMessage(Object? value) {
    if (value is String) return value.isEmpty ? null : value;
    if (value is List) {
      for (final item in value) {
        final message = _firstMessage(item);
        if (message != null) return message;
      }
    }
    return null;
  }

  @override
  String toString() => 'ApiException($kind, $statusCode, $message)';
}

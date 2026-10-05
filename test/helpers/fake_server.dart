import 'dart:convert';

import 'package:budget_manager/tools/dates.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// An in-memory stand-in for the Budget Manager REST API, enough for widget
/// tests: login, the month response, expense and income writes, categories
/// and planned savings. Months are built around today so the fixtures stay
/// valid whenever the tests run.
class FakeServer {
  FakeServer({this.password = 'secret'}) {
    final today = Dates.today();
    final currentStart = DateTime(today.year, today.month, 1);
    final currentEnd = DateTime(today.year, today.month + 1, 0);
    final previousStart = DateTime(today.year, today.month - 1, 1);
    final previousEnd = DateTime(today.year, today.month, 0);
    months = [
      {'id': 11, 'start_date': Dates.formatApi(currentStart), 'end_date': Dates.formatApi(currentEnd)},
      {'id': 10, 'start_date': Dates.formatApi(previousStart), 'end_date': Dates.formatApi(previousEnd)},
    ];
    incomes = {
      11: [
        {'id': 1, 'value': 5000.0, 'date': Dates.formatApi(currentStart), 'comment': '', 'is_salary': true},
      ],
      10: [],
    };
    expenses = {
      11: [
        {
          'id': 1,
          'value': 120.0,
          'date': Dates.formatApi(currentStart),
          'comment': 'Weekly shop',
          'category': 1,
          'is_monthly': false,
        },
      ],
      10: [],
    };
  }

  final String password;
  late final List<Map<String, dynamic>> months;
  late final Map<int, List<Map<String, dynamic>>> incomes;
  late final Map<int, List<Map<String, dynamic>>> expenses;
  final List<Map<String, dynamic>> categories = [
    {'id': 1, 'name': 'Groceries', 'position': 1},
    {'id': 2, 'name': 'Transport', 'position': 2},
  ];
  double plannedSavings = 0;
  String currency = 'PLN';
  final List<Map<String, dynamic>> currencyChoices = [
    {'code': 'PLN', 'name': 'Polish złoty'},
    {'code': 'EUR', 'name': 'Euro'},
    {'code': 'CHF', 'name': 'Swiss franc'},
  ];
  int defaultMonthId = 11;
  int _nextId = 1000;

  /// Every request received, oldest first.
  final List<http.Request> requests = [];

  /// How many times a month was fetched.
  int get monthLoads => requests.where((r) => r.method == 'GET' && r.url.path == '/api/month/').length;

  http.Client get client => MockClient(_handle);

  Map<String, dynamic> get currentMonth => months.firstWhere((m) => m['id'] == 11);

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    if (path == '/api/token/') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (body['password'] != password) {
        return _json({'detail': 'No active account found with the given credentials'}, 401);
      }
      return _json({'access': 'access-1', 'refresh': 'refresh-1'});
    }
    if (path == '/api/token/refresh/') {
      return _json({'access': 'access-2', 'refresh': 'refresh-2'});
    }
    if (request.headers['Authorization'] == null) {
      return _json({'detail': 'Authentication credentials were not provided.'}, 401);
    }
    switch (path) {
      case '/api/month/':
        return _month(request);
      case '/api/expense/':
        return _entry(request, expenses);
      case '/api/income/':
        return _entry(request, incomes);
      case '/api/category/':
        return _json(categories);
      case '/api/planned-savings/':
        plannedSavings = (jsonDecode(request.body)['planned_savings'] as num).toDouble();
        return _json({'planned_savings': plannedSavings});
      case '/api/currency/':
        if (request.method == 'POST') {
          final code = jsonDecode(request.body)['currency'] as String?;
          if (!currencyChoices.any((c) => c['code'] == code)) return _json({'detail': 'Invalid currency.'}, 400);
          currency = code!;
        }
        return _json({'currency': currency, 'choices': currencyChoices});
    }
    return _json({'detail': 'Not found.'}, 404);
  }

  http.Response _month(http.Request request) {
    if (request.method == 'GET') {
      final idParam = request.url.queryParameters['month_id'];
      final id = idParam == null ? defaultMonthId : int.parse(idParam);
      final month = months.firstWhere((m) => m['id'] == id, orElse: () => const {});
      if (month.isEmpty) return http.Response('<html>Server Error (500)</html>', 500);
      final sorted = [...months]..sort((a, b) => (b['start_date'] as String).compareTo(a['start_date'] as String));
      return _json({
        'months': sorted,
        'categories': categories,
        'month': month,
        'incomes': incomes[id] ?? [],
        'expenses': expenses[id] ?? [],
        'planned_savings': plannedSavings,
        'currency': currency,
      });
    }
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    if (request.method == 'DELETE') {
      months.removeWhere((m) => m['id'] == body['id']);
      return http.Response('', 204);
    }
    if (body['id'] != null) {
      final month = months.firstWhere((m) => m['id'] == body['id']);
      month['start_date'] = body['start_date'];
      month['end_date'] = body['end_date'];
      return _json(month);
    }
    final id = _nextId++;
    months.add({'id': id, 'start_date': body['start_date'], 'end_date': body['end_date']});
    incomes[id] = [];
    expenses[id] = [];
    return _json({'id': id, 'start_date': body['start_date'], 'end_date': body['end_date']}, 201);
  }

  http.Response _entry(http.Request request, Map<int, List<Map<String, dynamic>>> store) {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    if (request.method == 'DELETE') {
      for (final list in store.values) {
        list.removeWhere((e) => e['id'] == body['id']);
      }
      return http.Response('', 204);
    }
    final monthId = body['month'] as int;
    final list = store.putIfAbsent(monthId, () => []);
    if (body['id'] != null) {
      final entry = list.firstWhere((e) => e['id'] == body['id']);
      entry.addAll(body..remove('month'));
      return _json(body);
    }
    final entry = {...body, 'id': _nextId++}..remove('month');
    list.add(entry);
    return _json(entry, 201);
  }

  static http.Response _json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});
}

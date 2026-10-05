import 'dart:convert';
import 'dart:io';

import 'package:budget_manager/api/api.dart';
import 'package:budget_manager/state/month_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> monthJson(int id) => switch (id) {
      13 => {'id': 13, 'start_date': '2026-11-26', 'end_date': '2026-12-25'},
      12 => {'id': 12, 'start_date': '2026-10-26', 'end_date': '2026-11-25'},
      11 => {'id': 11, 'start_date': '2026-09-26', 'end_date': '2026-10-25'},
      _ => {'id': 10, 'start_date': '2026-08-26', 'end_date': '2026-09-25'},
    };

Map<String, dynamic> response(int monthId, {bool withNewest = false}) => {
      'months': [
        if (withNewest) monthJson(13),
        monthJson(12),
        monthJson(11),
        monthJson(10)
      ],
      'categories': [
        {'id': 1, 'name': 'Food', 'position': 1},
      ],
      'month': monthJson(monthId),
      'incomes': [
        {
          'id': 1,
          'value': 3000.0,
          'date': '2026-09-26',
          'comment': '',
          'is_salary': true
        },
      ],
      'expenses': [
        {
          'id': 1,
          'value': 100.0,
          'date': '2026-09-27',
          'comment': '',
          'category': 1,
          'is_monthly': false
        },
      ],
      'planned_savings': 500.0,
    };

http.Response json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

int? requestedMonthId(http.Request request) {
  final value = request.url.queryParameters['month_id'];
  return value == null ? null : int.parse(value);
}

void main() {
  late SessionStore session;
  late List<http.Request> requests;

  MonthController controller(
      Future<http.Response> Function(http.Request) handler) {
    final api = ApiClient(
      session: session,
      httpClient: MockClient((request) async {
        requests.add(request);
        return handler(request);
      }),
    );
    return MonthController(api);
  }

  setUp(() async {
    session = SessionStore(InMemoryKeyValueStore());
    await session.saveTokens(access: 'A', refresh: 'R');
    requests = [];
  });

  test('loads the default month and exposes typed data and figures', () async {
    final months =
        controller((r) async => json(response(requestedMonthId(r) ?? 11)));
    final notifications = <bool>[];
    months.addListener(() => notifications.add(months.isLoading));

    expect(months.hasData, isFalse);
    await months.load();

    expect(months.hasData, isTrue);
    expect(months.month!.id, 11);
    expect(months.data!.months.map((m) => m.id), [12, 11, 10]);
    expect(months.data!.plannedSavings, 500.0);
    expect(months.summary.allIncomes, 3000);
    expect(months.burndown.startingBalance, 3000);
    expect(months.isLoading, isFalse);
    expect(months.isRefreshing, isFalse);
    expect(months.error, isNull);
    expect(notifications, [true, false]);
  });

  test('reports an error when the first load fails', () async {
    final months = controller(
        (_) async => http.Response('<html>Server Error</html>', 500));

    await months.load();

    expect(months.hasData, isFalse);
    expect(months.isLoading, isFalse);
    expect(months.error?.kind, ApiErrorKind.server);
  });

  test('keeps the data on screen when a refresh fails', () async {
    var failing = false;
    final months = controller((r) async {
      if (failing) throw const SocketException('offline');
      return json(response(requestedMonthId(r) ?? 11));
    });
    await months.load();

    failing = true;
    await months.refresh();

    expect(months.hasData, isTrue);
    expect(months.month!.id, 11);
    expect(months.error?.kind, ApiErrorKind.network);
    expect(months.isRefreshing, isFalse);

    failing = false;
    await months.refresh();
    expect(months.error, isNull);
  });

  test('navigates between months, newest first', () async {
    final months =
        controller((r) async => json(response(requestedMonthId(r) ?? 11)));
    await months.load();

    expect(months.previousMonth!.id, 10);
    expect(months.nextMonth!.id, 12);

    await months.goToNextMonth();
    expect(months.month!.id, 12);
    expect(months.nextMonth, isNull);
    expect(requestedMonthId(requests.last), 12);

    await months.goToPreviousMonth();
    await months.goToPreviousMonth();
    expect(months.month!.id, 10);
    expect(months.previousMonth, isNull);
  });

  test('refresh reloads the month on screen', () async {
    final months =
        controller((r) async => json(response(requestedMonthId(r) ?? 11)));
    await months.selectMonth(12);

    await months.refresh();

    expect(requests.map(requestedMonthId), [12, 12]);
  });

  test('saveExpense posts and then reloads the same month', () async {
    final months = controller((r) async {
      if (r.method == 'POST') return json({'id': 5}, 201);
      return json(response(requestedMonthId(r) ?? 11));
    });
    await months.selectMonth(11);

    await months.saveExpense(
        value: 12,
        date: DateTime(2026, 10, 5),
        categoryId: 1,
        isMonthly: false);

    expect(requests.map((r) => '${r.method} ${r.url.path}'),
        ['GET /api/month/', 'POST /api/expense/', 'GET /api/month/']);
    expect(jsonDecode(requests[1].body), containsPair('month', 11));
    expect(requestedMonthId(requests.last), 11);
  });

  test('createMonth proposes the month after the newest and opens it',
      () async {
    var created = false;
    final months = controller((r) async {
      if (r.method == 'POST') {
        created = true;
        return json({'id': 13}, 201);
      }
      final id = requestedMonthId(r);
      return json(response(id ?? 11, withNewest: created));
    });
    await months.load();

    await months.createMonth();

    final post = requests.firstWhere((r) => r.method == 'POST');
    expect(jsonDecode(post.body),
        {'start_date': '2026-11-26', 'end_date': '2026-12-25'});
    expect(months.month!.id, 13);
  });

  test('clear forgets everything', () async {
    final months = controller((r) async => json(response(11)));
    await months.load();

    months.clear();

    expect(months.hasData, isFalse);
    expect(months.error, isNull);
    expect(months.summary.allIncomes, 0);
  });
}

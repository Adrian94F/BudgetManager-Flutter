import 'dart:convert';
import 'dart:io';

import 'package:budget_manager/api/api.dart';
import 'package:budget_manager/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final Map<String, dynamic> monthResponse = {
  'months': [
    {'id': 11, 'start_date': '2026-09-26', 'end_date': '2026-10-25'},
  ],
  'categories': [
    {'id': 1, 'name': 'Food', 'position': 1},
  ],
  'month': {'id': 11, 'start_date': '2026-09-26', 'end_date': '2026-10-25'},
  'incomes': [],
  'expenses': [],
  'planned_savings': 0,
};

http.Response json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

void main() {
  late InMemoryKeyValueStore store;
  late SessionStore session;
  late List<http.Request> requests;
  var expired = 0;

  ApiClient client(Future<http.Response> Function(http.Request) handler) => ApiClient(
        session: session,
        httpClient: MockClient((request) async {
          requests.add(request);
          return handler(request);
        }),
        onSessionExpired: () => expired++,
      );

  setUp(() async {
    store = InMemoryKeyValueStore();
    session = SessionStore(store);
    requests = [];
    expired = 0;
    await session.saveTokens(access: 'A1', refresh: 'R1');
  });

  group('requests', () {
    test('build URLs under /api with trailing slashes and a bearer token', () async {
      final api = client((_) async => json(monthResponse));

      final data = await api.fetchMonth(monthId: 5);

      expect(requests.single.url.toString(), '${ApiClient.baseUrl}/api/month/?month_id=5');
      expect(requests.single.headers['Authorization'], 'Bearer A1');
      expect(data.month!.id, 11);
    });

    test('send the bodies the server expects', () async {
      final api = client((_) async => http.Response('', 204));

      await api.createExpense(monthId: 11, value: 12.5, date: DateTime(2026, 10, 5), categoryId: 1, comment: 'Bread', isMonthly: false);
      await api.updateIncome(id: 7, monthId: 11, value: 100, date: DateTime(2026, 10, 1), isSalary: true);
      await api.deleteIncome(7);
      await api.reorderCategories(const [Category(id: 3, name: 'B', position: 9), Category(id: 1, name: 'A', position: 9)]);
      await api.savePlannedSavings(1500);

      expect(requests[0].method, 'POST');
      expect(requests[0].url.path, '/api/expense/');
      expect(jsonDecode(requests[0].body), {
        'month': 11,
        'value': 12.5,
        'date': '2026-10-05',
        'category': 1,
        'comment': 'Bread',
        'is_monthly': false,
      });
      expect(jsonDecode(requests[1].body), containsPair('id', 7));
      expect(jsonDecode(requests[1].body), containsPair('is_salary', true));
      expect(requests[2].method, 'DELETE');
      expect(jsonDecode(requests[2].body), {'id': 7});
      expect(jsonDecode(requests[3].body), [
        {'id': 3, 'position': 1},
        {'id': 1, 'position': 2},
      ]);
      expect(requests[4].url.path, '/api/planned-savings/');
      expect(jsonDecode(requests[4].body), {'planned_savings': 1500});
    });

    test('parse the categories list', () async {
      final api = client((_) async => json([
            {'id': 2, 'name': 'B', 'position': 2},
            {'id': 1, 'name': 'A', 'position': 1},
          ]));

      final categories = await api.fetchCategories();

      expect(categories.map((c) => c.name), ['A', 'B']);
    });
  });

  group('re-authentication', () {
    test('refreshes once on 401, stores the rotated tokens and retries', () async {
      final api = client((request) async {
        if (request.url.path.endsWith('token/refresh/')) {
          expect(jsonDecode(request.body), {'refresh': 'R1'});
          return json({'access': 'A2', 'refresh': 'R2'});
        }
        return request.headers['Authorization'] == 'Bearer A2'
            ? json(monthResponse)
            : json({'detail': 'Given token not valid', 'code': 'token_not_valid'}, 401);
      });

      final data = await api.fetchMonth();

      expect(data.month!.id, 11);
      expect(requests.map((r) => r.url.path), ['/api/month/', '/api/token/refresh/', '/api/month/']);
      expect(await session.accessToken(), 'A2');
      expect(await session.refreshToken(), 'R2');
      expect(expired, 0);
    });

    test('re-logs in with the remembered credentials when the refresh token is rejected', () async {
      await session.saveCredentials(username: 'adrian', password: 'secret');
      final api = client((request) async {
        if (request.url.path.endsWith('token/refresh/')) return json({'detail': 'blacklisted'}, 401);
        if (request.url.path.endsWith('/api/token/')) {
          expect(jsonDecode(request.body), {'username': 'adrian', 'password': 'secret'});
          return json({'access': 'A3', 'refresh': 'R3'});
        }
        return request.headers['Authorization'] == 'Bearer A3' ? json(monthResponse) : json({'detail': 'x'}, 401);
      });

      await api.fetchMonth();

      expect(requests.map((r) => r.url.path), ['/api/month/', '/api/token/refresh/', '/api/token/', '/api/month/']);
      expect(await session.accessToken(), 'A3');
      expect(expired, 0);
    });

    test('clears the session when refresh and re-login both fail', () async {
      final api = client((request) async => json({'detail': 'nope'}, 401));

      await expectLater(
        api.fetchMonth(),
        throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.auth)),
      );
      expect(await session.accessToken(), isNull);
      expect(await session.refreshToken(), isNull);
      expect(expired, 1);
    });

    test('shares one refresh between concurrent 401s', () async {
      final api = client((request) async {
        if (request.url.path.endsWith('token/refresh/')) return json({'access': 'A2', 'refresh': 'R2'});
        return request.headers['Authorization'] == 'Bearer A2' ? json(monthResponse) : json({'detail': 'x'}, 401);
      });

      await Future.wait([api.fetchMonth(), api.fetchMonth(monthId: 11), api.fetchCategories().catchError((_) => <Category>[])]);

      expect(requests.where((r) => r.url.path.endsWith('token/refresh/')).length, 1);
    });

    test('keeps the session when the network is down', () async {
      final api = client((_) async => throw const SocketException('offline'));

      await expectLater(
        api.fetchMonth(),
        throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.network)),
      );
      expect(await session.accessToken(), 'A1');
      expect(expired, 0);
      expect(await api.ensureSession(), isTrue);
    });

    test('ensureSession is false without tokens and refreshes otherwise', () async {
      await session.clearTokens();
      expect(await client((_) async => json({})).ensureSession(), isFalse);

      await session.saveTokens(access: 'A1', refresh: 'R1');
      final api = client((_) async => json({'access': 'A2', 'refresh': 'R2'}));
      expect(await api.ensureSession(), isTrue);
      expect(await session.accessToken(), 'A2');
    });
  });

  group('errors', () {
    test('carry the server message and field errors', () async {
      final api = client((_) async => json({'category': ['Invalid category.'], 'value': ['Required.']}, 400));

      try {
        await api.createExpense(monthId: 1, value: 1, date: DateTime(2026, 1, 1), categoryId: 9, isMonthly: false);
        fail('expected an ApiException');
      } on ApiException catch (e) {
        expect(e.kind, ApiErrorKind.client);
        expect(e.statusCode, 400);
        expect(e.message, 'Invalid category.');
        expect(e.fieldErrors, {'category': 'Invalid category.', 'value': 'Required.'});
      }
    });

    test('prefer detail, error and non_field_errors over field names', () {
      expect(ApiException.extractMessage({'detail': 'Not found.'}), 'Not found.');
      expect(ApiException.extractMessage({'error': 'Cannot delete a month that contains expenses.'}),
          'Cannot delete a month that contains expenses.');
      expect(ApiException.extractMessage({'non_field_errors': ['The fields user, name must make a unique set.']}),
          'The fields user, name must make a unique set.');
      expect(ApiException.extractMessage({'old_password': ['Wrong password.']}), 'Wrong password.');
      expect(ApiException.extractMessage('<html>500</html>'), '<html>500</html>');
      expect(ApiException.extractMessage(null), isNull);
    });

    test('fall back to the status code for unreadable bodies', () async {
      final api = client((_) async => http.Response('<html>Server Error (500)</html>', 500));

      await expectLater(
        api.fetchMonth(),
        throwsA(isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.server)
            .having((e) => e.message, 'message', 'HTTP 500')),
      );
    });

    test('login reports wrong credentials as an auth error', () async {
      final api = client((_) async => json({'detail': 'No active account found with the given credentials'}, 401));

      await expectLater(
        api.login(username: 'a', password: 'b'),
        throwsA(isA<ApiException>().having((e) => e.isAuth, 'isAuth', isTrue)),
      );
      expect(requests.single.headers.containsKey('Authorization'), isFalse);
    });
  });
}

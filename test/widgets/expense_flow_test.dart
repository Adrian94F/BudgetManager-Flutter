import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_server.dart';
import '../helpers/pump_app.dart';

Finder textFieldLabelled(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(TextField)).first;

void main() {
  testWidgets('adds, edits and deletes an expense', (tester) async {
    final server = FakeServer();
    await pumpApp(tester, server, loggedIn: true);

    // Expenses tab shows the existing expense.
    await tester.tap(find.byIcon(Icons.table_rows));
    await tester.pumpAndSettle();
    expect(find.text('Weekly shop'), findsOneWidget);

    // Add.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Add expense'), findsOneWidget);
    await tester.enterText(textFieldLabelled('Amount'), '42.50');
    await tester.enterText(textFieldLabelled('Comment'), 'Lunch');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    final created = server.requests.where((r) => r.method == 'POST' && r.url.path == '/api/expense/').single;
    final body = jsonDecode(created.body) as Map<String, dynamic>;
    expect(body['value'], 42.5);
    expect(body['comment'], 'Lunch');
    expect(body['category'], 1);
    expect(body['is_monthly'], isFalse);
    expect(body['month'], 11);
    expect(find.text('Lunch'), findsOneWidget);
    expect(find.textContaining('42.50'), findsOneWidget);

    // Edit.
    await tester.tap(find.text('Lunch'));
    await tester.pumpAndSettle();
    expect(find.text('Expense details'), findsOneWidget);
    await tester.enterText(textFieldLabelled('Amount'), '45');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final updated = server.requests.where((r) => r.method == 'POST' && r.url.path == '/api/expense/').last;
    expect(jsonDecode(updated.body)['id'], isNotNull);
    expect(find.textContaining('45.00'), findsOneWidget);

    // Delete: swipe the row, confirm the dialog.
    await tester.drag(find.text('Lunch'), const Offset(-400, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Do you really want to remove this expense?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(server.requests.where((r) => r.method == 'DELETE' && r.url.path == '/api/expense/'), hasLength(1));
    expect(find.text('Lunch'), findsNothing);
    expect(find.text('Weekly shop'), findsOneWidget);
  });

  testWidgets('shows the server message when a save is rejected', (tester) async {
    final server = FakeServer();
    server.categories.clear();
    await pumpApp(tester, server, loggedIn: true);

    await tester.tap(find.byIcon(Icons.table_rows));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(textFieldLabelled('Amount'), '10');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Add a category in Budget settings first.'), findsOneWidget);
    expect(server.requests.where((r) => r.method == 'POST'), isEmpty);
  });
}

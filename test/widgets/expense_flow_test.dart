import 'dart:convert';

import 'package:budget_manager/tools/dates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../helpers/fake_server.dart';
import '../helpers/pump_app.dart';

Finder textFieldLabelled(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(TextField)).first;

ChoiceChip chip(WidgetTester tester, String label) => tester.widget<ChoiceChip>(
    find.ancestor(of: find.text(label), matching: find.byType(ChoiceChip)));

bool amountHasFocus(WidgetTester tester) => tester
    .widget<EditableText>(find.descendant(
        of: textFieldLabelled('Amount'), matching: find.byType(EditableText)))
    .focusNode
    .hasPrimaryFocus;

List<Map<String, dynamic>> posted(FakeServer server, String path) => [
      for (final r in server.requests)
        if (r.method == 'POST' && r.url.path == path)
          jsonDecode(r.body) as Map<String, dynamic>,
    ];

void main() {
  testWidgets('adds, edits and deletes an expense', (tester) async {
    final server = FakeServer();
    await pumpApp(tester, server, loggedIn: true);

    // Expenses tab shows the existing expense.
    await tester.tap(find.byIcon(Icons.receipt_long_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Weekly shop'), findsOneWidget);

    // Add.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Add expense'), findsOneWidget);
    // The amount field starts focused and takes digits like a cash register.
    expect(
        tester
            .widget<EditableText>(find.descendant(
                of: textFieldLabelled('Amount'),
                matching: find.byType(EditableText)))
            .focusNode
            .hasPrimaryFocus,
        isTrue);
    await tester.enterText(textFieldLabelled('Amount'), '4250');
    expect(find.text('42.50'), findsOneWidget);
    await tester.enterText(textFieldLabelled('Comment'), 'Lunch');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    final created = server.requests
        .where((r) => r.method == 'POST' && r.url.path == '/api/expense/')
        .single;
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
    expect(find.text('42.50'), findsOneWidget);
    await tester.enterText(textFieldLabelled('Amount'), '4500');
    expect(find.text('45.00'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final updated = server.requests
        .where((r) => r.method == 'POST' && r.url.path == '/api/expense/')
        .last;
    expect(jsonDecode(updated.body)['id'], isNotNull);
    expect(find.textContaining('45.00'), findsOneWidget);

    // Delete: swipe the row, tap Remove; no dialog, an Undo snackbar instead.
    await tester.drag(find.text('Lunch'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(
        server.requests.where(
            (r) => r.method == 'DELETE' && r.url.path == '/api/expense/'),
        hasLength(1));
    expect(find.text('Lunch'), findsNothing);
    expect(find.text('Weekly shop'), findsOneWidget);
    expect(find.text('Expense deleted'), findsOneWidget);

    // Undo re-creates it in the same month.
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    final recreated = server.requests
        .where((r) => r.method == 'POST' && r.url.path == '/api/expense/')
        .last;
    expect(jsonDecode(recreated.body), containsPair('comment', 'Lunch'));
    expect(jsonDecode(recreated.body), containsPair('month', 11));
    expect(find.text('Lunch'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('finds an expense through the top-bar search', (tester) async {
    final server = FakeServer();
    await pumpApp(tester, server, loggedIn: true);

    // The magnifier shows on the expenses tab only.
    expect(find.byTooltip('Search expenses'), findsNothing);
    await tester.tap(find.byIcon(Icons.receipt_long_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search expenses'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'weekly');
    await tester.pumpAndSettle();
    // The result tile joins the date and the comment in one line.
    final result = find.ancestor(
        of: find.textContaining('· Weekly shop'),
        matching: find.byType(ListTile));
    expect(result, findsOneWidget);

    await tester.tap(result);
    await tester.pumpAndSettle();
    expect(find.text('Expense details'), findsOneWidget);
    expect(find.text('Weekly shop'), findsOneWidget);
  });

  testWidgets('shows the server message when a save is rejected',
      (tester) async {
    final server = FakeServer();
    server.categories.clear();
    await pumpApp(tester, server, loggedIn: true);

    await tester.tap(find.byIcon(Icons.receipt_long_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(textFieldLabelled('Amount'), '10');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(
        find.text('Add a category in Budget settings first.'), findsOneWidget);
    expect(server.requests.where((r) => r.method == 'POST'), isEmpty);
  });
  testWidgets('Today and Yesterday chips set the date of a new expense',
      (tester) async {
    final server = FakeServer();
    await pumpApp(tester, server, loggedIn: true);
    final today = Dates.today();
    final yesterday = Dates.addDays(today, -1);
    String shown(DateTime day) => DateFormat.yMMMMEEEEd('en').format(day);

    await tester.tap(find.byIcon(Icons.receipt_long_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // A new expense in the current month starts on today.
    expect(chip(tester, 'Today').selected, isTrue);
    expect(chip(tester, 'Yesterday').selected, isFalse);
    expect(find.text(shown(today)), findsOneWidget);

    await tester.tap(find.text('Yesterday'));
    await tester.pumpAndSettle();
    expect(chip(tester, 'Today').selected, isFalse);
    expect(chip(tester, 'Yesterday').selected, isTrue);
    expect(find.text(shown(yesterday)), findsOneWidget);

    await tester.enterText(textFieldLabelled('Amount'), '990');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(posted(server, '/api/expense/').single['date'],
        Dates.formatApi(yesterday));
  });

  testWidgets('editing an expense has the chips but no "Save and add another"',
      (tester) async {
    final server = FakeServer();
    await pumpApp(tester, server, loggedIn: true);

    await tester.tap(find.byIcon(Icons.receipt_long_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekly shop'));
    await tester.pumpAndSettle();

    expect(find.text('Expense details'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsWidgets);
    expect(find.text('Save and add another'), findsNothing);
  });

  testWidgets(
      'Save and add another keeps the date and category and starts a new expense',
      (tester) async {
    final server = FakeServer();
    await pumpApp(tester, server, loggedIn: true);
    final yesterday = Dates.addDays(Dates.today(), -1);

    await tester.tap(find.byIcon(Icons.receipt_long_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yesterday'));
    await tester.enterText(textFieldLabelled('Amount'), '1250');
    await tester.enterText(textFieldLabelled('Comment'), 'Coffee');
    await tester.tap(find.text('Recurrent expense'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save and add another'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save and add another'));
    await tester.pumpAndSettle();

    final first = posted(server, '/api/expense/').single;
    expect(first['value'], 12.5);
    expect(first['comment'], 'Coffee');
    expect(first['is_monthly'], isTrue);
    expect(first['date'], Dates.formatApi(yesterday));

    // Still the add dialog, confirmed by a snackbar, ready for the next one:
    // the amount, the comment and the recurring flag start over, the date
    // stays and the amount field has the focus again.
    expect(find.text('Add expense'), findsOneWidget);
    expect(find.text('Expense added'), findsOneWidget);
    expect(find.text('12.50'), findsNothing);
    expect(find.text('Coffee'), findsNothing);
    expect(chip(tester, 'Yesterday').selected, isTrue);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse);
    expect(amountHasFocus(tester), isTrue);

    await tester.enterText(textFieldLabelled('Amount'), '300');
    expect(find.text('3.00'), findsOneWidget);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    final second = posted(server, '/api/expense/').last;
    expect(posted(server, '/api/expense/'), hasLength(2));
    expect(second['value'], 3.0);
    expect(second['comment'], '');
    expect(second['is_monthly'], isFalse);
    expect(second['date'], Dates.formatApi(yesterday));
    expect(second['category'], first['category']);
    // The dialog closed after the plain save.
    expect(find.text('Add expense'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Save and add another works for incomes too', (tester) async {
    final server = FakeServer();
    await pumpApp(tester, server, loggedIn: true);

    await tester.tap(find.byIcon(Icons.savings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Add income'), findsOneWidget);
    expect(chip(tester, 'Today').selected, isTrue);

    await tester.enterText(textFieldLabelled('Amount'), '20000');
    await tester.enterText(textFieldLabelled('Comment'), 'Bonus');
    await tester.ensureVisible(find.text('Save and add another'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save and add another'));
    await tester.pumpAndSettle();

    expect(posted(server, '/api/income/').single['value'], 200.0);
    expect(find.text('Add income'), findsOneWidget);
    expect(find.text('Income added'), findsOneWidget);
    expect(find.text('Bonus'), findsNothing);
    expect(find.text('200.00'), findsNothing);
    expect(chip(tester, 'Today').selected, isTrue);
    expect(amountHasFocus(tester), isTrue);
    await tester.pump(const Duration(seconds: 3));
  });
}

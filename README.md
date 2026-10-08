# Budget Manager (Flutter)

Android client of Budget Manager, a personal budgeting app built around
billing periods ("months") with incomes, daily and recurring expenses,
categories and a planned savings target. It talks to the Django server
(BudgetManager-Srv) over its REST API; an iOS client (BudgetManager-iOS)
offers the same features with SwiftUI.

## Features

- Month summary: balance after planned savings, actual balance, max daily
  allowance, spent today, days left; burndown chart with the ideal line to
  the savings target, weekends and today shaded; tap it for the Statistics
  screen.
- Statistics: a Burndown | Cash flow | History switch. The full burndown with daily
  and recurring bars, or the month's cash flow as a Sankey diagram (salary
  and other income into the budget, out to the categories and the
  leftover), with the recurring expenses in or out and a category filter
  (untick categories to leave their bands out; incomes and the leftover
  stay as they are, as on the web); tap a category to see
  its expenses (back returns to the diagram), pinch to stretch the expenses column until every category
  has its label and scroll it, while incomes and the budget stay put and
  bands reach only the categories on screen. History: incomes and expenses
  as lines and the balance as bars month over month, a fixed width per
  month, scrolling sideways with the Y axis fixed and following the months
  in view.
- Expenses grouped by day with search, a collapsed section for future
  expenses, swipe to copy or delete (with Undo), suggested categories when
  adding.
- Expense and income forms: cash-register amount entry, Today / Yesterday
  chips for the date, and "Save and add another" when adding, which keeps
  the date (and the expense's category) for the next entry.
- Category × day table with drill-down into the filtered list.
- Incomes grouped by day, with the salary flag.
- Months: swipe the summary sideways to move a month (the screen follows
  the finger and a chevron shows at the edge), pick from a sheet grouped by
  year, edit dates and planned savings (whole amounts, as the server
  requires), delete an empty month, create the next one.
- Settings: App settings (theme, dynamic colour on Android 12+, language),
  Budget settings (currency, categories: add, rename, drag to reorder,
  delete), change password, log out.
- English and Polish.

## Structure

| Folder | Role |
| --- | --- |
| `lib/models/` | `Month`, `Category`, `Income`, `Expense`, `MonthData`: the API response, parsed once |
| `lib/domain/` | Pure Dart budget rules: `MonthSummary`, `BurndownSeries`, `CashFlow`, `ExpenseTable`, `BudgetRules` |
| `lib/api/` | `ApiClient` (one method per endpoint, shared token refresh), `ApiException`, `SessionStore` |
| `lib/state/` | `AuthController`, `SettingsController`, `MonthController` (`ChangeNotifier`) |
| `lib/app/` | `AppServices` wiring, `AppScope`, theme, dynamic colour, the `MaterialApp` |
| `lib/views/` | Screens and widgets, Material 3 |
| `lib/l10n/` | ARB files; `flutter gen-l10n` generates `app_localizations*.dart` (git-ignored) |
| `test/` | Unit tests for models, domain math, the API client and the controller; widget tests against a fake server |

The budget rules mirror the server's `calculator.py` and `chart_data.py`
and the iOS `SummaryViewModel`; the domain tests use the same fixtures as
the server's tests.

## Development

Needs Flutter 3.47 or newer (`pubspec.lock` requires it; CI pins 3.47.5 in
`.github/workflows/flutter.yml`).

```sh
flutter pub get
flutter gen-l10n
dart format lib test
flutter analyze
flutter test
flutter run
```

The server URL is fixed: `ApiClient.baseUrl` in `lib/api/api_client.dart`
(`https://budget.frydmanski.cc`). The app has no setting for it, neither in
App settings nor on the login page; the login page's Register link opens
`<baseUrl>/register`. To work against a local server, change that constant
temporarily (for example to `http://10.0.2.2:8000` for the Android emulator,
which reaches the host's `localhost` there) and do not commit the change.
Android blocks cleartext HTTP by default, so a plain `http://` server also
needs `<application android:usesCleartextTraffic="true"/>` in
`android/app/src/debug/AndroidManifest.xml`.

## Release build

Create a keystore and copy `android/key.properties.example` to
`android/key.properties` with its values. `flutter build apk --release` (or
`appbundle`) then signs with it; without the file the release build uses the
debug key so it still runs locally. Version name and code come from
`version:` in `pubspec.yaml`.

`build_unsigned_ipa.sh` builds an unsigned iOS archive.

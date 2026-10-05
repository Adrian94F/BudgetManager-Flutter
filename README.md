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
- Statistics: a Burndown | Cash flow switch. The full burndown with daily
  and recurring bars, or the month's cash flow as a Sankey diagram (salary
  and other income into the budget, out to the categories and the
  leftover), with the recurring expenses in or out; tap a category to see
  its expenses.
- Expenses grouped by day with search, a collapsed section for future
  expenses, swipe to copy or delete, suggested categories when adding.
- Category × day table with drill-down into the filtered list.
- Incomes grouped by day, with the salary flag.
- Months: swipe the summary sideways to move a month (the screen follows
  the finger and a chevron shows at the edge), pick from a sheet grouped by
  year, edit dates and planned
  savings, delete an empty month, create the next one.
- Settings: theme, dynamic colour (Android 12+), server URL, categories
  (add, rename, drag to reorder, delete), change password.
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

```sh
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
flutter run
```

The app signs in against `https://budget.frydmanski.cc` by default; another
server can be typed on the login page or in App settings.

## Release build

Create a keystore and copy `android/key.properties.example` to
`android/key.properties` with its values. `flutter build apk --release` (or
`appbundle`) then signs with it; without the file the release build uses the
debug key so it still runs locally. Version name and code come from
`version:` in `pubspec.yaml`.

`build_unsigned_ipa.sh` builds an unsigned iOS archive.

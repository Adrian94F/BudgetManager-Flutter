import 'package:flutter/foundation.dart';

import '../api/api.dart';
import '../domain/domain.dart';
import '../models/models.dart';

/// The month on screen: its data, loading state and the operations on it.
///
/// Data stays available while a refresh runs ([isRefreshing]); [isLoading]
/// is set only when there is nothing to show yet. A failed load keeps the
/// previous data and exposes the [error]. Write operations call the API and
/// then reload, and let their [ApiException] reach the caller so a form can
/// show the server's message.
class MonthController extends ChangeNotifier {
  MonthController(this._api);

  final ApiClient _api;

  MonthData? _data;
  bool _isLoading = false;
  bool _isRefreshing = false;
  ApiException? _error;
  int? _requestedMonthId;
  int _loadSequence = 0;
  MonthSummary? _summary;
  BurndownSeries? _burndown;
  CashFlow? _cashFlow;
  MonthHistory? _history;
  ApiException? _historyError;
  bool _isLoadingHistory = false;

  MonthData? get data => _data;

  bool get hasData => _data != null;

  /// A request is in flight and there is no data to show.
  bool get isLoading => _isLoading;

  /// A request is in flight while the previous data stays on screen.
  bool get isRefreshing => _isRefreshing;
  bool get isBusy => _isLoading || _isRefreshing;
  ApiException? get error => _error;

  Month? get month => _data?.month;

  /// The currency every amount is in, as the server reports it.
  String get currency => _data?.currency ?? defaultCurrency;

  MonthSummary get summary => _summary ??=
      _data == null ? MonthSummary.empty : MonthSummary.compute(_data!);

  BurndownSeries get burndown => _burndown ??=
      _data == null ? BurndownSeries.empty : BurndownSeries.compute(_data!);

  CashFlow get cashFlow =>
      _cashFlow ??= _data == null ? CashFlow.empty : CashFlow.compute(_data!);

  /// The month before the one on screen (months are kept newest first).
  Month? get previousMonth {
    final index = _currentIndex;
    if (index == null) return null;
    final months = _data!.months;
    return index + 1 < months.length ? months[index + 1] : null;
  }

  /// The month after the one on screen.
  Month? get nextMonth {
    final index = _currentIndex;
    if (index == null) return null;
    return index > 0 ? _data!.months[index - 1] : null;
  }

  int? get _currentIndex {
    final current = _data?.month;
    if (current == null) return null;
    final index = _data!.months.indexWhere((m) => m.id == current.id);
    return index < 0 ? null : index;
  }

  /// The month-over-month history, once [loadHistory] fetched it; any
  /// reload of the month forgets it, since the sums may have changed.
  MonthHistory? get history => _history;
  ApiException? get historyError => _historyError;
  bool get isLoadingHistory => _isLoadingHistory;

  /// Fetches the history unless it is there or on its way.
  Future<void> loadHistory() async {
    if (_history != null || _isLoadingHistory) return;
    _isLoadingHistory = true;
    _historyError = null;
    notifyListeners();
    try {
      _history = await _api.fetchHistory(months: _data?.months ?? const []);
    } on ApiException catch (e) {
      _historyError = e;
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  /// Loads [monthId], or, when null, the month that has today in it: the
  /// server's own default is its newest month, which may be one made ahead
  /// of time, and the app should open on the current one.
  Future<void> load({int? monthId}) async {
    final sequence = ++_loadSequence;
    _requestedMonthId = monthId;
    if (_data == null) {
      _isLoading = true;
    } else {
      _isRefreshing = true;
    }
    _error = null;
    notifyListeners();
    try {
      var data = await _api.fetchMonth(monthId: monthId);
      if (monthId == null) {
        final current = _monthWithToday(data.months);
        if (current != null && current.id != data.month?.id) {
          data = await _api.fetchMonth(monthId: current.id);
        }
      }
      if (sequence != _loadSequence) return;
      _data = data;
      _summary = null;
      _burndown = null;
      _cashFlow = null;
      _history = null;
    } on ApiException catch (e) {
      if (sequence != _loadSequence) return;
      _error = e;
    } finally {
      if (sequence == _loadSequence) {
        _isLoading = false;
        _isRefreshing = false;
        notifyListeners();
      }
    }
  }

  static Month? _monthWithToday(List<Month> months) {
    final today = DateTime.now();
    for (final month in months) {
      if (month.isActual(today)) return month;
    }
    return null;
  }

  /// Reloads the month on screen.
  Future<void> refresh() =>
      load(monthId: _data?.month?.id ?? _requestedMonthId);

  Future<void> selectMonth(int monthId) => load(monthId: monthId);

  Future<void> goToPreviousMonth() async {
    final target = previousMonth;
    if (target != null) await selectMonth(target.id);
  }

  Future<void> goToNextMonth() async {
    final target = nextMonth;
    if (target != null) await selectMonth(target.id);
  }

  /// Forgets everything, e.g. after a logout.
  void clear() {
    _loadSequence++;
    _data = null;
    _error = null;
    _isLoading = false;
    _isRefreshing = false;
    _requestedMonthId = null;
    _historyError = null;
    _summary = null;
    _burndown = null;
    _cashFlow = null;
    _history = null;
    notifyListeners();
  }

  // MARK: - Months

  /// Creates a month and opens it. [start] and [end] default to the month
  /// after the newest one, or to the current calendar month when there is
  /// no month yet.
  Future<void> createMonth({DateTime? start, DateTime? end}) async {
    final newest =
        _data?.months.isNotEmpty == true ? _data!.months.first : null;
    final range = newest == null
        ? BudgetRules.firstMonthRange()
        : BudgetRules.nextMonthRange(newest);
    await _api.createMonth(start: start ?? range.start, end: end ?? range.end);
    await load();
    final created =
        _data?.months.isNotEmpty == true ? _data!.months.first : null;
    if (created != null && created.id != _data?.month?.id) {
      await load(monthId: created.id);
    }
  }

  Future<void> updateMonth(
      {required int id, required DateTime start, required DateTime end}) async {
    await _api.updateMonth(id: id, start: start, end: end);
    await refresh();
  }

  /// Deletes a month and shows the server's default month afterwards.
  Future<void> deleteMonth(int id) async {
    await _api.deleteMonth(id);
    await load();
  }

  Future<void> savePlannedSavings(double value) async {
    await _api.savePlannedSavings(value);
    await refresh();
  }

  /// Changes the user's currency on the server; the amounts on screen switch
  /// at once, without a reload.
  Future<void> setCurrency(String code) async {
    await _api.setCurrency(code);
    _data = _data?.copyWith(currency: code);
    notifyListeners();
  }

  // MARK: - Incomes and expenses

  Future<void> saveIncome({
    int? id,
    required double value,
    required DateTime date,
    String comment = '',
    required bool isSalary,
  }) async {
    final monthId = _requireMonthId();
    if (id == null) {
      await _api.createIncome(
          monthId: monthId,
          value: value,
          date: date,
          comment: comment,
          isSalary: isSalary);
    } else {
      await _api.updateIncome(
          id: id,
          monthId: monthId,
          value: value,
          date: date,
          comment: comment,
          isSalary: isSalary);
    }
    await refresh();
  }

  Future<void> deleteIncome(int id) async {
    await _api.deleteIncome(id);
    await refresh();
  }

  Future<void> saveExpense({
    int? id,
    required double value,
    required DateTime date,
    required int categoryId,
    String comment = '',
    required bool isMonthly,
  }) async {
    final monthId = _requireMonthId();
    if (id == null) {
      await _api.createExpense(
          monthId: monthId,
          value: value,
          date: date,
          categoryId: categoryId,
          comment: comment,
          isMonthly: isMonthly);
    } else {
      await _api.updateExpense(
          id: id,
          monthId: monthId,
          value: value,
          date: date,
          categoryId: categoryId,
          comment: comment,
          isMonthly: isMonthly);
    }
    await refresh();
  }

  Future<void> deleteExpense(int id) async {
    await _api.deleteExpense(id);
    await refresh();
  }

  int _requireMonthId() {
    final id = _data?.month?.id;
    if (id == null) throw StateError('No month is loaded');
    return id;
  }
}

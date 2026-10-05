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
  Map<String, dynamic>? _rawJson;
  bool _isLoading = false;
  bool _isRefreshing = false;
  ApiException? _error;
  int? _requestedMonthId;
  int _loadSequence = 0;
  MonthSummary? _summary;
  BurndownSeries? _burndown;

  MonthData? get data => _data;

  /// The response as the server sent it, for screens not yet moved to
  /// [data]. Removed once they are.
  Map<String, dynamic>? get rawJson => _rawJson;

  bool get hasData => _data != null;

  /// A request is in flight and there is no data to show.
  bool get isLoading => _isLoading;

  /// A request is in flight while the previous data stays on screen.
  bool get isRefreshing => _isRefreshing;
  bool get isBusy => _isLoading || _isRefreshing;
  ApiException? get error => _error;

  Month? get month => _data?.month;

  MonthSummary get summary =>
      _summary ??= _data == null ? MonthSummary.empty : MonthSummary.compute(_data!);

  BurndownSeries get burndown =>
      _burndown ??= _data == null ? BurndownSeries.empty : BurndownSeries.compute(_data!);

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

  /// Loads [monthId], or the server's default month when null.
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
      final json = await _api.fetchMonthJson(monthId: monthId);
      if (sequence != _loadSequence) return;
      _rawJson = json;
      _data = MonthData.fromJson(json);
      _summary = null;
      _burndown = null;
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

  /// Reloads the month on screen.
  Future<void> refresh() => load(monthId: _data?.month?.id ?? _requestedMonthId);

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
    _rawJson = null;
    _error = null;
    _isLoading = false;
    _isRefreshing = false;
    _requestedMonthId = null;
    _summary = null;
    _burndown = null;
    notifyListeners();
  }

  // MARK: - Months

  /// Creates a month and opens it. [start] and [end] default to the month
  /// after the newest one, or to the current calendar month when there is
  /// no month yet.
  Future<void> createMonth({DateTime? start, DateTime? end}) async {
    final newest = _data?.months.isNotEmpty == true ? _data!.months.first : null;
    final range = newest == null ? BudgetRules.firstMonthRange() : BudgetRules.nextMonthRange(newest);
    await _api.createMonth(start: start ?? range.start, end: end ?? range.end);
    await load();
    final created = _data?.months.isNotEmpty == true ? _data!.months.first : null;
    if (created != null && created.id != _data?.month?.id) {
      await load(monthId: created.id);
    }
  }

  Future<void> updateMonth({required int id, required DateTime start, required DateTime end}) async {
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
      await _api.createIncome(monthId: monthId, value: value, date: date, comment: comment, isSalary: isSalary);
    } else {
      await _api.updateIncome(id: id, monthId: monthId, value: value, date: date, comment: comment, isSalary: isSalary);
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
          monthId: monthId, value: value, date: date, categoryId: categoryId, comment: comment, isMonthly: isMonthly);
    } else {
      await _api.updateExpense(
          id: id, monthId: monthId, value: value, date: date, categoryId: categoryId, comment: comment, isMonthly: isMonthly);
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

import 'package:flutter/material.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart' as charts;
import '../services/auth_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  Map<String, dynamic>? _statistics;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchStatistics();
  }

  Future<void> _fetchStatistics() async {
    try {
      final response = await _authService.get('statistics');
      setState(() {
        _statistics = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load statistics.';
      });
    }
  }

  List<charts.Series<dynamic, String>> _createChartData(Map<String, dynamic> stats) {
    final incomeData = (stats['incomeSums'] as List<dynamic>).asMap().entries.map((e) => {'label': stats['labels'][e.key], 'value': e.value}).toList();
    final expenseData = (stats['expenseSums'] as List<dynamic>).asMap().entries.map((e) => {'label': stats['labels'][e.key], 'value': -e.value}).toList();
    final balanceData = (stats['balances'] as List<dynamic>).asMap().entries.map((e) => {'label': stats['labels'][e.key], 'value': e.value}).toList();

    return [
      charts.Series<dynamic, String>(
        id: 'Income',
        domainFn: (datum, _) => datum['label'],
        measureFn: (datum, _) => datum['value'],
        data: incomeData,
        labelAccessorFn: (datum, _) => '${datum['value']}',
        colorFn: (_, __) => charts.MaterialPalette.indigo.shadeDefault.lighter.lighter,
      ),
      charts.Series<dynamic, String>(
        id: 'Expenses',
        domainFn: (datum, _) => datum['label'],
        measureFn: (datum, _) => datum['value'],
        data: expenseData,
        labelAccessorFn: (datum, _) => '${datum['value']}',
        colorFn: (_, __) => charts.MaterialPalette.indigo.shadeDefault.lighter.lighter,
      ),
      charts.Series<dynamic, String>(
        id: 'Balance',
        domainFn: (datum, _) => datum['label'],
        measureFn: (datum, _) => datum['value'],
        data: balanceData,
        labelAccessorFn: (datum, _) => '${datum['value']}',
        colorFn: (_, __) => charts.MaterialPalette.indigo.shadeDefault,
      )
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: charts.BarChart(
          _createChartData(_statistics!),
          animate: true,
          barGroupingType: charts.BarGroupingType.stacked
        ),
      ),
    );
  }
}

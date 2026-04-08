import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';

enum MarketStatus { initial, loading, loaded, error }

class MarketProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  MarketStatus _status = MarketStatus.initial;
  String? _errorMessage;
  
  // Simulation Date — dynamically loaded on init
  String _currentDate = ''; 
  
  Map<String, dynamic>? _marketSummary;
  List<dynamic> _stocks = [];

  // ── Getters ─────────────────────────────────────────────────────

  MarketStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String get currentDate => _currentDate;
  Map<String, dynamic>? get marketSummary => _marketSummary;
  List<dynamic> get stocks => _stocks;
  bool get isLoading => _status == MarketStatus.loading;

  // ── Actions ─────────────────────────────────────────────────────

  Future<void> fetchMarketData() async {
    _status = MarketStatus.loading;
    _errorMessage = null;
    notifyListeners();

    // If no date is set, find the first available date
    if (_currentDate.isEmpty) {
      final firstDateResult = await _apiService.getNextMarketDate('1900-01-01');
      if (firstDateResult.success && firstDateResult.data != null) {
        _currentDate = firstDateResult.data!['next_date'].toString().split('T')[0];
      } else {
        _status = MarketStatus.error;
        _errorMessage = 'no_historical_data_available';
        notifyListeners();
        return;
      }
    }

    final result = await _apiService.getMarketData(_currentDate);

    if (result.success && result.data != null) {
      _marketSummary = result.data!['summary'];
      _stocks = result.data!['market'] ?? [];
      _status = MarketStatus.loaded;
    } else {
      _status = MarketStatus.error;
      _errorMessage = result.error ?? 'failed_to_load_market';
    }
    
    notifyListeners();
  }

  /// Simulation: Move to the next actual trading day from the DB.
  Future<void> nextDay() async {
    _status = MarketStatus.loading;
    notifyListeners();

    final result = await _apiService.getNextMarketDate(_currentDate);

    if (result.success && result.data != null) {
      final next = result.data!['next_date'];
      // Handle Postgres DATE string format correctly
      _currentDate = next.toString().split('T')[0];
      await fetchMarketData();
    } else {
      _status = MarketStatus.error;
      _errorMessage = 'No more historical data available';
      notifyListeners();
    }
  }
}

// Helper extension to handle BD specific weekends if needed
extension BDWeekend on DateTime {
  static const int friday = 5;
  static const int saturday = 6;
  bool get isBDWeekend => weekday == friday || weekday == saturday;
}

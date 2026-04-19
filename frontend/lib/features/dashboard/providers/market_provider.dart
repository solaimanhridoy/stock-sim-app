import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';

enum MarketStatus { initial, loading, loaded, error }

class MarketProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  MarketStatus _status = MarketStatus.initial;
  String? _errorMessage;
  String _currentDate = '';
  Map<String, dynamic>? _marketSummary;
  List<dynamic> _stocks = [];
  String _searchQuery = '';

  // ── Getters ─────────────────────────────────────────────────────

  MarketStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String get currentDate => _currentDate;
  Map<String, dynamic>? get marketSummary => _marketSummary;
  bool get isLoading => _status == MarketStatus.loading;

  List<dynamic> get stocks {
    if (_searchQuery.isEmpty) return _stocks;
    return _stocks.where((s) {
      final ticker = (s['ticker'] ?? '').toString().toLowerCase();
      final name = (s['company_name'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return ticker.contains(q) || name.contains(q);
    }).toList();
  }

  String get searchQuery => _searchQuery;

  // ── Actions ─────────────────────────────────────────────────────

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Fetch market data. Server auto-initializes sim date if needed.
  Future<void> fetchMarketData() async {
    _status = MarketStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await _apiService.getMarketData();

    if (result.success && result.data != null) {
      _currentDate = (result.data!['date'] ?? '').toString().split('T')[0];
      _marketSummary = result.data!['summary'];
      _stocks = result.data!['market'] ?? [];
      _status = MarketStatus.loaded;
    } else {
      _status = MarketStatus.error;
      _errorMessage = result.error ?? 'failed_to_load_market';
    }

    notifyListeners();
  }

  /// Server-authoritative: advance to the next trading day.
  Future<void> nextDay() async {
    _status = MarketStatus.loading;
    notifyListeners();

    final advanceResult = await _apiService.advanceDay();

    if (advanceResult.success && advanceResult.data != null) {
      final simDate = advanceResult.data!['simulation_date'];
      _currentDate = simDate.toString().split('T')[0];
      // Now fetch market data for the new date
      await fetchMarketData();
    } else {
      _status = MarketStatus.error;
      _errorMessage = advanceResult.error ?? 'No more historical data available';
      notifyListeners();
    }
  }
}

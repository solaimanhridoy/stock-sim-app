import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';

enum PortfolioStatus { initial, loading, loaded, error }

class PortfolioProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  PortfolioStatus _status = PortfolioStatus.initial;
  String? _errorMessage;

  List<dynamic> _holdings = [];
  Map<String, dynamic>? _summary;
  List<dynamic> _transactions = [];

  // ── Getters ─────────────────────────────────────────────────────

  PortfolioStatus get status => _status;
  String? get errorMessage => _errorMessage;
  List<dynamic> get holdings => _holdings;
  Map<String, dynamic>? get summary => _summary;
  List<dynamic> get transactions => _transactions;
  bool get isLoading => _status == PortfolioStatus.loading;

  // ── Fetch Portfolio ─────────────────────────────────────────────

  Future<void> fetchPortfolio() async {
    _status = PortfolioStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await _apiService.getPortfolio();

    if (result.success && result.data != null) {
      _holdings = result.data!['holdings'] ?? [];
      _summary = result.data!['summary'];
      _status = PortfolioStatus.loaded;
    } else {
      _status = PortfolioStatus.error;
      _errorMessage = result.error ?? 'Failed to load portfolio';
    }
    notifyListeners();
  }

  // ── Fetch Transactions ──────────────────────────────────────────

  Future<void> fetchTransactions() async {
    final result = await _apiService.getTransactions();
    if (result.success && result.data != null) {
      _transactions = result.data!['transactions'] ?? [];
      notifyListeners();
    }
  }

  // ── Buy Stock ───────────────────────────────────────────────────

  Future<ApiResult<Map<String, dynamic>>> buyStock(String ticker, int quantity) async {
    final result = await _apiService.buyStock(ticker, quantity);
    if (result.success) {
      // Refresh portfolio data after trade
      await fetchPortfolio();
    }
    return result;
  }

  // ── Sell Stock ──────────────────────────────────────────────────

  Future<ApiResult<Map<String, dynamic>>> sellStock(String ticker, int quantity) async {
    final result = await _apiService.sellStock(ticker, quantity);
    if (result.success) {
      await fetchPortfolio();
    }
    return result;
  }
}

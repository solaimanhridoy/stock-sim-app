import 'dart:io';
import 'package:flutter/foundation.dart';

/// API configuration constants.
class ApiConfig {
  ApiConfig._();

  /// Base URL for the backend.
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:3000';
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:3000';
    return 'http://localhost:3000'; // Windows, iOS, macOS
  }

  /// Auth Endpoints
  static const String googleAuth = '/api/auth/google';
  static const String refresh = '/api/auth/refresh';
  static const String logout = '/api/auth/logout';

  /// User Endpoints
  static const String profile = '/api/user/profile';

  /// Market Endpoints
  static const String market = '/api/market';
  static const String marketStocks = '/api/market/stocks';
  static const String advanceDay = '/api/market/advance-day';
  static String stockDetail(String ticker) => '/api/market/stock/$ticker';

  /// Trade Endpoints
  static const String tradeBuy = '/api/trade/buy';
  static const String tradeSell = '/api/trade/sell';

  /// Portfolio Endpoints
  static const String portfolio = '/api/portfolio';
  static const String transactions = '/api/portfolio/transactions';

  /// Leaderboard
  static const String leaderboard = '/api/leaderboard';

  /// Timeouts
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);
}

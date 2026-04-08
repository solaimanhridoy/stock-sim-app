import 'dart:io';
import 'package:flutter/foundation.dart';

/// API configuration constants.
class ApiConfig {
  ApiConfig._();

  /// Base URL for the auth backend.
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:3000';
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:3000';
    return 'http://localhost:3000'; // Windows, iOS, macOS
  }

  /// Endpoints
  static const String googleAuth = '/api/auth/google';
  static const String refresh = '/api/auth/refresh';
  static const String logout = '/api/auth/logout';
  static const String profile = '/api/user/profile';

  /// Timeouts
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);
}

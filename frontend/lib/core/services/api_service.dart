import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'token_storage.dart';

/// Result wrapper for API calls.
class ApiResult<T> {
  final T? data;
  final String? error;
  final bool success;
  final int? statusCode;

  ApiResult.ok(this.data)
      : success = true,
        error = null,
        statusCode = 200;

  ApiResult.fail(this.error, {this.statusCode})
      : success = false,
        data = null;
}

/// Auth response model.
class AuthResponse {
  final String accessToken;
  final String? refreshToken;
  final bool isNewUser;
  final Map<String, dynamic>? user;

  AuthResponse({
    required this.accessToken,
    this.refreshToken,
    required this.isNewUser,
    this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return AuthResponse(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String?,
      isNewUser: data['isNewUser'] as bool,
      user: data['user'] as Map<String, dynamic>?,
    );
  }
}

/// Handles all communication with the backend.
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final TokenStorage _tokenStorage = TokenStorage();

  // ── Google Login ────────────────────────────────────────────────

  Future<ApiResult<AuthResponse>> loginWithGoogle({
    String? idToken,
    String? accessToken,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.googleAuth}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              if (idToken != null) 'idToken': idToken,
              if (accessToken != null) 'accessToken': accessToken,
            }),
          )
          .timeout(ApiConfig.receiveTimeout);

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final authResponse = AuthResponse.fromJson(body);
        await _tokenStorage.saveAccessToken(authResponse.accessToken);
        if (authResponse.refreshToken != null) {
          await _tokenStorage.saveRefreshToken(authResponse.refreshToken!);
        }
        return ApiResult.ok(authResponse);
      }

      final errorMsg =
          body['error']?['message'] as String? ?? 'Authentication failed';
      return ApiResult.fail(errorMsg);
    } on SocketException {
      return ApiResult.fail('network_error');
    } on HttpException {
      return ApiResult.fail('network_error');
    } catch (e) {
      return ApiResult.fail('something_went_wrong');
    }
  }

  // ── Refresh Token ───────────────────────────────────────────────

  Future<ApiResult<String>> refreshAccessToken() async {
    try {
      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken == null) {
        return ApiResult.fail('No refresh token');
      }

      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.refresh}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(ApiConfig.receiveTimeout);

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final newAccessToken = body['data']['accessToken'] as String;
        final newRefreshToken = body['data']['refreshToken'] as String?;
        await _tokenStorage.saveAccessToken(newAccessToken);
        if (newRefreshToken != null) {
          await _tokenStorage.saveRefreshToken(newRefreshToken);
        }
        return ApiResult.ok(newAccessToken);
      }

      return ApiResult.fail('Session expired');
    } catch (e) {
      return ApiResult.fail('something_went_wrong');
    }
  }

  // ── Retry Interceptor Wrapper ───────────────────────────────────

  Future<http.Response> _authRequest({
    required Future<http.Response> Function(String token) request,
  }) async {
    String? token = await _tokenStorage.getAccessToken();
    if (token == null) throw Exception('No access token');

    http.Response response = await request(token);

    if (response.statusCode == 401) {
      final refreshResult = await refreshAccessToken();
      if (refreshResult.success && refreshResult.data != null) {
        token = refreshResult.data!;
        response = await request(token);
      }
    }
    return response;
  }

  // ── Get Profile ─────────────────────────────────────────────────

  Future<ApiResult<Map<String, dynamic>>> getProfile() async {
    try {
      final response = await _authRequest(
        request: (token) => http.get(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.profile}'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(ApiConfig.receiveTimeout),
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return ApiResult.ok(body['data'] as Map<String, dynamic>);
      }

      final errorMsg = body['error']?['message'] as String? ?? 'Failed to get profile';
      return ApiResult.fail(errorMsg, statusCode: response.statusCode);
    } on SocketException {
      return ApiResult.fail('network_error');
    } catch (e) {
      return ApiResult.fail('something_went_wrong');
    }
  }

  // ── Update Profile ──────────────────────────────────────────────

  Future<ApiResult<Map<String, dynamic>>> updateProfile({
    String? displayName,
    String? language,
    String? experience,
  }) async {
    try {
      final bodyMap = <String, dynamic>{};
      if (displayName != null) bodyMap['display_name'] = displayName;
      if (language != null) bodyMap['language'] = language;
      if (experience != null) bodyMap['experience'] = experience;

      final response = await _authRequest(
        request: (token) => http.patch(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.profile}'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(bodyMap),
        ).timeout(ApiConfig.receiveTimeout),
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return ApiResult.ok(body['data'] as Map<String, dynamic>);
      }

      final errorMsg = body['error']?['message'] as String? ?? 'Update failed';
      return ApiResult.fail(errorMsg, statusCode: response.statusCode);
    } on SocketException {
      return ApiResult.fail('network_error');
    } catch (e) {
      return ApiResult.fail('something_went_wrong');
    }
  }

  // ── Market Data ────────────────────────────────────────────────

  Future<ApiResult<Map<String, dynamic>>> getMarketData([String? date]) async {
    try {
      final uri = date != null
          ? '${ApiConfig.baseUrl}${ApiConfig.market}?date=$date'
          : '${ApiConfig.baseUrl}${ApiConfig.market}';

      final response = await _authRequest(
        request: (token) => http.get(
          Uri.parse(uri),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(ApiConfig.receiveTimeout),
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return ApiResult.ok(body['data'] as Map<String, dynamic>);
      }

      final errorMsg = body['error']?['message'] as String? ?? body['message'] as String? ?? 'Failed to fetch market data';
      return ApiResult.fail(errorMsg, statusCode: response.statusCode);
    } on SocketException {
      return ApiResult.fail('network_error');
    } catch (e) {
      return ApiResult.fail('something_went_wrong');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getNextMarketDate(String current) async {
    try {
      final response = await _authRequest(
        request: (token) => http.get(
          Uri.parse('${ApiConfig.baseUrl}/api/market/next-date?current=$current'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(ApiConfig.receiveTimeout),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        return ApiResult.ok(body['data'] as Map<String, dynamic>);
      }
      return ApiResult.fail(body['error']?['message'] ?? body['message'] ?? 'No more data');
    } catch (_) {
      return ApiResult.fail('something_went_wrong');
    }
  }

  // ── Advance Day (Server-side) ──────────────────────────────────

  Future<ApiResult<Map<String, dynamic>>> advanceDay() async {
    try {
      final response = await _authRequest(
        request: (token) => http.post(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.advanceDay}'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(ApiConfig.receiveTimeout),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        return ApiResult.ok(body['data'] as Map<String, dynamic>);
      }
      return ApiResult.fail(body['error']?['message'] ?? body['message'] ?? 'Cannot advance day');
    } catch (_) {
      return ApiResult.fail('something_went_wrong');
    }
  }

  // ── Stock Detail ───────────────────────────────────────────────

  Future<ApiResult<Map<String, dynamic>>> getStockDetail(String ticker) async {
    try {
      final response = await _authRequest(
        request: (token) => http.get(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.stockDetail(ticker)}'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(ApiConfig.receiveTimeout),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        return ApiResult.ok(body['data'] as Map<String, dynamic>);
      }
      return ApiResult.fail(body['error']?['message'] ?? 'Failed to load stock');
    } on SocketException {
      return ApiResult.fail('network_error');
    } catch (e) {
      return ApiResult.fail('something_went_wrong');
    }
  }

  // ── Trading ────────────────────────────────────────────────────

  Future<ApiResult<Map<String, dynamic>>> buyStock(String ticker, int quantity) async {
    try {
      final response = await _authRequest(
        request: (token) => http.post(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.tradeBuy}'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'ticker': ticker, 'quantity': quantity}),
        ).timeout(ApiConfig.receiveTimeout),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        return ApiResult.ok(body['data'] as Map<String, dynamic>);
      }
      return ApiResult.fail(body['error']?['message'] ?? 'Buy failed');
    } on SocketException {
      return ApiResult.fail('network_error');
    } catch (e) {
      return ApiResult.fail('something_went_wrong');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> sellStock(String ticker, int quantity) async {
    try {
      final response = await _authRequest(
        request: (token) => http.post(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.tradeSell}'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'ticker': ticker, 'quantity': quantity}),
        ).timeout(ApiConfig.receiveTimeout),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        return ApiResult.ok(body['data'] as Map<String, dynamic>);
      }
      return ApiResult.fail(body['error']?['message'] ?? 'Sell failed');
    } on SocketException {
      return ApiResult.fail('network_error');
    } catch (e) {
      return ApiResult.fail('something_went_wrong');
    }
  }

  // ── Portfolio ──────────────────────────────────────────────────

  Future<ApiResult<Map<String, dynamic>>> getPortfolio() async {
    try {
      final response = await _authRequest(
        request: (token) => http.get(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.portfolio}'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(ApiConfig.receiveTimeout),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        return ApiResult.ok(body['data'] as Map<String, dynamic>);
      }
      return ApiResult.fail(body['error']?['message'] ?? 'Failed to load portfolio');
    } on SocketException {
      return ApiResult.fail('network_error');
    } catch (e) {
      return ApiResult.fail('something_went_wrong');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getTransactions({int limit = 50, int offset = 0}) async {
    try {
      final response = await _authRequest(
        request: (token) => http.get(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.transactions}?limit=$limit&offset=$offset'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(ApiConfig.receiveTimeout),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        return ApiResult.ok(body['data'] as Map<String, dynamic>);
      }
      return ApiResult.fail(body['error']?['message'] ?? 'Failed to load transactions');
    } catch (_) {
      return ApiResult.fail('something_went_wrong');
    }
  }

  // ── Leaderboard ────────────────────────────────────────────────

  Future<ApiResult<Map<String, dynamic>>> getLeaderboard({int limit = 20}) async {
    try {
      final response = await _authRequest(
        request: (token) => http.get(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.leaderboard}?limit=$limit'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(ApiConfig.receiveTimeout),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        return ApiResult.ok(body['data'] as Map<String, dynamic>);
      }
      return ApiResult.fail(body['error']?['message'] ?? 'Failed to load leaderboard');
    } catch (_) {
      return ApiResult.fail('something_went_wrong');
    }
  }

  // ── Logout ──────────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      final accessToken = await _tokenStorage.getAccessToken();
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.logout}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );
    } catch (_) {
      // Best-effort logout
    } finally {
      await _tokenStorage.clearAll();
    }
  }
}

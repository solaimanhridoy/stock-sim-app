import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles secure storage of tokens.
/// Uses SharedPreferences on Web (flutter_secure_storage is not supported on Web).
/// Uses flutter_secure_storage on mobile (Keychain/Keystore).
class TokenStorage {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  static final TokenStorage _instance = TokenStorage._internal();
  factory TokenStorage() => _instance;
  TokenStorage._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// In-memory cache for fast access token reads.
  String? _accessTokenCache;

  // ── Access Token ────────────────────────────────────────────────

  Future<void> saveAccessToken(String token) async {
    _accessTokenCache = token;
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accessTokenKey, token);
    } else {
      await _secureStorage.write(key: _accessTokenKey, value: token);
    }
  }

  Future<String?> getAccessToken() async {
    if (_accessTokenCache != null) return _accessTokenCache;
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      _accessTokenCache = prefs.getString(_accessTokenKey);
    } else {
      _accessTokenCache = await _secureStorage.read(key: _accessTokenKey);
    }
    return _accessTokenCache;
  }

  // ── Refresh Token ───────────────────────────────────────────────

  Future<void> saveRefreshToken(String token) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_refreshTokenKey, token);
    } else {
      await _secureStorage.write(key: _refreshTokenKey, value: token);
    }
  }

  Future<String?> getRefreshToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_refreshTokenKey);
    } else {
      return await _secureStorage.read(key: _refreshTokenKey);
    }
  }

  // ── Clear All ───────────────────────────────────────────────────

  Future<void> clearAll() async {
    _accessTokenCache = null;
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_accessTokenKey);
      await prefs.remove(_refreshTokenKey);
    } else {
      await _secureStorage.deleteAll();
    }
  }
}

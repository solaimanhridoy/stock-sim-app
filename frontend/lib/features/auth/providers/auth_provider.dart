import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/token_storage.dart';

/// Authentication state.
enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

/// Manages authentication state for the app.
class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final TokenStorage _tokenStorage = TokenStorage();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '779423654508-urmdpmdjk8qjnqh6otmacmmn99v2t6ml.apps.googleusercontent.com',
    scopes: ['email', 'profile'],
  );

  AuthStatus _status = AuthStatus.initial;
  String? _errorKey; // Localization key for error message
  bool _isNewUser = false;
  Map<String, dynamic>? _user;
  bool _initializing = false;

  // ── Getters ─────────────────────────────────────────────────────

  AuthStatus get status => _status;
  String? get errorKey => _errorKey;
  bool get isNewUser => _isNewUser;
  bool get isLoading => _status == AuthStatus.loading;
  Map<String, dynamic>? get user => _user;

  // ── Initialization ──────────────────────────────────────────────

  /// Checks if a user is already logged in on app startup.
  /// Tries to fetch the profile; if the token expired, attempts a refresh.
  Future<void> initializeAuth() async {
    if (_initializing) return;
    _initializing = true;
    try {
      final token = await _tokenStorage.getAccessToken();

      if (token == null) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      _status = AuthStatus.loading;
      notifyListeners();

      // Token exists, verify it by fetching the user profile
      final result = await _apiService.getProfile();

      if (result.success && result.data != null) {
        _user = result.data;
        _isNewUser = false; // returning user
        _status = AuthStatus.authenticated;
        notifyListeners();
        return;
      }

      // Profile fetch failed — try refreshing the token if 401
      if (result.statusCode == 401 || result.error == 'Session expired') {
        final refreshResult = await _apiService.refreshAccessToken();

        if (refreshResult.success && refreshResult.data != null) {
          // Token refreshed — retry profile fetch
          final retryResult = await _apiService.getProfile();

          if (retryResult.success && retryResult.data != null) {
            _user = retryResult.data;
            _isNewUser = false;
            _status = AuthStatus.authenticated;
            notifyListeners();
            return;
          }
        }

        // Refresh failed — force re-login
        await _clearAuthState();
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      // Other errors (network, etc.) — go to login
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    } finally {
      _initializing = false;
    }
  }

  // ── Google Sign-In Flow ─────────────────────────────────────────

  Future<void> signInWithGoogle() async {
    _status = AuthStatus.loading;
    _errorKey = null;
    notifyListeners();

    try {
      // 1. Trigger Google Sign-In
      final googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled
        _status = AuthStatus.unauthenticated;
        _errorKey = 'google_sign_in_cancelled';
        notifyListeners();
        return;
      }

      // 1.5 On Flutter Web, GIS splits Authentication and Authorization. 
      // We must explicitly request scopes to receive an accessToken.
      if (kIsWeb) {
        await _googleSignIn.requestScopes(['email', 'profile']);
      }

      // 2. Get tokens
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null && accessToken == null) {
        _status = AuthStatus.error;
        _errorKey = 'login_error';
        notifyListeners();
        return;
      }

      // 3. Send tokens to backend
      final result = await _apiService.loginWithGoogle(
        idToken: idToken,
        accessToken: accessToken,
      );

      if (result.success && result.data != null) {
        _isNewUser = result.data!.isNewUser;
        _user = result.data!.user;
        _status = AuthStatus.authenticated;
      } else {
        _status = AuthStatus.error;
        _errorKey = result.error ?? 'login_error';
      }
    } catch (e, stackTrace) {
      debugPrint('signInWithGoogle error: $e\n$stackTrace');
      _status = AuthStatus.error;
      _errorKey = 'something_went_wrong';
    }

    notifyListeners();
  }

  // ── Sign Out ────────────────────────────────────────────────────

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Google sign out can fail silently on web
    }
    await _apiService.logout();
    _status = AuthStatus.unauthenticated;
    _isNewUser = false;
    _user = null;
    _errorKey = null;
    notifyListeners();
  }

  // ── Profile Update ──────────────────────────────────────────────

  Future<bool> updateProfile({
    String? displayName,
    String? language,
    String? experience,
  }) async {
    final result = await _apiService.updateProfile(
      displayName: displayName,
      language: language,
      experience: experience,
    );
    if (result.success) {
      // Mark user as no longer new after profile setup
      _isNewUser = false;
      notifyListeners();
    }
    return result.success;
  }

  // ── Clear Error ─────────────────────────────────────────────────

  void clearError() {
    _errorKey = null;
    notifyListeners();
  }

  // ── Internal ────────────────────────────────────────────────────

  Future<void> _clearAuthState() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _tokenStorage.clearAll();
    _user = null;
    _isNewUser = false;
    _errorKey = null;
  }
}

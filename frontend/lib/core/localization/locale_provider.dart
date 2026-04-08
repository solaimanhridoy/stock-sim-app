import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

/// Manages the app locale (Bangla / English) and persists user preference.
class LocaleProvider extends ChangeNotifier {
  static const String _prefKey = 'app_locale';
  
  // Default to Bangla (bn) per requirements
  Locale _locale = const Locale('bn');
  
  final ApiService _apiService = ApiService();

  Locale get locale => _locale;

  bool get isBangla => _locale.languageCode == 'bn';

  /// Call this when the app starts.
  Future<void> loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_prefKey);
    if (savedCode != null) {
      _locale = Locale(savedCode);
      notifyListeners();
    }
  }

  Future<void> toggleLocale() async {
    final newCode = _locale.languageCode == 'en' ? 'bn' : 'en';
    await _updateLocale(newCode);
  }

  Future<void> setLocale(Locale newLocale) async {
    await _updateLocale(newLocale.languageCode);
  }

  Future<void> _updateLocale(String code) async {
    _locale = Locale(code);
    notifyListeners();

    // 1. Save locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, code);

    // 2. Try saving to backend (fire and forget)
    // If the user isn't logged in, the token will be null and the backend 
    // patch will naturally fail silently due to our ApiService error catching.
    _apiService.updateProfile(language: code);
  }
}

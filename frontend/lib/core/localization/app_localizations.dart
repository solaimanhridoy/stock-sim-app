import 'dart:async';
import 'package:flutter/material.dart';

/// A minimal, self-contained localization system.
/// No code generation required — just add strings to the maps below.
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  // ── String Maps ─────────────────────────────────────────────────
  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // Login Screen
      'app_name': 'StockSim',
      'app_tagline': 'Learn to invest.\nRisk-free.',
      'app_description':
          'Practice stock trading with virtual money in the Bangladesh stock market',
      'continue_with_google': 'Continue with Google',
      'terms_notice':
          'By continuing, you agree to our Terms of Service and Privacy Policy',
      'login_error': 'Login failed. Please try again.',
      'network_error': 'Network error. Check your connection.',
      'google_sign_in_cancelled': 'Sign-in was cancelled',
      'something_went_wrong': 'Something went wrong',

      // Language Toggle
      'language_bangla': 'বাংলা',
      'language_english': 'English',

      // Profile Setup
      'profile_setup_title': 'Set Up Your Profile',
      'profile_setup_subtitle': 'Tell us a bit about yourself',
      'profile_greeting': 'Welcome aboard! 👋',
      'display_name_label': 'Display Name',
      'display_name_hint': 'Enter your name',
      'display_name_empty_error': 'Name cannot be empty',
      'select_language': 'Preferred Language',
      'select_experience': 'How would you describe yourself?',
      'experience_beginner': 'Beginner',
      'experience_intermediate': 'Intermediate',
      'continue_btn': 'Get Started',
      'beginner_desc': "I'm new to stock trading",
      'intermediate_desc': 'I have some trading experience',
      'profile_save_error': 'Failed to save profile. Please try again.',

      // Dashboard
      'dashboard_title': 'Dashboard',
      'welcome_back': 'Welcome back!',
      'virtual_balance': 'Virtual Balance',
      'simulation_date': 'Simulation Date',
      'next_day': 'Next Day',
      'market_summary': 'Market Summary',
      'top_gainers': 'Top Gainers',
      'top_losers': 'Top Losers',
      'search_stocks': 'Search Stocks...',

      // General
      'loading': 'Loading...',
      'retry': 'Retry',
    },
    'bn': {
      // Login Screen
      'app_name': 'স্টক সিম',
      'app_tagline': 'বিনিয়োগ শিখুন।\nঝুঁকিমুক্ত।',
      'app_description':
          'বাংলাদেশ শেয়ারবাজারে ভার্চুয়াল টাকা দিয়ে শেয়ার ট্রেডিং অনুশীলন করুন',
      'continue_with_google': 'গুগল দিয়ে চালিয়ে যান',
      'terms_notice':
          'চালিয়ে যাওয়ার মাধ্যমে আপনি আমাদের সেবার শর্তাবলী এবং গোপনীয়তা নীতিতে সম্মতি দিচ্ছেন',
      'login_error': 'লগইন ব্যর্থ হয়েছে। আবার চেষ্টা করুন।',
      'network_error': 'নেটওয়ার্ক ত্রুটি। আপনার সংযোগ পরীক্ষা করুন।',
      'google_sign_in_cancelled': 'সাইন-ইন বাতিল করা হয়েছে',
      'something_went_wrong': 'কিছু একটা সমস্যা হয়েছে',

      // Language Toggle
      'language_bangla': 'বাংলা',
      'language_english': 'English',

      // Profile Setup
      'profile_setup_title': 'আপনার প্রোফাইল সেটআপ করুন',
      'profile_setup_subtitle': 'আপনার সম্পর্কে কিছু বলুন',
      'profile_greeting': 'স্বাগতম! 👋',
      'display_name_label': 'প্রদর্শন নাম',
      'display_name_hint': 'আপনার নাম লিখুন',
      'display_name_empty_error': 'নাম খালি রাখা যাবে না',
      'select_language': 'পছন্দের ভাষা',
      'select_experience': 'আপনি নিজেকে কীভাবে বর্ণনা করবেন?',
      'experience_beginner': 'নতুন',
      'experience_intermediate': 'মাঝারি',
      'continue_btn': 'শুরু করুন',
      'beginner_desc': 'শেয়ার ট্রেডিংয়ে আমি নতুন',
      'intermediate_desc': 'আমার কিছুটা ট্রেডিং অভিজ্ঞতা আছে',
      'profile_save_error': 'প্রোফাইল সংরক্ষণ ব্যর্থ হয়েছে। আবার চেষ্টা করুন।',

      // Dashboard
      'dashboard_title': 'ড্যাশবোর্ড',
      'welcome_back': 'আবার স্বাগতম!',
      'virtual_balance': 'ভার্চুয়াল ব্যালেন্স',
      'simulation_date': 'সিমুলেশন তারিখ',
      'next_day': 'পরের দিন',
      'market_summary': 'মার্কেট সারাংশ',
      'top_gainers': 'সেরা লাভজনক',
      'top_losers': 'সেরা লোকসান',
      'search_stocks': 'শেয়ার খুঁজুন...',

      // General
      'loading': 'লোড হচ্ছে...',
      'retry': 'আবার চেষ্টা করুন',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'bn'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant _AppLocalizationsDelegate old) => false;
}

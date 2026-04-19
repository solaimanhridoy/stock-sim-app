import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';

enum LeaderboardStatus { initial, loading, loaded, error }

class LeaderboardProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  LeaderboardStatus _status = LeaderboardStatus.initial;
  String? _errorMessage;
  List<dynamic> _leaderboard = [];
  Map<String, dynamic>? _currentUserRank;

  // ── Getters ─────────────────────────────────────────────────────

  LeaderboardStatus get status => _status;
  String? get errorMessage => _errorMessage;
  List<dynamic> get leaderboard => _leaderboard;
  Map<String, dynamic>? get currentUserRank => _currentUserRank;
  bool get isLoading => _status == LeaderboardStatus.loading;

  // ── Fetch Leaderboard ───────────────────────────────────────────

  Future<void> fetchLeaderboard() async {
    _status = LeaderboardStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await _apiService.getLeaderboard();

    if (result.success && result.data != null) {
      _leaderboard = result.data!['leaderboard'] ?? [];
      _currentUserRank = result.data!['current_user_rank'];
      _status = LeaderboardStatus.loaded;
    } else {
      _status = LeaderboardStatus.error;
      _errorMessage = result.error ?? 'Failed to load leaderboard';
    }
    notifyListeners();
  }
}

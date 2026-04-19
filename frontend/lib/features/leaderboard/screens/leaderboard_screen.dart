import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/leaderboard_provider.dart';

/// Leaderboard screen: weekly rankings by profit %.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeaderboardProvider>().fetchLeaderboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lb = context.watch<LeaderboardProvider>();

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.translate('leaderboard'), style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                    const SizedBox(height: 4),
                    Text(t.translate('leaderboard_subtitle'), style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Content ─────────────────────────────────────
              if (lb.isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator(color: AppTheme.primary)))
              else if (lb.leaderboard.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.emoji_events_outlined, size: 64, color: AppTheme.textMuted),
                        const SizedBox(height: 16),
                        Text(t.translate('no_rankings'), style: GoogleFonts.inter(fontSize: 16, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: lb.fetchLeaderboard,
                    color: AppTheme.primary,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: lb.leaderboard.length,
                      itemBuilder: (context, index) {
                        final entry = lb.leaderboard[index];
                        final rank = entry['rank'] as int;
                        final profitPct = (entry['profit_pct'] as num).toDouble();
                        final isCurrentUser = entry['is_current_user'] == true;
                        final isPositive = profitPct >= 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isCurrentUser
                                ? AppTheme.primary.withValues(alpha: 0.15)
                                : AppTheme.surfaceCard,
                            borderRadius: AppTheme.borderRadiusMd,
                            border: isCurrentUser
                                ? Border.all(color: AppTheme.primary.withValues(alpha: 0.5), width: 1.5)
                                : null,
                          ),
                          child: Row(
                            children: [
                              // Rank badge
                              SizedBox(
                                width: 40,
                                child: rank <= 3
                                    ? _rankMedal(rank)
                                    : Text('#$rank',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                              ),
                              const SizedBox(width: 12),

                              // Avatar
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppTheme.surfaceLight,
                                backgroundImage: entry['avatar_url'] != null
                                    ? NetworkImage(entry['avatar_url'])
                                    : null,
                                child: entry['avatar_url'] == null
                                    ? const Icon(Icons.person, size: 18, color: AppTheme.textMuted)
                                    : null,
                              ),
                              const SizedBox(width: 12),

                              // Name
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            entry['display_name'] ?? 'Investor',
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: isCurrentUser ? FontWeight.w700 : FontWeight.w600,
                                              color: AppTheme.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isCurrentUser) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(4)),
                                            child: Text(t.translate('you'), style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      '৳${(entry['total_value'] as num).toStringAsFixed(0)}',
                                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ),

                              // Profit %
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: (isPositive ? AppTheme.success : AppTheme.error).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${isPositive ? '+' : ''}${profitPct.toStringAsFixed(2)}%',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isPositive ? AppTheme.success : AppTheme.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rankMedal(int rank) {
    final colors = {
      1: const Color(0xFFFFD700),
      2: const Color(0xFFC0C0C0),
      3: const Color(0xFFCD7F32),
    };
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: (colors[rank] ?? AppTheme.primary).withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉',
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}

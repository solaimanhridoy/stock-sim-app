import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../dashboard/providers/market_provider.dart';

/// Landing page after login with simulation controls.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Initial fetch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MarketProvider>().fetchMarketData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final auth = context.watch<AuthProvider>();
    final market = context.watch<MarketProvider>();
    final user = auth.user;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.translate('welcome_back'),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user?['displayName'] ?? 'Investor',
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () async => await auth.signOut(),
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor: AppTheme.surfaceCard,
                              backgroundImage: user?['avatarUrl'] != null ? NetworkImage(user!['avatarUrl']) : null,
                              child: user?['avatarUrl'] == null ? const Icon(Icons.person, color: AppTheme.textSecondary) : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      // Balance card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: AppTheme.borderRadiusLg,
                          boxShadow: AppTheme.glowShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.translate('virtual_balance'),
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.8)),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '৳ ${_formatBalance(user?['virtualBalance'])}',
                              style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Simulation Control
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceCard,
                          borderRadius: AppTheme.borderRadiusMd,
                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.translate('simulation_date'), style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                                Text(market.currentDate, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: market.isLoading ? null : () => market.nextDay(),
                              icon: const Icon(Icons.skip_next_rounded),
                              label: Text(t.translate('next_day')),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusMd),
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Search Bar
                      TextField(
                        style: GoogleFonts.inter(color: AppTheme.textPrimary),
                        decoration: AppTheme.inputDecoration(
                          hint: t.translate('search_stocks'),
                          icon: Icons.search_rounded,
                        ),
                        onChanged: (val) {
                          // TODO: Implement search filter
                        },
                      ),
                      const SizedBox(height: 32),
                      Text(t.translate('market_summary'), style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                if (market.isLoading)
                  const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
                else if (market.status == MarketStatus.error)
                  SliverFillRemaining(child: Center(child: Text(t.translate(market.errorMessage ?? 'something_went_wrong'))))
                else ...[
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummarySection(t.translate('top_gainers'), market.marketSummary?['gainers'], Colors.greenAccent),
                        const SizedBox(height: 24),
                        _buildSummarySection(t.translate('top_losers'), market.marketSummary?['losers'], Colors.redAccent),
                        const SizedBox(height: 32),
                        Text('All Stocks', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final stock = market.stocks[index];
                        final change = stock['change_percentage'] ?? 0.0;
                        final color = change >= 0 ? Colors.greenAccent : Colors.redAccent;
                        final trendIcon = change >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceCard,
                            borderRadius: AppTheme.borderRadiusMd,
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                                child: Icon(trendIcon, color: color, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(stock['ticker'], style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                                    Text(stock['company_name'] ?? '', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('৳ ${stock['close']}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
                                  Text('${change > 0 ? '+' : ''}$change%', style: GoogleFonts.inter(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                      childCount: market.stocks.length,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummarySection(String title, List<dynamic>? stocks, Color color) {
    if (stocks == null || stocks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        ...stocks.map((s) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.surfaceCard, borderRadius: AppTheme.borderRadiusMd),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(s['ticker'], style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  Text('${s['change_percentage']}%', style: GoogleFonts.inter(color: color, fontWeight: FontWeight.bold)),
                ],
              ),
            )),
      ],
    );
  }

  String _formatBalance(dynamic balance) {
    if (balance == null) return '1,00,000.00';
    final num = (balance is double) ? balance : double.tryParse('$balance') ?? 0;
    // Bangladeshi number format: 1,00,000.00
    final parts = num.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];

    if (intPart.length <= 3) return '$intPart.$decPart';

    final lastThree = intPart.substring(intPart.length - 3);
    final remaining = intPart.substring(0, intPart.length - 3);
    final formatted = remaining.replaceAllMapped(
      RegExp(r'\B(?=(\d{2})+(?!\d))'),
      (m) => ',',
    );
    return '$formatted,$lastThree.$decPart';
  }
}

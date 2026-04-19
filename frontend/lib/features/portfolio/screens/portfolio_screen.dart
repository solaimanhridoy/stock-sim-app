import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/portfolio_provider.dart';

/// Portfolio screen: shows holdings with P&L and transaction history.
class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<PortfolioProvider>();
      prov.fetchPortfolio();
      prov.fetchTransactions();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final portfolio = context.watch<PortfolioProvider>();
    final summary = portfolio.summary;

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
                child: Text(t.translate('portfolio'), style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              ),
              const SizedBox(height: 16),

              // ── Summary Card ────────────────────────────────
              if (summary != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: AppTheme.borderRadiusLg,
                      boxShadow: AppTheme.glowShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.translate('total_portfolio_value'), style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
                        const SizedBox(height: 4),
                        Text(
                          '৳ ${_formatBD((summary['total_portfolio_value'] as num?)?.toDouble() ?? 100000)}',
                          style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _summaryChip(
                              t.translate('profit_loss'),
                              '${(summary['total_pnl'] as num?) != null && (summary['total_pnl'] as num) >= 0 ? '+' : ''}৳${(summary['total_pnl'] as num?)?.toStringAsFixed(2) ?? '0'}',
                              (summary['total_pnl'] as num?) != null && (summary['total_pnl'] as num) >= 0,
                            ),
                            const SizedBox(width: 8),
                            _summaryChip(
                              t.translate('cash'),
                              '৳${_formatBD((summary['cash_balance'] as num?)?.toDouble() ?? 0)}',
                              true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // ── Tabs ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: AppTheme.borderRadiusMd,
                    color: AppTheme.primary,
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppTheme.textSecondary,
                  labelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                  tabs: [
                    Tab(text: t.translate('holdings')),
                    Tab(text: t.translate('history')),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Tab Content ─────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Holdings
                    _buildHoldingsTab(portfolio, t),
                    // Tab 2: Transaction History
                    _buildTransactionsTab(portfolio, t),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHoldingsTab(PortfolioProvider portfolio, AppLocalizations t) {
    if (portfolio.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    if (portfolio.holdings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 64, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text(t.translate('no_holdings'), style: GoogleFonts.inter(fontSize: 16, color: AppTheme.textSecondary)),
            Text(t.translate('start_trading'), style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: portfolio.fetchPortfolio,
      color: AppTheme.primary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: portfolio.holdings.length,
        itemBuilder: (context, index) {
          final h = portfolio.holdings[index];
          final pnl = (h['unrealized_pnl'] as num?)?.toDouble() ?? 0;
          final pnlPct = (h['pnl_percentage'] as num?)?.toDouble() ?? 0;
          final isPositive = pnl >= 0;
          final color = isPositive ? AppTheme.success : AppTheme.error;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: AppTheme.borderRadiusMd,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Icon(isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(h['ticker'], style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                          Text('${h['quantity']} ${t.translate('shares')} @ ৳${(h['avg_price'] as num).toStringAsFixed(2)}',
                              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('৳${(h['market_value'] as num).toStringAsFixed(0)}',
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                        Text(
                          '${isPositive ? '+' : ''}${pnl.toStringAsFixed(0)} (${pnlPct.toStringAsFixed(1)}%)',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransactionsTab(PortfolioProvider portfolio, AppLocalizations t) {
    if (portfolio.transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 64, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text(t.translate('no_transactions'), style: GoogleFonts.inter(fontSize: 16, color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: portfolio.transactions.length,
      itemBuilder: (context, index) {
        final tx = portfolio.transactions[index];
        final isBuy = tx['action'] == 'BUY';
        final color = isBuy ? AppTheme.success : AppTheme.error;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: AppTheme.surfaceCard, borderRadius: AppTheme.borderRadiusSm),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(isBuy ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${tx['action']} ${tx['ticker']}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    Text('${tx['quantity']} × ৳${(tx['price'] as num).toStringAsFixed(2)}',
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('৳${(tx['total_value'] as num).toStringAsFixed(0)}',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
                  Text(tx['date'].toString().split('T')[0], style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryChip(String label, String value, bool positive) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.white70)),
            const SizedBox(height: 2),
            Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  String _formatBD(double num) {
    final parts = num.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    if (intPart.length <= 3) return '$intPart.$decPart';
    final lastThree = intPart.substring(intPart.length - 3);
    final remaining = intPart.substring(0, intPart.length - 3);
    final formatted = remaining.replaceAllMapped(RegExp(r'\B(?=(\d{2})+(?!\d))'), (m) => ',');
    return '$formatted,$lastThree.$decPart';
  }
}

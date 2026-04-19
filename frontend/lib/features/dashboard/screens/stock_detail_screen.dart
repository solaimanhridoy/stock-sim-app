import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/market_provider.dart';
import 'trade_dialog.dart';

/// Detail screen for a single stock with price history and buy/sell.
class StockDetailScreen extends StatefulWidget {
  final String ticker;
  final String companyName;
  final double currentPrice;
  final double changePercentage;

  const StockDetailScreen({
    super.key,
    required this.ticker,
    required this.companyName,
    required this.currentPrice,
    required this.changePercentage,
  });

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  final ApiService _apiService = ApiService();
  bool _loading = true;
  Map<String, dynamic>? _stockData;
  List<dynamic> _priceHistory = [];
  Map<String, dynamic>? _holding;

  @override
  void initState() {
    super.initState();
    _loadStockDetail();
  }

  Future<void> _loadStockDetail() async {
    setState(() => _loading = true);
    final result = await _apiService.getStockDetail(widget.ticker);
    if (result.success && result.data != null) {
      setState(() {
        _stockData = result.data!['stock'];
        _priceHistory = result.data!['price_history'] ?? [];
        _holding = result.data!['holding'];
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final isPositive = widget.changePercentage >= 0;
    final changeColor = isPositive ? AppTheme.success : AppTheme.error;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ── App Bar ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.ticker, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                          Text(widget.companyName, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),

                            // ── Price Card ─────────────────────────
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                gradient: AppTheme.cardGradient,
                                borderRadius: AppTheme.borderRadiusLg,
                                border: Border.all(color: changeColor.withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.translate('current_price'), style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                                  const SizedBox(height: 4),
                                  Text('৳ ${widget.currentPrice.toStringAsFixed(2)}',
                                      style: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: changeColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                                    child: Text(
                                      '${isPositive ? '+' : ''}${widget.changePercentage.toStringAsFixed(2)}%',
                                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: changeColor),
                                    ),
                                  ),
                                  if (_stockData?['sector'] != null) ...[
                                    const SizedBox(height: 12),
                                    Text(_stockData!['sector'], style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
                                  ],
                                ],
                              ),
                            ),

                            // ── Mini Price Chart ───────────────────
                            if (_priceHistory.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              Text(t.translate('price_history'), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 120,
                                child: CustomPaint(
                                  size: const Size(double.infinity, 120),
                                  painter: _MiniChartPainter(
                                    prices: _priceHistory.map((p) => double.tryParse(p['close'].toString()) ?? 0).toList(),
                                    color: changeColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_priceHistory.first['date'].toString().split('T')[0], style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted)),
                                  Text(_priceHistory.last['date'].toString().split('T')[0], style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted)),
                                ],
                              ),
                            ],

                            // ── Your Holding ──────────────────────
                            if (_holding != null) ...[
                              const SizedBox(height: 24),
                              Text(t.translate('your_holding'), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: AppTheme.surfaceCard, borderRadius: AppTheme.borderRadiusMd),
                                child: Column(
                                  children: [
                                    _holdingRow(t.translate('shares_owned'), '${_holding!['quantity']}'),
                                    _holdingRow(t.translate('avg_price'), '৳ ${(_holding!['avg_price'] as num).toStringAsFixed(2)}'),
                                    _holdingRow(t.translate('current_value'), '৳ ${(_holding!['current_value'] as num?)?.toStringAsFixed(2) ?? '-'}'),
                                    _holdingRow(
                                      t.translate('profit_loss'),
                                      '৳ ${(_holding!['pnl'] as num?)?.toStringAsFixed(2) ?? '-'}',
                                      valueColor: (_holding!['pnl'] as num?) != null
                                          ? ((_holding!['pnl'] as num) >= 0 ? AppTheme.success : AppTheme.error)
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // ── OHLCV Table ───────────────────────
                            if (_priceHistory.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              Text(t.translate('price_data'), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                              const SizedBox(height: 12),
                              ..._priceHistory.reversed.take(10).map((p) => Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(color: AppTheme.surfaceCard, borderRadius: AppTheme.borderRadiusSm),
                                    child: Row(
                                      children: [
                                        Expanded(child: Text(p['date'].toString().split('T')[0], style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary))),
                                        Text('৳${double.tryParse(p['close'].toString())?.toStringAsFixed(1) ?? '-'}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                        const SizedBox(width: 8),
                                        Text('Vol: ${_formatVolume(int.tryParse(p['volume'].toString()) ?? 0)}', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                                      ],
                                    ),
                                  )),
                            ],

                            const SizedBox(height: 100), // Space for bottom buttons
                          ],
                        ),
                      ),
              ),

              // ── Buy / Sell Buttons ──────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  border: Border(top: BorderSide(color: AppTheme.surfaceCard)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusMd),
                        ),
                        onPressed: () => _showTradeDialog(context, true),
                        child: Text(t.translate('buy'), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusMd),
                        ),
                        onPressed: _holding != null ? () => _showTradeDialog(context, false) : null,
                        child: Text(t.translate('sell'), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _holdingRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary)),
          Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor ?? AppTheme.textPrimary)),
        ],
      ),
    );
  }

  void _showTradeDialog(BuildContext context, bool isBuy) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TradeDialog(
        ticker: widget.ticker,
        companyName: widget.companyName,
        price: widget.currentPrice,
        isBuy: isBuy,
        maxSellQuantity: _holding != null ? (_holding!['quantity'] as int) : 0,
        onTradeComplete: () {
          _loadStockDetail(); // Refresh holding data
          context.read<MarketProvider>().fetchMarketData(); // Refresh balance
        },
      ),
    );
  }

  String _formatVolume(int vol) {
    if (vol >= 1000000) return '${(vol / 1000000).toStringAsFixed(1)}M';
    if (vol >= 1000) return '${(vol / 1000).toStringAsFixed(1)}K';
    return vol.toString();
  }
}

/// Draws a simple line chart from price data.
class _MiniChartPainter extends CustomPainter {
  final List<double> prices;
  final Color color;

  _MiniChartPainter({required this.prices, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (prices.isEmpty) return;

    final min = prices.reduce((a, b) => a < b ? a : b);
    final max = prices.reduce((a, b) => a > b ? a : b);
    final range = max - min == 0 ? 1.0 : max - min;

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < prices.length; i++) {
      final x = (i / (prices.length - 1)) * size.width;
      final y = size.height - ((prices[i] - min) / range) * size.height * 0.9;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

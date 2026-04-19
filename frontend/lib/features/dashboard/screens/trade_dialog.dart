import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../portfolio/providers/portfolio_provider.dart';

/// Bottom sheet dialog for executing buy/sell trades.
class TradeDialog extends StatefulWidget {
  final String ticker;
  final String companyName;
  final double price;
  final bool isBuy;
  final int maxSellQuantity;
  final VoidCallback onTradeComplete;

  const TradeDialog({
    super.key,
    required this.ticker,
    required this.companyName,
    required this.price,
    required this.isBuy,
    required this.maxSellQuantity,
    required this.onTradeComplete,
  });

  @override
  State<TradeDialog> createState() => _TradeDialogState();
}

class _TradeDialogState extends State<TradeDialog> {
  final _quantityController = TextEditingController(text: '1');
  bool _processing = false;
  String? _errorMessage;
  int _quantity = 1;

  double get _totalCost => widget.price * _quantity;

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final auth = context.watch<AuthProvider>();
    final balance = (auth.user?['virtualBalance'] as num?)?.toDouble() ?? 0;
    final isBuy = widget.isBuy;
    final accentColor = isBuy ? AppTheme.success : AppTheme.error;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: accentColor.withValues(alpha: 0.3), width: 2)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppTheme.textMuted, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  isBuy ? t.translate('buy') : t.translate('sell'),
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: accentColor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.ticker, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                    Text(widget.companyName, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Price ─────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.surfaceCard, borderRadius: AppTheme.borderRadiusMd),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(t.translate('price_per_share'), style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary)),
                Text('৳ ${widget.price.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Quantity ──────────────────────────────────────
          Text(t.translate('quantity'), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Row(
            children: [
              _quantityButton(Icons.remove, () {
                if (_quantity > 1) setState(() { _quantity--; _quantityController.text = '$_quantity'; });
              }),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppTheme.surfaceCard,
                    border: OutlineInputBorder(borderRadius: AppTheme.borderRadiusMd, borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (val) {
                    final parsed = int.tryParse(val);
                    if (parsed != null && parsed > 0) {
                      setState(() { _quantity = parsed; _errorMessage = null; });
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              _quantityButton(Icons.add, () {
                setState(() { _quantity++; _quantityController.text = '$_quantity'; });
              }),
            ],
          ),
          const SizedBox(height: 16),

          // ── Total & Balance ───────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.08),
              borderRadius: AppTheme.borderRadiusMd,
              border: Border.all(color: accentColor.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(t.translate('total_cost'), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                    Text('৳ ${_totalCost.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: accentColor)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isBuy ? t.translate('available_balance') : t.translate('shares_owned'),
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
                    Text(
                      isBuy ? '৳ ${balance.toStringAsFixed(2)}' : '${widget.maxSellQuantity}',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Error ─────────────────────────────────────────
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(_errorMessage!, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.error), textAlign: TextAlign.center),
          ],
          const SizedBox(height: 20),

          // ── Submit Button ─────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusMd),
                disabledBackgroundColor: accentColor.withValues(alpha: 0.3),
              ),
              onPressed: _processing ? null : _executeTrade,
              child: _processing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                      isBuy
                          ? '${t.translate("buy")} ${widget.ticker}'
                          : '${t.translate("sell")} ${widget.ticker}',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quantityButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: AppTheme.surfaceCard, borderRadius: AppTheme.borderRadiusMd),
        child: Icon(icon, color: AppTheme.textPrimary, size: 20),
      ),
    );
  }

  Future<void> _executeTrade() async {
    if (_quantity <= 0) {
      setState(() => _errorMessage = 'Invalid quantity');
      return;
    }

    setState(() { _processing = true; _errorMessage = null; });

    final portfolio = context.read<PortfolioProvider>();
    final result = widget.isBuy
        ? await portfolio.buyStock(widget.ticker, _quantity)
        : await portfolio.sellStock(widget.ticker, _quantity);

    if (result.success) {
      widget.onTradeComplete();
      if (mounted) {
        // Refresh auth user data to update balance display
        await context.read<AuthProvider>().initializeAuth();
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isBuy
                  ? 'Bought $_quantity shares of ${widget.ticker}'
                  : 'Sold $_quantity shares of ${widget.ticker}',
            ),
            backgroundColor: widget.isBuy ? AppTheme.success : AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } else {
      setState(() {
        _errorMessage = result.error ?? 'Trade failed';
        _processing = false;
      });
    }
  }
}

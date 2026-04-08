import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/animated_background.dart';
import '../widgets/google_sign_in_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<Offset> _buttonSlideAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _buttonSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final size = MediaQuery.of(context).size;

    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return Scaffold(
          body: Stack(
            children: [
              // Animated background
              const AnimatedBackground(),

              // Main content
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      // Language toggle — top right
                      _buildLanguageToggle(context),

                      const Spacer(flex: 2),

                      // Logo & branding
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: _buildBranding(t, size),
                        ),
                      ),

                      const Spacer(flex: 2),

                      // Google Sign-In button + error
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _buttonSlideAnimation,
                          child: _buildAuthSection(context, auth, t),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Terms notice
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            t.translate('terms_notice'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppTheme.textMuted,
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Language Toggle ─────────────────────────────────────────────

  Widget _buildLanguageToggle(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    final isBangla = localeProvider.isBangla;

    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard.withValues(alpha: 0.7),
            borderRadius: AppTheme.borderRadiusFull,
            border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: InkWell(
            borderRadius: AppTheme.borderRadiusFull,
            onTap: () => localeProvider.toggleLocale(),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '🌐',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      isBangla ? 'English' : 'বাংলা',
                      key: ValueKey(isBangla),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Branding ────────────────────────────────────────────────────

  Widget _buildBranding(AppLocalizations t, Size size) {
    return Column(
      children: [
        // App icon
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: AppTheme.borderRadiusXl,
            boxShadow: AppTheme.glowShadow,
          ),
          child: const Center(
            child: Icon(
              Icons.candlestick_chart_rounded,
              size: 44,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 28),

        // App name
        ShaderMask(
          shaderCallback: (bounds) =>
              AppTheme.primaryGradient.createShader(bounds),
          child: Text(
            t.translate('app_name'),
            style: GoogleFonts.inter(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Tagline
        Text(
          t.translate('app_tagline'),
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w300,
            color: AppTheme.textPrimary.withValues(alpha: 0.9),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),

        // Description
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: min(size.width * 0.8, 360)),
          child: Text(
            t.translate('app_description'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  // ── Auth Section ────────────────────────────────────────────────

  Widget _buildAuthSection(
      BuildContext context, AuthProvider auth, AppLocalizations t) {
    return Column(
      children: [
        // Error message
        if (auth.errorKey != null) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.1),
              borderRadius: AppTheme.borderRadiusMd,
              border: Border.all(
                color: AppTheme.error.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: AppTheme.error, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t.translate(auth.errorKey!),
                    style: GoogleFonts.inter(
                      color: AppTheme.error,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => auth.clearError(),
                  child: Icon(Icons.close, color: AppTheme.error, size: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Google Sign-In button
        GoogleSignInButton(
          onPressed: auth.isLoading ? null : () => auth.signInWithGoogle(),
          isLoading: auth.isLoading,
          label: t.translate('continue_with_google'),
        ),
      ],
    );
  }
}

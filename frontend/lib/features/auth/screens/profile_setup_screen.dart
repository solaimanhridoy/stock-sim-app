import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with SingleTickerProviderStateMixin {
  late TextEditingController _nameController;
  late FocusNode _nameFocusNode;

  String _selectedLanguage = 'en';
  String? _selectedExperience;
  bool _isSaving = false;
  String? _nameError;
  String? _saveError;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    // Pre-fill display name from Google profile
    final auth = context.read<AuthProvider>();
    final googleDisplayName = auth.user?['displayName'] as String? ?? '';

    _nameController = TextEditingController(text: googleDisplayName);
    _nameFocusNode = FocusNode();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ── Validation ──────────────────────────────────────────────────

  bool _validateName() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _nameError = 'display_name_empty_error';
      });
      _nameFocusNode.requestFocus();
      return false;
    }
    setState(() => _nameError = null);
    return true;
  }

  bool get _isFormValid =>
      _nameController.text.trim().isNotEmpty &&
      _selectedExperience != null &&
      !_isSaving;

  // ── Submit ──────────────────────────────────────────────────────

  Future<void> _handleSubmit() async {
    if (!_validateName() || _selectedExperience == null) return;

    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    final auth = context.read<AuthProvider>();
    final success = await auth.updateProfile(
      displayName: _nameController.text.trim(),
      language: _selectedLanguage,
      experience: _selectedExperience,
    );

    if (success && mounted) {
      setState(() => _isSaving = false);
      // Sync locale to the user's selection
      context.read<LocaleProvider>().setLocale(Locale(_selectedLanguage));
      // SplashWrapper will automatically navigate to Dashboard
      // because updateProfile() sets isNewUser = false
    } else if (mounted) {
      setState(() {
        _isSaving = false;
        _saveError = 'profile_save_error';
      });
    }
  }

  // ── Build ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 32),

                            // Step indicator
                            _buildStepIndicator(),

                            const SizedBox(height: 32),

                            // Greeting + title
                            Text(
                              t.translate('profile_greeting'),
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: AppTheme.accent,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              t.translate('profile_setup_title'),
                              style: GoogleFonts.inter(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              t.translate('profile_setup_subtitle'),
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                color: AppTheme.textSecondary,
                              ),
                            ),

                            const SizedBox(height: 36),

                            // ── Display Name ──────────────────────
                            _buildSectionLabel(
                                t.translate('display_name_label')),
                            const SizedBox(height: 10),
                            _buildNameField(t),

                            const SizedBox(height: 28),

                            // ── Language ──────────────────────────
                            _buildSectionLabel(
                                t.translate('select_language')),
                            const SizedBox(height: 10),
                            _buildLanguageSelector(),

                            const SizedBox(height: 28),

                            // ── Experience ────────────────────────
                            _buildSectionLabel(
                                t.translate('select_experience')),
                            const SizedBox(height: 10),
                            _buildExperienceSelector(t),

                            // Save error
                            if (_saveError != null) ...[
                              const SizedBox(height: 20),
                              _buildErrorBanner(t.translate(_saveError!)),
                            ],

                            const Spacer(),
                            const SizedBox(height: 24),

                            // ── Submit Button ─────────────────────
                            _buildSubmitButton(t),

                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  WIDGETS
  // ══════════════════════════════════════════════════════════════════

  // ── Step Indicator ──────────────────────────────────────────────

  Widget _buildStepIndicator() {
    return Row(
      children: [
        // Step 1 — Login (done)
        _stepDot(completed: true),
        _stepLine(active: true),
        // Step 2 — Profile (current)
        _stepDot(active: true),
        _stepLine(active: false),
        // Step 3 — Dashboard (next)
        _stepDot(),
      ],
    );
  }

  Widget _stepDot({bool active = false, bool completed = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: active ? 28 : 12,
      height: 12,
      decoration: BoxDecoration(
        gradient: (active || completed) ? AppTheme.primaryGradient : null,
        color: (!active && !completed)
            ? AppTheme.surfaceCard.withValues(alpha: 0.6)
            : null,
        borderRadius: AppTheme.borderRadiusFull,
        border: completed
            ? null
            : Border.all(
                color: active
                    ? Colors.transparent
                    : AppTheme.surfaceCard,
                width: 1,
              ),
      ),
      child: completed
          ? const Center(
              child: Icon(Icons.check, size: 8, color: Colors.white))
          : null,
    );
  }

  Widget _stepLine({required bool active}) {
    return Container(
      width: 24,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: active
            ? AppTheme.primary.withValues(alpha: 0.4)
            : AppTheme.surfaceCard.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  // ── Section Label ───────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppTheme.textMuted,
        letterSpacing: 1.2,
      ),
    );
  }

  // ── Display Name Field ──────────────────────────────────────────

  Widget _buildNameField(AppLocalizations t) {
    final hasError = _nameError != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard.withValues(alpha: 0.5),
            borderRadius: AppTheme.borderRadiusMd,
            border: Border.all(
              color: hasError
                  ? AppTheme.error.withValues(alpha: 0.6)
                  : _nameFocusNode.hasFocus
                      ? AppTheme.primary.withValues(alpha: 0.5)
                      : AppTheme.surfaceCard,
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: _nameController,
            focusNode: _nameFocusNode,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: t.translate('display_name_hint'),
              hintStyle: GoogleFonts.inter(
                fontSize: 16,
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Icon(
                Icons.person_outline_rounded,
                color: hasError ? AppTheme.error : AppTheme.textMuted,
                size: 22,
              ),
              suffixIcon: _nameController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded,
                          size: 18, color: AppTheme.textMuted),
                      onPressed: () {
                        _nameController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_nameError != null) {
                setState(() => _nameError = null);
              }
              setState(() {}); // rebuild for clear button
            },
            onSubmitted: (_) => _nameFocusNode.unfocus(),
          ),
        ),

        // Validation error
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.only(top: 8, left: 12),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          size: 14, color: AppTheme.error),
                      const SizedBox(width: 6),
                      Text(
                        t.translate(_nameError!),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  // ── Language Selector ───────────────────────────────────────────

  Widget _buildLanguageSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildSelectionCard(
            label: 'English',
            icon: '🇬🇧',
            isSelected: _selectedLanguage == 'en',
            onTap: () => setState(() => _selectedLanguage = 'en'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSelectionCard(
            label: 'বাংলা',
            icon: '🇧🇩',
            isSelected: _selectedLanguage == 'bn',
            onTap: () => setState(() => _selectedLanguage = 'bn'),
          ),
        ),
      ],
    );
  }

  // ── Experience Selector ─────────────────────────────────────────

  Widget _buildExperienceSelector(AppLocalizations t) {
    return Column(
      children: [
        _buildSelectionCard(
          label: t.translate('experience_beginner'),
          subtitle: t.translate('beginner_desc'),
          icon: '🌱',
          isSelected: _selectedExperience == 'beginner',
          onTap: () => setState(() => _selectedExperience = 'beginner'),
        ),
        const SizedBox(height: 12),
        _buildSelectionCard(
          label: t.translate('experience_intermediate'),
          subtitle: t.translate('intermediate_desc'),
          icon: '📊',
          isSelected: _selectedExperience == 'intermediate',
          onTap: () => setState(() => _selectedExperience = 'intermediate'),
        ),
      ],
    );
  }

  // ── Reusable Selection Card ─────────────────────────────────────

  Widget _buildSelectionCard({
    required String label,
    String? subtitle,
    required String icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.cardGradient : null,
          color:
              isSelected ? null : AppTheme.surfaceCard.withValues(alpha: 0.5),
          borderRadius: AppTheme.borderRadiusMd,
          border: Border.all(
            color: isSelected
                ? AppTheme.primary.withValues(alpha: 0.6)
                : AppTheme.surfaceCard,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    blurRadius: 20,
                    spreadRadius: -4,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary.withValues(alpha: 0.15)
                    : AppTheme.surface.withValues(alpha: 0.5),
                borderRadius: AppTheme.borderRadiusSm,
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 16),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Check indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                gradient: isSelected ? AppTheme.primaryGradient : null,
                color: isSelected
                    ? null
                    : AppTheme.surface.withValues(alpha: 0.5),
                shape: BoxShape.circle,
                border: isSelected
                    ? null
                    : Border.all(color: AppTheme.surfaceCard, width: 2),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ── Error Banner ────────────────────────────────────────────────

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.1),
        borderRadius: AppTheme.borderRadiusMd,
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: AppTheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _saveError = null),
            child:
                Icon(Icons.close_rounded, size: 16, color: AppTheme.error),
          ),
        ],
      ),
    );
  }

  // ── Submit Button ───────────────────────────────────────────────

  Widget _buildSubmitButton(AppLocalizations t) {
    final enabled = _isFormValid;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: enabled ? AppTheme.primaryGradient : null,
          color: enabled ? null : AppTheme.surfaceCard,
          borderRadius: AppTheme.borderRadiusMd,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                    spreadRadius: -4,
                  ),
                ]
              : null,
        ),
        child: ElevatedButton(
          onPressed: enabled ? _handleSubmit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: AppTheme.borderRadiusMd,
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _isSaving
                ? SizedBox(
                    key: const ValueKey('spinner'),
                    width: 24,
                    height: 24,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    key: const ValueKey('label'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        t.translate('continue_btn'),
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: enabled
                              ? Colors.white
                              : AppTheme.textMuted,
                        ),
                      ),
                      if (enabled) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded,
                            size: 20, color: Colors.white),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

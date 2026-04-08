import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/screens/profile_setup_screen.dart';
import '../../dashboard/screens/dashboard_screen.dart';

/// Wraps the app entry to show a splash screen while authenticating.
/// Directs the user to the appropriate screen based on auth state.
class SplashWrapper extends StatefulWidget {
  const SplashWrapper({super.key});

  @override
  State<SplashWrapper> createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<SplashWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().initializeAuth();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.status == AuthStatus.initial ||
            auth.status == AuthStatus.loading) {
          return const Scaffold(
            backgroundColor: AppTheme.background,
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
              ),
            ),
          );
        }

        if (auth.status == AuthStatus.authenticated) {
          // Route new users to profile setup, returning users to dashboard
          if (auth.isNewUser) {
            return const ProfileSetupScreen();
          }
          return const DashboardScreen();
        }

        return const LoginScreen();
      },
    );
  }
}

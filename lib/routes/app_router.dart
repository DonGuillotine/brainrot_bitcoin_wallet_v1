import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../screens/lightning/channel_list_screen.dart';
import '../screens/lightning/lightning_setup_screen.dart';
import '../screens/scanner/qr_scanner_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/transactions/transaction_history_screen.dart';
import '../screens/wallet/create_wallet_screen.dart';
import '../screens/wallet/restore_wallet_screen.dart';
import '../screens/wallet/backup_verification_screen.dart';
import '../screens/send/send_bitcoin_screen.dart';
import '../screens/receive/receive_bitcoin_screen.dart';
import '../screens/settings/settings_screen.dart';

// Providers
import '../providers/app_state_provider.dart';
import '../theme/app_theme.dart';

/// Main app router configuration
class AppRouter {
  static final router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: true,

    // Redirect logic for authentication
    redirect: (context, state) {
      final appState = context.read<AppStateProvider>();
      final isOnboarding = state.matchedLocation == '/onboarding';
      final isCreatingWallet = state.matchedLocation.startsWith('/wallet/');

      // If wallet exists and we're on splash, go to home
      if (appState.hasWallet && state.matchedLocation == '/') {
        return '/home';
      }

      // If no wallet and not onboarding, go to onboarding
      if (!appState.hasWallet && !isOnboarding && !isCreatingWallet) {
        return '/onboarding';
      }

      return null;
    },

    // Route definitions
    routes: [
      // Splash screen
      GoRoute(
        path: '/',
        name: 'splash',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SplashScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      ),

      // Onboarding
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const OnboardingScreen(),
          transitionsBuilder: _chaosTransition,
        ),
      ),

      // Wallet creation/restoration
      GoRoute(
        path: '/wallet',
        name: 'wallet',
        builder: (context, state) => const SizedBox.shrink(),
        routes: [
          GoRoute(
            path: 'create',
            name: 'create-wallet',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const CreateWalletScreen(),
              transitionsBuilder: _chaosTransition,
            ),
          ),
          GoRoute(
            path: 'restore',
            name: 'restore-wallet',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const RestoreWalletScreen(),
              transitionsBuilder: _chaosTransition,
            ),
          ),
          GoRoute(
            path: 'backup',
            name: 'backup-verification',
            pageBuilder: (context, state) {
              final mnemonic = state.extra as String?;
              if (mnemonic == null) {
                return CustomTransitionPage(
                  key: state.pageKey,
                  child: const ErrorScreen(),
                  transitionsBuilder: _chaosTransition,
                );
              }

              return CustomTransitionPage(
                key: state.pageKey,
                child: BackupVerificationScreen(mnemonic: mnemonic),
                transitionsBuilder: _chaosTransition,
              );
            },
          ),
        ],
      ),

      // Home screen
      GoRoute(
        path: '/home',
        name: 'home',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const HomeScreen(),
          transitionsBuilder: _chaosTransition,
        ),
        routes: [
          // Send Bitcoin
          GoRoute(
            path: 'send',
            name: 'send',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const SendBitcoinScreen(),
              transitionsBuilder: _slideUpTransition,
            ),
          ),

          // Receive Bitcoin
          GoRoute(
            path: 'receive',
            name: 'receive',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const ReceiveBitcoinScreen(),
              transitionsBuilder: _slideUpTransition,
            ),
          ),
        ],
      ),

      // Settings
      GoRoute(
        path: '/settings',
        name: 'settings',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SettingsScreen(),
          transitionsBuilder: _slideUpTransition,
        ),
      ),

      // Transactions
      GoRoute(
        path: '/transactions',
        name: 'transactions',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const TransactionHistoryScreen(),
          transitionsBuilder: _slideUpTransition,
        ),
      ),

      // Lightning
      GoRoute(
        path: '/lightning',
        name: 'lightning',
        builder: (context, state) => const SizedBox.shrink(),
        routes: [
          GoRoute(
            path: 'setup',
            name: 'lightning-setup',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const LightningSetupScreen(),
              transitionsBuilder: _chaosTransition,
            ),
          ),
          GoRoute(
            path: 'channels',
            name: 'lightning-channels',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const ChannelListScreen(),
              transitionsBuilder: _slideUpTransition,
            ),
          ),
        ],
      ),

      GoRoute(
        path: '/scan',
        name: 'scan',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const QRScannerScreen(),
          transitionsBuilder: _slideUpTransition,
        ),
      ),
    ],

    // Error page
    errorPageBuilder: (context, state) => CustomTransitionPage(
      key: state.pageKey,
      child: const ErrorScreen(),
      transitionsBuilder: _chaosTransition,
    ),
  );

  // Custom transition animations
  static Widget _chaosTransition(
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
      ) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: animation.drive(
          Tween(
            begin: const Offset(0.1, 0.1),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.elasticOut)),
        ),
        child: RotationTransition(
          turns: animation.drive(
            Tween(begin: 0.05, end: 0.0).chain(
              CurveTween(curve: Curves.elasticOut),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  static Widget _slideUpTransition(
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
      ) {
    return SlideTransition(
      position: animation.drive(
        Tween(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.elasticOut)),
      ),
      child: child,
    );
  }
}

/// Error screen for 404s and other routing errors
class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '404',
              style: TextStyle(
                fontSize: 120,
                fontWeight: FontWeight.bold,
                color: AppTheme.hotPink,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Page not found\nYou\'re lost in the void',
              textAlign: TextAlign.center,
              style: AppTheme.bodyStyle,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('GO HOME'),
            ),
          ],
        ),
      ),
    );
  }
}

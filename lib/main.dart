import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

// Providers
import 'providers/app_state_provider.dart';
import 'providers/wallet_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';

// Routing
import 'routes/app_router.dart';

// Theme
import 'theme/app_theme.dart';

// Services
import 'services/secure_storage_service.dart';
import 'services/logger_service.dart';

// Global instances
late final Logger logger;
late final FlutterSecureStorage secureStorage;
late final SharedPreferences prefs;

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  await initializeApp();

  // Lock orientation to portrait for maximum chaos control
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style for that dark theme vibe
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.darkGrey,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const BrainrotWalletApp());
}

/// Initialize all required services before app starts
Future<void> initializeApp() async {
  // Initialize logger
  logger = LoggerService.createLogger();
  logger.i('🧠 Initializing Brainrot Wallet...');

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Initialize secure storage
  secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Initialize shared preferences
  prefs = await SharedPreferences.getInstance();

  // Configure Flutter Animate
  Animate.restartOnHotReload = true;

  logger.i('✅ App initialization complete!');
}

/// Main app widget with all providers and routing
class BrainrotWalletApp extends StatelessWidget {
  const BrainrotWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Core app state
        ChangeNotifierProvider(
          create: (_) => AppStateProvider(),
        ),

        // Wallet functionality
        ChangeNotifierProvider(
          create: (_) => WalletProvider(),
        ),

        // Theme management
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),

        // Settings
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp.router(
            title: 'Brainrot Wallet',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            routerConfig: AppRouter.router,
            builder: (context, child) {
              // Wrap the entire app with animations
              return Stack(
                children: [
                  // Animated gradient background
                  const AnimatedGradientBackground(),

                  // Main app content
                  if (child != null) child,

                  // Global loading overlay
                  Consumer<AppStateProvider>(
                    builder: (context, appState, _) {
                      return appState.isLoading
                          ? const ChaosLoadingOverlay()
                          : const SizedBox.shrink();
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Animated gradient background for maximum chaos
class AnimatedGradientBackground extends StatelessWidget {
  const AnimatedGradientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.darkGrey,
            AppTheme.deepPurple.withAlpha(51),
            AppTheme.darkGrey,
          ],
        ),
      ),
    )
        .animate(
      onPlay: (controller) => controller.repeat(reverse: true),
    )
        .shimmer(
      duration: const Duration(seconds: 3),
      color: AppTheme.limeGreen.withAlpha(26),
    );
  }
}

/// Global loading overlay with meme animations
class ChaosLoadingOverlay extends StatelessWidget {
  const ChaosLoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Spinning Bitcoin logo with glitch effect
            const Icon(
              Icons.currency_bitcoin,
              size: 80,
              color: AppTheme.limeGreen,
            )
                .animate(
              onPlay: (controller) => controller.repeat(),
            )
                .rotate(duration: const Duration(seconds: 2))
                .shake(hz: 8, curve: Curves.easeInOut),

            const SizedBox(height: 20),

            // Chaotic loading text
            const Text(
              'LOADING...',
              style: TextStyle(
                fontFamily: 'ComicSans',
                fontSize: 24,
                color: AppTheme.hotPink,
                fontWeight: FontWeight.bold,
              ),
            )
                .animate(
              onPlay: (controller) => controller.repeat(),
            )
                .fadeIn(duration: 500.ms)
                .then()
                .fadeOut(duration: 500.ms),
          ],
        ),
      ),
    );
  }
}
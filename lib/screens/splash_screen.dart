import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../theme/chaos_theme.dart';
import '../providers/app_state_provider.dart';
import '../widgets/animated/meme_text.dart';
import '../widgets/effects/particle_system.dart';
import '../services/service_locator.dart';
import 'dart:math' as math;

/// Meme-themed splash screen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  bool _initialized = false;
  String _loadingMessage = 'Initializing chaos...';

  final List<String> _loadingMessages = [
    'Summoning Bitcoin spirits... 👻',
    'Charging Lightning capacitors... ⚡',
    'Mining memes... ⛏️',
    'Downloading more RAM... 💾',
    'Reticulating splines... 🌀',
    'Achieving consciousness... 🤖',
    'Touching grass... 🌱',
    'Pumping bags... 💰',
    'Diamond handing... 💎🙌',
    'Going to the moon... 🚀',
  ];

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _textController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _initializeApp();
    _animateLoadingMessages();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    final appState = context.read<AppStateProvider>();

    // Play startup sound
    await services.soundService.startup();

    // Simulate loading with meme messages
    await Future.delayed(const Duration(milliseconds: 500));

    // Check wallet status
    if (appState.hasWallet) {
      // Try to unlock wallet
      _navigateToHome();
    } else if (appState.isOnboarded) {
      // User has seen onboarding but no wallet
      context.go('/wallet/create');
    } else {
      // First time user
      context.go('/onboarding');
    }
  }

  void _animateLoadingMessages() async {
    while (mounted && !_initialized) {
      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted) {
        setState(() {
          _loadingMessage = _loadingMessages[
          math.Random().nextInt(_loadingMessages.length)
          ];
        });

        _textController.forward(from: 0);
      }
    }
  }

  void _navigateToHome() {
    setState(() => _initialized = true);

    // Haptic feedback
    services.hapticService.success();

    // Navigate after animation
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        context.go('/home');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkGrey,
      body: Stack(
        children: [
          // Animated gradient background
          Container(
            decoration: BoxDecoration(
              gradient: ChaosTheme.getChaosGradient(5),
            ),
          )
              .animate(
            onPlay: (controller) => controller.repeat(reverse: true),
          )
              .shimmer(
            duration: const Duration(seconds: 3),
            color: AppTheme.deepPurple.withAlpha((0.3 * 255).round()),
          ),

          // Particle system
          const ParticleSystem(
            particleType: ParticleType.bitcoin,
            particleCount: 30,
            isActive: true,
          ),

          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow effect
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.limeGreen.withAlpha((0.5 * 255).round()),
                            blurRadius: 50,
                            spreadRadius: 20,
                          ),
                        ],
                      ),
                    ),

                    // Bitcoin logo
                    RotationTransition(
                      turns: Tween(begin: 0.0, end: 1.0).animate(
                        CurvedAnimation(
                          parent: _logoController,
                          curve: Curves.linear,
                        ),
                      ),
                      child: Icon(
                        Icons.currency_bitcoin,
                        size: 120,
                        color: AppTheme.limeGreen,
                      )
                          .animate()
                          .scale(
                        begin: const Offset(0.5, 0.5),
                        end: const Offset(1, 1),
                        duration: const Duration(seconds: 1),
                        curve: Curves.elasticOut,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // App name
                MemeText(
                  'BRAINROT',
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  rainbow: true,
                )
                    .animate()
                    .fadeIn(delay: 500.ms)
                    .slideY(begin: 0.5, end: 0),

                MemeText(
                  'WALLET',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.hotPink,
                )
                    .animate()
                    .fadeIn(delay: 700.ms)
                    .slideY(begin: 0.5, end: 0),

                const SizedBox(height: 60),

                // Loading indicator
                SizedBox(
                  width: 250,
                  child: Column(
                    children: [
                      // Progress bar
                      LinearProgressIndicator(
                        backgroundColor: AppTheme.lightGrey,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.limeGreen,
                        ),
                        minHeight: 4,
                      )
                          .animate(
                        onPlay: (controller) => controller.repeat(),
                      )
                          .shimmer(
                        duration: const Duration(seconds: 1),
                        color: Colors.white.withAlpha((0.5 * 255).round()),
                      ),

                      const SizedBox(height: 20),

                      // Loading message
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        child: MemeText(
                          _loadingMessage,
                          key: ValueKey(_loadingMessage),
                          fontSize: 16,
                          textAlign: TextAlign.center,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Version info
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: MemeText(
                'v4.2.0 - Not your keys, not your cheese 🧀',
                fontSize: 12,
                color: Colors.white30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

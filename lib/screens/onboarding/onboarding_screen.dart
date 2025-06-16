import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_state_provider.dart';
import '../../widgets/animated/chaos_button.dart';
import '../../widgets/animated/meme_text.dart';
import '../../widgets/effects/particle_system.dart';
import '../../widgets/effects/glitch_effect.dart';
import '../../services/service_locator.dart';

/// Chaotic onboarding flow
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      emoji: '🧠',
      title: 'Welcome to Brainrot',
      subtitle: 'The most chaotic Bitcoin wallet',
      description: 'Where your sats go to party and your brain cells go to die. WAGMI! 🚀',
      particleType: ParticleType.chaos,
      backgroundColor: AppTheme.deepPurple,
    ),
    OnboardingPage(
      emoji: '🔑',
      title: 'Your Keys, Your Cheese',
      subtitle: 'True self-custody',
      description: 'No KYC, no BS, just pure unadulterated Bitcoin ownership. Stack sats and stay humble 💎🙌',
      particleType: ParticleType.bitcoin,
      backgroundColor: AppTheme.darkGrey,
    ),
    OnboardingPage(
      emoji: '⚡',
      title: 'Lightning Fast',
      subtitle: 'Instant payments go brrrr',
      description: 'Send sats at the speed of light. Your transactions are faster than your wife\'s boyfriend\'s Lambo 🏎️',
      particleType: ParticleType.lightning,
      backgroundColor: AppTheme.darkGrey,
    ),
    OnboardingPage(
      emoji: '🎯',
      title: 'Maximum Chaos Mode',
      subtitle: 'Adjust your experience',
      description: 'From normie-friendly to reality-breaking. How much brain damage can you handle? 🤯',
      particleType: ParticleType.rockets,
      backgroundColor: AppTheme.darkGrey,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _completeOnboarding() async {
    // Play sound and haptic feedback safely
    services.playSoundSafely((sound) => sound.success());
    services.triggerHapticSafely((haptic) => haptic.success());

    // Navigate to wallet creation (don't set onboarded until backup verification is complete)
    if (mounted) {
      context.go('/wallet/create');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkGrey,
      body: Stack(
        children: [
          // Page content
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
              services.triggerHapticSafely((haptic) => haptic.light());
            },
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              final page = _pages[index];

              return Stack(
                children: [
                  // Background
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          page.backgroundColor,
                          AppTheme.darkGrey,
                        ],
                      ),
                    ),
                  ),

                  // Particles
                  ParticleSystem(
                    particleType: page.particleType,
                    particleCount: 20,
                    isActive: true,
                  ),

                  // Content
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Emoji
                          Text(
                            page.emoji,
                            style: const TextStyle(fontSize: 120),
                          )
                              .animate()
                              .fadeIn(delay: 200.ms)
                              .scale(
                            begin: const Offset(0.5, 0.5),
                            end: const Offset(1, 1),
                            curve: Curves.elasticOut,
                          )
                              .then()
                              .animate(
                            onPlay: (controller) => controller.repeat(),
                          )
                              .rotate(
                            begin: -0.05,
                            end: 0.05,
                            duration: const Duration(seconds: 3),
                          ),

                          const SizedBox(height: 40),

                          // Title
                          GlitchEffect(
                            isActive: index == 3,
                            child: MemeText(
                              page.title,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              textAlign: TextAlign.center,
                              rainbow: index == 0,
                            ),
                          )
                              .animate()
                              .fadeIn(delay: 400.ms)
                              .slideY(begin: 0.2, end: 0),

                          const SizedBox(height: 16),

                          // Subtitle
                          MemeText(
                            page.subtitle,
                            fontSize: 20,
                            color: AppTheme.limeGreen,
                            textAlign: TextAlign.center,
                          )
                              .animate()
                              .fadeIn(delay: 600.ms)
                              .slideY(begin: 0.2, end: 0),

                          const SizedBox(height: 32),

                          // Description
                          MemeText(
                            page.description,
                            fontSize: 16,
                            textAlign: TextAlign.center,
                            color: Colors.white70,
                          )
                              .animate()
                              .fadeIn(delay: 800.ms),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // Bottom controls
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Column(
              children: [
                // Page indicator
                SmoothPageIndicator(
                  controller: _pageController,
                  count: _pages.length,
                  effect: WormEffect(
                    dotHeight: 8,
                    dotWidth: 8,
                    spacing: 16,
                    dotColor: AppTheme.lightGrey,
                    activeDotColor: AppTheme.limeGreen,
                  ),
                ),

                const SizedBox(height: 32),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Skip button
                    if (_currentPage < _pages.length - 1)
                      TextButton(
                        onPressed: _completeOnboarding,
                        child: MemeText(
                          'Skip (NGMI)',
                          fontSize: 16,
                          color: Colors.white54,
                        ),
                      )
                    else
                      const SizedBox(width: 100),

                    // Next/Complete button
                    ChaosButton(
                      text: _currentPage < _pages.length - 1
                          ? 'Next'
                          : 'LFG! 🚀',
                      onPressed: _nextPage,
                      width: 150,
                      icon: _currentPage < _pages.length - 1
                          ? Icons.arrow_forward
                          : Icons.rocket_launch,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Onboarding page data
class OnboardingPage {
  final String emoji;
  final String title;
  final String subtitle;
  final String description;
  final ParticleType particleType;
  final Color backgroundColor;

  const OnboardingPage({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.particleType,
    required this.backgroundColor,
  });
}

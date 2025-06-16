import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../theme/chaos_theme.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/lightning_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/animated/meme_text.dart';
import '../../widgets/effects/particle_system.dart';
import '../../widgets/meme/balance_display.dart';
import '../../services/service_locator.dart';
import 'widgets/transaction_list.dart';
import 'widgets/quick_actions.dart';
import 'widgets/lightning_balance_card.dart';
import 'widgets/price_ticker.dart';
import 'dart:math' as math;

/// Main wallet dashboard screen
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey();
  late AnimationController _balanceAnimationController;
  late AnimationController _floatingActionController;
  bool _showParticles = false;

  @override
  void initState() {
    super.initState();
    _balanceAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _floatingActionController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _initializeWallet();
  }

  @override
  void dispose() {
    _balanceAnimationController.dispose();
    _floatingActionController.dispose();
    super.dispose();
  }

  Future<void> _initializeWallet() async {
    // Initialize wallet and lightning if needed
    final walletProvider = context.read<WalletProvider>();
    final lightningProvider = context.read<LightningProvider>();

    // Sync wallet
    await _refreshData();

    // Check if lightning is initialized
    if (!lightningProvider.isInitialized && walletProvider.isInitialized) {
      // Auto-initialize lightning with same seed
      // This would be done after user consent in production
    }
  }

  Future<void> _refreshData() async {
    final walletProvider = context.read<WalletProvider>();
    final lightningProvider = context.read<LightningProvider>();

    // Sync both wallet and lightning
    await Future.wait([
      walletProvider.syncWallet(),
      if (lightningProvider.isInitialized)
        lightningProvider.syncNode(),
    ]);

    // Play refresh sound
    services.soundService.tap();
    services.hapticService.light();
  }

  void _showMemeMessage() {
    final messages = [
      'HODL strong, anon! 💎🙌',
      'Number go up technology 📈',
      'Stack sats and stay humble 🙏',
      'We\'re all gonna make it! 🚀',
      'Bitcoin fixes this 🔧',
      'Few understand 🧠',
    ];

    final message = messages[math.Random().nextInt(messages.length)];

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: MemeText(message, color: Colors.white),
        backgroundColor: AppTheme.deepPurple,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final chaosLevel = themeProvider.chaosLevel;

    // Use PopScope instead of the deprecated WillPopScope
    return PopScope(
      canPop: false, // Prevents back button from exiting app on home screen
      child: Scaffold(
        backgroundColor: AppTheme.darkGrey,
        body: Stack(
          children: [
            // Background effects
            if (chaosLevel >= 5)
              Container(
                decoration: BoxDecoration(
                  gradient: ChaosTheme.getChaosGradient(chaosLevel),
                ),
              ).animate(
                onPlay: (controller) => controller.repeat(reverse: true),
              ).shimmer(
                duration: const Duration(seconds: 3),
                color: Colors.white.withAlpha((0.1 * 255).round()),
              ),

            // Particle system
            if (_showParticles || chaosLevel >= 8)
              const ParticleSystem(
                particleType: ParticleType.money,
                particleCount: 30,
                isActive: true,
              ),

            // Main content
            RefreshIndicator(
              key: _refreshKey,
              onRefresh: _refreshData,
              color: AppTheme.limeGreen,
              backgroundColor: AppTheme.darkGrey,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // App bar
                  _buildAppBar(),

                  // Price ticker
                  SliverToBoxAdapter(
                    child: PriceTicker(),
                  ),

                  // Balance cards
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Bitcoin balance
                          BalanceDisplay(
                            showFiat: true,
                            compact: false,
                          )
                              .animate()
                              .fadeIn(delay: 200.ms)
                              .slideY(begin: 0.2, end: 0),

                          const SizedBox(height: 16),

                          // Lightning balance
                          const LightningBalanceCard()
                              .animate()
                              .fadeIn(delay: 400.ms)
                              .slideY(begin: 0.2, end: 0),

                          const SizedBox(height: 24),

                          // Quick actions
                          const QuickActions()
                              .animate()
                              .fadeIn(delay: 600.ms)
                              .slideY(begin: 0.2, end: 0),
                        ],
                      ),
                    ),
                  ),

                  // Transactions header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          MemeText(
                            'Recent Activity',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          TextButton(
                            onPressed: () => context.go('/transactions'),
                            child: MemeText(
                              'See All',
                              fontSize: 14,
                              color: AppTheme.limeGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Transaction list
                  const TransactionList(),
                ],
              ),
            ),
          ],
        ),

        // Floating action button
        floatingActionButton: _buildFloatingActionButton(),
      ),
    );
  }

  Widget _buildAppBar() {
    final walletProvider = context.watch<WalletProvider>();
    final settingsProvider = context.watch<SettingsProvider>();

    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      floating: true,
      title: Row(
        children: [
          // Wallet name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MemeText(
                  walletProvider.walletConfig?.name ?? 'Brainrot Wallet',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),

                // Network indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: settingsProvider.isTestnet
                        ? AppTheme.warning.withAlpha((0.2 * 255).round())
                        : AppTheme.success.withAlpha((0.2 * 255).round()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: MemeText(
                    settingsProvider.isTestnet ? 'TESTNET' : 'MAINNET',
                    fontSize: 10,
                    color: settingsProvider.isTestnet
                        ? AppTheme.warning
                        : AppTheme.success,
                  ),
                ),
              ],
            ),
          ),

          // Menu button
          IconButton(
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.settings),
            color: AppTheme.limeGreen,
          ),
        ],
      ),
      actions: [
        // Meme button
        IconButton(
          onPressed: _showMemeMessage,
          icon: Text(
            AppTheme.getRandomMemeEmoji(),
            style: const TextStyle(fontSize: 24),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingActionButton() {
    final themeProvider = context.watch<ThemeProvider>();
    final chaosLevel = themeProvider.chaosLevel;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Send button
        FloatingActionButton(
          heroTag: 'send',
          onPressed: () => context.go('/home/send'),
          backgroundColor: AppTheme.hotPink,
          child: const Icon(Icons.send, color: Colors.white),
        )
            .animate(
          onPlay: (controller) {
            if (chaosLevel >= 7) {
              controller.repeat(reverse: true);
            }
          },
        )
            .scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1.1, 1.1),
          duration: const Duration(seconds: 2),
        ),

        const SizedBox(height: 16),

        // Receive button
        FloatingActionButton.large(
          heroTag: 'receive',
          onPressed: () => context.go('/home/receive'),
          backgroundColor: AppTheme.limeGreen,
          child: const Icon(
            Icons.qr_code_scanner,
            color: AppTheme.darkGrey,
            size: 32,
          ),
        )
            .animate(
          onPlay: (controller) {
            if (chaosLevel >= 5) {
              controller.repeat();
            }
          },
        )
            .rotate(
          begin: 0,
          end: chaosLevel >= 9 ? 1 : 0.05,
          duration: Duration(seconds: 10 - chaosLevel),
        ),
      ],
    );
  }
}

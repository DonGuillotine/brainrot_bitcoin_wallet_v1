import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/chaos_theme.dart';
import '../../../providers/lightning_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../widgets/animated/meme_text.dart';
import '../../../widgets/animated/chaos_button.dart';

/// Lightning balance card for dashboard
class LightningBalanceCard extends StatefulWidget {
  const LightningBalanceCard({super.key});

  @override
  State<LightningBalanceCard> createState() => _LightningBalanceCardState();
}

class _LightningBalanceCardState extends State<LightningBalanceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleDetails() {
    setState(() => _showDetails = !_showDetails);
    if (_showDetails) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lightningProvider = context.watch<LightningProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final chaosLevel = themeProvider.chaosLevel;

    if (!lightningProvider.isInitialized) {
      return _buildUninitialized(context);
    }

    final balance = lightningProvider.balance;
    final spendableSats = balance?.spendableSats ?? 0;
    final receivableSats = balance?.receivableSats ?? 0;
    final hideBalance = settingsProvider.hideBalance;

    return GestureDetector(
      onTap: _toggleDetails,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: ChaosTheme.getChaosDecoration(
          chaosLevel: chaosLevel,
          baseColor: AppTheme.darkGrey,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.bolt,
                  color: AppTheme.limeGreen,
                  size: 32,
                )
                    .animate(
                  onPlay: (controller) {
                    if (chaosLevel >= 5) {
                      controller.repeat();
                    }
                  },
                )
                    .shimmer(
                  duration: const Duration(seconds: 2),
                  color: Colors.yellow,
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MemeText(
                        'Lightning Balance',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),

                      if (lightningProvider.activeChannels > 0)
                        MemeText(
                          '${lightningProvider.activeChannels} active channels',
                          fontSize: 12,
                          color: AppTheme.limeGreen,
                        ),
                    ],
                  ),
                ),

                // Expand icon
                AnimatedRotation(
                  turns: _showDetails ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    Icons.expand_more,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Balance
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MemeText(
                        'Can Send',
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                      const SizedBox(height: 4),
                      MemeText(
                        hideBalance ? '****' : '$spendableSats sats',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.hotPink,
                      ),
                    ],
                  ),
                ),

                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white12,
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      MemeText(
                        'Can Receive',
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                      const SizedBox(height: 4),
                      MemeText(
                        hideBalance ? '****' : '$receivableSats sats',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.limeGreen,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Animated details
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              child: _showDetails
                  ? Column(
                children: [
                  const SizedBox(height: 20),

                  // Meme status
                  if (balance != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.lightGrey,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: MemeText(
                        balance.getMemeDescription(),
                        fontSize: 14,
                        textAlign: TextAlign.center,
                        color: AppTheme.hotPink,
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ChaosButton(
                          text: 'Channels',
                          onPressed: () => context.go('/lightning/channels'),
                          isPrimary: false,
                          height: 40,
                          icon: Icons.hub,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChaosButton(
                          text: 'Open Channel',
                          onPressed: () => context.go('/lightning/open-channel'),
                          height: 40,
                          icon: Icons.add,
                        ),
                      ),
                    ],
                  ),
                ],
              )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUninitialized(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final chaosLevel = themeProvider.chaosLevel;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: ChaosTheme.getChaosDecoration(
        chaosLevel: chaosLevel,
        baseColor: AppTheme.darkGrey,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.bolt,
                color: Colors.white54,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MemeText(
                      'Lightning Network',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    MemeText(
                      'Not initialized',
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          MemeText(
            'Enable Lightning for instant payments ⚡',
            fontSize: 14,
            textAlign: TextAlign.center,
            color: Colors.white70,
          ),

          const SizedBox(height: 16),

          ChaosButton(
            text: 'Initialize Lightning',
            onPressed: () => context.go('/lightning/setup'),
            icon: Icons.flash_on,
          ),
        ],
      ),
    );
  }
}

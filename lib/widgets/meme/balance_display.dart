import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import '../../services/service_locator.dart';
import '../../theme/app_theme.dart';
import '../../theme/chaos_theme.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/settings_provider.dart';
import '../animated/meme_text.dart';
import '../effects/particle_system.dart';

/// Meme-themed balance display widget
class BalanceDisplay extends StatefulWidget {
  final bool showFiat;
  final bool compact;

  const BalanceDisplay({
    super.key,
    this.showFiat = true,
    this.compact = false,
  });

  @override
  State<BalanceDisplay> createState() => _BalanceDisplayState();
}

class _BalanceDisplayState extends State<BalanceDisplay>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _animationController;
  double _previousBalance = 0;
  bool _showParticles = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _checkBalanceChange(double newBalance) {
    if (newBalance > _previousBalance && _previousBalance > 0) {
      // Balance increased - celebration time!
      _confettiController.play();
      _showParticles = true;

      // Play sound
      services.soundService.receiveTransaction();
      services.hapticService.success();

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _showParticles = false);
        }
      });
    }

    _previousBalance = newBalance;
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final settingsProvider = context.watch<SettingsProvider>();

    final balance = walletProvider.balance;
    final btcBalance = balance?.btc ?? 0.0;

    // Check for balance changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBalanceChange(btcBalance);
    });

    final hideBalance = settingsProvider.hideBalance;
    final chaosLevel = themeProvider.chaosLevel;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Background decoration
        Container(
          padding: EdgeInsets.all(widget.compact ? 16 : 24),
          decoration: ChaosTheme.getChaosDecoration(
            chaosLevel: chaosLevel,
            baseColor: AppTheme.darkGrey,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // BTC Balance
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  // Bitcoin icon with rotation
                  Icon(
                    Icons.currency_bitcoin,
                    color: AppTheme.limeGreen,
                    size: widget.compact ? 24 : 32,
                  )
                      .animate(
                    onPlay: (controller) {
                      if (chaosLevel >= 5) {
                        controller.repeat();
                      }
                    },
                  )
                      .rotate(
                    duration: Duration(seconds: 10 - chaosLevel),
                  ),

                  const SizedBox(width: 8),

                  // Balance amount
                  MemeText(
                    hideBalance
                        ? '****'
                        : btcBalance.toStringAsFixed(8),
                    fontSize: widget.compact ? 24 : 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    rainbow: btcBalance > 1, // Rainbow for whole coiners
                    glitch: chaosLevel >= 8,
                  ),

                  const SizedBox(width: 4),

                  // BTC label
                  MemeText(
                    'BTC',
                    fontSize: widget.compact ? 16 : 20,
                    color: AppTheme.limeGreen,
                  ),
                ],
              ),

              if (widget.showFiat) ...[
                const SizedBox(height: 8),

                // Fiat balance
                MemeText(
                  hideBalance
                      ? '≈ \$****'
                      : '≈ ${walletProvider.balanceFiat}',
                  fontSize: widget.compact ? 14 : 16,
                  color: Colors.white70,
                ),
              ],

              // Meme status
              if (!widget.compact && balance != null) ...[
                const SizedBox(height: 12),
                MemeText(
                  balance.getMemeDescription(),
                  fontSize: 14,
                  color: AppTheme.hotPink,
                  textAlign: TextAlign.center,
                  enableChaos: true,
                ),
              ],

              // Unconfirmed balance warning
              if (balance != null && balance.unconfirmed > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withAlpha((0.2 * 255).round()),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.warning,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.schedule,
                        color: AppTheme.warning,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      MemeText(
                        '${balance.unconfirmedBtc.toStringAsFixed(8)} BTC pending',
                        fontSize: 12,
                        color: AppTheme.warning,
                      ),
                    ],
                  ),
                )
                    .animate(
                  onPlay: (controller) => controller.repeat(),
                )
                    .fadeIn()
                    .then()
                    .fadeOut(),
              ],
            ],
          ),
        ),

        // Confetti overlay
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          emissionFrequency: 0.05,
          numberOfParticles: 20,
          gravity: 0.1,
          colors: ChaosTheme.chaosColors,
          createParticlePath: (size) {
            final path = Path();
            path.addOval(Rect.fromCircle(
              center: Offset(size.width / 2, size.height / 2),
              radius: size.width / 2,
            ));
            return path;
          },
        ),

        // Particle system overlay
        if (_showParticles)
          Positioned.fill(
            child: ParticleSystem(
              particleType: btcBalance > 1
                  ? ParticleType.rockets
                  : ParticleType.bitcoin,
              particleCount: 30,
              isActive: true,
            ),
          ),
      ],
    );
  }
}

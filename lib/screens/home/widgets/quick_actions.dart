import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/lightning_provider.dart';
import '../../../widgets/animated/meme_text.dart';
import '../../../services/service_locator.dart';

/// Quick action buttons for dashboard
class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final lightningProvider = context.watch<LightningProvider>();
    final chaosLevel = themeProvider.chaosLevel;

    final actions = [
      QuickAction(
        icon: Icons.qr_code_scanner,
        label: 'Scan',
        color: AppTheme.deepPurple,
        onTap: () => context.go('/home/receive'),
      ),
      QuickAction(
        icon: lightningProvider.isInitialized ? Icons.bolt : Icons.flash_on,
        label: lightningProvider.isInitialized ? 'Lightning' : 'Setup ⚡',
        color: AppTheme.limeGreen,
        onTap: () => context.go(lightningProvider.isInitialized ? '/lightning/channels' : '/lightning/setup'),
      ),
      QuickAction(
        icon: Icons.receipt_long,
        label: 'Invoice',
        color: AppTheme.cyan,
        onTap: () => context.go('/lightning/create-invoice'),
        isEnabled: lightningProvider.isInitialized,
      ),
      QuickAction(
        icon: Icons.send,
        label: 'Pay',
        color: AppTheme.hotPink,
        onTap: () => context.go('/lightning/pay-invoice'),
        isEnabled: lightningProvider.isInitialized,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];

        return GestureDetector(
          onTap: action.isEnabled ? () {
            services.hapticService.light();
            services.soundService.tap();
            action.onTap();
          } : null,
          child: Container(
            decoration: BoxDecoration(
              color: action.isEnabled 
                  ? action.color.withAlpha((0.2 * 255).round())
                  : Colors.grey.withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: action.isEnabled
                    ? action.color.withAlpha((0.5 * 255).round())
                    : Colors.grey.withAlpha((0.3 * 255).round()),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  action.icon,
                  color: action.isEnabled ? action.color : Colors.grey,
                  size: 28,
                )
                    .animate(
                  onPlay: (controller) {
                    if (chaosLevel >= 6 && index % 2 == 0 && action.isEnabled) {
                      controller.repeat(reverse: true);
                    }
                  },
                )
                    .scale(
                  begin: const Offset(0.9, 0.9),
                  end: const Offset(1.1, 1.1),
                  duration: Duration(seconds: 2 + index),
                ),

                const SizedBox(height: 8),

                MemeText(
                  action.label,
                  fontSize: 12,
                  color: action.isEnabled ? action.color : Colors.grey,
                ),
              ],
            ),
          )
              .animate(delay: Duration(milliseconds: index * 100))
              .fadeIn()
              .scale(
            begin: const Offset(0.8, 0.8),
            end: const Offset(1, 1),
          ),
        );
      },
    );
  }
}

class QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isEnabled;

  const QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isEnabled = true,
  });
}

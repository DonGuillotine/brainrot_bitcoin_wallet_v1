import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/animated/meme_text.dart';
import '../../../providers/theme_provider.dart';
import '../../../models/wallet_models.dart';
import '../../../services/service_locator.dart';

/// Fee selection widget with meme options
class FeeSelector extends StatelessWidget {
  final FeeEstimate feeEstimate;
  final int selectedFeeRate;
  final Function(int) onFeeSelected;

  const FeeSelector({
    super.key,
    required this.feeEstimate,
    required this.selectedFeeRate,
    required this.onFeeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final chaosLevel = themeProvider.chaosLevel;

    final feeOptions = [
      FeeOption(
        name: 'YOLO MODE',
        description: 'Next block or die trying',
        emoji: '🚀',
        feeRate: feeEstimate.fastestFee,
        confirmationTime: '~10 minutes',
        color: AppTheme.error,
      ),
      FeeOption(
        name: 'Zoomer Speed',
        description: 'Pretty fast ngl',
        emoji: '⚡',
        feeRate: feeEstimate.halfHourFee,
        confirmationTime: '~30 minutes',
        color: AppTheme.warning,
      ),
      FeeOption(
        name: 'Normie Pace',
        description: 'Regular confirmation',
        emoji: '🚶',
        feeRate: feeEstimate.hourFee,
        confirmationTime: '~1 hour',
        color: AppTheme.limeGreen,
      ),
      FeeOption(
        name: 'Diamond Hands',
        description: 'I can wait forever',
        emoji: '💎',
        feeRate: feeEstimate.economyFee,
        confirmationTime: '2+ hours',
        color: AppTheme.deepPurple,
      ),
    ];

    return Column(
      children: feeOptions.map((option) {
        final isSelected = selectedFeeRate == option.feeRate;

        return GestureDetector(
          onTap: () {
            onFeeSelected(option.feeRate);
            services.hapticService.light();
            services.soundService.tap();
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? option.color.withAlpha((0.2 * 255).round())
                  : AppTheme.lightGrey,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? option.color : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                // Emoji
                Text(
                  option.emoji,
                  style: const TextStyle(fontSize: 32),
                )
                    .animate(target: isSelected ? 1 : 0)
                    .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.2, 1.2),
                ),

                const SizedBox(width: 16),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          MemeText(
                            option.name,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? option.color : Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: option.color.withAlpha((0.2 * 255).round()),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: MemeText(
                              '${option.feeRate} sat/vB',
                              fontSize: 12,
                              color: option.color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      MemeText(
                        option.description,
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                      const SizedBox(height: 2),
                      MemeText(
                        option.confirmationTime,
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ],
                  ),
                ),

                // Selection indicator
                Radio<int>(
                  value: option.feeRate,
                  groupValue: selectedFeeRate,
                  onChanged: (value) => onFeeSelected(value!),
                  activeColor: option.color,
                ),
              ],
            ),
          )
              .animate(target: isSelected ? 1 : 0)
              .scale(
            begin: const Offset(0.98, 0.98),
            end: const Offset(1, 1),
          ),
        );
      }).toList(),
    );
  }
}

class FeeOption {
  final String name;
  final String description;
  final String emoji;
  final int feeRate;
  final String confirmationTime;
  final Color color;

  const FeeOption({
    required this.name,
    required this.description,
    required this.emoji,
    required this.feeRate,
    required this.confirmationTime,
    required this.color,
  });
}

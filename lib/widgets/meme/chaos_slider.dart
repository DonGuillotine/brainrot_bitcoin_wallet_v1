import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/chaos_theme.dart';
import '../../providers/theme_provider.dart';
import '../../services/service_locator.dart';
import '../animated/meme_text.dart';
import 'dart:math' as math;

/// Chaos level slider with meme effects
class ChaosSlider extends StatefulWidget {
  const ChaosSlider({super.key});

  @override
  State<ChaosSlider> createState() => _ChaosSliderState();
}

class _ChaosSliderState extends State<ChaosSlider>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _currentValue = 5;
  bool _isDragging = false;

  final List<String> _chaosLabels = [
    'Normie Mode 😴',
    'Slightly Based 🤔',
    'Getting Spicy 🌶️',
    'Chaos Rising 📈',
    'Brain Melting 🧠',
    'MAXIMUM CHAOS 🤯',
    'BEYOND REASON 👁️',
    'REALITY BROKEN 🌀',
    'ASCENDED 🛸',
    'SINGULARITY 🕳️',
    'Ģ̷͉L̸̢̈I̶̱̐T̷̰̄C̶̣̈H̵̬̀ 💀',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    final themeProvider = context.read<ThemeProvider>();
    _currentValue = themeProvider.chaosLevel.toDouble();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged(double value) {
    setState(() {
      _currentValue = value;
    });

    // Haptic feedback based on value
    if (value >= 8) {
      services.hapticService.heavy();
    } else if (value >= 5) {
      services.hapticService.medium();
    } else {
      services.hapticService.light();
    }
  }

  void _handleChangeEnd(double value) {
    final themeProvider = context.read<ThemeProvider>();
    themeProvider.setChaosLevel(value.round());

    setState(() {
      _isDragging = false;
    });

    // Play sound based on level
    if (value >= 8) {
      services.soundService.chaos();
    } else {
      services.soundService.tap();
    }
  }

  @override
  Widget build(BuildContext context) {
    final intValue = _currentValue.round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: ChaosTheme.getChaosDecoration(
        chaosLevel: intValue,
        baseColor: AppTheme.lightGrey,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              Icon(
                Icons.whatshot,
                color: ChaosTheme.getRandomChaosColor(),
                size: 24,
              )
                  .animate(
                onPlay: (controller) {
                  if (intValue >= 5) {
                    controller.repeat();
                  }
                },
              )
                  .shake(hz: intValue.toDouble()),

              const SizedBox(width: 8),

              MemeText(
                'CHAOS LEVEL',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                rainbow: intValue >= 9,
                glitch: intValue >= 10,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: ChaosTheme.getRandomChaosColor(),
              inactiveTrackColor: AppTheme.darkGrey,
              thumbColor: AppTheme.hotPink,
              overlayColor: AppTheme.hotPink.withAlpha((0.3 * 255).round()),
              thumbShape: _ChaosThumbShape(
                chaosLevel: intValue,
                isDragging: _isDragging,
              ),
              trackHeight: 8 + (intValue * 0.5),
            ),
            child: Slider(
              value: _currentValue,
              min: 0,
              max: 10,
              divisions: 10,
              onChanged: _handleChanged,
              onChangeStart: (_) {
                setState(() => _isDragging = true);
                _controller.forward();
              },
              onChangeEnd: _handleChangeEnd,
            ),
          ),

          const SizedBox(height: 12),

          // Current level label
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                gradient: ChaosTheme.getChaosGradient(intValue),
                borderRadius: BorderRadius.circular(20),
              ),
              child: MemeText(
                _chaosLabels[intValue],
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                glitch: intValue >= 10,
              ),
            ),
          )
              .animate(
            onPlay: (controller) {
              if (_isDragging && intValue >= 7) {
                controller.repeat();
              }
            },
          )
              .shake(
            hz: intValue.toDouble() * 2,
            offset: Offset(intValue.toDouble(), 0),
          ),

          // Warning for maximum chaos
          if (intValue >= 9) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.error.withAlpha((0.2 * 255).round()),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.error,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning,
                    color: AppTheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MemeText(
                      'WARNING: Reality may become unstable',
                      fontSize: 12,
                      color: AppTheme.error,
                      glitch: true,
                    ),
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
    );
  }
}

/// Custom thumb shape for chaos slider
class _ChaosThumbShape extends SliderComponentShape {
  final int chaosLevel;
  final bool isDragging;

  const _ChaosThumbShape({
    required this.chaosLevel,
    required this.isDragging,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    final size = 20.0 + (chaosLevel * 2);
    return Size(size, size);
  }

  @override
  void paint(
      PaintingContext context,
      Offset center, {
        required Animation<double> activationAnimation,
        required Animation<double> enableAnimation,
        required bool isDiscrete,
        required TextPainter labelPainter,
        required RenderBox parentBox,
        required SliderThemeData sliderTheme,
        required TextDirection textDirection,
        required double value,
        required double textScaleFactor,
        required Size sizeWithOverflow,
      }) {
    final canvas = context.canvas;
    final radius = getPreferredSize(true, true).width / 2;

    // Draw multiple circles for chaos effect
    if (chaosLevel >= 7) {
      final random = math.Random();
      for (int i = 0; i < 3; i++) {
        final offset = Offset(
          (random.nextDouble() - 0.5) * 4,
          (random.nextDouble() - 0.5) * 4,
        );

        canvas.drawCircle(
          center + offset,
          radius,
          Paint()
            ..color = ChaosTheme.glitchColors[i].withAlpha((0.3 * 255).round())
            ..style = PaintingStyle.fill,
        );
      }
    }

    // Main thumb
    final paint = Paint()
      ..color = sliderTheme.thumbColor ?? AppTheme.hotPink
      ..style = PaintingStyle.fill;

    if (isDragging && chaosLevel >= 5) {
      // Pulsing effect when dragging
      final scale = 1.0 + (math.sin(DateTime.now().millisecondsSinceEpoch / 100) * 0.1);
      canvas.drawCircle(center, radius * scale, paint);
    } else {
      canvas.drawCircle(center, radius, paint);
    }

    // Draw emoji on thumb for maximum chaos
    if (chaosLevel >= 9) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: chaosLevel == 10 ? '💀' : '🔥',
          style: TextStyle(fontSize: radius),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        center - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }
}

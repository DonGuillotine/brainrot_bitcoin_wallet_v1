import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../theme/chaos_theme.dart';
import '../../providers/theme_provider.dart';
import 'dart:math' as math;

import '../effects/glitch_effect.dart';

/// Animated text with meme effects
class MemeText extends StatefulWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final Color? color;
  final TextAlign textAlign;
  final bool enableChaos;
  final bool rainbow;
  final bool glitch;

  const MemeText(
      this.text, {
        super.key,
        this.fontSize = 16,
        this.fontWeight = FontWeight.normal,
        this.color,
        this.textAlign = TextAlign.left,
        this.enableChaos = true,
        this.rainbow = false,
        this.glitch = false,
      });

  @override
  State<MemeText> createState() => _MemeTextState();
}

class _MemeTextState extends State<MemeText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Color> _rainbowColors = [
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.indigo,
    Colors.purple,
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    if (widget.rainbow) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final chaosLevel = widget.enableChaos ? themeProvider.chaosLevel : 0;

    Widget textWidget = Text(
      widget.text,
      textAlign: widget.textAlign,
      style: ChaosTheme.getChaosTextStyle(
        fontSize: widget.fontSize,
        chaosLevel: chaosLevel,
        fontWeight: widget.fontWeight,
        color: widget.color,
      ),
    );

    // Apply rainbow effect
    if (widget.rainbow) {
      textWidget = AnimatedBuilder(
        animation: _controller,
        child: textWidget,
        builder: (context, child) {
          return ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                colors: _rainbowColors,
                tileMode: TileMode.repeated,
                transform: GradientRotation(_controller.value * 2 * math.pi),
              ).createShader(bounds);
            },
            child: child,
          );
        },
      );
    }

    // Apply glitch effect
    if (widget.glitch && chaosLevel >= 6) {
      textWidget = GlitchEffect(
        isActive: true,
        intensity: chaosLevel / 10,
        child: textWidget,
      );
    }

    // Apply chaos animations
    if (widget.enableChaos && chaosLevel > 0) {
      // determine the initial delay & overall duration
      final begin = chaosLevel >= 9
          ? const Duration(milliseconds: 100)
          : const Duration(milliseconds: 500);
      final totalDuration = chaosLevel >= 9
          ? const Duration(milliseconds: 200)
          : const Duration(seconds: 1);

      return textWidget
          .animate(
        onPlay: (controller) {
          if (chaosLevel >= 7) {
            controller.repeat(reverse: true);
          }
        },
      )
      // wait ‘begin’ before starting the shake/scale
          .then(delay: begin)
      // shake effect with its own duration
          .shake(
        hz: chaosLevel.toDouble(),
        offset: Offset(chaosLevel.toDouble(), 0),
        duration: totalDuration,
      )
      // scale effect, inheriting the same duration
          .scale(
        begin: const Offset(1, 1),
        end: Offset(
          1 + chaosLevel * 0.02,
          1 + chaosLevel * 0.02,
        ),
        duration: totalDuration,
      );
    }

    return textWidget;
  }
}

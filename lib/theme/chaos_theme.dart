import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

import 'app_theme.dart';

/// Chaos theme configuration with meme aesthetics
class ChaosTheme {
  // Private constructor
  ChaosTheme._();

  // Chaos color variations
  static const List<Color> chaosColors = [
    Color(0xFF6B46C1), // Deep Purple
    Color(0xFF84CC16), // Lime Green
    Color(0xFFEC4899), // Hot Pink
    Color(0xFFFBBF24), // Yellow
    Color(0xFF22D3EE), // Cyan
    Color(0xFFF97316), // Orange
    Color(0xFF8B5CF6), // Violet
  ];

  // Glitch colors
  static const List<Color> glitchColors = [
    Color(0xFFFF0080), // Magenta
    Color(0xFF00FF88), // Green
    Color(0xFF00D9FF), // Cyan
  ];

  // Get random chaos color
  static Color getRandomChaosColor() {
    return chaosColors[math.Random().nextInt(chaosColors.length)];
  }

  // Get chaos gradient based on chaos level
  static LinearGradient getChaosGradient(int chaosLevel) {
    final colorCount = (chaosLevel / 2).clamp(2, chaosColors.length).toInt();
    final colors = List.generate(
      colorCount,
          (index) => chaosColors[index % chaosColors.length],
    );

    return LinearGradient(
      colors: colors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      transform: GradientRotation(chaosLevel * math.pi / 10),
    );
  }

  // Text styles with chaos variations
  static TextStyle getChaosTextStyle({
    required double fontSize,
    required int chaosLevel,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
  }) {
    final fonts = [
      GoogleFonts.bebasNeue,
      GoogleFonts.permanentMarker,
      GoogleFonts.creepster,
      GoogleFonts.nosifer,
      GoogleFonts.rubikGlitch,
    ];

    final fontIndex = chaosLevel >= 8
        ? math.Random().nextInt(fonts.length)
        : (chaosLevel / 3).floor().clamp(0, fonts.length - 1);

    return fonts[fontIndex](
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? Colors.white,
      letterSpacing: chaosLevel > 5 ? (math.Random().nextDouble() * 3) : 1,
    );
  }

  // Box decoration with chaos effects
  static BoxDecoration getChaosDecoration({
    required int chaosLevel,
    Color? baseColor,
    bool glitch = false,
  }) {
    if (chaosLevel >= 8 && glitch) {
      // Maximum chaos with glitch effect
      return BoxDecoration(
        gradient: getChaosGradient(chaosLevel),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: getRandomChaosColor(),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: glitchColors[0].withAlpha((0.5 * 255).round()),
            blurRadius: 20,
            offset: const Offset(-5, -5),
          ),
          BoxShadow(
            color: glitchColors[0].withAlpha((0.5 * 255).round()),
            blurRadius: 20,
            offset: const Offset(5, 5),
          ),
        ],
      );
    }

    return BoxDecoration(
      color: baseColor ?? AppTheme.lightGrey,
      borderRadius: BorderRadius.circular(16 + chaosLevel.toDouble()),
      border: chaosLevel > 3
          ? Border.all(
        color: getRandomChaosColor(),
        width: (chaosLevel / 3).clamp(1, 4).toDouble(),
      )
          : null,
      boxShadow: [
        BoxShadow(
          color: (baseColor ?? AppTheme.deepPurple).withAlpha((0.3 * 255).round()),
          blurRadius: 10 + chaosLevel.toDouble(),
          offset: Offset(0, 4 + chaosLevel.toDouble()),
        ),
      ],
    );
  }
}

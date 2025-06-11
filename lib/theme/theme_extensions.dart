import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'app_theme.dart';
import 'chaos_theme.dart';

/// Theme extensions for chaos effects
extension ChaosThemeExtensions on ThemeData {
  /// Get button style based on chaos level
  ButtonStyle chaosButtonStyle(int chaosLevel, {bool isPrimary = true}) {
    return ElevatedButton.styleFrom(
      backgroundColor: isPrimary ? AppTheme.deepPurple : Colors.transparent,
      foregroundColor: isPrimary ? Colors.white : AppTheme.limeGreen,
      padding: EdgeInsets.symmetric(
        horizontal: 24 + (chaosLevel * 2),
        vertical: 16,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12 + chaosLevel.toDouble()),
        side: isPrimary
            ? BorderSide.none
            : BorderSide(
          color: AppTheme.limeGreen,
          width: 2 + (chaosLevel * 0.2),
        ),
      ),
      elevation: chaosLevel.toDouble(),
    );
  }

  /// Get input decoration based on chaos level
  InputDecoration chaosInputDecoration({
    required String labelText,
    required int chaosLevel,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      labelStyle: ChaosTheme.getChaosTextStyle(
        fontSize: 16,
        chaosLevel: chaosLevel,
        color: AppTheme.limeGreen,
      ),
      hintStyle: TextStyle(
        color: Colors.white.withAlpha((0.5 * 255).round()),
      ),
      filled: true,
      fillColor: AppTheme.darkGrey,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12 + chaosLevel.toDouble()),
        borderSide: BorderSide(
          color: AppTheme.deepPurple,
          width: 2,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12 + chaosLevel.toDouble()),
        borderSide: BorderSide(
          color: AppTheme.deepPurple.withAlpha((0.5 * 255).round()),
          width: 2,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12 + chaosLevel.toDouble()),
        borderSide: BorderSide(
          color: chaosLevel >= 7
              ? ChaosTheme.getRandomChaosColor()
              : AppTheme.limeGreen,
          width: 3,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12 + chaosLevel.toDouble()),
        borderSide: const BorderSide(
          color: AppTheme.error,
          width: 2,
        ),
      ),
    );
  }
}

/// Widget extensions for chaos animations
extension ChaosWidgetExtensions on Widget {
  /// Apply chaos shake effect
  Widget chaosShake(int chaosLevel) {
    if (chaosLevel == 0) return this;

    return animate(
      onPlay: (controller) {
        if (chaosLevel >= 5) {
          controller.repeat(reverse: true);
        }
      },
    ).shake(
      hz: chaosLevel.toDouble(),
      offset: Offset(chaosLevel.toDouble() * 0.5, 0),
    );
  }

  /// Apply chaos rotation effect
  Widget chaosRotate(int chaosLevel) {
    if (chaosLevel < 3) return this;

    return animate(
      onPlay: (controller) {
        if (chaosLevel >= 7) {
          controller.repeat();
        }
      },
    ).rotate(
      begin: 0,
      end: chaosLevel >= 9 ? 1 : 0.1,
      duration: Duration(seconds: 10 - chaosLevel),
    );
  }

  /// Apply chaos scale effect
  Widget chaosScale(int chaosLevel) {
    if (chaosLevel < 4) return this;

    return animate(
      onPlay: (controller) {
        if (chaosLevel >= 6) {
          controller.repeat(reverse: true);
        }
      },
    ).scale(
      begin: const Offset(1, 1),
      end: Offset(
        1 + (chaosLevel * 0.02),
        1 + (chaosLevel * 0.02),
      ),
      duration: Duration(milliseconds: 2000 - (chaosLevel * 150)),
    );
  }

  /// Apply all chaos effects
  Widget chaos(int chaosLevel) {
    return this
        .chaosShake(chaosLevel)
        .chaosRotate(chaosLevel)
        .chaosScale(chaosLevel);
  }
}

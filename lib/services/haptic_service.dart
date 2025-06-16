import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../providers/theme_provider.dart';
import 'base/base_service.dart';

/// Service for haptic feedback based on chaos level
class HapticService extends BaseService {
  final ThemeProvider _themeProvider;

  HapticService(this._themeProvider) : super('HapticService');

  /// Light haptic feedback
  Future<void> light() async {
    if (!_themeProvider.hapticsEnabled) return;

    HapticFeedback.lightImpact();
    logDebug('Light haptic triggered');
  }

  /// Medium haptic feedback
  Future<void> medium() async {
    if (!_themeProvider.hapticsEnabled) return;

    HapticFeedback.mediumImpact();
    logDebug('Medium haptic triggered');
  }

  /// Heavy haptic feedback
  Future<void> heavy() async {
    if (!_themeProvider.hapticsEnabled) return;

    HapticFeedback.heavyImpact();
    logDebug('Heavy haptic triggered');
  }

  /// Selection haptic feedback
  Future<void> selection() async {
    if (!_themeProvider.hapticsEnabled) return;

    HapticFeedback.selectionClick();
    logDebug('Selection haptic triggered');
  }

  /// Chaos haptic (based on chaos level)
  Future<void> chaos() async {
    if (!_themeProvider.hapticsEnabled) return;

    final chaos = _themeProvider.chaosLevel;

    if (chaos >= 8) {
      // Maximum chaos - random pattern
      await _chaosPattern();
    } else if (chaos >= 5) {
      // High chaos - double tap
      await heavy();
      await Future.delayed(const Duration(milliseconds: 100));
      await medium();
    } else if (chaos >= 3) {
      // Medium chaos - single heavy
      await heavy();
    } else {
      // Low chaos - light tap
      await light();
    }
  }

  /// Success haptic pattern
  Future<void> success() async {
    if (!_themeProvider.hapticsEnabled) return;

    if (_themeProvider.chaosLevel >= 7) {
      // Chaotic success
      for (int i = 0; i < 3; i++) {
        await medium();
        await Future.delayed(const Duration(milliseconds: 50));
      }
    } else {
      // Normal success
      await medium();
      await Future.delayed(const Duration(milliseconds: 100));
      await heavy();
    }

    logDebug('Success haptic pattern triggered');
  }

  /// Error haptic pattern
  Future<void> error() async {
    if (!_themeProvider.hapticsEnabled) return;

    // Vibrate if available
    final canVibrate = await Vibration.hasVibrator();
    if (canVibrate == true) {
      await Vibration.vibrate();
    } else {
      // Fallback to heavy impacts
      for (int i = 0; i < 2; i++) {
        await heavy();
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    logDebug('Error haptic pattern triggered');
  }

  /// Warning haptic pattern
  Future<void> warning() async {
    if (!_themeProvider.hapticsEnabled) return;

    await medium();
    await Future.delayed(const Duration(milliseconds: 150));
    await medium();

    logDebug('Warning haptic pattern triggered');
  }

  /// Transaction haptic (for sending/receiving)
  Future<void> transaction() async {
    if (!_themeProvider.hapticsEnabled) return;

    if (_themeProvider.chaosLevel >= 6) {
      // Chaotic transaction feedback
      await _chaosPattern();
    } else {
      // Normal transaction feedback
      await light();
      await Future.delayed(const Duration(milliseconds: 100));
      await medium();
      await Future.delayed(const Duration(milliseconds: 100));
      await heavy();
    }

    logDebug('Transaction haptic pattern triggered');
  }

  /// Private chaos pattern
  Future<void> _chaosPattern() async {
    final patterns = [
      [HapticFeedback.lightImpact, HapticFeedback.heavyImpact, HapticFeedback.mediumImpact],
      [HapticFeedback.heavyImpact, HapticFeedback.heavyImpact, HapticFeedback.lightImpact],
      [HapticFeedback.selectionClick, HapticFeedback.mediumImpact, HapticFeedback.heavyImpact],
    ];

    final pattern = patterns[DateTime.now().millisecond % patterns.length];

    for (final haptic in pattern) {
      haptic();
      await Future.delayed(Duration(milliseconds: 50 + (DateTime.now().millisecond % 100)));
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';

/// Theme provider for managing app theming and chaos levels
class ThemeProvider extends ChangeNotifier {
  // Chaos level (0-10)
  int _chaosLevel = 5;
  bool _soundEnabled = true;
  bool _hapticsEnabled = true;
  bool _particlesEnabled = true;

  // Getters
  int get chaosLevel => _chaosLevel;
  bool get soundEnabled => _soundEnabled;
  bool get hapticsEnabled => _hapticsEnabled;
  bool get particlesEnabled => _particlesEnabled;

  ThemeProvider() {
    _loadPreferences();
  }

  /// Load theme preferences
  Future<void> _loadPreferences() async {
    _chaosLevel = prefs.getInt('chaos_level') ?? 5;
    _soundEnabled = prefs.getBool('sound_enabled') ?? true;
    _hapticsEnabled = prefs.getBool('haptics_enabled') ?? true;
    _particlesEnabled = prefs.getBool('particles_enabled') ?? true;
    notifyListeners();
  }

  /// Set chaos level
  Future<void> setChaosLevel(int level) async {
    _chaosLevel = level.clamp(0, 10);
    await prefs.setInt('chaos_level', _chaosLevel);

    // Trigger haptic feedback based on chaos level
    if (_hapticsEnabled && _chaosLevel > 5) {
      HapticFeedback.heavyImpact();
    }

    notifyListeners();
  }

  /// Toggle sound
  Future<void> toggleSound() async {
    _soundEnabled = !_soundEnabled;
    await prefs.setBool('sound_enabled', _soundEnabled);
    notifyListeners();
  }

  /// Toggle haptics
  Future<void> toggleHaptics() async {
    _hapticsEnabled = !_hapticsEnabled;
    await prefs.setBool('haptics_enabled', _hapticsEnabled);
    notifyListeners();
  }

  /// Toggle particles
  Future<void> toggleParticles() async {
    _particlesEnabled = !_particlesEnabled;
    await prefs.setBool('particles_enabled', _particlesEnabled);
    notifyListeners();
  }

  /// Get animation duration based on chaos level
  Duration getAnimationDuration() {
    // Higher chaos = faster animations
    final baseMs = 500;
    final multiplier = 1.0 - (_chaosLevel * 0.08);
    return Duration(milliseconds: (baseMs * multiplier).round());
  }

  /// Get shake intensity based on chaos level
  double getShakeIntensity() {
    return _chaosLevel * 0.5;
  }

  /// Should show random effects based on chaos level
  bool shouldShowRandomEffect() {
    if (_chaosLevel == 0) return false;
    // Higher chaos = more random effects
    final threshold = 1.0 - (_chaosLevel * 0.1);
    return DateTime.now().millisecond / 1000.0 > threshold;
  }
}

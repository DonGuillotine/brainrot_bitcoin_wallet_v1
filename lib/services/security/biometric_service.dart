import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import '../base/base_service.dart';
import '../base/service_result.dart';
import '../../providers/theme_provider.dart';

/// Service for handling biometric authentication
class BiometricService extends BaseService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  BiometricService() : super('BiometricService');

  /// Check if biometrics are available
  Future<ServiceResult<bool>> isBiometricAvailable() async {
    return executeOperation(
      operation: () async {
        final canCheckBiometrics = await _localAuth.canCheckBiometrics;
        final isDeviceSupported = await _localAuth.isDeviceSupported();

        return canCheckBiometrics && isDeviceSupported;
      },
      operationName: 'check biometric availability',
      errorCode: ErrorCodes.authFailed,
    );
  }

  /// Get available biometric types
  Future<ServiceResult<List<BiometricType>>> getAvailableBiometrics() async {
    return executeOperation(
      operation: () async {
        return await _localAuth.getAvailableBiometrics();
      },
      operationName: 'get available biometrics',
      errorCode: ErrorCodes.authFailed,
    );
  }

  /// Authenticate with biometrics
  Future<ServiceResult<bool>> authenticate({
    required String reason,
    bool stickyAuth = true,
    bool biometricOnly = false,
  }) async {
    return executeOperation(
      operation: () async {
        try {
          final authenticated = await _localAuth.authenticate(
            localizedReason: reason,
            options: AuthenticationOptions(
              stickyAuth: stickyAuth,
              biometricOnly: biometricOnly,
              useErrorDialogs: true,
            ),
          );

          if (authenticated) {
            // Trigger haptic feedback on success
            HapticFeedback.heavyImpact();
          }

          return authenticated;
        } on PlatformException catch (e) {
          logWarning('Biometric auth failed: ${e.message}');
          return false;
        }
      },
      operationName: 'biometric authentication',
      errorCode: ErrorCodes.authFailed,
    );
  }

  /// Authenticate with meme messages
  Future<ServiceResult<bool>> authenticateWithMemes({
    required ThemeProvider themeProvider,
  }) async {
    final chaosLevel = themeProvider.chaosLevel;

    // Generate chaos-based authentication message
    final reasons = [
      'Prove you\'re not a bot, anon 🤖',
      'Show me your face, no cap 🧢',
      'Biometric check, let\'s gooo 🚀',
      'Touch the thing to unlock gains 💎',
      'Face ID check or stay poor 📈',
      'Scan your flesh prison to continue 👁️',
      'Authentication required, fr fr 🔐',
      'Verify your meat suit identity 🥩',
      'Touch grass... I mean sensor 🌱',
      'WHO GOES THERE?! Show yourself! 👀',
    ];

    final reason = reasons[chaosLevel.clamp(0, reasons.length - 1)];

    return authenticate(reason: reason);
  }

  /// Stop authentication
  Future<ServiceResult<bool>> stopAuthentication() async {
    return executeOperation(
      operation: () async {
        return await _localAuth.stopAuthentication();
      },
      operationName: 'stop authentication',
      errorCode: ErrorCodes.authFailed,
    );
  }
}

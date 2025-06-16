import 'package:flutter/foundation.dart';
import 'security/encryption_service.dart';
import 'security/biometric_service.dart';
import 'storage/storage_service.dart';
import 'network/network_service.dart';
import 'network/price_service.dart';
import 'haptic_service.dart';
import 'sound_service.dart';
import 'bitcoin/bdk_service.dart';
import 'lightning/ldk_service.dart';
import '../providers/theme_provider.dart';

/// Service locator for dependency injection
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  // Service instances
  late final EncryptionService encryptionService;
  late final BiometricService biometricService;
  late final StorageService storageService;
  late final NetworkService networkService;
  late final PriceService priceService;
  late final HapticService hapticService;
  late final SoundService soundService;
  late final BdkService bdkService;
  late final LdkService ldkService;

  // Initialization flag
  bool _initialized = false;

  /// Check if services are initialized
  bool get isInitialized => _initialized;

  /// Initialize all services
  Future<void> initialize(ThemeProvider themeProvider) async {
    if (_initialized) return;

    try {
      // Initialize core services
      encryptionService = await EncryptionService.create();
      biometricService = BiometricService();
      networkService = NetworkService();

      // Initialize services with dependencies
      storageService = StorageService(encryptionService);
      priceService = PriceService(networkService);
      hapticService = HapticService(themeProvider);
      soundService = SoundService(themeProvider);
      bdkService = BdkService(encryptionService, storageService);
      ldkService = LdkService(storageService, encryptionService, networkService);

      // Initialize storage
      await storageService.initialize();

      // Start price updates
      priceService.startPriceUpdates();

      _initialized = true;

      if (kDebugMode) {
        print('🎯 ServiceLocator initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ServiceLocator initialization failed: $e');
      }
      rethrow;
    }
  }

  /// Safe access to sound service
  void playSoundSafely(void Function(SoundService) action) {
    if (_initialized) {
      try {
        action(soundService);
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Sound service action failed: $e');
        }
      }
    }
  }

  /// Safe access to haptic service
  void triggerHapticSafely(void Function(HapticService) action) {
    if (_initialized) {
      try {
        action(hapticService);
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Haptic service action failed: $e');
        }
      }
    }
  }

  /// Dispose all services
  void dispose() {
    if (_initialized) {
      priceService.dispose();
      soundService.dispose();
      networkService.cancelAllRequests();
    }
  }
}

/// Global service locator instance
final services = ServiceLocator();

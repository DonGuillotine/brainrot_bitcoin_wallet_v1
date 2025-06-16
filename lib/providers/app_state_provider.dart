import 'package:flutter/foundation.dart';
import '../main.dart';

/// Main app state provider
class AppStateProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _hasWallet = false;
  bool _isOnboarded = false;
  bool _isWalletInitializing = false;
  String? _currentRoute;

  // Getters
  bool get isLoading => _isLoading || _isWalletInitializing;
  bool get hasWallet => _hasWallet;
  bool get isOnboarded => _isOnboarded;
  String? get currentRoute => _currentRoute;

  AppStateProvider() {
    _initializeAppState();
  }

  /// Initialize app state from storage
  Future<void> _initializeAppState() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Small delay to ensure storage is ready
      await Future.delayed(const Duration(milliseconds: 100));

      // Check if wallet exists
      logger.d('🏪 Checking if wallet exists in secure storage...');
      final walletExists = await secureStorage.containsKey(key: 'wallet_mnemonic');
      _hasWallet = walletExists;
      logger.d('🏪 Wallet exists: $_hasWallet');

      // Check if user has completed onboarding
      logger.d('🏪 Checking onboarding status...');
      _isOnboarded = prefs.getBool('is_onboarded') ?? false;
      logger.d('🏪 Onboarded: $_isOnboarded');

      logger.i('✅ App state initialized - Wallet: $_hasWallet, Onboarded: $_isOnboarded');
    } catch (e) {
      logger.e('❌ Error initializing app state', error: e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh app state from storage (for manual refresh)
  Future<void> refreshAppState() async {
    await _initializeAppState();
  }

  /// Set loading state
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set wallet existence
  void setHasWallet(bool hasWallet) {
    _hasWallet = hasWallet;
    notifyListeners();
  }

  /// Set onboarding completion
  Future<void> setOnboarded(bool onboarded) async {
    _isOnboarded = onboarded;
    await prefs.setBool('is_onboarded', onboarded);
    notifyListeners();
  }

  /// Update current route
  void setCurrentRoute(String route) {
    _currentRoute = route;
    notifyListeners();
  }

  /// Set wallet initialization state
  void setWalletInitializing(bool initializing) {
    logger.d('🔄 Setting wallet initializing: $initializing (was: $_isWalletInitializing)');
    _isWalletInitializing = initializing;
    notifyListeners();
  }

  /// Reset app state (for logout/wallet deletion)
  Future<void> resetAppState() async {
    _hasWallet = false;
    _isOnboarded = false;
    await prefs.clear();
    await secureStorage.deleteAll();
    notifyListeners();
  }
}

import 'package:flutter/foundation.dart';
import '../main.dart';

/// Main app state provider
class AppStateProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _hasWallet = false;
  bool _isOnboarded = false;
  String? _currentRoute;

  // Getters
  bool get isLoading => _isLoading;
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

      // Check if wallet exists
      final walletExists = await secureStorage.containsKey(key: 'wallet_mnemonic');
      _hasWallet = walletExists;

      // Check if user has completed onboarding
      _isOnboarded = prefs.getBool('is_onboarded') ?? false;

      logger.i('App state initialized - Wallet: $_hasWallet, Onboarded: $_isOnboarded');
    } catch (e) {
      logger.e('Error initializing app state', error: e);
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

  /// Reset app state (for logout/wallet deletion)
  Future<void> resetAppState() async {
    _hasWallet = false;
    _isOnboarded = false;
    await prefs.clear();
    await secureStorage.deleteAll();
    notifyListeners();
  }
}

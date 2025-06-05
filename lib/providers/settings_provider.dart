import 'package:flutter/foundation.dart';
import '../main.dart';

/// Settings provider for app configuration
class SettingsProvider extends ChangeNotifier {
  // Network settings
  bool _isTestnet = true;
  String _bitcoinNetwork = 'testnet';

  // Security settings
  bool _biometricsEnabled = false;
  int _pinLength = 6;

  // Display settings
  String _fiatCurrency = 'USD';
  bool _hideBalance = false;

  // Getters
  bool get isTestnet => _isTestnet;
  String get bitcoinNetwork => _bitcoinNetwork;
  bool get biometricsEnabled => _biometricsEnabled;
  int get pinLength => _pinLength;
  String get fiatCurrency => _fiatCurrency;
  bool get hideBalance => _hideBalance;

  SettingsProvider() {
    _loadSettings();
  }

  /// Load settings from storage
  Future<void> _loadSettings() async {
    _isTestnet = prefs.getBool('is_testnet') ?? true;
    _bitcoinNetwork = _isTestnet ? 'testnet' : 'mainnet';
    _biometricsEnabled = prefs.getBool('biometrics_enabled') ?? false;
    _pinLength = prefs.getInt('pin_length') ?? 6;
    _fiatCurrency = prefs.getString('fiat_currency') ?? 'USD';
    _hideBalance = prefs.getBool('hide_balance') ?? false;
    notifyListeners();
  }

  /// Toggle network
  Future<void> toggleNetwork() async {
    _isTestnet = !_isTestnet;
    _bitcoinNetwork = _isTestnet ? 'testnet' : 'mainnet';
    await prefs.setBool('is_testnet', _isTestnet);
    notifyListeners();
  }

  /// Toggle biometrics
  Future<void> toggleBiometrics() async {
    _biometricsEnabled = !_biometricsEnabled;
    await prefs.setBool('biometrics_enabled', _biometricsEnabled);
    notifyListeners();
  }

  /// Set fiat currency
  Future<void> setFiatCurrency(String currency) async {
    _fiatCurrency = currency;
    await prefs.setString('fiat_currency', currency);
    notifyListeners();
  }

  /// Toggle balance visibility
  Future<void> toggleBalanceVisibility() async {
    _hideBalance = !_hideBalance;
    await prefs.setBool('hide_balance', _hideBalance);
    notifyListeners();
  }
}

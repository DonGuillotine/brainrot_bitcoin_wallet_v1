import 'package:flutter/foundation.dart';
import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:provider/provider.dart';
import '../services/bitcoin/bdk_service.dart';
import '../services/service_locator.dart';
import '../models/wallet_models.dart';
import '../main.dart';
import 'app_state_provider.dart';

/// Wallet provider for managing Bitcoin wallet state
class WalletProvider extends ChangeNotifier {
  final BdkService _bdkService;

  // State
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _error;
  int? _currentBlockHeight;

  // Wallet data
  WalletConfig? _walletConfig;
  BrainrotBalance? _balance;
  List<BrainrotTransaction> _transactions = [];
  List<BrainrotAddress> _addresses = [];
  BrainrotAddress? _currentReceiveAddress;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get error => _error;
  WalletConfig? get walletConfig => _walletConfig;
  BrainrotBalance? get balance => _balance;
  List<BrainrotTransaction> get transactions => _transactions;
  List<BrainrotAddress> get addresses => _addresses;
  BrainrotAddress? get currentReceiveAddress => _currentReceiveAddress;
  int? get currentBlockHeight => _currentBlockHeight;

  // Computed getters
  String get balanceDisplay {
    if (_balance == null) return '0.00000000 BTC';
    return '${_balance!.btc.toStringAsFixed(8)} BTC';
  }

  String get balanceFiat {
    if (_balance == null) return '\$0.00';
    
    final priceData = services.priceService.getCurrentPrice('USD');
    if (priceData == null) {
      return '\$0.00';
    }
    
    final fiatValue = services.priceService.convertBtcToFiat(_balance!.btc, priceData);
    return '\$${fiatValue.toStringAsFixed(2)}';
  }

  WalletProvider() : _bdkService = BdkService(
    services.encryptionService,
    services.storageService,
  ) {
    _setupListeners();
  }

  /// Setup stream listeners
  void _setupListeners() {
    // Balance updates
    _bdkService.balanceStream.listen((balance) {
      _balance = balance;
      notifyListeners();
    });

    // Transaction updates
    _bdkService.transactionStream.listen((transactions) {
      _transactions = transactions;
      notifyListeners();
    });

    // Sync status
    _bdkService.syncStream.listen((isSyncing) {
      _isSyncing = isSyncing;
      notifyListeners();
    });

    // Blockchain height updates
    _bdkService.blockHeightStream.listen((height) {
      _currentBlockHeight = height;
      notifyListeners();
    });
  }

  /// Initialize wallet from storage
  Future<void> initializeWallet(String password) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _bdkService.initializeWallet(password);

      if (result.isSuccess) {
        _walletConfig = _bdkService.walletConfig;
        _addresses = _bdkService.addresses;
        _transactions = _bdkService.transactions;
        _isInitialized = true;

        // Get current receive address
        await _updateReceiveAddress();

        logger.i('Wallet initialized! LFG! 🚀');
      } else {
        _setError(result.errorOrNull!.toMemeMessage());
      }
    } catch (e) {
      _setError('Failed to initialize wallet: $e');
      logger.e('Wallet initialization failed', error: e);
    } finally {
      _setLoading(false);
    }
  }

  /// Create new wallet
  Future<String?> createWallet({
    required String name,
    required String password,
    required Network network,
    required WalletType walletType,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _bdkService.createWallet(
        name: name,
        password: password,
        network: network,
        walletType: walletType,
      );

      if (result.isSuccess) {
        _walletConfig = _bdkService.walletConfig;
        _isInitialized = true;

        // Get initial receive address
        await _updateReceiveAddress();

        logger.i('New wallet created! WAGMI! 💎');

        // Return mnemonic for backup
        return result.valueOrNull;
      } else {
        _setError(result.errorOrNull!.toMemeMessage());
        return null;
      }
    } catch (e) {
      _setError('Failed to create wallet: $e');
      logger.e('Wallet creation failed', error: e);
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Restore wallet from mnemonic
  Future<bool> restoreWallet({
    required String name,
    required String mnemonic,
    required String password,
    required Network network,
    required WalletType walletType,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _bdkService.restoreWallet(
        name: name,
        mnemonic: mnemonic,
        password: password,
        network: network,
        walletType: walletType,
      );

      if (result.isSuccess) {
        _walletConfig = _bdkService.walletConfig;
        _isInitialized = true;

        logger.i('Wallet restored! We\'re back! 🎉');
        return true;
      } else {
        _setError(result.errorOrNull!.toMemeMessage());
        return false;
      }
    } catch (e) {
      _setError('Failed to restore wallet: $e');
      logger.e('Wallet restoration failed', error: e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Sync wallet
  Future<void> syncWallet() async {
    if (!_isInitialized || _isSyncing) return;

    _clearError();

    final result = await _bdkService.syncWallet();

    if (result.isError) {
      _setError(result.errorOrNull!.toMemeMessage());
    } else {
      // Update local state
      _addresses = _bdkService.addresses;
      _transactions = _bdkService.transactions;
    }
  }

  /// Get new receive address
  Future<void> getNewReceiveAddress() async {
    if (!_isInitialized) return;

    await _updateReceiveAddress();
  }

  /// Update receive address
  Future<void> _updateReceiveAddress() async {
    final result = await _bdkService.getReceiveAddress();

    if (result.isSuccess) {
      _currentReceiveAddress = result.valueOrNull;
      notifyListeners();
    }
  }

  /// Send Bitcoin
  Future<String?> sendBitcoin({
    required String address,
    required int amountSats,
    required int feeRate,
    String? memo,
  }) async {
    if (!_isInitialized) return null;

    _setLoading(true);
    _clearError();

    try {
      // Validate address first
      final validResult = await _bdkService.validateAddress(address);
      if (validResult.isError || !validResult.valueOrNull!) {
        _setError('Invalid Bitcoin address! That ain\'t it chief 🤨');
        return null;
      }

      // Check balance
      if (_balance == null || amountSats > _balance!.confirmed) {
        _setError('Insufficient funds! You broke boi 💸');
        return null;
      }

      // Create and broadcast transaction
      final result = await _bdkService.createTransaction(
        recipientAddress: address,
        amountSats: amountSats,
        feeRate: feeRate,
        memo: memo,
      );

      if (result.isSuccess) {
        logger.i('Transaction sent! TXID: ${result.valueOrNull}');

        // Play sound and haptic
        await services.soundService.sendTransaction();
        await services.hapticService.transaction();

        return result.valueOrNull;
      } else {
        _setError(result.errorOrNull!.toMemeMessage());
        return null;
      }
    } catch (e) {
      _setError('Failed to send transaction: $e');
      logger.e('Send transaction failed', error: e);
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Get fee estimates
  Future<FeeEstimate?> getFeeEstimates() async {
    final result = await _bdkService.getFeeEstimates();

    if (result.isSuccess) {
      return result.valueOrNull;
    } else {
      _setError('Failed to get fee estimates');
      return null;
    }
  }

  /// Validate address
  Future<bool> validateAddress(String address) async {
    if (!_isInitialized) return false;

    final result = await _bdkService.validateAddress(address);
    return result.isSuccess && result.valueOrNull == true;
  }

  /// Delete wallet
  Future<void> deleteWallet() async {
    _setLoading(true);

    final result = await _bdkService.deleteWallet();

    if (result.isSuccess) {
      // Reset state
      _isInitialized = false;
      _walletConfig = null;
      _balance = null;
      _transactions = [];
      _addresses = [];
      _currentReceiveAddress = null;

      // Update app state
      final appState = Provider.of<AppStateProvider>(
        navigatorKey.currentContext!,
        listen: false,
      );
      await appState.resetAppState();

      logger.w('Wallet deleted! F in the chat 😢');
    }

    _setLoading(false);
  }

  /// Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();

    // Play error sound
    services.soundService.error();
    services.hapticService.error();
  }

  void _clearError() {
    _error = null;
  }

  @override
  void dispose() {
    _bdkService.dispose();
    super.dispose();
  }
}

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:ldk_node/ldk_node.dart' as ldk;
import '../services/lightning/ldk_service.dart';
import '../services/service_locator.dart';
import '../models/lightning_models.dart';
import '../main.dart';

/// Lightning provider for managing Lightning Network state
class LightningProvider extends ChangeNotifier {
  final LdkService _ldkService;

  // State
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _error;

  // Lightning data
  NodeInfo? _nodeInfo;
  LightningBalance? _balance;
  List<BrainrotChannel> _channels = [];
  List<BrainrotPayment> _payments = [];
  BrainrotInvoice? _lastInvoice;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get error => _error;
  NodeInfo? get nodeInfo => _nodeInfo;
  LightningBalance? get balance => _balance;
  List<BrainrotChannel> get channels => _channels;
  List<BrainrotPayment> get payments => _payments;
  BrainrotInvoice? get lastInvoice => _lastInvoice;

  // Computed getters
  int get totalChannels => _channels.length;
  int get activeChannels => _channels.where((c) => c.isActive).length;
  int get totalCapacitySats => _balance?.totalSats ?? 0;
  int get spendableSats => _balance?.spendableSats ?? 0;
  int get receivableSats => _balance?.receivableSats ?? 0;

  LightningProvider() : _ldkService = LdkService(
    services.storageService,
    services.encryptionService,
    services.networkService,
  ) {
    _setupListeners();
  }

  /// Setup stream listeners
  void _setupListeners() {
    // Balance updates
    _ldkService.balanceStream.listen((balance) {
      _balance = balance;
      notifyListeners();
    });

    // Channel updates
    _ldkService.channelStream.listen((channels) {
      _channels = channels;
      notifyListeners();
    });

    // Payment updates
    _ldkService.paymentStream.listen((payment) {
      _payments.insert(0, payment);

      // Play sound for incoming payment
      if (payment.isIncoming && payment.status == PaymentStatus.succeeded) {
        services.soundService.receiveTransaction();
        services.hapticService.success();
      }

      notifyListeners();
    });
  }

  /// Initialize Lightning node
  Future<void> initializeLightning({
    required String seedPhrase,
    required String password,
    required ldk.Network network,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _ldkService.initializeNode(
        seedPhrase: seedPhrase,
        password: password,
        bitcoinNetwork: network,
      );

      if (result.isSuccess) {
        _isInitialized = true;

        // Get node info
        await updateNodeInfo();

        logger.i('Lightning node initialized! ⚡🚀');
      } else {
        _setError(result.errorOrNull!.toMemeMessage());
      }
    } catch (e) {
      _setError('Failed to initialize Lightning: $e');
      logger.e('Lightning initialization failed', error: e);
    } finally {
      _setLoading(false);
    }
  }

  /// Restore Lightning node
  Future<void> restoreLightning(String password) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _ldkService.restoreNode(password);

      if (result.isSuccess) {
        _isInitialized = true;

        // Get node info
        await updateNodeInfo();

        logger.i('Lightning node restored! ⚡');
      } else {
        _setError(result.errorOrNull!.toMemeMessage());
      }
    } catch (e) {
      _setError('Failed to restore Lightning: $e');
      logger.e('Lightning restoration failed', error: e);
    } finally {
      _setLoading(false);
    }
  }

  /// Update node info
  Future<void> updateNodeInfo() async {
    if (!_isInitialized) return;

    final result = await _ldkService.getNodeInfo();

    if (result.isSuccess) {
      _nodeInfo = result.valueOrNull;
      notifyListeners();
    }
  }

  /// Sync Lightning node
  Future<void> syncNode() async {
    if (!_isInitialized || _isSyncing) return;

    _isSyncing = true;
    notifyListeners();

    try {
      final result = await _ldkService.syncNode();

      if (result.isError) {
        _setError(result.errorOrNull!.toMemeMessage());
      } else {
        await updateNodeInfo();
      }
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Open channel
  Future<String?> openChannel({
    required String nodeId,
    required String nodeAddress,
    required int amountSats,
    int? pushSats,
    bool announceChannel = false,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _ldkService.openChannel(
        nodeId: nodeId,
        nodeAddress: nodeAddress,
        channelAmountSats: amountSats,
        pushMsat: pushSats != null ? pushSats * 1000 : null,
        announceChannel: announceChannel,
      );

      if (result.isSuccess) {
        logger.i('Channel opened! ID: ${result.valueOrNull}');

        // Play sound
        await services.soundService.success();
        await services.hapticService.success();

        return result.valueOrNull;
      } else {
        _setError(result.errorOrNull!.toMemeMessage());
        return null;
      }
    } catch (e) {
      _setError('Failed to open channel: $e');
      logger.e('Channel open failed', error: e);
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Close channel
  Future<void> closeChannel({
    required String channelId,
    required String nodeId,
    bool force = false,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _ldkService.closeChannel(
        channelId: channelId,
        nodeId: nodeId,
        force: force,
      );

      if (result.isSuccess) {
        logger.i('Channel closing initiated!');

        // Play sound
        await services.soundService.tap();
        await services.hapticService.medium();
      } else {
        _setError(result.errorOrNull!.toMemeMessage());
      }
    } catch (e) {
      _setError('Failed to close channel: $e');
      logger.e('Channel close failed', error: e);
    } finally {
      _setLoading(false);
    }
  }

  /// Create invoice
  Future<BrainrotInvoice?> createInvoice({
    int? amountSats,
    String? description,
    int expirySecs = 3600,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _ldkService.createInvoice(
        amountSats: amountSats,
        description: description,
        expirySecs: expirySecs,
      );

      if (result.isSuccess) {
        _lastInvoice = result.valueOrNull;
        notifyListeners();

        logger.i('Invoice created! ⚡');

        // Play sound
        await services.soundService.tap();
        await services.hapticService.light();

        return _lastInvoice;
      } else {
        _setError(result.errorOrNull!.toMemeMessage());
        return null;
      }
    } catch (e) {
      _setError('Failed to create invoice: $e');
      logger.e('Invoice creation failed', error: e);
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Pay invoice
  Future<String?> payInvoice({
    required String bolt11,
    int? amountSats,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _ldkService.payInvoice(
        bolt11: bolt11,
        amountSats: amountSats,
      );

      if (result.isSuccess) {
        logger.i('Payment sent! Hash: ${result.valueOrNull}');

        // Play sound
        await services.soundService.sendTransaction();
        await services.hapticService.transaction();

        return result.valueOrNull;
      } else {
        _setError(result.errorOrNull!.toMemeMessage());
        return null;
      }
    } catch (e) {
      _setError('Failed to pay invoice: $e');
      logger.e('Payment failed', error: e);
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Send to Lightning address
  Future<String?> sendToLightningAddress({
    required String address,
    required int amountSats,
    String? comment,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _ldkService.sendToLightningAddress(
        address: address,
        amountSats: amountSats,
        comment: comment,
      );

      if (result.isSuccess) {
        logger.i('Sent to Lightning address! ⚡');

        // Play sound
        await services.soundService.sendTransaction();
        await services.hapticService.transaction();

        return result.valueOrNull;
      } else {
        _setError(result.errorOrNull!.toMemeMessage());
        return null;
      }
    } catch (e) {
      _setError('Failed to send to Lightning address: $e');
      logger.e('Lightning address send failed', error: e);
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Delete Lightning node
  Future<void> deleteLightningNode() async {
    _setLoading(true);

    final result = await _ldkService.deleteNode();

    if (result.isSuccess) {
      // Reset state
      _isInitialized = false;
      _nodeInfo = null;
      _balance = null;
      _channels = [];
      _payments = [];
      _lastInvoice = null;

      logger.w('Lightning node deleted! ⚡💀');
    }

    _setLoading(false);
  }

  /// Force refresh balance
  Future<void> refreshBalance() async {
    if (!_isInitialized) return;

    try {
      final result = await _ldkService.getBalance();
      
      if (result.isSuccess) {
        _balance = result.valueOrNull;
        notifyListeners();
      } else {
        _setError(result.errorOrNull!.toMemeMessage());
      }
    } catch (e) {
      _setError('Failed to refresh balance: $e');
      logger.e('Balance refresh failed', error: e);
    }
  }

  /// Create Lightning backup
  Future<LightningBackup?> createBackup(String password) async {
    if (!_isInitialized) {
      _setError('Node not initialized');
      return null;
    }

    _setLoading(true);
    _clearError();

    try {
      final result = await _ldkService.createBackup(password: password);

      if (result.isSuccess) {
        logger.i('Lightning backup created! 💾');
        
        // Play success sound
        await services.soundService.success();
        await services.hapticService.success();

        return result.valueOrNull;
      } else {
        _setError(result.errorOrNull!.toMemeMessage());
        return null;
      }
    } catch (e) {
      _setError('Failed to create backup: $e');
      logger.e('Backup creation failed', error: e);
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Restore from Lightning backup
  Future<void> restoreFromBackup({
    required LightningBackup backup,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _ldkService.restoreFromBackup(
        backup: backup,
        password: password,
      );

      if (result.isSuccess) {
        _isInitialized = true;
        
        // Update node info
        await updateNodeInfo();
        
        logger.i('Lightning backup restored! ⚡');
        
        // Play success sound
        await services.soundService.success();
        await services.hapticService.success();
      } else {
        _setError(result.errorOrNull!.toMemeMessage());
      }
    } catch (e) {
      _setError('Failed to restore backup: $e');
      logger.e('Backup restoration failed', error: e);
    } finally {
      _setLoading(false);
    }
  }

  /// Export data directory
  Future<Uint8List?> exportDataDirectory() async {
    if (!_isInitialized) {
      _setError('Node not initialized');
      return null;
    }

    _setLoading(true);
    _clearError();

    try {
      final result = await _ldkService.exportDataDirectory();

      if (result.isSuccess) {
        logger.i('Data directory exported! 📦');
        
        // Play success sound
        await services.soundService.tap();
        await services.hapticService.light();

        return result.valueOrNull;
      } else {
        _setError(result.errorOrNull!.toMemeMessage());
        return null;
      }
    } catch (e) {
      _setError('Failed to export data: $e');
      logger.e('Data export failed', error: e);
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Import data directory
  Future<void> importDataDirectory({
    required Uint8List archiveData,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _ldkService.importDataDirectory(
        archiveData: archiveData,
        password: password,
      );

      if (result.isSuccess) {
        logger.i('Data directory imported! 📂');
        
        // Play success sound
        await services.soundService.success();
        await services.hapticService.success();
      } else {
        _setError(result.errorOrNull!.toMemeMessage());
      }
    } catch (e) {
      _setError('Failed to import data: $e');
      logger.e('Data import failed', error: e);
    } finally {
      _setLoading(false);
    }
  }

  /// List available backups
  Future<List<String>> listBackups() async {
    try {
      final result = await _ldkService.listBackups();
      
      if (result.isSuccess) {
        return result.valueOrNull ?? [];
      } else {
        _setError(result.errorOrNull!.toMemeMessage());
        return [];
      }
    } catch (e) {
      _setError('Failed to list backups: $e');
      logger.e('Backup listing failed', error: e);
      return [];
    }
  }

  /// Delete specific backup
  Future<void> deleteBackup(String backupKey) async {
    try {
      final result = await _ldkService.deleteBackup(backupKey);
      
      if (result.isSuccess) {
        logger.i('Backup deleted: $backupKey');
        
        // Play tap sound
        await services.soundService.tap();
        await services.hapticService.light();
      } else {
        _setError(result.errorOrNull!.toMemeMessage());
      }
    } catch (e) {
      _setError('Failed to delete backup: $e');
      logger.e('Backup deletion failed', error: e);
    }
  }

  /// Get node health status
  bool get isHealthy => _ldkService.isHealthy;

  /// Get error recovery metrics
  Map<String, dynamic> get errorMetrics => _ldkService.getErrorMetrics();

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
    _ldkService.dispose();
    super.dispose();
  }
}

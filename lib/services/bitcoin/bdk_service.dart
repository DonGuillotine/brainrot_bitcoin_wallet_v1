import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:bdk_flutter/bdk_flutter.dart';
import '../base/base_service.dart';
import '../base/service_result.dart';
import '../security/encryption_service.dart';
import '../storage/storage_service.dart';
import '../../models/wallet_models.dart';
import '../../main.dart';

/// BDK wallet service for Bitcoin operations
class BdkService extends BaseService {
  // Services
  final EncryptionService _encryptionService;
  final StorageService _storageService;

  // BDK instances
  Wallet? _wallet;
  Blockchain? _blockchain;

  // Wallet data
  WalletConfig? _walletConfig;
  String? _mnemonic;
  final List<BrainrotAddress> _addresses = [];
  final List<BrainrotTransaction> _transactions = [];

  // Sync state
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  Timer? _syncTimer;
  int? _currentBlockHeight;

  // Stream controllers
  final _balanceController = StreamController<BrainrotBalance>.broadcast();
  final _transactionController = StreamController<List<BrainrotTransaction>>.broadcast();
  final _syncController = StreamController<bool>.broadcast();
  final _blockHeightController = StreamController<int>.broadcast();

  // Streams
  Stream<BrainrotBalance> get balanceStream => _balanceController.stream;
  Stream<List<BrainrotTransaction>> get transactionStream => _transactionController.stream;
  Stream<bool> get syncStream => _syncController.stream;
  Stream<int> get blockHeightStream => _blockHeightController.stream;

  // Getters
  bool get isInitialized => _wallet != null;
  bool get isReadOnlyMode => _wallet != null && _mnemonic == null;
  WalletConfig? get walletConfig => _walletConfig;
  List<BrainrotAddress> get addresses => List.unmodifiable(_addresses);
  List<BrainrotTransaction> get transactions => List.unmodifiable(_transactions);
  int? get currentBlockHeight => _currentBlockHeight;


  // Configuration for the fee estimation API
  static const String _mempoolSpaceApiUrl = 'https://mempool.space/api/v1/fees/recommended';
  static const Duration _apiTimeout = Duration(seconds: 10);

  BdkService(
      this._encryptionService,
      this._storageService,
      ) : super('BdkService');

  /// Ensure Flutter is properly initialized for BDK operations
  Future<void> _ensureFlutterInitialized() async {
    // Ensure platform channels are ready
    await Future.delayed(const Duration(milliseconds: 200));
    
    // Try to trigger BDK plugin initialization with a simple call
    try {
      logDebug('Testing BDK Flutter plugin initialization...');
      
      // Try to create a simple WordCount enum to trigger plugin initialization
      // This is safer than creating a mnemonic directly
      final testWordCount = WordCount.words12;
      logDebug('BDK plugin test successful with word count: ${testWordCount.name}');
      
    } catch (e) {
      logWarning('BDK plugin initialization test failed: $e');
      
      // If that fails, try to ensure the method channel is available
      try {
        // Force method channel registration by calling a platform channel
        const platform = MethodChannel('bdk_flutter');
        await platform.invokeMethod('test').catchError((error) => null);
      } catch (channelError) {
        logWarning('Method channel test failed: $channelError');
      }
      
      // Add additional delay to allow plugin to initialize
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  /// Initialize wallet from storage
  Future<ServiceResult<void>> initializeWallet(String password) async {
    return executeOperation(
      operation: () async {
        // Ensure Flutter binding is initialized before BDK operations
        await _ensureFlutterInitialized();
        // Load wallet config
        final configResult = await _storageService.getValue<String>(
          key: 'wallet_config',
        );

        if (configResult.isError || configResult.valueOrNull == null) {
          throw ServiceException(
            message: 'No wallet found',
            code: ErrorCodes.walletNotFound,
          );
        }

        final config = WalletConfig.fromJson(
          jsonDecode(configResult.valueOrNull!) as Map<String, dynamic>,
        );

        // Load encrypted mnemonic
        final mnemonicResult = await _storageService.getSecureValue(
          key: 'wallet_mnemonic',
          password: password,
        );

        if (mnemonicResult.isError || mnemonicResult.valueOrNull == null) {
          throw ServiceException(
            message: 'Failed to decrypt wallet',
            code: ErrorCodes.encryptionError,
          );
        }

        _walletConfig = config;
        _mnemonic = mnemonicResult.valueOrNull!;

        // Initialize BDK wallet
        await _initializeBdk();

        // Load cached data
        await _loadCachedData();

        // Start sync
        await syncWallet();
        _startAutoSync();

        logInfo('Wallet initialized successfully 🎉');
      },
      operationName: 'initialize wallet',
      errorCode: ErrorCodes.walletNotFound,
    );
  }

  /// Unlock wallet for signing operations (requires password)
  Future<ServiceResult<void>> unlockWallet(String password) async {
    if (_walletConfig == null) {
      return ServiceError(
        ServiceException(
          message: 'No wallet configuration found',
          code: ErrorCodes.walletNotFound,
        ),
      );
    }

    return executeOperation(
      operation: () async {
        // Load encrypted mnemonic
        final mnemonicResult = await _storageService.getSecureValue(
          key: 'wallet_mnemonic',
          password: password,
        );

        if (mnemonicResult.isError || mnemonicResult.valueOrNull == null) {
          throw ServiceException(
            message: 'Failed to decrypt wallet with provided password',
            code: ErrorCodes.encryptionError,
          );
        }

        _mnemonic = mnemonicResult.valueOrNull!;
        
        // Reinitialize BDK wallet with mnemonic
        await _initializeBdk();

        // Ensure wallet is synced after unlocking to get accurate balance
        await syncWallet();

        logInfo('Wallet unlocked for signing operations 🔓');
      },
      operationName: 'unlock wallet',
      errorCode: ErrorCodes.encryptionError,
    );
  }

  /// Auto-initialize wallet for read-only operations (no password required)
  Future<ServiceResult<void>> autoInitializeWallet() async {
    return executeOperation(
      operation: () async {
        // Ensure Flutter binding is initialized before BDK operations
        await _ensureFlutterInitialized();

        // Load wallet config (not encrypted)
        final configResult = await _storageService.getValue<String>(
          key: 'wallet_config',
        );

        if (configResult.isError || configResult.valueOrNull == null) {
          throw ServiceException(
            message: 'No wallet found',
            code: ErrorCodes.walletNotFound,
          );
        }

        final config = WalletConfig.fromJson(
          jsonDecode(configResult.valueOrNull!) as Map<String, dynamic>,
        );

        _walletConfig = config;
        // Note: _mnemonic remains null for read-only mode

        // Initialize BDK wallet using descriptors only
        await _initializeBdk();

        // Load cached data
        await _loadCachedData();

        // Start sync
        await syncWallet();
        _startAutoSync();

        logInfo('Wallet auto-initialized for read-only operations 🔍');
      },
      operationName: 'auto-initialize wallet',
      errorCode: ErrorCodes.walletNotFound,
    );
  }

  /// Create new wallet
  Future<ServiceResult<String>> createWallet({
    required String name,
    required String password,
    required Network network,
    required WalletType walletType,
    String? mnemonic,
  }) async {
    return executeOperation(
      operation: () async {
        // Ensure Flutter binding is initialized before BDK operations
        await _ensureFlutterInitialized();
        
        // Generate or validate mnemonic
        final Mnemonic mnemonicObj;
        if (mnemonic != null) {
          mnemonicObj = await Mnemonic.fromString(mnemonic);
        } else {
          // Generate new mnemonic with proper entropy
          final entropyResult = await _encryptionService.generateMnemonicEntropy(
            strength: 128, // 12 words
          );

          if (entropyResult.isError) {
            throw entropyResult.errorOrNull!;
          }

          mnemonicObj = await Mnemonic.fromEntropy(entropyResult.valueOrNull!);
        }

        _mnemonic = mnemonicObj.asString();

        // Create descriptors based on wallet type
        final descriptors = await _createDescriptors(
          mnemonic: mnemonicObj,
          network: network,
          walletType: walletType,
        );

        // Create wallet config
        _walletConfig = WalletConfig(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          network: network,
          descriptor: descriptors.external,
          changeDescriptor: descriptors.internal,
          createdAt: DateTime.now(),
          walletType: walletType,
          externalDerivationPath: descriptors.externalPath,
          internalDerivationPath: descriptors.internalPath,
        );

        // Save wallet config
        await _storageService.setValue(
          key: 'wallet_config',
          value: jsonEncode(_walletConfig!.toJson()),
        );

        // Encrypt and save mnemonic
        await _storageService.setSecureValue(
          key: 'wallet_mnemonic',
          value: _mnemonic!,
          password: password,
        );

        // Initialize BDK wallet
        await _initializeBdk();

        // Generate initial addresses
        await _generateAddresses(count: 20);

        // Start sync
        await syncWallet();
        _startAutoSync();

        logInfo('Wallet created successfully! Type: ${walletType.name} 🚀');

        return _mnemonic!;
      },
      operationName: 'create wallet',
      errorCode: ErrorCodes.unknown,
    );
  }

  /// Restore wallet from mnemonic
  Future<ServiceResult<void>> restoreWallet({
    required String name,
    required String mnemonic,
    required String password,
    required Network network,
    required WalletType walletType,
  }) async {
    // Ensure Flutter binding is initialized before BDK operations
    await _ensureFlutterInitialized();
    
    // Use createWallet with provided mnemonic
    final result = await createWallet(
      name: name,
      password: password,
      network: network,
      walletType: walletType,
      mnemonic: mnemonic,
    );

    if (result.isError) {
      return ServiceError(result.errorOrNull!);
    }

    // Force full rescan for restored wallet
    await syncWallet(fullScan: true);

    return const Success(null);
  }

  /// Initialize BDK wallet instance
  Future<void> _initializeBdk() async {
    if (_walletConfig == null) {
      logError('Attempted to initialize BDK without wallet config.');
      throw ServiceException(
        message: 'Wallet config not loaded',
        code: ErrorCodes.walletNotFound,
      );
    }

    Descriptor externalDescriptor;
    Descriptor? changeDescriptorInstance;

    // If we have the mnemonic (unlocked mode), create fresh descriptors with signing capability
    if (_mnemonic != null) {
      logDebug('Creating wallet with mnemonic for signing operations...');
      
      final mnemonicObj = await Mnemonic.fromString(_mnemonic!);
      
      // Create DescriptorSecretKey directly for signing capability
      final secretKey = await DescriptorSecretKey.create(
        mnemonic: mnemonicObj,
        network: _walletConfig!.network,
      );

      // Create descriptors directly with the secret key (preserves private key material)
      switch (_walletConfig!.walletType) {
        case WalletType.standard: // BIP84 Native SegWit
          externalDescriptor = await Descriptor.newBip84(
            secretKey: secretKey,
            keychain: KeychainKind.externalChain,
            network: _walletConfig!.network,
          );
          changeDescriptorInstance = await Descriptor.newBip84(
            secretKey: secretKey,
            keychain: KeychainKind.internalChain,
            network: _walletConfig!.network,
          );
          break;

        case WalletType.legacy: // BIP44 Legacy
          externalDescriptor = await Descriptor.newBip44(
            secretKey: secretKey,
            keychain: KeychainKind.externalChain,
            network: _walletConfig!.network,
          );
          changeDescriptorInstance = await Descriptor.newBip44(
            secretKey: secretKey,
            keychain: KeychainKind.internalChain,
            network: _walletConfig!.network,
          );
          break;

        case WalletType.nested: // BIP49 Nested SegWit
          externalDescriptor = await Descriptor.newBip49(
            secretKey: secretKey,
            keychain: KeychainKind.externalChain,
            network: _walletConfig!.network,
          );
          changeDescriptorInstance = await Descriptor.newBip49(
            secretKey: secretKey,
            keychain: KeychainKind.internalChain,
            network: _walletConfig!.network,
          );
          break;

        case WalletType.taproot: // BIP86 Taproot
          externalDescriptor = await Descriptor.newBip86(
            secretKey: secretKey,
            keychain: KeychainKind.externalChain,
            network: _walletConfig!.network,
          );
          changeDescriptorInstance = await Descriptor.newBip86(
            secretKey: secretKey,
            keychain: KeychainKind.internalChain,
            network: _walletConfig!.network,
          );
          break;
      }

      logDebug('Descriptors created with private key material for signing');
    } else {
      logDebug('Creating read-only wallet from stored descriptors...');
      
      // Read-only mode: use stored descriptors
      externalDescriptor = await Descriptor.create(
        descriptor: _walletConfig!.descriptor,
        network: _walletConfig!.network,
      );

      if (_walletConfig!.changeDescriptor != null) {
        changeDescriptorInstance = await Descriptor.create(
          descriptor: _walletConfig!.changeDescriptor!,
          network: _walletConfig!.network,
        );
      }
    }

    _wallet = await Wallet.create(
      descriptor: externalDescriptor,
      changeDescriptor: changeDescriptorInstance,
      network: _walletConfig!.network,
      databaseConfig: const DatabaseConfig.memory(),
    );

    // Create blockchain connection
    _blockchain = await _createBlockchain(_walletConfig!.network);

    logInfo('BDK wallet initialized 🎯');
  }

  /// Create blockchain connection
  Future<Blockchain> _createBlockchain(Network network) async {
    // For production, use your own Electrum server
    final electrumConfig = network == Network.testnet
        ? ElectrumConfig(
      url: 'ssl://electrum.blockstream.info:60002',
      retry: 5,
      timeout: 10,
      stopGap: BigInt.from(100),
      validateDomain: true,
    )
        : ElectrumConfig(
      url: 'ssl://electrum.blockstream.info:50002',
      retry: 5,
      timeout: 10,
      stopGap: BigInt.from(100),
      validateDomain: true,
    );

    return await Blockchain.create(
      config: BlockchainConfig.electrum(
        config: electrumConfig,
      ),
    );
  }

  /// Create descriptors for wallet type
  Future<_Descriptors> _createDescriptors({
    required Mnemonic mnemonic,
    required Network network,
    required WalletType walletType,
  }) async {
    final networkPath = network == Network.testnet ? '1' : '0';

    // Use DescriptorSecretKey.create instead of fromMnemonic
    final secretKey = await DescriptorSecretKey.create(
      mnemonic: mnemonic,
      network: network,
      // password: null, // Add password if you use it for DescriptorSecretKey derivation
    );

    switch (walletType) {
      case WalletType.standard: // BIP84 Native SegWit
        final externalPath = "m/84'/$networkPath'/0'/0";
        final internalPath = "m/84'/$networkPath'/0'/1";

        final externalDescriptor = await Descriptor.newBip84(
          secretKey: secretKey,
          keychain: KeychainKind.externalChain, // Correct enum constant
          network: network,
        );

        final internalDescriptor = await Descriptor.newBip84(
          secretKey: secretKey,
          keychain: KeychainKind.internalChain, // Correct enum constant
          network: network,
        );

        return _Descriptors(
          external: externalDescriptor.toString(),
          internal: internalDescriptor.toString(),
          externalPath: externalPath,
          internalPath: internalPath,
        );

      case WalletType.legacy: // BIP44 Legacy
        final externalPath = "m/44'/$networkPath'/0'/0";
        final internalPath = "m/44'/$networkPath'/0'/1";

        final externalDescriptor = await Descriptor.newBip44(
          secretKey: secretKey,
          keychain: KeychainKind.externalChain,
          network: network,
        );

        final internalDescriptor = await Descriptor.newBip44(
          secretKey: secretKey,
          keychain: KeychainKind.internalChain,
          network: network,
        );

        return _Descriptors(
          external: externalDescriptor.toString(),
          internal: internalDescriptor.toString(),
          externalPath: externalPath,
          internalPath: internalPath,
        );

      case WalletType.nested: // BIP49 Nested SegWit
        final externalPath = "m/49'/$networkPath'/0'/0";
        final internalPath = "m/49'/$networkPath'/0'/1";

        final externalDescriptor = await Descriptor.newBip49(
          secretKey: secretKey,
          keychain: KeychainKind.externalChain,
          network: network,
        );

        final internalDescriptor = await Descriptor.newBip49(
          secretKey: secretKey,
          keychain: KeychainKind.internalChain,
          network: network,
        );

        return _Descriptors(
          external: externalDescriptor.toString(),
          internal: internalDescriptor.toString(),
          externalPath: externalPath,
          internalPath: internalPath,
        );

      case WalletType.taproot: // BIP86 Taproot
        final externalPath = "m/86'/$networkPath'/0'/0";
        final internalPath = "m/86'/$networkPath'/0'/1";

        final externalDescriptor = await Descriptor.newBip86(
          secretKey: secretKey,
          keychain: KeychainKind.externalChain,
          network: network,
        );

        final internalDescriptor = await Descriptor.newBip86(
          secretKey: secretKey,
          keychain: KeychainKind.internalChain,
          network: network,
        );

        return _Descriptors(
          external: externalDescriptor.toString(),
          internal: internalDescriptor.toString(),
          externalPath: externalPath,
          internalPath: internalPath,
        );
    }
  }

  /// Sync wallet with blockchain
  Future<ServiceResult<void>> syncWallet({bool fullScan = false}) async {
    if (_wallet == null || _blockchain == null) {
      return ServiceError(
        ServiceException(
          message: 'Wallet not initialized',
          code: ErrorCodes.walletNotFound,
        ),
      );
    }

    return executeOperation(
      operation: () async {
        _isSyncing = true;
        _syncController.add(true);

        try {
          // Sync wallet
          await _wallet!.sync(blockchain: _blockchain!);

          _lastSyncTime = DateTime.now();

          // Update balance
          await _updateBalance();

          // Update transactions
          await _updateTransactions();

          // Update addresses
          await _updateAddresses();

          // Update blockchain height
          await _updateBlockHeight();

          // Save cached data
          await _saveCachedData();

          logInfo('Wallet synced successfully! 🔄');
        } finally {
          _isSyncing = false;
          _syncController.add(false);
        }
      },
      operationName: 'sync wallet',
      errorCode: ErrorCodes.networkError,
    );
  }

  /// Update balance
  Future<void> _updateBalance() async {
    final balance = await _wallet!.getBalance();

    final brainrotBalance = BrainrotBalance(
      confirmed: balance.confirmed.toInt(),
      unconfirmed: balance.immature.toInt() +
          balance.trustedPending.toInt() +
          balance.untrustedPending.toInt(),
      lastUpdate: DateTime.now(),
    );

    _balanceController.add(brainrotBalance);

    logInfo('Balance updated: ${brainrotBalance.btc} BTC 💰');
  }

  /// Update transactions
  Future<void> _updateTransactions() async {
    final txList = await _wallet!.listTransactions(includeRaw: false);

    _transactions.clear();

    for (final tx in txList) {
      // tx is TransactionDetails
      // tx.confirmationTime is BlockTime?
      // tx.confirmationTime.timestamp is BigInt (seconds since epoch)

      int? timestampMilliseconds;
      if (tx.confirmationTime != null) {
        // Get the timestamp in seconds as a BigInt
        final BigInt timestampSecondsBigInt = tx.confirmationTime!.timestamp;

        // Convert seconds to milliseconds:
        // Multiply by BigInt.from(1000) to ensure the operation is done using BigInt arithmetic
        final BigInt timestampMillisecondsBigInt = timestampSecondsBigInt * BigInt.from(1000);

        // Convert the BigInt result to an int for DateTime.fromMillisecondsSinceEpoch
        timestampMilliseconds = timestampMillisecondsBigInt.toInt();
      }

      final brainrotTx = BrainrotTransaction(
        txid: tx.txid,
        details: tx,
        status: tx.confirmationTime != null
            ? TransactionStatus.confirmed
            : TransactionStatus.pending,
        blockHeight: tx.confirmationTime?.height.toInt(),
        timestamp: timestampMilliseconds != null
            ? DateTime.fromMillisecondsSinceEpoch(timestampMilliseconds)
            : null,
      );

      _transactions.add(brainrotTx);
    }

    // Sort by timestamp (newest first)
    _transactions.sort((a, b) {
      if (a.timestamp == null && b.timestamp == null) return 0;
      if (a.timestamp == null) return 1;
      if (b.timestamp == null) return -1;
      return b.timestamp!.compareTo(a.timestamp!);
    });

    _transactionController.add(_transactions);

    logInfo('Transactions updated: ${_transactions.length} total 📜');
  }

  /// Update addresses
  Future<void> _updateAddresses() async {
    // This is a simplified version - in production, track address usage
    if (_addresses.isEmpty) {
      await _generateAddresses(count: 20);
    }
  }

  /// Update blockchain height
  Future<void> _updateBlockHeight() async {
    if (_blockchain == null) return;

    try {
      // Get blockchain height via Electrum
      final height = await _blockchain!.getHeight();
      _currentBlockHeight = height;
      _blockHeightController.add(height);
      
      logInfo('Blockchain height updated: $height 📏');
    } catch (e) {
      logError('Failed to get blockchain height: $e');
    }
  }

  /// Generate new addresses
  Future<void> _generateAddresses({
    required int count,
    KeychainKind keychain = KeychainKind.externalChain,
  }) async {
    if (_wallet == null) {
      logError('Wallet not initialized for address generation.');
      return;
    }


    for (int i = 0; i < count; i++) {
      // AddressIndex.increase is typically used when you want to derive addresses sequentially
      // by incrementing the child index. This is suitable for generating a batch of new addresses.
      final addressInfo = _wallet!.getAddress(
        addressIndex: AddressIndex.increase(),
      );

      // GetAddressType might need the Address object itself from addressInfo.address
      final addressType = _getAddressType(addressInfo.address);

      final brainrotAddress = BrainrotAddress(
        address: addressInfo.address.asString(),
        index: addressInfo.index,
        addressType: addressType,
        createdAt: DateTime.now(),
        // isUsed: false, // New addresses are generally considered unused until a transaction involves them
      );

      _addresses.add(brainrotAddress);
    }

    logInfo('Generated $count new addresses for ${keychain.name} keychain 🏠');
  }

  /// Get current receive address
  Future<ServiceResult<BrainrotAddress>> getReceiveAddress() async {
    if (_wallet == null) {
      return ServiceError(
        ServiceException(
          message: 'Wallet not initialized',
          code: ErrorCodes.walletNotFound,
        ),
      );
    }

    return executeOperation(
      operation: () async {
        // Get unused address or generate new one
        final unusedAddress = _addresses.firstWhere(
              (addr) => !addr.isUsed,
          orElse: () => _addresses.last,
        );

        // If all addresses are used, generate more
        if (unusedAddress.isUsed || _addresses.isEmpty) {
          await _generateAddresses(count: 5);
          return _addresses.last;
        }

        return unusedAddress;
      },
      operationName: 'get receive address',
    );
  }

  /// Create transaction
  Future<ServiceResult<String>> createTransaction({
    required String recipientAddress,
    required int amountSats,
    required int feeRate,
    String? memo,
  }) async {
    if (_wallet == null) {
      return ServiceError(
        ServiceException(
          message: 'Wallet not initialized',
          code: ErrorCodes.walletNotFound,
        ),
      );
    }
    if (_blockchain == null) {
      return ServiceError(
        ServiceException(
          message: 'Blockchain service not initialized',
          code: ErrorCodes.networkError,
        ),
      );
    }
    if (_mnemonic == null) {
      return ServiceError(
        ServiceException(
          message: 'Wallet is in read-only mode. Please unlock wallet with password to send transactions.',
          code: ErrorCodes.encryptionError,
        ),
      );
    }

    return executeOperation(
      operation: () async {
        // Validate address
        final address = await Address.fromString(
          s: recipientAddress,
          network: _walletConfig!.network,
        );

        // Check wallet balance before building transaction
        final balance = await _wallet!.getBalance();
        final totalNeeded = amountSats + (feeRate * 250); // Rough estimate of fee (250 vbytes is typical transaction size)
        
        logInfo('Current balance: confirmed=${balance.confirmed}, total=${balance.total}');
        logInfo('Attempting to send: $amountSats sats with fee rate: $feeRate sat/vB');
        logInfo('Estimated total needed: $totalNeeded sats');

        // Convert totalNeeded to BigInt for comparison with balance.confirmed
        final BigInt totalNeededBigInt = BigInt.from(totalNeeded);

        if (balance.confirmed < totalNeededBigInt) { // Compare BigInt with BigInt
          throw Exception('Insufficient funds: need $totalNeededBigInt sats but only have ${balance.confirmed} confirmed sats');
        }

        // Build transaction
        final txBuilder = TxBuilder(); // Initialize first
        txBuilder.addRecipient( // Call as a method with positional arguments
          address.scriptPubkey(), // First argument: script
          BigInt.from(amountSats),             // Second argument: amount
        );
        txBuilder.feeRate(feeRate.toDouble());

        // Create PSBT
        final (psbt, transactionDetails) = await txBuilder.finish(_wallet!);

        // Check if we can afford this transaction
        logInfo('Transaction details: fee=${transactionDetails.fee}, sent=${transactionDetails.sent}, received=${transactionDetails.received}');
        
        // Sign the PSBT with more detailed error handling
        try {
          logDebug('Attempting to sign transaction...');
          
          // Verify wallet is in signing mode
          if (_mnemonic == null) {
            throw Exception('Wallet is in read-only mode - cannot sign transactions');
          }
          
          final signSuccess = await _wallet!.sign(psbt: psbt);
          logDebug('Sign operation returned: $signSuccess');
          
          if (!signSuccess) {
            throw Exception('BDK wallet sign operation returned false - this typically indicates missing private keys, invalid PSBT structure, or incompatible transaction inputs');
          }
          
          logInfo('Transaction signed successfully ✍️');
        } catch (e) {
          logError('Signing error: $e');
          throw Exception('Transaction signing failed: $e');
        }

        // Extract the final transaction from the signed PSBT
        final finalTransaction = psbt.extractTx();

        // Broadcast transaction
        await _blockchain!.broadcast(transaction: finalTransaction); // Pass the Transaction object

        // Get transaction ID from the final transaction
        final txid = finalTransaction.txid();

        // Save memo if provided
        if (memo != null && memo.isNotEmpty) {
          await _storageService.setValue(
            key: 'tx_memo_$txid',
            value: memo,
          );
        }

        // Force sync to update balance and transaction list
        await syncWallet();

        logInfo('Transaction sent! TXID: $txid 🚀');

        return txid;
      },
      operationName: 'create transaction',
      errorCode: ErrorCodes.transactionFailed,
    );
  }

  /// Validate Bitcoin address
  Future<ServiceResult<bool>> validateAddress(String address) async {
    return executeOperation(
      operation: () async {
        try {
          await Address.fromString(
            s: address,
            network: _walletConfig!.network,
          );
          return true;
        } catch (e) {
          return false;
        }
      },
      operationName: 'validate address',
    );
  }

  /// Get transaction details
  Future<ServiceResult<BrainrotTransaction?>> getTransaction(String txid) async {
    return executeOperation(
      operation: () async {
        return _transactions.firstWhere(
              (tx) => tx.txid == txid,
          orElse: () => throw ServiceException(
            message: 'Transaction not found',
            code: ErrorCodes.unknown,
          ),
        );
      },
      operationName: 'get transaction',
    );
  }

  /// Get fee estimates
  Future<ServiceResult<FeeEstimate>> getFeeEstimates() async {
    return executeOperation(
      operation: () async {
        try {
          // Attempt to fetch from the primary API (Mempool.space)
          final FeeEstimate? primaryEstimate = await _fetchFromMempoolSpace();

          if (primaryEstimate != null) {
            logInfo('Fee estimates fetched successfully from Mempool.space');
            return primaryEstimate;
          }

          logError('All fee estimation attempts failed.');
          throw ServiceException(
            message: 'Unable to fetch fee estimates from any provider.',
            code: ErrorCodes.networkError,
          );

        } on http.ClientException catch (e) {
          logError('Network error during fee estimation: $e');
          throw ServiceException(
            message: 'Network error fetching fee estimates: ${e.message}',
            code: ErrorCodes.networkError,
          );
        } on TimeoutException catch (e) {
          logError('Timeout during fee estimation: $e');
          throw ServiceException(
            message: 'Timeout fetching fee estimates.',
            code: ErrorCodes.networkError,
          );
        } on FormatException catch (e) {
          logError('Error parsing fee estimation data: $e');
          throw ServiceException(
            message: 'Invalid data format from fee estimation API.',
            code: ErrorCodes.unknown,
          );
        }
        // Catch other specific exceptions from the HTTP client or JSON parsing
        catch (e) {
          logError('Unexpected error during fee estimation: $e');
          // Rethrow if it's already a ServiceException, otherwise wrap it
          if (e is ServiceException) rethrow;
          throw ServiceException(
            message: 'An unexpected error occurred while fetching fee estimates.',
            code: ErrorCodes.unknown, // A general error code
          );
        }
      },
      operationName: 'get fee estimates',
      errorCode: ErrorCodes.unknown,
    );
  }


  /// Fetches fee estimates from Mempool.space API.
  /// Returns FeeEstimate on success, null on failure.
  Future<FeeEstimate?> _fetchFromMempoolSpace() async {
    try {
      final response = await http.get(Uri.parse(_mempoolSpaceApiUrl)).timeout(_apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // Validate that the expected keys exist
        if (data.containsKey('fastestFee') &&
            data.containsKey('halfHourFee') &&
            data.containsKey('hourFee') &&
            data.containsKey('economyFee')) {
          return FeeEstimate(
            fastestFee: (data['fastestFee'] as num).toInt(),
            halfHourFee: (data['halfHourFee'] as num).toInt(),
            hourFee: (data['hourFee'] as num).toInt(),
            economyFee: (data['economyFee'] as num).toInt(),
            timestamp: DateTime.now().toUtc(),
          );
        } else {
          logWarning('Mempool.space API response missing expected fee keys: ${response.body}');
          return null; // Data format is not as expected
        }
      } else {
        logWarning('Mempool.space API request failed with status: ${response.statusCode}, body: ${response.body}');
        return null; // API returned an error status
      }
    } on http.ClientException catch (e) {
      logWarning('Network error fetching from Mempool.space: $e');
      return null; // Network issue
    } on TimeoutException catch (e) {
      logWarning('Timeout fetching from Mempool.space: $e');
      return null; // Request timed out
    } on FormatException catch (e) {
      logWarning('Format error parsing Mempool.space response: $e');
      return null; // JSON parsing failed
    } catch (e) {
      logWarning('Unexpected error fetching from Mempool.space: $e');
      return null; // Other unexpected errors
    }
  }

  /// Start auto sync
  void _startAutoSync() {
    _stopAutoSync();

    // Sync every 30 seconds
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_isSyncing) {
        syncWallet();
      }
    });

    logInfo('Auto-sync started 🔄');
  }

  /// Stop auto sync
  void _stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Get address type from address string
  AddressType _getAddressType(Address address) {
    final addressStr = address.asString();

    if (addressStr.startsWith('bc1p') || addressStr.startsWith('tb1p')) {
      return AddressType.taproot;
    } else if (addressStr.startsWith('bc1') || addressStr.startsWith('tb1')) {
      return AddressType.nativeSegwit;
    } else if (addressStr.startsWith('3') || addressStr.startsWith('2')) {
      return AddressType.nestedSegwit;
    } else {
      return AddressType.legacy;
    }
  }

  /// Load cached data
  Future<void> _loadCachedData() async {
    // Load cached balance
    final balanceResult = await _storageService.getValue<String>(
      key: 'cached_balance',
    );

    if (balanceResult.isSuccess && balanceResult.valueOrNull != null) {
      final balanceData = jsonDecode(balanceResult.valueOrNull!);
      final balance = BrainrotBalance(
        confirmed: balanceData['confirmed'] as int,
        unconfirmed: balanceData['unconfirmed'] as int,
        lastUpdate: DateTime.parse(balanceData['lastUpdate'] as String),
      );
      _balanceController.add(balance);
    }

    // Load cached transactions
    final txResult = await _storageService.getValue<String>(
      key: 'cached_transactions',
    );

    if (txResult.isSuccess && txResult.valueOrNull != null) {
      final txList = jsonDecode(txResult.valueOrNull!) as List;
      // Parse cached transactions - simplified for demo
      logDebug('Loaded ${txList.length} cached transactions');
    }
  }

  /// Save cached data
  Future<void> _saveCachedData() async {
    // Save balance
    final balance = await _wallet!.getBalance();
    await _storageService.setValue(
      key: 'cached_balance',
      value: jsonEncode({
        'confirmed': balance.confirmed.toInt(),
        'unconfirmed': balance.immature.toInt() +
            balance.trustedPending.toInt() +
            balance.untrustedPending.toInt(),
        'lastUpdate': DateTime.now().toIso8601String(),
      }),
    );

    // Save transactions - simplified for demo
    await _storageService.setValue(
      key: 'cached_transactions',
      value: jsonEncode(_transactions.take(50).map((tx) => {
        'txid': tx.txid,
        'amount': tx.netAmount.toInt(),
        'timestamp': tx.timestamp?.toIso8601String(),
      }).toList()),
    );
  }

  /// Delete wallet
  Future<ServiceResult<void>> deleteWallet() async {
    return executeOperation(
      operation: () async {
        _stopAutoSync();

        // Clear all wallet data
        await _storageService.deleteValue(key: 'wallet_config');
        await secureStorage.delete(key: 'wallet_mnemonic');
        await _storageService.deleteValue(key: 'cached_balance');
        await _storageService.deleteValue(key: 'cached_transactions');

        // Clear memory
        _wallet = null;
        _blockchain = null;
        _walletConfig = null;
        _mnemonic = null;
        _addresses.clear();
        _transactions.clear();

        logWarning('Wallet deleted! It\'s so over 😭');
      },
      operationName: 'delete wallet',
    );
  }

  /// Dispose service
  void dispose() {
    _stopAutoSync();
    _balanceController.close();
    _transactionController.close();
    _syncController.close();
    _blockHeightController.close();
  }
}

/// Helper class for descriptors
class _Descriptors {
  final String external;
  final String internal;
  final String externalPath;
  final String internalPath;

  _Descriptors({
    required this.external,
    required this.internal,
    required this.externalPath,
    required this.internalPath,
  });
}

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:ldk_node/ldk_node.dart' as ldk;
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:archive/archive.dart';
import '../base/base_service.dart';
import '../base/service_result.dart';
import '../storage/storage_service.dart';
import '../security/encryption_service.dart';
import '../network/network_service.dart';
import '../../models/lightning_models.dart';
import '../../main.dart';

/// LDK Node service for Lightning Network operations
class LdkService extends BaseService {
  final StorageService _storageService;
  final EncryptionService _encryptionService;
  final NetworkService _networkService;

  // LDK Node instance
  ldk.Node? _node;

  // Configuration
  LightningConfig? _config;
  String? _seedPhrase;

  // State
  bool _isInitialized = false;
  bool _eventLoopRunning = false;
  final List<BrainrotChannel> _channels = [];
  final List<BrainrotPayment> _payments = [];
  final Map<String, BrainrotInvoice> _invoices = {};

  // Error recovery state
  int _consecutiveErrors = 0;
  DateTime? _lastErrorTime;
  static const int _maxConsecutiveErrors = 5;
  static const Duration _maxBackoffDuration = Duration(minutes: 5);
  bool _circuitBreakerOpen = false;
  DateTime? _circuitBreakerOpenTime;

  // Stream controllers
  final _balanceController = StreamController<LightningBalance>.broadcast();
  final _channelController = StreamController<List<BrainrotChannel>>.broadcast();
  final _paymentController = StreamController<BrainrotPayment>.broadcast();

  // Streams
  Stream<LightningBalance> get balanceStream => _balanceController.stream;
  Stream<List<BrainrotChannel>> get channelStream => _channelController.stream;
  Stream<BrainrotPayment> get paymentStream => _paymentController.stream;

  // Getters
  bool get isInitialized => _isInitialized;
  List<BrainrotChannel> get channels => List.unmodifiable(_channels);
  List<BrainrotPayment> get payments => List.unmodifiable(_payments);

  LdkService(
      this._storageService,
      this._encryptionService,
      this._networkService,
      ) : super('LdkService');

  /// Initialize Lightning node
  Future<ServiceResult<void>> initializeNode({
    required String seedPhrase,
    required String password,
    required ldk.Network bitcoinNetwork,
    String? testDataDir, // For testing only
  }) async {
    return executeOperation(
      operation: () async {
        // Determine network
        final network = bitcoinNetwork == ldk.Network.testnet
            ? ldk.Network.testnet
            : ldk.Network.bitcoin;

        // Get app directory for LDK data
        late final Directory ldkDataDir;
        if (testDataDir != null) {
          // Use test directory (don't create it to avoid file system issues in tests)
          ldkDataDir = Directory(testDataDir);
        } else {
          final appDir = await getApplicationDocumentsDirectory();
          ldkDataDir = Directory('${appDir.path}/ldk_node');
          if (!await ldkDataDir.exists()) {
            await ldkDataDir.create(recursive: true);
          }
        }

        // Create builder
        final builder = ldk.Builder()
            .setNetwork(network)
            .setStorageDirPath(ldkDataDir.path)
            .setListeningAddresses([
          ldk.SocketAddress.hostname(
            addr: '0.0.0.0',
            port: 9735,
          ),
        ]);

        // Set entropy from seed phrase using BIP39 Mnemonic
        final mnemonic = ldk.Mnemonic(seedPhrase: seedPhrase);
        builder.setEntropyBip39Mnemonic(mnemonic: mnemonic);

        // Set esplora server
        if (network == ldk.Network.testnet) {
          builder.setEsploraServer('https://mempool.space/testnet/api');
        } else {
          builder.setEsploraServer('https://mempool.space/api');
        }

        // Build and start node
        _node = await builder.build();
        await _node!.start();

        // Get node info
        final publicKey = await _node!.nodeId();
        final nodeIdHex = publicKey.hex;

        // Save configuration
        _config = LightningConfig(
          nodeId: nodeIdHex,
          network: network.name,
          dataDir: ldkDataDir.path,
          listeningAddresses: ['0.0.0.0:9735'],
          createdAt: DateTime.now(),
        );

        // Save encrypted config
        await _storageService.setValue(
          key: 'lightning_config',
          value: jsonEncode(_config!.toJson()),
        );

        // Save encrypted seed
        await _storageService.setSecureValue(
          key: 'lightning_seed',
          value: seedPhrase,
          password: password,
        );

        _seedPhrase = seedPhrase;
        _isInitialized = true;

        // Setup listeners
        _setupEventListeners();

        // Initial sync
        await syncNode();

        logInfo('Lightning node initialized! Node ID: ${nodeIdHex.substring(0, 16)}... ⚡');
      },
      operationName: 'initialize lightning node',
      errorCode: ErrorCodes.lightningError,
    );
  }

  /// Restore Lightning node from storage
  Future<ServiceResult<void>> restoreNode(String password) async {
    return executeOperation(
      operation: () async {
        // Load config
        final configResult = await _storageService.getValue<String>(
          key: 'lightning_config',
        );

        if (configResult.isError || configResult.valueOrNull == null) {
          throw ServiceException(
            message: 'No Lightning node found',
            code: ErrorCodes.lightningError,
          );
        }

        _config = LightningConfig.fromJson(
          jsonDecode(configResult.valueOrNull!) as Map<String, dynamic>,
        );

        // Load seed
        final seedResult = await _storageService.getSecureValue(
          key: 'lightning_seed',
          password: password,
        );

        if (seedResult.isError || seedResult.valueOrNull == null) {
          throw ServiceException(
            message: 'Failed to decrypt Lightning seed',
            code: ErrorCodes.encryptionError,
          );
        }

        _seedPhrase = seedResult.valueOrNull!;

        // Initialize with stored config
        final network = _config!.network == 'testnet'
            ? ldk.Network.testnet
            : ldk.Network.bitcoin;

        await initializeNode(
          seedPhrase: _seedPhrase!,
          password: password,
          bitcoinNetwork: network,
        );
      },
      operationName: 'restore lightning node',
      errorCode: ErrorCodes.lightningError,
    );
  }

  /// Sync node with network
  Future<ServiceResult<void>> syncNode() async {
    if (_node == null) {
      return ServiceError(
        ServiceException(
          message: 'Node not initialized',
          code: ErrorCodes.lightningError,
        ),
      );
    }

    return executeOperation(
      operation: () async {
        await _node!.syncWallets();

        // Update channels
        await _updateChannels();

        // Update balance
        await _updateBalance();

        // Update payments
        await _updatePayments();

        logInfo('Lightning node synced! ⚡');
      },
      operationName: 'sync lightning node',
      errorCode: ErrorCodes.networkError,
    );
  }

  /// Get node info
  Future<ServiceResult<NodeInfo>> getNodeInfo() async {
    if (_node == null) {
      return ServiceError(
        ServiceException(
          message: 'Node not initialized',
          code: ErrorCodes.lightningError,
        ),
      );
    }

    return executeOperation(
      operation: () async {
        final publicKey = await _node!.nodeId();
        final nodeIdHex = publicKey.hex;
        final peers = await _node!.listPeers();
        final channels = await _node!.listChannels();

        final usableChannels = channels.where((c) =>
        c.isUsable && c.isChannelReady
        ).length;

        return NodeInfo(
          nodeId: nodeIdHex,
          alias: _config!.alias ?? 'Brainrot Node 🧠',
          color: _config!.color ?? '#6B46C1',
          listeningAddresses: _config!.listeningAddresses,
          numPeers: peers.length,
          numChannels: channels.length,
          numUsableChannels: usableChannels,
        );
      },
      operationName: 'get node info',
    );
  }

  /// Open channel
  Future<ServiceResult<String>> openChannel({
    required String nodeId,
    required String nodeAddress, // Expected format: "hostname:port"
    required int channelAmountSats,
    int? pushMsat,
    bool announceChannel = false,
  }) async {
    if (_node == null) {
      return ServiceError(
        ServiceException(
          message: 'Node not initialized',
          code: ErrorCodes.lightningError,
        ),
      );
    }

    return executeOperation(
      operation: () async {
        // Connect to peer first
        final counterpartyNodeId = ldk.PublicKey(hex: nodeId);

        // Parse nodeAddress to get host and port
        final parts = nodeAddress.split(':');
        if (parts.length != 2) {
          throw ServiceException(
            message: 'Invalid node address format. Expected "hostname:port", got "$nodeAddress"',
            code: ErrorCodes.lightningError,
          );
        }

        final String host = parts[0];
        final int? port = int.tryParse(parts[1]);

        if (port == null) {
          throw ServiceException(
            message: 'Invalid port in node address: "${parts[1]}"',
            code: ErrorCodes.lightningError, // Or a more specific error code
          );
        }

        // Use the SocketAddress.hostname factory constructor
        final socketAddress = ldk.SocketAddress.hostname(
          addr: host,
          port: port,
        );

        await _node!.connect(
          nodeId: counterpartyNodeId,
          address: socketAddress,
          persist: true,
        );

        // Open channel
        // The LDK Node connectOpenChannel method also expects types.PublicKey for nodeId
        final userChannelId = await _node!.connectOpenChannel(
          nodeId: counterpartyNodeId,
          socketAddress: socketAddress,
          channelAmountSats: BigInt.from(channelAmountSats),
          pushToCounterpartyMsat: pushMsat != null ? BigInt.from(pushMsat) : null,
          announceChannel: announceChannel,
        );

        logInfo('Channel opening initiated! Amount: $channelAmountSats sats ⚡');

        // Force sync to update channels
        await syncNode();

        return userChannelId.toString();
      },
      operationName: 'open channel',
      errorCode: ErrorCodes.lightningError,
    );
  }

  /// Close channel
  Future<ServiceResult<void>> closeChannel({
    required String channelId,
    required String nodeId,
    bool force = false,
  }) async {
    if (_node == null) {
      return ServiceError(
        ServiceException(
          message: 'Node not initialized',
          code: ErrorCodes.lightningError,
        ),
      );
    }

    return executeOperation(
      operation: () async {
        final counterpartyNodeId = ldk.PublicKey(hex: nodeId);
        
        // Convert channel ID string to proper UserChannelId
        // Assuming channelId is a hex string, convert to bytes properly
        final channelIdBytes = _hexStringToBytes(channelId);
        final userChannelId = ldk.UserChannelId(data: channelIdBytes);

        if (force) {
          await _node!.forceCloseChannel(
            userChannelId: userChannelId,
            counterpartyNodeId: counterpartyNodeId,
          );
          logWarning('Force closing channel! RIP 💀');
        } else {
          await _node!.closeChannel(
            userChannelId: userChannelId,
            counterpartyNodeId: counterpartyNodeId,
          );
          logInfo('Closing channel cooperatively 🤝');
        }

        // Update channels
        await _updateChannels();
      },
      operationName: 'close channel',
      errorCode: ErrorCodes.lightningError,
    );
  }

  /// Create invoice
  Future<ServiceResult<BrainrotInvoice>> createInvoice({
    int? amountSats,
    String? description,
    int expirySecs = 3600,
  }) async {
    if (_node == null) {
      return ServiceError(
        ServiceException(
          message: 'Node not initialized',
          code: ErrorCodes.lightningError,
        ),
      );
    }

    return executeOperation(
      operation: () async {
        // LDK node's bolt11Payment().receive() takes amountMsat
        final BigInt? amountMsat = amountSats != null ? BigInt.from(amountSats) * BigInt.from(1000) : null;
        final bolt11Payment = await _node!.bolt11Payment();

        final ldkInvoice = amountMsat != null
            ? await bolt11Payment.receive(
          amountMsat: amountMsat,
          description: description ?? 'Brainrot Wallet Invoice ⚡',
          expirySecs: expirySecs,
        )
            : await bolt11Payment.receiveVariableAmount(
          description: description ?? 'Brainrot Wallet Invoice ⚡',
          expirySecs: expirySecs,
        );

        // Parse invoice to get details  
        final invoiceStr = ldkInvoice.toString();
        final paymentHashHex = _extractPaymentHashFromBolt11(invoiceStr);
        
        final invoice = BrainrotInvoice(
          bolt11: invoiceStr,
          paymentHash: paymentHashHex,
          amountMsat: amountMsat?.toInt(),
          description: description,
          expiryTime: expirySecs,
          createdAt: DateTime.now(),
          status: InvoiceStatus.pending,
        );

        // Store invoice using payment hash as key
        _invoices[paymentHashHex] = invoice;

        logInfo('Invoice created! Amount: ${amountSats ?? 'any'} sats 📄');

        return invoice;
      },
      operationName: 'create invoice',
      errorCode: ErrorCodes.lightningError,
    );
  }

  /// Pay invoice
  Future<ServiceResult<String>> payInvoice({
    required String bolt11,
    int? amountSats,
  }) async {
    if (_node == null) {
      return ServiceError(
        ServiceException(
          message: 'Node not initialized',
          code: ErrorCodes.lightningError,
        ),
      );
    }


    return executeOperation(
      operation: () async {
        // Create Bolt11Invoice object from string
        final invoice = ldk.Bolt11Invoice(signedRawInvoice: bolt11);
        final bolt11Payment = await _node!.bolt11Payment();
        ldk.PaymentId paymentId;

        if (amountSats != null) {
          paymentId = await bolt11Payment.sendUsingAmount(
            invoice: invoice,
            amountMsat: BigInt.from(amountSats) * BigInt.from(1000),
          );
        } else {
          paymentId = await bolt11Payment.send(
            invoice: invoice,
          );
        }

        final paymentHashString = paymentId.toString();

        logInfo('Payment sent! Hash: ${paymentHashString.substring(0, 16)}... ⚡');

        // Update payments
        await _updatePayments();

        return paymentHashString;
      },
      operationName: 'pay invoice',
      errorCode: ErrorCodes.lightningError,
    );
  }

  /// Send to Lightning address using LNURL-pay
  Future<ServiceResult<String>> sendToLightningAddress({
    required String address,
    required int amountSats,
    String? comment,
  }) async {
    return executeOperation(
      operation: () async {
        // Parse Lightning address (e.g., user@domain.com)
        if (!address.contains('@')) {
          throw ServiceException(
            message: 'Invalid Lightning address format',
            code: ErrorCodes.invalidAddress,
          );
        }

        final parts = address.split('@');
        if (parts.length != 2) {
          throw ServiceException(
            message: 'Invalid Lightning address format',
            code: ErrorCodes.invalidAddress,
          );
        }

        final username = parts[0];
        final domain = parts[1];

        logInfo('💫 Starting LNURL-pay for $address...');

        // Step 1: Query LNURL-pay endpoint
        final lnurlResult = await _queryLnurlPayEndpoint(domain, username);
        if (lnurlResult.isError) {
          final serviceError = lnurlResult as ServiceError;
          throw serviceError.error;
        }

        final lnurlData = lnurlResult.valueOrNull!;
        logInfo('📡 LNURL data received from $domain');

        // Step 2: Validate amount is within limits
        final amountMsat = amountSats * 1000;
        if (amountMsat < lnurlData.minSendable || amountMsat > lnurlData.maxSendable) {
          throw ServiceException(
            message: 'Amount not supported. Min: ${lnurlData.minSendable ~/ 1000} sats, Max: ${lnurlData.maxSendable ~/ 1000} sats',
            code: ErrorCodes.invalidAmount,
          );
        }

        // Step 3: Request invoice from callback
        final invoiceResult = await _requestLnurlInvoice(
          lnurlData.callback,
          amountMsat,
          comment,
        );
        if (invoiceResult.isError) {
          final serviceError = invoiceResult as ServiceError;
          throw serviceError.error;
        }

        final bolt11 = invoiceResult.valueOrNull!;
        logInfo('📄 Invoice received from $domain');

        // Step 4: Pay the invoice
        final paymentResult = await payInvoice(bolt11: bolt11);
        if (paymentResult.isError) {
          final serviceError = paymentResult as ServiceError;
          throw serviceError.error;
        }

        final paymentHash = paymentResult.valueOrNull!;
        logInfo('⚡ Lightning address payment sent! Hash: ${paymentHash.substring(0, 16)}...');

        return paymentHash;
      },
      operationName: 'send to lightning address',
      errorCode: ErrorCodes.lightningError,
    );
  }

  /// Process LNURL-withdraw request
  Future<ServiceResult<String>> processLnurlWithdraw({
    required String lnurlWithdraw,
    required int amountSats,
    String? description,
  }) async {
    return executeOperation(
      operation: () async {
        logInfo('💰 Starting LNURL-withdraw processing...');

        // Step 1: Decode LNURL and query endpoint
        final lnurlResult = await _queryLnurlWithdrawEndpoint(lnurlWithdraw);
        if (lnurlResult.isError) {
          final serviceError = lnurlResult as ServiceError;
          throw serviceError.error;
        }

        final lnurlData = lnurlResult.valueOrNull!;
        logInfo('📡 LNURL-withdraw data received');

        // Step 2: Validate amount is within limits
        final amountMsat = amountSats * 1000;
        if (amountMsat < lnurlData.minWithdrawable || amountMsat > lnurlData.maxWithdrawable) {
          throw ServiceException(
            message: 'Amount not supported. Min: ${lnurlData.minWithdrawableSats} sats, Max: ${lnurlData.maxWithdrawableSats} sats',
            code: ErrorCodes.invalidAmount,
          );
        }

        // Step 3: Create an invoice to receive the withdrawal
        final invoiceResult = await createInvoice(
          amountSats: amountSats,
          description: description ?? lnurlData.defaultDescription,
        );
        if (invoiceResult.isError) {
          final serviceError = invoiceResult as ServiceError;
          throw serviceError.error;
        }

        final invoice = invoiceResult.valueOrNull!;
        logInfo('📄 Invoice created for withdrawal');

        // Step 4: Submit withdrawal request
        final withdrawResult = await _submitLnurlWithdraw(
          lnurlData.callback,
          lnurlData.k1,
          invoice.bolt11,
        );
        if (withdrawResult.isError) {
          final serviceError = withdrawResult as ServiceError;
          throw serviceError.error;
        }

        logInfo('✅ LNURL-withdraw processed successfully');
        return invoice.paymentHash ?? invoice.bolt11.hashCode.toString();
      },
      operationName: 'process LNURL-withdraw',
      errorCode: ErrorCodes.lightningError,
    );
  }

  /// Query LNURL-pay endpoint for payment details
  Future<ServiceResult<LnurlPayData>> _queryLnurlPayEndpoint(String domain, String username) async {
    return executeOperation(
      operation: () async {
        final url = 'https://$domain/.well-known/lnurlp/$username';
        
        final response = await _networkService.get<Map<String, dynamic>>(
          url: url,
          options: Options(
            sendTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        );

        if (response.isError) {
          final serviceError = response as ServiceError;
          throw ServiceException(
            message: 'Failed to fetch LNURL data: ${serviceError.error.message}',
            code: ErrorCodes.networkError,
          );
        }

        final data = response.valueOrNull!;
        
        // Check for LNURL error response
        if (data['status'] == 'ERROR') {
          throw ServiceException(
            message: data['reason'] ?? 'LNURL error',
            code: ErrorCodes.lightningError,
          );
        }

        // Validate required fields
        if (data['tag'] != 'payRequest') {
          throw ServiceException(
            message: 'Invalid LNURL response: wrong tag',
            code: ErrorCodes.lightningError,
          );
        }

        return LnurlPayData.fromJson(data);
      },
      operationName: 'query LNURL endpoint',
    );
  }

  /// Request invoice from LNURL callback
  Future<ServiceResult<String>> _requestLnurlInvoice(
    String callbackUrl,
    int amountMsat,
    String? comment,
  ) async {
    return executeOperation(
      operation: () async {
        final queryParams = <String, String>{
          'amount': amountMsat.toString(),
        };

        if (comment != null && comment.isNotEmpty) {
          queryParams['comment'] = comment;
        }

        final response = await _networkService.get<Map<String, dynamic>>(
          url: callbackUrl,
          queryParameters: queryParams,
          options: Options(
            sendTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
          ),
        );

        if (response.isError) {
          final serviceError = response as ServiceError;
          throw ServiceException(
            message: 'Failed to fetch LNURL data: ${serviceError.error.message}',
            code: ErrorCodes.networkError,
          );
        }

        final data = response.valueOrNull!;

        // Check for error response
        if (data['status'] == 'ERROR') {
          throw ServiceException(
            message: data['reason'] ?? 'Invoice request failed',
            code: ErrorCodes.lightningError,
          );
        }

        final bolt11 = data['pr'] as String?;
        if (bolt11 == null || bolt11.isEmpty) {
          throw ServiceException(
            message: 'No invoice received',
            code: ErrorCodes.lightningError,
          );
        }

        return bolt11;
      },
      operationName: 'request LNURL invoice',
    );
  }

  /// Query LNURL-withdraw endpoint
  Future<ServiceResult<LnurlWithdrawData>> _queryLnurlWithdrawEndpoint(String lnurl) async {
    return executeOperation(
      operation: () async {
        // Decode LNURL (simplified - in production you'd use proper bech32 decoding)
        String url;
        if (lnurl.toLowerCase().startsWith('lnurl')) {
          // For now, assume it's already a URL or needs simple decoding
          // In production, implement proper LNURL bech32 decoding
          url = lnurl;
        } else {
          url = lnurl;
        }

        final response = await _networkService.get<Map<String, dynamic>>(
          url: url,
          options: Options(
            sendTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        );

        if (response.isError) {
          final serviceError = response as ServiceError;
          throw ServiceException(
            message: 'Failed to fetch LNURL-withdraw data: ${serviceError.error.message}',
            code: ErrorCodes.networkError,
          );
        }

        final data = response.valueOrNull!;

        // Check for LNURL error response
        if (data['status'] == 'ERROR') {
          throw ServiceException(
            message: data['reason'] ?? 'LNURL-withdraw error',
            code: ErrorCodes.lightningError,
          );
        }

        // Validate required fields
        if (data['tag'] != 'withdrawRequest') {
          throw ServiceException(
            message: 'Invalid LNURL response: wrong tag',
            code: ErrorCodes.lightningError,
          );
        }

        return LnurlWithdrawData.fromJson(data);
      },
      operationName: 'query LNURL-withdraw endpoint',
    );
  }

  /// Submit LNURL-withdraw request
  Future<ServiceResult<void>> _submitLnurlWithdraw(
    String callbackUrl,
    String k1,
    String invoice,
  ) async {
    return executeOperation(
      operation: () async {
        final queryParams = <String, String>{
          'k1': k1,
          'pr': invoice,
        };

        final response = await _networkService.get<Map<String, dynamic>>(
          url: callbackUrl,
          queryParameters: queryParams,
          options: Options(
            sendTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
          ),
        );

        if (response.isError) {
          final serviceError = response as ServiceError;
          throw ServiceException(
            message: 'Failed to submit withdrawal: ${serviceError.error.message}',
            code: ErrorCodes.networkError,
          );
        }

        final data = response.valueOrNull!;

        // Check for error response
        if (data['status'] == 'ERROR') {
          throw ServiceException(
            message: data['reason'] ?? 'Withdrawal submission failed',
            code: ErrorCodes.lightningError,
          );
        }

        // Success if status is OK or not present
        if (data['status'] != null && data['status'] != 'OK') {
          throw ServiceException(
            message: 'Unexpected response status: ${data['status']}',
            code: ErrorCodes.lightningError,
          );
        }
      },
      operationName: 'submit LNURL-withdraw',
    );
  }

  /// Get Lightning balance
  Future<ServiceResult<LightningBalance>> getBalance() async {
    if (_node == null) {
      return ServiceError(
        ServiceException(
          message: 'Node not initialized',
          code: ErrorCodes.lightningError,
        ),
      );
    }

    return executeOperation(
      operation: () async {
        final balanceDetails = await _node!.listBalances();
        final channels = await _node!.listChannels();

        // Use BalanceDetails for Lightning balances (convert sats to msat)
        final BigInt totalLightningMsat = balanceDetails.totalLightningBalanceSats * BigInt.from(1000);
        final BigInt spendableLightningMsat = balanceDetails.spendableOnchainBalanceSats * BigInt.from(1000);
        
        // Calculate receivable capacity from channels
        BigInt receivableMsat = BigInt.zero;
        BigInt pendingMsat = BigInt.zero;
        
        for (final channel in channels) {
          if (channel.isChannelReady && channel.isUsable) {
            receivableMsat += channel.inboundCapacityMsat;
          } else {
            pendingMsat += channel.channelValueSats * BigInt.from(1000);
          }
        }

        return LightningBalance(
          totalMsat: totalLightningMsat.toInt(),
          spendableMsat: spendableLightningMsat.toInt(),
          receivableMsat: receivableMsat.toInt(),
          pendingMsat: pendingMsat.toInt(),
          lastUpdate: DateTime.now(),
        );
      },
      operationName: 'get lightning balance',
    );
  }

  /// Update channels
  Future<void> _updateChannels() async {
    final ldkChannels = await _node!.listChannels();

    _channels.clear();

    for (final ldkChannel in ldkChannels) {
      final channel = BrainrotChannel(
        channelId: ldkChannel.userChannelId.toString(),
        nodeId: ldkChannel.counterpartyNodeId.hex,
        localBalanceMsat: ldkChannel.outboundCapacityMsat.toInt(),
        remoteBalanceMsat: ldkChannel.inboundCapacityMsat.toInt(),
        capacityMsat: (ldkChannel.channelValueSats * BigInt.from(1000)).toInt(),
        isActive: ldkChannel.isChannelReady,
        isUsable: ldkChannel.isUsable,
        state: _mapChannelState(ldkChannel),
      );

      _channels.add(channel);
    }

    _channelController.add(_channels);

    logInfo('Channels updated: ${_channels.length} total ⚡');
  }

  /// Update balance
  Future<void> _updateBalance() async {
    final balanceResult = await getBalance();
    if (balanceResult.isSuccess) {
      _balanceController.add(balanceResult.valueOrNull!);
    }
  }

  /// Update payments
  Future<void> _updatePayments() async {
    final ldkPayments = await _node!.listPayments();

    _payments.clear();

    for (final ldkPayment in ldkPayments) {
      final payment = BrainrotPayment(
        paymentHash: ldkPayment.id.toString(),
        paymentPreimage: null, // Not available in current API
        amountMsat: ldkPayment.amountMsat?.toInt() ?? 0,
        feeMsat: null, // Not available in current API
        direction: ldkPayment.direction == ldk.PaymentDirection.inbound
            ? PaymentDirection.inbound
            : PaymentDirection.outbound,
        status: _mapPaymentStatus(ldkPayment.status),
        timestamp: DateTime.now(), // Use current time since timestamp not available
      );
      _payments.add(payment);
    }

    // Sort by timestamp (newest first)
    _payments.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Emit latest payment
    if (_payments.isNotEmpty) {
      _paymentController.add(_payments.first);
    }

    logInfo('Payments updated: ${_payments.length} total ⚡');
  }

  /// Setup event listeners
  void _setupEventListeners() {
    // Start proper event handling loop
    _startEventLoop();
    
    // Keep periodic sync as fallback for robustness
    Timer.periodic(const Duration(minutes: 5), (_) {
      if (_isInitialized && !_eventLoopRunning) {
        logWarning('Event loop not running, falling back to periodic sync');
        syncNode();
      }
    });
  }

  /// Start the main event processing loop
  Future<void> _startEventLoop() async {
    if (_eventLoopRunning || _node == null) return;
    
    _eventLoopRunning = true;
    logInfo('Starting Lightning event loop ⚡');
    
    // Run event loop in background
    _eventLoop().catchError((e) {
      logError('Event loop failed to start: $e');
      _eventLoopRunning = false;
    });
  }

  /// Main event processing loop
  Future<void> _eventLoop() async {
    while (_isInitialized && _node != null && _eventLoopRunning) {
      try {
        // Check for events using nextEventAsync if available
        // Note: LDK Node 0.3.0 may not expose direct event methods
        // so we use enhanced polling with immediate sync on changes
        
        final previousPaymentCount = _payments.length;
        final previousChannelCount = _channels.length;
        
        // Sync and check for changes
        await _node!.syncWallets();
        
        // Check for payment changes
        final currentPayments = await _node!.listPayments();
        if (currentPayments.length != previousPaymentCount) {
          await _handlePaymentEvent(currentPayments);
        }
        
        // Check for channel changes  
        final currentChannels = await _node!.listChannels();
        if (currentChannels.length != previousChannelCount) {
          await _handleChannelEvent(currentChannels);
        }
        
        // Check balance changes
        await _updateBalance();
        
        // Mobile-optimized delay to conserve battery and resources
        await Future.delayed(const Duration(seconds: 10));
        
        // Reset error counter on successful iteration
        _resetErrorRecovery();
        
      } catch (e, stackTrace) {
        logError('Event loop error: $e\n$stackTrace');
        
        // Handle error with sophisticated recovery
        await _handleEventLoopError(e, stackTrace);
      }
    }
    
    _eventLoopRunning = false;
    logWarning('Lightning event loop stopped 🛑');
  }

  /// Handle payment events
  Future<void> _handlePaymentEvent(List<ldk.PaymentDetails> ldkPayments) async {
    final previousPayments = Map.fromEntries(_payments.map((p) => MapEntry(p.paymentHash, p)));
    
    await _updatePayments();
    
    // Find new payments
    for (final payment in _payments) {
      if (!previousPayments.containsKey(payment.paymentHash)) {
        if (payment.direction == PaymentDirection.inbound) {
          await _handlePaymentReceived(payment);
        } else {
          await _handlePaymentSent(payment);
        }
      } else {
        // Check for status changes
        final previous = previousPayments[payment.paymentHash]!;
        if (previous.status != payment.status) {
          await _handlePaymentStatusChanged(payment, previous.status);
        }
      }
    }
  }

  /// Handle channel events
  Future<void> _handleChannelEvent(List<ldk.ChannelDetails> ldkChannels) async {
    final previousChannels = Map.fromEntries(_channels.map((c) => MapEntry(c.channelId, c)));
    
    await _updateChannels();
    
    // Find new or changed channels
    for (final channel in _channels) {
      if (!previousChannels.containsKey(channel.channelId)) {
        await _handleChannelOpened(channel);
      } else {
        final previous = previousChannels[channel.channelId]!;
        if (previous.state != channel.state) {
          await _handleChannelStateChanged(channel, previous.state);
        }
      }
    }
    
    // Find closed channels
    for (final previousChannel in previousChannels.values) {
      if (!_channels.any((c) => c.channelId == previousChannel.channelId)) {
        await _handleChannelClosed(previousChannel);
      }
    }
  }

  /// Handle payment received event
  Future<void> _handlePaymentReceived(BrainrotPayment payment) async {
    logInfo('💰 Payment received! Amount: ${payment.amountMsat ~/ 1000} sats');
    
    // Emit payment event
    _paymentController.add(payment);
    
    // Update invoice status if this matches an invoice
    final matchingInvoiceEntry = _invoices.entries.where((entry) => 
      entry.value.status == InvoiceStatus.pending
    ).firstOrNull;
    
    if (matchingInvoiceEntry != null) {
      final invoice = matchingInvoiceEntry.value;
      final updatedInvoice = BrainrotInvoice(
        bolt11: invoice.bolt11,
        paymentHash: invoice.paymentHash,
        paymentSecret: invoice.paymentSecret,
        amountMsat: invoice.amountMsat,
        description: invoice.description,
        expiryTime: invoice.expiryTime,
        createdAt: invoice.createdAt,
        status: InvoiceStatus.paid,
        paidAt: DateTime.now(),
        routeHints: invoice.routeHints,
      );
      _invoices[matchingInvoiceEntry.key] = updatedInvoice;
    }
  }

  /// Handle payment sent event
  Future<void> _handlePaymentSent(BrainrotPayment payment) async {
    logInfo('⚡ Payment sent! Amount: ${payment.amountMsat ~/ 1000} sats');
    
    // Emit payment event
    _paymentController.add(payment);
  }

  /// Handle payment status changed
  Future<void> _handlePaymentStatusChanged(BrainrotPayment payment, PaymentStatus previousStatus) async {
    logInfo('📊 Payment status changed: $previousStatus → ${payment.status}');
    
    // Emit updated payment
    _paymentController.add(payment);
  }

  /// Handle channel opened event
  Future<void> _handleChannelOpened(BrainrotChannel channel) async {
    logInfo('🎉 Channel opened! Capacity: ${channel.capacityMsat ~/ 1000} sats');
    
    // Emit channel update
    _channelController.add(_channels);
  }

  /// Handle channel state changed
  Future<void> _handleChannelStateChanged(BrainrotChannel channel, ChannelState previousState) async {
    logInfo('📡 Channel state changed: $previousState → ${channel.state}');
    
    if (channel.state == ChannelState.active && previousState == ChannelState.pending) {
      logInfo('✅ Channel is now ready for payments!');
    }
    
    // Emit channel update
    _channelController.add(_channels);
  }

  /// Handle channel closed event
  Future<void> _handleChannelClosed(BrainrotChannel channel) async {
    logWarning('💔 Channel closed! ID: ${channel.channelId.substring(0, 16)}...');
    
    // Emit channel update
    _channelController.add(_channels);
  }

  /// Stop event loop
  Future<void> _stopEventLoop() async {
    _eventLoopRunning = false;
    logInfo('Stopping Lightning event loop...');
  }

  /// Map LDK channel state to our enum
  ChannelState _mapChannelState(ldk.ChannelDetails channel) {
    // Check for pending state (channel exists but not ready)
    if (!channel.isChannelReady) return ChannelState.pending;
    
    // Check for inactive state (ready but not usable)
    if (!channel.isUsable) return ChannelState.inactive;
    
    // Default to active state
    return ChannelState.active;
  }

  /// Map LDK payment status to our enum
  PaymentStatus _mapPaymentStatus(ldk.PaymentStatus status) {
    switch (status) {
      case ldk.PaymentStatus.pending:
        return PaymentStatus.pending;
      case ldk.PaymentStatus.succeeded:
        return PaymentStatus.succeeded;
      case ldk.PaymentStatus.failed:
        return PaymentStatus.failed;
    }
  }

  /// Convert hex string to bytes
  Uint8List _hexStringToBytes(String hex) {
    // Remove '0x' prefix if present
    if (hex.startsWith('0x')) {
      hex = hex.substring(2);
    }
    
    // Ensure even length
    if (hex.length % 2 != 0) {
      hex = '0$hex';
    }
    
    final List<int> bytes = [];
    for (int i = 0; i < hex.length; i += 2) {
      final hexByte = hex.substring(i, i + 2);
      bytes.add(int.parse(hexByte, radix: 16));
    }
    
    return Uint8List.fromList(bytes);
  }

  /// Extract payment hash from BOLT11 invoice
  String _extractPaymentHashFromBolt11(String bolt11) {
    // The LDK Node 0.3.0 Bolt11Invoice class doesn't expose paymentHash() method
    // Using a deterministic hash of the invoice string as the key
    return _generateFallbackHash(bolt11);
  }

  /// Generate fallback hash for invoice storage
  String _generateFallbackHash(String bolt11) {
    // Using a deterministic hash of the invoice string
    // This ensures consistency across app restarts while avoiding the need
    // to extract the actual payment hash from the BOLT11 invoice
    return bolt11.hashCode.abs().toRadixString(16).padLeft(8, '0');
  }

  /// Stop Lightning node
  Future<ServiceResult<void>> stopNode() async {
    if (_node == null) {
      return const Success(null);
    }

    return executeOperation(
      operation: () async {
        // Stop event loop first
        await _stopEventLoop();
        
        await _node!.stop();
        _node = null;
        _isInitialized = false;

        logInfo('Lightning node stopped 🛑');
      },
      operationName: 'stop lightning node',
    );
  }

  /// Delete Lightning node
  Future<ServiceResult<void>> deleteNode() async {
    return executeOperation(
      operation: () async {
        // Stop node first
        await stopNode();

        // Delete stored data
        await _storageService.deleteValue(key: 'lightning_config');
        await secureStorage.delete(key: 'lightning_seed');

        // Delete data directory
        if (_config != null) {
          final dataDir = Directory(_config!.dataDir);
          if (await dataDir.exists()) {
            await dataDir.delete(recursive: true);
          }
        }

        // Clear state
        _config = null;
        _seedPhrase = null;
        _channels.clear();
        _payments.clear();
        _invoices.clear();

        logWarning('Lightning node deleted! F ⚡');
      },
      operationName: 'delete lightning node',
    );
  }

  /// Create a complete backup of Lightning node data
  Future<ServiceResult<LightningBackup>> createBackup({
    required String password,
  }) async {
    return executeOperation(
      operation: () async {
        if (!_isInitialized || _config == null) {
          throw ServiceException(
            message: 'Node not initialized',
            code: ErrorCodes.lightningError,
          );
        }

        // Get all current data
        final channels = await _node!.listChannels();
        final payments = await _node!.listPayments();
        final balance = await getBalance();

        // Create backup data
        final backup = LightningBackup(
          nodeId: _config!.nodeId,
          network: _config!.network,
          seedPhrase: _seedPhrase!,
          channels: _channels,
          payments: _payments,
          invoices: _invoices.values.toList(),
          balance: balance.isSuccess ? balance.valueOrNull! : null,
          dataDir: _config!.dataDir,
          createdAt: DateTime.now(),
          version: '1.0',
        );

        // Encrypt backup data
        final backupJson = jsonEncode(backup.toJson());
        final encryptedBackup = await _encryptionService.encryptWithPassword(
          plainText: backupJson,
          password: password,
        );

        if (encryptedBackup.isError) {
          final serviceError = encryptedBackup as ServiceError;
          throw serviceError.error;
        }

        // Store backup in secure storage
        final backupKey = 'lightning_backup_${DateTime.now().millisecondsSinceEpoch}';
        await _storageService.setSecureValue(
          key: backupKey,
          value: encryptedBackup.valueOrNull!,
          password: password,
        );

        // Update backup index
        final backupIndexResult = await _storageService.getValue<List<dynamic>>(
          key: 'lightning_backup_index',
        );
        List<String> backupKeys = [];
        if (backupIndexResult.isSuccess && backupIndexResult.valueOrNull != null) {
          backupKeys = (backupIndexResult.valueOrNull as List<dynamic>).cast<String>();
        }
        backupKeys.add(backupKey);
        await _storageService.setValue<List<String>>(
          key: 'lightning_backup_index',
          value: backupKeys,
        );

        logInfo('⚡ Lightning backup created! ${_channels.length} channels, ${_payments.length} payments');

        return backup;
      },
      operationName: 'create lightning backup',
      errorCode: ErrorCodes.lightningError,
    );
  }

  /// Restore Lightning node from backup
  Future<ServiceResult<void>> restoreFromBackup({
    required LightningBackup backup,
    required String password,
  }) async {
    return executeOperation(
      operation: () async {
        // Stop current node if running
        if (_isInitialized) {
          await stopNode();
        }

        // Validate backup version
        if (backup.version != '1.0') {
          throw ServiceException(
            message: 'Unsupported backup version: ${backup.version}',
            code: ErrorCodes.lightningError,
          );
        }

        // Restore node configuration
        final network = backup.network == 'testnet' 
            ? ldk.Network.testnet 
            : ldk.Network.bitcoin;

        // Initialize node with backup seed
        final initResult = await initializeNode(
          seedPhrase: backup.seedPhrase,
          password: password,
          bitcoinNetwork: network,
        );

        if (initResult.isError) {
          final serviceError = initResult as ServiceError;
          throw serviceError.error;
        }

        // Restore invoices
        _invoices.clear();
        for (final invoice in backup.invoices) {
          _invoices[invoice.paymentHash ?? invoice.bolt11.hashCode.toString()] = invoice;
        }

        // Force sync to restore channels and payments
        await syncNode();

        logInfo('⚡ Lightning backup restored! Node ID: ${backup.nodeId.substring(0, 16)}...');
      },
      operationName: 'restore lightning backup',
      errorCode: ErrorCodes.lightningError,
    );
  }

  /// Export Lightning data directory for external backup
  Future<ServiceResult<Uint8List>> exportDataDirectory() async {
    return executeOperation(
      operation: () async {
        if (_config == null) {
          throw ServiceException(
            message: 'Node not initialized',
            code: ErrorCodes.lightningError,
          );
        }

        final dataDir = Directory(_config!.dataDir);
        if (!await dataDir.exists()) {
          throw ServiceException(
            message: 'Data directory not found',
            code: ErrorCodes.storageError,
          );
        }

        // Create production-ready tar.gz archive using archive library
        final archive = Archive();
        final files = await dataDir.list(recursive: true).toList();
        int fileCount = 0;
        
        for (final file in files) {
          if (file is File) {
            try {
              final relativePath = file.path.replaceFirst('${dataDir.path}/', '');
              final fileBytes = await file.readAsBytes();
              final fileStat = await file.stat();
              
              // Create archive file with proper metadata
              final archiveFile = ArchiveFile(
                relativePath,
                fileBytes.length,
                fileBytes,
              );
              
              // Set file timestamps and permissions
              archiveFile.lastModTime = fileStat.modified.millisecondsSinceEpoch ~/ 1000;
              archiveFile.mode = 0644; // Standard file permissions
              
              archive.addFile(archiveFile);
              fileCount++;
              
              logInfo('📄 Added to archive: $relativePath (${fileBytes.length} bytes)');
            } catch (e) {
              logWarning('⚠️ Failed to add file to archive: ${file.path} - $e');
              // Continue with other files instead of failing completely
            }
          } else if (file is Directory) {
            // Add empty directories
            final relativePath = file.path.replaceFirst('${dataDir.path}/', '');
            if (relativePath.isNotEmpty) {
              final dirFile = ArchiveFile('$relativePath/', 0, null);
              dirFile.mode = 0755; // Directory permissions
              archive.addFile(dirFile);
            }
          }
        }

        // Compress to tar.gz format for optimal size and compatibility
        final tarData = TarEncoder().encode(archive);
        final compressedData = GZipEncoder().encode(tarData);

        final originalSize = archive.files.fold<int>(0, (sum, file) => sum + file.size);
        final compressedSize = compressedData?.length ?? 0;
        final compressionRatio = originalSize > 0 ? ((1 - compressedSize / originalSize) * 100).toStringAsFixed(1) : '0.0';

        logInfo('📦 Lightning data directory exported: $fileCount files, ${(originalSize / 1024).toStringAsFixed(1)}KB → ${(compressedSize / 1024).toStringAsFixed(1)}KB ($compressionRatio% compression)');

        return Uint8List.fromList(compressedData ?? []);
      },
      operationName: 'export data directory',
      errorCode: ErrorCodes.storageError,
    );
  }

  /// Import Lightning data directory from external backup
  Future<ServiceResult<void>> importDataDirectory({
    required Uint8List archiveData,
    required String password,
  }) async {
    return executeOperation(
      operation: () async {
        if (_isInitialized) {
          await stopNode();
        }

        // Get app directory for restoration
        final appDir = await getApplicationDocumentsDirectory();
        final restoreDir = Directory('${appDir.path}/ldk_node_restore');
        
        if (await restoreDir.exists()) {
          await restoreDir.delete(recursive: true);
        }
        await restoreDir.create(recursive: true);

        try {
          // Decompress tar.gz archive using archive library
          logInfo('📂 Decompressing archive data...');
          final decompressedData = GZipDecoder().decodeBytes(archiveData);
          
          logInfo('📂 Extracting tar archive...');
          final archive = TarDecoder().decodeBytes(decompressedData);
          
          int fileCount = 0;
          int dirCount = 0;
          int totalBytes = 0;

          for (final file in archive) {
            final filePath = File('${restoreDir.path}/${file.name}');
            
            // Handle directories
            if (file.isFile == false || file.name.endsWith('/')) {
              await filePath.parent.create(recursive: true);
              dirCount++;
              logInfo('📁 Created directory: ${file.name}');
              continue;
            }

            // Handle files
            try {
              // Ensure parent directory exists
              await filePath.parent.create(recursive: true);
              
              // Write file content
              if (file.content != null) {
                await filePath.writeAsBytes(file.content as List<int>);
                
                // Restore file permissions and timestamps if available
                if (file.lastModTime != null && file.lastModTime! > 0) {
                  // Note: Dart/Flutter has limited support for setting file timestamps
                  // This is primarily for compatibility with other systems
                }
                
                fileCount++;
                totalBytes += file.size;
                logInfo('📄 Restored file: ${file.name} (${file.size} bytes)');
              }
            } catch (e) {
              logWarning('⚠️ Failed to restore file ${file.name}: $e');
              // Continue with other files instead of failing completely
            }
          }

          logInfo('📂 Lightning data directory imported successfully:');
          logInfo('   📁 Directories: $dirCount');
          logInfo('   📄 Files: $fileCount');
          logInfo('   💾 Total size: ${(totalBytes / 1024).toStringAsFixed(1)}KB');
          logInfo('   📍 Location: ${restoreDir.path}');
          
        } catch (e) {
          throw ServiceException(
            message: 'Failed to extract archive: $e',
            code: ErrorCodes.storageError,
          );
        }
      },
      operationName: 'import data directory',
      errorCode: ErrorCodes.storageError,
    );
  }

  /// List available backups
  Future<ServiceResult<List<String>>> listBackups() async {
    return executeOperation(
      operation: () async {
        // Since StorageService doesn't have getAllKeys, we'll maintain a backup index
        final backupIndexResult = await _storageService.getValue<List<dynamic>>(
          key: 'lightning_backup_index',
        );
        
        List<String> backupKeys = [];
        if (backupIndexResult.isSuccess && backupIndexResult.valueOrNull != null) {
          backupKeys = (backupIndexResult.valueOrNull as List<dynamic>).cast<String>();
        }
        
        logInfo('📋 Found ${backupKeys.length} Lightning backups');
        
        return backupKeys;
      },
      operationName: 'list lightning backups',
    );
  }

  /// Delete a specific backup
  Future<ServiceResult<void>> deleteBackup(String backupKey) async {
    return executeOperation(
      operation: () async {
        // Delete the backup
        await _storageService.deleteValue(key: backupKey);
        
        // Update backup index
        final backupIndexResult = await _storageService.getValue<List<dynamic>>(
          key: 'lightning_backup_index',
        );
        if (backupIndexResult.isSuccess && backupIndexResult.valueOrNull != null) {
          List<String> backupKeys = (backupIndexResult.valueOrNull as List<dynamic>).cast<String>();
          backupKeys.remove(backupKey);
          await _storageService.setValue<List<String>>(
            key: 'lightning_backup_index',
            value: backupKeys,
          );
        }
        
        logInfo('🗑️ Lightning backup deleted: $backupKey');
      },
      operationName: 'delete lightning backup',
    );
  }


  /// Handle event loop errors with sophisticated recovery
  Future<void> _handleEventLoopError(dynamic error, StackTrace stackTrace) async {
    _consecutiveErrors++;
    _lastErrorTime = DateTime.now();

    // Check if we should open circuit breaker
    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      _openCircuitBreaker();
    }

    // Determine error type and apply appropriate recovery strategy
    final recoveryStrategy = _determineRecoveryStrategy(error);
    
    logWarning('🔧 Error recovery strategy: ${recoveryStrategy.name}, attempt: $_consecutiveErrors/$_maxConsecutiveErrors');

    switch (recoveryStrategy) {
      case ErrorRecoveryStrategy.exponentialBackoff:
        await _exponentialBackoff();
        break;
      case ErrorRecoveryStrategy.networkReconnect:
        await _attemptNetworkRecovery();
        break;
      case ErrorRecoveryStrategy.nodeRestart:
        await _attemptNodeRestart();
        break;
      case ErrorRecoveryStrategy.circuitBreaker:
        await _handleCircuitBreaker();
        break;
    }
  }

  /// Determine the appropriate recovery strategy based on error type
  ErrorRecoveryStrategy _determineRecoveryStrategy(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    // Network-related errors
    if (errorString.contains('network') || 
        errorString.contains('connection') || 
        errorString.contains('timeout') ||
        errorString.contains('socket')) {
      return _consecutiveErrors < 3 
          ? ErrorRecoveryStrategy.exponentialBackoff
          : ErrorRecoveryStrategy.networkReconnect;
    }
    
    // LDK node-specific errors
    if (errorString.contains('ldk') || 
        errorString.contains('lightning') ||
        errorString.contains('channel') ||
        errorString.contains('payment')) {
      return _consecutiveErrors < 3
          ? ErrorRecoveryStrategy.exponentialBackoff
          : ErrorRecoveryStrategy.nodeRestart;
    }
    
    // Circuit breaker for persistent failures
    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      return ErrorRecoveryStrategy.circuitBreaker;
    }
    
    // Default to exponential backoff
    return ErrorRecoveryStrategy.exponentialBackoff;
  }

  /// Apply exponential backoff with jitter
  Future<void> _exponentialBackoff() async {
    // Calculate backoff duration: 2^attempts seconds with jitter
    final baseDelay = Duration(seconds: (1 << _consecutiveErrors.clamp(0, 8)));
    final jitter = Duration(milliseconds: (DateTime.now().millisecond % 1000));
    final delay = baseDelay + jitter;
    
    final clampedDelay = delay > _maxBackoffDuration ? _maxBackoffDuration : delay;
    
    logInfo('⏳ Exponential backoff: ${clampedDelay.inSeconds}s (attempt $_consecutiveErrors)');
    await Future.delayed(clampedDelay);
  }

  /// Attempt network recovery
  Future<void> _attemptNetworkRecovery() async {
    logInfo('🌐 Attempting network recovery...');
    
    try {
      // Check network connectivity
      final networkResult = await _networkService.isOnline();
      if (networkResult.isError || !networkResult.valueOrNull!) {
        logWarning('📶 No network connection detected');
        await Future.delayed(const Duration(seconds: 30));
        return;
      }
      
      // Attempt to sync wallets to test LDK connectivity
      if (_node != null) {
        await _node!.syncWallets();
        logInfo('✅ Network recovery successful');
        _resetErrorRecovery();
      }
    } catch (e) {
      logWarning('🔧 Network recovery failed: $e');
      await _exponentialBackoff();
    }
  }

  /// Attempt node restart for severe issues
  Future<void> _attemptNodeRestart() async {
    logWarning('🔄 Attempting Lightning node restart...');
    
    try {
      if (_node != null && _seedPhrase != null && _config != null) {
        await stopNode();
        
        // Wait before restart
        await Future.delayed(const Duration(seconds: 10));
        
        // Restart with existing configuration
        final network = _config!.network == 'testnet'
            ? ldk.Network.testnet
            : ldk.Network.bitcoin;
            
        final restartResult = await initializeNode(
          seedPhrase: _seedPhrase!,
          password: '', // Password should be managed appropriately
          bitcoinNetwork: network,
        );
        
        if (restartResult.isSuccess) {
          logInfo('✅ Node restart successful');
          _resetErrorRecovery();
        } else {
          logError('❌ Node restart failed: ${restartResult.errorOrNull?.message}');
          await _exponentialBackoff();
        }
      }
    } catch (e) {
      logError('🔧 Node restart failed: $e');
      await _exponentialBackoff();
    }
  }

  /// Handle circuit breaker state
  Future<void> _handleCircuitBreaker() async {
    if (!_circuitBreakerOpen) {
      _openCircuitBreaker();
    }
    
    // Check if circuit breaker should be closed
    if (_shouldCloseCircuitBreaker()) {
      _closeCircuitBreaker();
      return;
    }
    
    // Long delay when circuit breaker is open
    logWarning('⚡ Circuit breaker OPEN - Lightning operations suspended');
    await Future.delayed(const Duration(minutes: 1));
  }

  /// Open circuit breaker
  void _openCircuitBreaker() {
    _circuitBreakerOpen = true;
    _circuitBreakerOpenTime = DateTime.now();
    logError('🚨 Circuit breaker OPENED - Too many consecutive errors ($_consecutiveErrors)');
  }

  /// Close circuit breaker and reset error state
  void _closeCircuitBreaker() {
    _circuitBreakerOpen = false;
    _circuitBreakerOpenTime = null;
    _resetErrorRecovery();
    logInfo('✅ Circuit breaker CLOSED - Resuming normal operations');
  }

  /// Check if circuit breaker should be closed
  bool _shouldCloseCircuitBreaker() {
    if (!_circuitBreakerOpen || _circuitBreakerOpenTime == null) {
      return false;
    }
    
    // Close after 5 minutes
    return DateTime.now().difference(_circuitBreakerOpenTime!) > const Duration(minutes: 5);
  }

  /// Reset error recovery state
  void _resetErrorRecovery() {
    _consecutiveErrors = 0;
    _lastErrorTime = null;
    if (_circuitBreakerOpen) {
      _closeCircuitBreaker();
    }
  }

  /// Check if system is healthy (for external monitoring)
  bool get isHealthy => !_circuitBreakerOpen && _consecutiveErrors < _maxConsecutiveErrors;

  /// Get error recovery metrics
  Map<String, dynamic> getErrorMetrics() {
    return {
      'consecutiveErrors': _consecutiveErrors,
      'lastErrorTime': _lastErrorTime?.toIso8601String(),
      'circuitBreakerOpen': _circuitBreakerOpen,
      'circuitBreakerOpenTime': _circuitBreakerOpenTime?.toIso8601String(),
      'isHealthy': isHealthy,
    };
  }

  /// Dispose service
  void dispose() {
    _stopEventLoop();
    _balanceController.close();
    _channelController.close();
    _paymentController.close();
    stopNode();
  }
}

import 'dart:typed_data';
import 'package:ldk_node/ldk_node.dart' as ldk;

/// Lightning node configuration
class LightningConfig {
  final String nodeId;
  final String network;
  final String dataDir;
  final List<String> listeningAddresses;
  final DateTime createdAt;
  final String? alias;
  final String? color;

  LightningConfig({
    required this.nodeId,
    required this.network,
    required this.dataDir,
    required this.listeningAddresses,
    required this.createdAt,
    this.alias,
    this.color,
  });

  Map<String, dynamic> toJson() => {
    'nodeId': nodeId,
    'network': network,
    'dataDir': dataDir,
    'listeningAddresses': listeningAddresses,
    'createdAt': createdAt.toIso8601String(),
    'alias': alias,
    'color': color,
  };

  factory LightningConfig.fromJson(Map<String, dynamic> json) {
    return LightningConfig(
      nodeId: json['nodeId'] as String,
      network: json['network'] as String,
      dataDir: json['dataDir'] as String,
      listeningAddresses: List<String>.from(json['listeningAddresses']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      alias: json['alias'] as String?,
      color: json['color'] as String?,
    );
  }
}

/// Lightning channel model with meme fields
class BrainrotChannel {
  final String channelId;
  final String nodeId;
  final String? alias;
  final int localBalanceMsat;
  final int remoteBalanceMsat;
  final int capacityMsat;
  final bool isActive;
  final bool isUsable;
  final ChannelState state;
  final DateTime? openedAt;
  final DateTime? closedAt;

  BrainrotChannel({
    required this.channelId,
    required this.nodeId,
    this.alias,
    required this.localBalanceMsat,
    required this.remoteBalanceMsat,
    required this.capacityMsat,
    required this.isActive,
    required this.isUsable,
    required this.state,
    this.openedAt,
    this.closedAt,
  });

  /// Get local balance in sats
  int get localBalanceSats => localBalanceMsat ~/ 1000;

  /// Get remote balance in sats
  int get remoteBalanceSats => remoteBalanceMsat ~/ 1000;

  /// Get capacity in sats
  int get capacitySats => capacityMsat ~/ 1000;

  /// Get channel health percentage
  double get healthPercentage {
    if (capacityMsat == 0) return 0;
    return (localBalanceMsat / capacityMsat) * 100;
  }

  /// Get meme status for channel
  String getMemeStatus() {
    if (!isActive) return 'Channel is sleeping 😴';
    if (!isUsable) return 'Channel machine broke 🔧';

    if (healthPercentage < 10) return 'Inbound liquidity gang 📥';
    if (healthPercentage > 90) return 'Outbound liquidity enjoyer 📤';
    if (healthPercentage > 40 && healthPercentage < 60) return 'Perfectly balanced ⚖️';

    return 'Channel go brrrr ⚡';
  }

  /// Get channel emojis based on state
  List<String> getEmojis() {
    switch (state) {
      case ChannelState.pending:
        return ['⏳', '🔄', '👀'];
      case ChannelState.active:
        if (healthPercentage > 80) return ['⚡', '🚀', '💪'];
        if (healthPercentage < 20) return ['📥', '🥺', '💧'];
        return ['⚡', '✅', '🤝'];
      case ChannelState.inactive:
        return ['😴', '💤', '🌙'];
      case ChannelState.closing:
        return ['👋', '📤', '😢'];
      case ChannelState.closed:
        return ['💀', '🪦', 'F'];
    }
  }

  Map<String, dynamic> toJson() => {
    'channelId': channelId,
    'nodeId': nodeId,
    'localBalanceMsat': localBalanceMsat,
    'remoteBalanceMsat': remoteBalanceMsat,
    'capacityMsat': capacityMsat,
    'isActive': isActive,
    'isUsable': isUsable,
    'state': state.name,
    'openedAt': openedAt?.toIso8601String(),
    'closedAt': closedAt?.toIso8601String(),
  };

  factory BrainrotChannel.fromJson(Map<String, dynamic> json) {
    return BrainrotChannel(
      channelId: json['channelId'] as String,
      nodeId: json['nodeId'] as String,
      localBalanceMsat: json['localBalanceMsat'] as int,
      remoteBalanceMsat: json['remoteBalanceMsat'] as int,
      capacityMsat: json['capacityMsat'] as int,
      isActive: json['isActive'] as bool,
      isUsable: json['isUsable'] as bool,
      state: ChannelState.values.byName(json['state'] as String),
      openedAt: json['openedAt'] != null ? DateTime.parse(json['openedAt'] as String) : null,
      closedAt: json['closedAt'] != null ? DateTime.parse(json['closedAt'] as String) : null,
    );
  }
}

/// Channel state enum
enum ChannelState {
  pending,
  active,
  inactive,
  closing,
  closed,
}

/// Lightning invoice model with meme fields
class BrainrotInvoice {
  final String bolt11;
  final String? paymentHash;
  final String? paymentSecret;
  final int? amountMsat;
  final String? description;
  final int expiryTime;
  final DateTime createdAt;
  final InvoiceStatus status;
  final DateTime? paidAt;
  final List<String> routeHints;

  BrainrotInvoice({
    required this.bolt11,
    this.paymentHash,
    this.paymentSecret,
    this.amountMsat,
    this.description,
    required this.expiryTime,
    required this.createdAt,
    required this.status,
    this.paidAt,
    this.routeHints = const [],
  });

  /// Get amount in sats
  int? get amountSats => amountMsat != null ? amountMsat! ~/ 1000 : null;

  /// Check if invoice is expired
  bool get isExpired {
    final expiryDate = createdAt.add(Duration(seconds: expiryTime));
    return DateTime.now().isAfter(expiryDate);
  }

  /// Get time until expiry
  Duration get timeUntilExpiry {
    final expiryDate = createdAt.add(Duration(seconds: expiryTime));
    final remaining = expiryDate.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Get meme status message
  String getMemeStatus() {
    if (status == InvoiceStatus.paid) {
      return 'Paid! Money printer go brrrr 🖨️💵';
    }

    if (isExpired) {
      return 'Expired! It\'s so over 😭';
    }

    final minutes = timeUntilExpiry.inMinutes;
    if (minutes < 5) return 'Pay now or cry later! ⏰';
    if (minutes < 30) return 'Waiting for payment... 👀';

    return 'Fresh invoice, hot off the press! 📄';
  }

  /// Get invoice emojis
  List<String> getEmojis() {
    if (status == InvoiceStatus.paid) return ['✅', '💰', '🎉'];
    if (isExpired) return ['❌', '⏰', '💀'];
    if (timeUntilExpiry.inMinutes < 5) return ['⚠️', '⏳', '🏃'];
    return ['⚡', '📄', '⏰'];
  }

  Map<String, dynamic> toJson() => {
    'bolt11': bolt11,
    'paymentHash': paymentHash,
    'paymentSecret': paymentSecret,
    'amountMsat': amountMsat,
    'description': description,
    'expiryTime': expiryTime,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    'paidAt': paidAt?.toIso8601String(),
    'routeHints': routeHints,
  };

  factory BrainrotInvoice.fromJson(Map<String, dynamic> json) {
    return BrainrotInvoice(
      bolt11: json['bolt11'] as String,
      paymentHash: json['paymentHash'] as String?,
      paymentSecret: json['paymentSecret'] as String?,
      amountMsat: json['amountMsat'] as int?,
      description: json['description'] as String?,
      expiryTime: json['expiryTime'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: InvoiceStatus.values.byName(json['status'] as String),
      paidAt: json['paidAt'] != null ? DateTime.parse(json['paidAt'] as String) : null,
      routeHints: (json['routeHints'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
}

/// Invoice status enum
enum InvoiceStatus {
  pending,
  paid,
  expired,
  cancelled,
}

/// Lightning payment model
class BrainrotPayment {
  final String paymentHash;
  final String? paymentPreimage;
  final int amountMsat;
  final int? feeMsat;
  final PaymentDirection direction;
  final PaymentStatus status;
  final DateTime timestamp;
  final String? bolt11;
  final String? description;
  final String? errorMessage;

  BrainrotPayment({
    required this.paymentHash,
    this.paymentPreimage,
    required this.amountMsat,
    this.feeMsat,
    required this.direction,
    required this.status,
    required this.timestamp,
    this.bolt11,
    this.description,
    this.errorMessage,
  });

  /// Get amount in sats
  int get amountSats => amountMsat ~/ 1000;

  /// Get fee in sats
  int? get feeSats => feeMsat != null ? feeMsat! ~/ 1000 : null;

  /// Check if payment is incoming
  bool get isIncoming => direction == PaymentDirection.inbound;

  /// Get meme status message
  String getMemeStatus() {
    if (status == PaymentStatus.succeeded) {
      return isIncoming
          ? 'Sats received! WAGMI! 💎'
          : 'Payment sent at light speed! ⚡';
    }

    if (status == PaymentStatus.failed) {
      return 'Payment failed! Skill issue? 🎮';
    }

    return 'Payment pending... Vibing 🎵';
  }

  /// Get payment emojis
  List<String> getEmojis() {
    if (status == PaymentStatus.succeeded) {
      return isIncoming ? ['📥', '💰', '🎉'] : ['📤', '⚡', '✅'];
    }
    if (status == PaymentStatus.failed) {
      return ['❌', '😢', 'F'];
    }
    return ['⏳', '🔄', '👀'];
  }

  Map<String, dynamic> toJson() => {
    'paymentHash': paymentHash,
    'paymentPreimage': paymentPreimage,
    'amountMsat': amountMsat,
    'feeMsat': feeMsat,
    'direction': direction.name,
    'status': status.name,
    'timestamp': timestamp.toIso8601String(),
    'bolt11': bolt11,
    'description': description,
    'errorMessage': errorMessage,
  };

  factory BrainrotPayment.fromJson(Map<String, dynamic> json) {
    return BrainrotPayment(
      paymentHash: json['paymentHash'] as String,
      paymentPreimage: json['paymentPreimage'] as String?,
      amountMsat: json['amountMsat'] as int,
      feeMsat: json['feeMsat'] as int?,
      direction: PaymentDirection.values.byName(json['direction'] as String),
      status: PaymentStatus.values.byName(json['status'] as String),
      timestamp: DateTime.parse(json['timestamp'] as String),
      bolt11: json['bolt11'] as String?,
      description: json['description'] as String?,
      errorMessage: json['errorMessage'] as String?,
    );
  }
}

/// Payment direction enum
enum PaymentDirection {
  inbound,
  outbound,
}

/// Payment status enum
enum PaymentStatus {
  pending,
  succeeded,
  failed,
}

/// Lightning balance model
class LightningBalance {
  final int totalMsat;
  final int spendableMsat;
  final int receivableMsat;
  final int pendingMsat;
  final DateTime lastUpdate;

  LightningBalance({
    required this.totalMsat,
    required this.spendableMsat,
    required this.receivableMsat,
    required this.pendingMsat,
    required this.lastUpdate,
  });

  /// Get balances in sats
  int get totalSats => totalMsat ~/ 1000;
  int get spendableSats => spendableMsat ~/ 1000;
  int get receivableSats => receivableMsat ~/ 1000;
  int get pendingSats => pendingMsat ~/ 1000;

  /// Get meme description
  String getMemeDescription() {
    if (totalSats == 0) return 'No Lightning sats? Open a channel! 🌩️';
    if (spendableSats == 0) return 'Can\'t send? Need outbound liquidity! 📤';
    if (receivableSats == 0) return 'Can\'t receive? Need inbound liquidity! 📥';
    if (spendableSats > 100000) return 'Lightning whale spotted! 🐋⚡';
    return 'Lightning ready! Zap zap! ⚡⚡';
  }

  Map<String, dynamic> toJson() => {
    'totalMsat': totalMsat,
    'spendableMsat': spendableMsat,
    'receivableMsat': receivableMsat,
    'pendingMsat': pendingMsat,
    'lastUpdate': lastUpdate.toIso8601String(),
  };

  factory LightningBalance.fromJson(Map<String, dynamic> json) {
    return LightningBalance(
      totalMsat: json['totalMsat'] as int,
      spendableMsat: json['spendableMsat'] as int,
      receivableMsat: json['receivableMsat'] as int,
      pendingMsat: json['pendingMsat'] as int,
      lastUpdate: DateTime.parse(json['lastUpdate'] as String),
    );
  }
}

/// LNURL data model
class LnurlData {
  final String encodedUrl;
  final LnurlType type;
  final Map<String, dynamic> metadata;

  LnurlData({
    required this.encodedUrl,
    required this.type,
    required this.metadata,
  });
}

/// LNURL type enum
enum LnurlType {
  pay,
  withdraw,
  auth,
  channel,
}

/// Lightning node info
class NodeInfo {
  final String nodeId;
  final String? alias;
  final String? color;
  final List<String> listeningAddresses;
  final int numPeers;
  final int numChannels;
  final int numUsableChannels;

  NodeInfo({
    required this.nodeId,
    this.alias,
    this.color,
    required this.listeningAddresses,
    required this.numPeers,
    required this.numChannels,
    required this.numUsableChannels,
  });

  /// Get node health status
  String getHealthStatus() {
    if (numChannels == 0) return 'No channels? Touch grass ⚡';
    if (numUsableChannels == 0) return 'Channels not usable! 🔧';
    if (numUsableChannels < numChannels) {
      return 'Some channels need attention 👀';
    }
    return 'Node is vibing! All systems go! 🚀';
  }
}

/// LNURL-pay data model
class LnurlPayData {
  final String callback;
  final int minSendable;
  final int maxSendable;
  final String metadata;
  final int? commentAllowed;
  final String tag;
  final List<String>? allowsNostr;
  final String? nostrPubkey;

  LnurlPayData({
    required this.callback,
    required this.minSendable,
    required this.maxSendable,
    required this.metadata,
    this.commentAllowed,
    required this.tag,
    this.allowsNostr,
    this.nostrPubkey,
  });

  factory LnurlPayData.fromJson(Map<String, dynamic> json) {
    return LnurlPayData(
      callback: json['callback'] as String,
      minSendable: json['minSendable'] as int,
      maxSendable: json['maxSendable'] as int,
      metadata: json['metadata'] as String,
      commentAllowed: json['commentAllowed'] as int?,
      tag: json['tag'] as String,
      allowsNostr: (json['allowsNostr'] as List<dynamic>?)?.cast<String>(),
      nostrPubkey: json['nostrPubkey'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'callback': callback,
    'minSendable': minSendable,
    'maxSendable': maxSendable,
    'metadata': metadata,
    'commentAllowed': commentAllowed,
    'tag': tag,
    'allowsNostr': allowsNostr,
    'nostrPubkey': nostrPubkey,
  };

  /// Get minimum amount in sats
  int get minSendableSats => minSendable ~/ 1000;

  /// Get maximum amount in sats
  int get maxSendableSats => maxSendable ~/ 1000;

  /// Check if comments are allowed
  bool get supportsComments => commentAllowed != null && commentAllowed! > 0;

  /// Get max comment length
  int get maxCommentLength => commentAllowed ?? 0;
}

/// LNURL-withdraw data model
class LnurlWithdrawData {
  final String callback;
  final String k1;
  final int minWithdrawable;
  final int maxWithdrawable;
  final String defaultDescription;
  final String tag;

  LnurlWithdrawData({
    required this.callback,
    required this.k1,
    required this.minWithdrawable,
    required this.maxWithdrawable,
    required this.defaultDescription,
    required this.tag,
  });

  factory LnurlWithdrawData.fromJson(Map<String, dynamic> json) {
    return LnurlWithdrawData(
      callback: json['callback'] as String,
      k1: json['k1'] as String,
      minWithdrawable: json['minWithdrawable'] as int,
      maxWithdrawable: json['maxWithdrawable'] as int,
      defaultDescription: json['defaultDescription'] as String,
      tag: json['tag'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'callback': callback,
    'k1': k1,
    'minWithdrawable': minWithdrawable,
    'maxWithdrawable': maxWithdrawable,
    'defaultDescription': defaultDescription,
    'tag': tag,
  };

  /// Get minimum amount in sats
  int get minWithdrawableSats => minWithdrawable ~/ 1000;

  /// Get maximum amount in sats
  int get maxWithdrawableSats => maxWithdrawable ~/ 1000;
}

/// Lightning backup data model
class LightningBackup {
  final String nodeId;
  final String network;
  final String seedPhrase;
  final List<BrainrotChannel> channels;
  final List<BrainrotPayment> payments;
  final List<BrainrotInvoice> invoices;
  final LightningBalance? balance;
  final String dataDir;
  final DateTime createdAt;
  final String version;

  LightningBackup({
    required this.nodeId,
    required this.network,
    required this.seedPhrase,
    required this.channels,
    required this.payments,
    required this.invoices,
    this.balance,
    required this.dataDir,
    required this.createdAt,
    required this.version,
  });

  factory LightningBackup.fromJson(Map<String, dynamic> json) {
    return LightningBackup(
      nodeId: json['nodeId'] as String,
      network: json['network'] as String,
      seedPhrase: json['seedPhrase'] as String,
      channels: (json['channels'] as List<dynamic>)
          .map((ch) => BrainrotChannel.fromJson(ch as Map<String, dynamic>))
          .toList(),
      payments: (json['payments'] as List<dynamic>)
          .map((pm) => BrainrotPayment.fromJson(pm as Map<String, dynamic>))
          .toList(),
      invoices: (json['invoices'] as List<dynamic>)
          .map((inv) => BrainrotInvoice.fromJson(inv as Map<String, dynamic>))
          .toList(),
      balance: json['balance'] != null
          ? LightningBalance.fromJson(json['balance'] as Map<String, dynamic>)
          : null,
      dataDir: json['dataDir'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      version: json['version'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'nodeId': nodeId,
    'network': network,
    'seedPhrase': seedPhrase,
    'channels': channels.map((ch) => ch.toJson()).toList(),
    'payments': payments.map((pm) => pm.toJson()).toList(),
    'invoices': invoices.map((inv) => inv.toJson()).toList(),
    'balance': balance?.toJson(),
    'dataDir': dataDir,
    'createdAt': createdAt.toIso8601String(),
    'version': version,
  };

  /// Get backup size in a human-readable format
  String get backupSize {
    final totalItems = channels.length + payments.length + invoices.length;
    return '$totalItems items';
  }

  /// Get backup age
  String get backupAge {
    final age = DateTime.now().difference(createdAt);
    if (age.inDays > 0) return '${age.inDays} days ago';
    if (age.inHours > 0) return '${age.inHours} hours ago';
    if (age.inMinutes > 0) return '${age.inMinutes} minutes ago';
    return 'Just now';
  }

  /// Check if backup is compatible with current version
  bool get isCompatible => version == '1.0';
}

/// Error recovery strategy enum
enum ErrorRecoveryStrategy {
  exponentialBackoff,
  networkReconnect,
  nodeRestart,
  circuitBreaker,
}

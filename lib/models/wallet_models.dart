import 'package:bdk_flutter/bdk_flutter.dart';

/// Wallet configuration model
class WalletConfig {
  final String id;
  final String name;
  final Network network;
  final String descriptor;
  final String? changeDescriptor;
  final DateTime createdAt;
  final WalletType walletType;
  final String? externalDerivationPath;
  final String? internalDerivationPath;

  WalletConfig({
    required this.id,
    required this.name,
    required this.network,
    required this.descriptor,
    this.changeDescriptor,
    required this.createdAt,
    required this.walletType,
    this.externalDerivationPath,
    this.internalDerivationPath,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'network': network.name,
    'descriptor': descriptor,
    'changeDescriptor': changeDescriptor,
    'createdAt': createdAt.toIso8601String(),
    'walletType': walletType.name,
    'externalDerivationPath': externalDerivationPath,
    'internalDerivationPath': internalDerivationPath,
  };

  factory WalletConfig.fromJson(Map<String, dynamic> json) {
    return WalletConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      network: Network.values.byName(json['network'] as String),
      descriptor: json['descriptor'] as String,
      changeDescriptor: json['changeDescriptor'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      walletType: WalletType.values.byName(json['walletType'] as String),
      externalDerivationPath: json['externalDerivationPath'] as String?,
      internalDerivationPath: json['internalDerivationPath'] as String?,
    );
  }
}

/// Wallet type enum
enum WalletType {
  standard,    // BIP84 Native SegWit (bc1...)
  legacy,      // BIP44 Legacy (1...)
  nested,      // BIP49 Nested SegWit (3...)
  taproot,     // BIP86 Taproot (bc1p...)
}

/// Transaction model with meme fields
class BrainrotTransaction {
  final String txid;
  final TransactionDetails details;
  final TransactionStatus status;
  final int? blockHeight;
  final DateTime? timestamp;
  final String? memo;
  final List<String> memeEmojis;

  BrainrotTransaction({
    required this.txid,
    required this.details,
    required this.status,
    this.blockHeight,
    this.timestamp,
    this.memo,
    List<String>? memeEmojis,
  }) : memeEmojis = memeEmojis ?? _generateMemeEmojis(details);

  /// Generate random meme emojis based on transaction
  static List<String> _generateMemeEmojis(TransactionDetails details) {
    final isReceive = details.received > details.sent;
    final amount = isReceive ? details.received : details.sent;

    // Compare BigInt with BigInt thresholds
    if (isReceive) {
      if (amount > BigInt.from(100000000)) return ['🐋', '💎', '🚀']; // Whale alert!
      if (amount > BigInt.from(10000000)) return ['💰', '📈', '🔥'];  // Nice gains
      if (amount > BigInt.from(1000000)) return ['💵', '✨', '😎'];   // Decent stack
      return ['🪙', '📥', '👍'];                         // Every sat counts
    } else {
      if (amount > BigInt.from(100000000)) return ['😭', '💸', 'F'];  // Big spend
      if (amount > BigInt.from(10000000)) return ['💳', '🛍️', '📉'];  // Shopping spree
      return ['📤', '⚡', '🤝'];                         // Normal send
    }
  }

  /// Get transaction amount (positive for receive, negative for send)
  BigInt get netAmount {
    // details.received and details.sent are BigInt
    return details.received - details.sent;
  }

  /// Check if transaction is incoming
  bool get isIncoming => netAmount > BigInt.zero;

  /// Get confirmation count
  int getConfirmations(int currentHeight) {
    if (blockHeight == null || blockHeight == 0) return 0;
    return currentHeight - blockHeight! + 1;
  }

  /// Get meme status message
  String getMemeStatus(int currentHeight) {
    final confirmations = getConfirmations(currentHeight);

    if (status == TransactionStatus.pending) {
      return isIncoming ? 'Incoming tendies! 🍗' : 'Yeeting sats... 🏃‍♂️';
    }

    if (confirmations == 0) return 'In the mempool 🏊‍♂️';
    if (confirmations == 1) return 'First confirmation! 🎯';
    if (confirmations < 3) return 'Almost there... ⏳';
    if (confirmations < 6) return 'Getting safer 🛡️';

    return isIncoming ? 'Funds are SAFU 🔒' : 'Successfully sent 📤';
  }
}

/// Transaction status enum
enum TransactionStatus {
  pending,
  confirmed,
  failed,
}

/// Balance model with meme fields
class BrainrotBalance {
  final int confirmed;      // Confirmed balance in sats
  final int unconfirmed;    // Unconfirmed balance in sats
  final int total;          // Total balance in sats
  final DateTime lastUpdate;

  BrainrotBalance({
    required this.confirmed,
    required this.unconfirmed,
    required this.lastUpdate,
  }) : total = confirmed + unconfirmed;

  /// Get balance in BTC
  double get btc => total / 100000000;
  double get confirmedBtc => confirmed / 100000000;
  double get unconfirmedBtc => unconfirmed / 100000000;

  /// Get meme-themed balance description
  String getMemeDescription() {
    if (total == 0) return 'No sats? NGMI 😢';
    if (total < 100000) return 'Smol stack, keep stacking! 🥺';
    if (total < 1000000) return 'Getting there, anon! 💪';
    if (total < 10000000) return 'Respectable stack 😎';
    if (total < 100000000) return 'Almost a whole coiner! 🎯';
    if (total < 1000000000) return 'Whale alert! 🐋';
    return 'GIGACHAD STACK 💎🙌';
  }
}

/// Address model
class BrainrotAddress {
  final String address;
  final int index;
  final AddressType addressType;
  final String? label;
  final DateTime createdAt;
  final bool isUsed;
  final int? lastUsedBlockHeight;

  BrainrotAddress({
    required this.address,
    required this.index,
    required this.addressType,
    this.label,
    required this.createdAt,
    this.isUsed = false,
    this.lastUsedBlockHeight,
  });

  /// Get address type emoji
  String get typeEmoji {
    switch (addressType) {
      case AddressType.legacy:
        return '👴'; // Legacy
      case AddressType.nestedSegwit:
        return '📦'; // Nested
      case AddressType.nativeSegwit:
        return '⚡'; // Native SegWit
      case AddressType.taproot:
        return '🌳'; // Taproot
      default:
        return '❓';
    }
  }

  Map<String, dynamic> toJson() => {
    'address': address,
    'index': index,
    'addressType': addressType.name,
    'label': label,
    'createdAt': createdAt.toIso8601String(),
    'isUsed': isUsed,
    'lastUsedBlockHeight': lastUsedBlockHeight,
  };

  factory BrainrotAddress.fromJson(Map<String, dynamic> json) {
    return BrainrotAddress(
      address: json['address'] as String,
      index: json['index'] as int,
      addressType: AddressType.values.byName(json['addressType'] as String),
      label: json['label'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isUsed: json['isUsed'] as bool,
      lastUsedBlockHeight: json['lastUsedBlockHeight'] as int?,
    );
  }
}

/// Address type enum
enum AddressType {
  legacy,
  nestedSegwit,
  nativeSegwit,
  taproot,
}

/// UTXO model
class BrainrotUtxo {
  final String txid;
  final int vout;
  final int value;
  final String address;
  final bool isConfirmed;
  final int? blockHeight;

  BrainrotUtxo({
    required this.txid,
    required this.vout,
    required this.value,
    required this.address,
    required this.isConfirmed,
    this.blockHeight,
  });

  /// Get UTXO identifier
  String get outpoint => '$txid:$vout';

  /// Get value in BTC
  double get btc => value / 100000000;
}

/// Recent send address model
class RecentSendAddress {
  final String address;
  final String? label;
  final DateTime lastUsed;
  final int usageCount;

  RecentSendAddress({
    required this.address,
    this.label,
    required this.lastUsed,
    this.usageCount = 1,
  });

  Map<String, dynamic> toJson() => {
    'address': address,
    'label': label,
    'lastUsed': lastUsed.toIso8601String(),
    'usageCount': usageCount,
  };

  factory RecentSendAddress.fromJson(Map<String, dynamic> json) {
    return RecentSendAddress(
      address: json['address'] as String,
      label: json['label'] as String?,
      lastUsed: DateTime.parse(json['lastUsed'] as String),
      usageCount: json['usageCount'] as int? ?? 1,
    );
  }

  RecentSendAddress copyWith({
    String? address,
    String? label,
    DateTime? lastUsed,
    int? usageCount,
  }) {
    return RecentSendAddress(
      address: address ?? this.address,
      label: label ?? this.label,
      lastUsed: lastUsed ?? this.lastUsed,
      usageCount: usageCount ?? this.usageCount,
    );
  }
}

/// Fee estimation model
class FeeEstimate {
  final int fastestFee;    // 1-2 blocks
  final int halfHourFee;   // ~3 blocks
  final int hourFee;       // ~6 blocks
  final int economyFee;    // 12+ blocks
  final DateTime timestamp;

  FeeEstimate({
    required this.fastestFee,
    required this.halfHourFee,
    required this.hourFee,
    required this.economyFee,
    required this.timestamp,
  });

  /// Get meme-themed fee description
  String getMemeFeeDescription(int selectedFee) {
    if (selectedFee >= fastestFee) return 'YOLO MODE 🚀💸';
    if (selectedFee >= halfHourFee) return 'Zoomer Speed ⚡';
    if (selectedFee >= hourFee) return 'Normie Pace 🚶';
    return 'Diamond Hands Mode 💎🐌';
  }
}

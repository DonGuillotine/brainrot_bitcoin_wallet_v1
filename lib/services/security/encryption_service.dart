import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:isolate';
import 'package:cryptography_plus/cryptography_plus.dart';
import 'package:cryptography_flutter_plus/cryptography_flutter_plus.dart';
import 'package:flutter/services.dart';
import '../base/base_service.dart';
import '../base/service_result.dart';

/// Production-ready encryption service using cryptography package
class EncryptionService extends BaseService {
  static const _saltLength = 32;
  static const _keyLength = 32;

  // Argon2id parameters (balanced for mobile)
  static const _argon2Memory = 64 * 1024 * 1024; // 65536 KiB = 64 MiB
  static const _argon2Iterations = 3;
  static const _argon2Parallelism = 4;

  // PBKDF2 parameters (fallback)
  static const _pbkdf2Iterations = 100000;

  // --- FIX: ADD LIGHTWEIGHT TEST PARAMETERS ---
  // These are intentionally weak for fast test execution and MUST NOT be used in production.
  static const _argon2MemoryTest = 8 * 1024; // 8 KiB
  static const _argon2IterationsTest = 1;
  static const _argon2ParallelismTest = 1;
  static const _pbkdf2IterationsTest = 100;

  // Algorithm instances
  late final AesGcm _aesGcm;
  late final Argon2id _argon2id;
  late final Pbkdf2 _pbkdf2;
  late final Sha256 _sha256;
  late final Sha512 _sha512;
  late final Hmac _hmacSha256Algorithm;

  final bool _isTest;

  // Private constructor now accepts the flag
  EncryptionService._({bool isTest = false})
      : _isTest = isTest,
        super('EncryptionService');

  /// Creates and initializes an instance of EncryptionService.
  /// This is required because initialization involves async operations.
  // Static create method now accepts the flag
  static Future<EncryptionService> create({bool isTest = false}) async {
    // Pass the flag to the constructor
    final service = EncryptionService._(isTest: isTest);
    await service._initializeAlgorithms();
    return service;
  }

  /// Initialize cryptographic algorithms
  Future<void> _initializeAlgorithms() async {
    try {
      FlutterCryptography.enable();
      logInfo('Native cryptography acceleration enabled/attempted 🚀');
    } catch (e) {
      logWarning('Failed to enable native cryptography (or not supported): $e');
    }

    if (_isTest) {
      logWarning('🚨 RUNNING IN TEST MODE WITH WEAK CRYPTO PARAMETERS 🚨');
    }

    final argon2Memory = _isTest ? _argon2MemoryTest : _argon2Memory;
    final argon2Iterations = _isTest ? _argon2IterationsTest : _argon2Iterations;
    final argon2Parallelism = _isTest ? _argon2ParallelismTest : _argon2Parallelism;
    final pbkdf2Iterations = _isTest ? _pbkdf2IterationsTest : _pbkdf2Iterations;

    logInfo('Initializing cryptographic algorithms. Is Test: $_isTest');

    _aesGcm = AesGcm.with256bits();

    _argon2id = Argon2id(
      memory: argon2Memory,
      iterations: argon2Iterations,
      parallelism: argon2Parallelism,
      hashLength: _keyLength,
    );

    _hmacSha256Algorithm = Hmac(Sha256());
    _pbkdf2 = Pbkdf2(
      macAlgorithm: _hmacSha256Algorithm,
      iterations: pbkdf2Iterations,
      bits: _keyLength * 8,
    );

    _sha256 = Sha256();
    _sha512 = Sha512();
  }

  /// Generate cryptographically secure random bytes
  Uint8List generateRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => random.nextInt(256)),
    );
  }

  /// Generate salt for key derivation
  Uint8List generateSalt() {
    return generateRandomBytes(_saltLength);
  }

  /// Production-ready key derivation using Argon2id
  Future<ServiceResult<SecretKey>> deriveKey(
      String password,
      Uint8List salt,
      ) async {
    return executeOperation(
      operation: () async {
        logDebug('Starting Argon2id key derivation...');

        try {
          final secretKey = await _deriveKeyArgon2(password, salt);
          logInfo('Key derived using Argon2id 💪');
          return secretKey;
        } catch (e) {
          logWarning('Argon2id failed, falling back to PBKDF2: $e');

          // Fallback to PBKDF2 if Argon2 fails
          final secretKey = await _deriveKeyPbkdf2(password, salt);
          logInfo('Key derived using PBKDF2 🔑');
          return secretKey;
        }
      },
      operationName: 'derive key',
      errorCode: ErrorCodes.encryptionError,
    );
  }

  /// Derive key using Argon2id (runs in isolate for performance)
  Future<SecretKey> _deriveKeyArgon2(String password, Uint8List salt) async {
    // For very long passwords, run in isolate to avoid blocking UI
    // if (password.length > 50) {
    //   logDebug('Password length > 50, using isolate for Argon2id.');
    //   return await _runInIsolate<SecretKey>(
    //     _argon2InIsolate,
    //     _Argon2Params(password: password, salt: salt),
    //   );
    // }

    // For normal passwords, run directly
    return await _argon2id.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  /// Derive key using PBKDF2 (fallback)
  Future<SecretKey> _deriveKeyPbkdf2(String password, Uint8List salt) async {
    return await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  /// Production-ready SHA-256 hashing
  Future<ServiceResult<String>> hashData(String data) async {
    return executeOperation(
      operation: () async {
        final bytes = utf8.encode(data);
        final hash = await _sha256.hash(bytes);
        return base64.encode(hash.bytes);
      },
      operationName: 'hash data',
      errorCode: ErrorCodes.encryptionError,
    );
  }

  /// Hash data with SHA-512 for extra security
  Future<ServiceResult<String>> hashDataSha512(String data) async {
    return executeOperation(
      operation: () async {
        final bytes = utf8.encode(data);
        final hash = await _sha512.hash(bytes);
        return base64.encode(hash.bytes);
      },
      operationName: 'hash data SHA-512',
      errorCode: ErrorCodes.encryptionError,
    );
  }

  /// Create HMAC-SHA256 hash
  Future<ServiceResult<String>> hmacSha256(String data, String key) async {
    return executeOperation(
      operation: () async {
        final secretKey = SecretKey(utf8.encode(key));
        final mac = await _hmacSha256Algorithm.calculateMac(
          utf8.encode(data),
          secretKey: secretKey,
        );
        return base64.encode(mac.bytes);
      },
      operationName: 'HMAC-SHA256',
      errorCode: ErrorCodes.encryptionError,
    );
  }

  /// Encrypt data with password using AES-GCM
  Future<ServiceResult<String>> encryptWithPassword({
    required String plainText,
    required String password,
  }) async {
    return executeOperation(
      operation: () async {
        // Generate salt and derive key
        final salt = generateSalt();
        final keyResult = await deriveKey(password, salt);
        if (keyResult.isError) {
          throw keyResult.errorOrNull!;
        }

        final secretKey = keyResult.valueOrNull!;

        // Encrypt with AES-GCM
        final secretBox = await _aesGcm.encrypt(
          utf8.encode(plainText),
          secretKey: secretKey,
        );

        // Combine salt, nonce, mac, and ciphertext
        final encrypted = EncryptedData(
          salt: salt,
          nonce: secretBox.nonce,
          mac: secretBox.mac.bytes,
          ciphertext: secretBox.cipherText,
        );

        return encrypted.toBase64();
      },
      operationName: 'encrypt with password',
      errorCode: ErrorCodes.encryptionError,
    );
  }

  /// Decrypt data with password using AES-GCM
  Future<ServiceResult<String>> decryptWithPassword({
    required String encryptedData,
    required String password,
  }) async {
    return executeOperation(
      operation: () async {
        // Parse encrypted data
        final encrypted = EncryptedData.fromBase64(encryptedData);

        // Derive key
        final keyResult = await deriveKey(password, encrypted.salt);
        if (keyResult.isError) {
          throw keyResult.errorOrNull!;
        }

        final secretKey = keyResult.valueOrNull!;

        // Reconstruct SecretBox
        final secretBox = SecretBox(
          encrypted.ciphertext,
          nonce: encrypted.nonce,
          mac: Mac(encrypted.mac),
        );

        // Decrypt with AES-GCM
        final decrypted = await _aesGcm.decrypt(
          secretBox,
          secretKey: secretKey,
        );

        return utf8.decode(decrypted);
      },
      operationName: 'decrypt with password',
      errorCode: ErrorCodes.encryptionError,
    );
  }

  /// Generate BIP39 mnemonic entropy
  Future<ServiceResult<Uint8List>> generateMnemonicEntropy({
    int strength = 128, // 12 words = 128 bits
  }) async {
    return executeOperation(
      operation: () async {
        if (strength % 32 != 0 || strength < 128 || strength > 256) {
          throw ArgumentError(
            'Strength must be 128, 160, 192, 224, or 256 bits',
          );
        }

        // Generate cryptographically secure random entropy
        final entropy = generateRandomBytes(strength ~/ 8);

        // Verify entropy quality (basic check)
        final uniqueBytes = entropy.toSet().length;
        if (uniqueBytes < (strength ~/ 16)) {
          throw Exception('Generated entropy has poor randomness');
        }

        return entropy;
      },
      operationName: 'generate mnemonic entropy',
      errorCode: ErrorCodes.encryptionError,
    );
  }

  /// Generate secure PIN with proper randomness
  String generateSecurePin({int length = 6}) {
    final random = Random.secure();
    final pin = StringBuffer();

    for (int i = 0; i < length; i++) {
      pin.write(random.nextInt(10));
    }

    return pin.toString();
  }

  /// Verify password against hash (for PIN/password verification)
  Future<ServiceResult<bool>> verifyPassword({
    required String password,
    required String hashedPassword,
    required Uint8List salt,
  }) async {
    return executeOperation(
      operation: () async {
        final keyResult = await deriveKey(password, salt);
        if (keyResult.isError) return false;

        final secretKey = keyResult.valueOrNull!;
        final keyBytes = await secretKey.extractBytes();
        final keyHash = base64.encode(keyBytes);

        return keyHash == hashedPassword;
      },
      operationName: 'verify password',
      errorCode: ErrorCodes.authFailed,
    );
  }

  /// Run expensive operations in isolate
  Future<T> _runInIsolate<T>(
      Future<T> Function(dynamic) function,
      dynamic params,
      ) async {
    final receivePort = ReceivePort();

    await Isolate.spawn(
      _isolateEntry,
      _IsolateParams(
        sendPort: receivePort.sendPort,
        function: function,
        params: params,
      ),
      onError: receivePort.sendPort, // Send errors back to the main isolate
      onExit: receivePort.sendPort,   // Send exit signals
    );

    // Listen for the first message, which could be data, error, or null (on exit)
    final result = await receivePort.first;
    if (result == null) {
      throw Exception('Isolate exited unexpectedly without a result.');
    }
    if (result is List && result.length == 2 && result[0] is String) { // Check if it's an error from Isolate.spawn's onError
      throw Exception('Isolate error: ${result[0]}\nStack trace: ${result[1]}');
    }
    // Check if the result is an exception re-thrown by our _isolateEntry
    if (result is Exception || result is Error) {
      throw result;
    }
    return result as T;
  }

  /// Isolate entry point
  static void _isolateEntry(_IsolateParams params) async {
    try {
      final result = await params.function(params.params);
      Isolate.exit(params.sendPort, result); // Use Isolate.exit for cleaner termination with result
    } catch (e, s) {
      // If the function inside the isolate throws, send the error back.
      // Note: The `onError` of Isolate.spawn might also catch unhandled errors.
      // This explicit catch ensures our specific function's errors are handled.
      Isolate.exit(params.sendPort, Exception('Error in isolate: $e\n$s'));
    }
  }

  /// Secure cleanup of sensitive data
  void secureCleanup(Uint8List data) {
    // Overwrite with random data
    final random = Random.secure();
    for (int i = 0; i < data.length; i++) {
      data[i] = random.nextInt(256);
    }
  }
}

/// Encrypted data container
class EncryptedData {
  final Uint8List salt;
  final List<int> nonce;
  final List<int> mac;
  final List<int> ciphertext;

  EncryptedData({
    required this.salt,
    required this.nonce,
    required this.mac,
    required this.ciphertext,
  });

  /// Serialize to JSON
  Map<String, dynamic> toJson() => {
    'salt': base64.encode(salt),
    'nonce': base64.encode(nonce),
    'mac': base64.encode(mac),
    'ciphertext': base64.encode(ciphertext),
  };

  /// Deserialize from JSON
  factory EncryptedData.fromJson(Map<String, dynamic> json) {
    return EncryptedData(
      salt: base64.decode(json['salt'] as String),
      nonce: base64.decode(json['nonce'] as String),
      mac: base64.decode(json['mac'] as String),
      ciphertext: base64.decode(json['ciphertext'] as String),
    );
  }

  /// Convert to base64 string
  String toBase64() {
    return base64.encode(utf8.encode(jsonEncode(toJson())));
  }

  /// Create from base64 string
  factory EncryptedData.fromBase64(String encoded) {
    final json = jsonDecode(utf8.decode(base64.decode(encoded)));
    return EncryptedData.fromJson(json as Map<String, dynamic>);
  }
}

/// Parameters for Argon2 in isolate
class _Argon2Params {
  final String password;
  final Uint8List salt;

  _Argon2Params({
    required this.password,
    required this.salt,
  });
}

/// Parameters for isolate execution
class _IsolateParams {
  final SendPort sendPort;
  final Future<dynamic> Function(dynamic) function;
  final dynamic params;

  _IsolateParams({
    required this.sendPort,
    required this.function,
    required this.params,
  });
}

/// Argon2 execution in isolate
// Future<SecretKey> _argon2InIsolate(dynamic params) async { // Changed parameter type to dynamic
//   // Cast the dynamic params to the expected type
//   final argon2Params = params as _Argon2Params;
//
//   // Re-initialize Argon2 in isolate
//   // It's good practice to initialize algorithms here if they are not already
//   // or pass them as part of the params if they are complex to recreate.
//   // For this specific case, re-initializing is fine as Argon2id is lightweight to create.
//   final argon2id = Argon2id(
//     memory: EncryptionService._argon2Memory,
//     iterations: EncryptionService._argon2Iterations,
//     parallelism: EncryptionService._argon2Parallelism,
//     hashLength: EncryptionService._keyLength,
//   );
//
//   return await argon2id.deriveKey(
//     secretKey: SecretKey(utf8.encode(argon2Params.password)),
//     nonce: argon2Params.salt,
//   );
// }

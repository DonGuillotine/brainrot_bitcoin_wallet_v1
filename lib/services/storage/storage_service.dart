import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../base/base_service.dart';
import '../base/service_result.dart';
import '../security/encryption_service.dart';
import '../../main.dart';

/// Service for handling local storage operations
class StorageService extends BaseService {
  static const _defaultBoxName = 'brainrot_storage';
  static const _secureBoxName = 'brainrot_secure';

  final EncryptionService _encryptionService;
  final Map<String, Box> _openBoxes = {};

  StorageService(this._encryptionService) : super('StorageService');

  /// Initialize storage
  Future<ServiceResult<void>> initialize() async {
    return executeOperation(
      operation: () async {
        // Open default box
        await openBox(_defaultBoxName);

        logInfo('Storage initialized successfully');
      },
      operationName: 'initialize storage',
      errorCode: ErrorCodes.storageError,
    );
  }

  /// Open a Hive box
  Future<ServiceResult<Box>> openBox(String boxName) async {
    return executeOperation(
      operation: () async {
        if (_openBoxes.containsKey(boxName)) {
          return _openBoxes[boxName]!;
        }

        final box = await Hive.openBox(boxName);
        _openBoxes[boxName] = box;

        return box;
      },
      operationName: 'open box $boxName',
      errorCode: ErrorCodes.storageError,
    );
  }

  /// Store value in box
  Future<ServiceResult<void>> setValue<T>({
    required String key,
    required T value,
    String? boxName,
  }) async {
    return executeOperation(
      operation: () async {
        final box = boxName != null
            ? (await openBox(boxName)).valueOrNull!
            : _openBoxes[_defaultBoxName]!;

        await box.put(key, value);
      },
      operationName: 'set value $key',
      errorCode: ErrorCodes.storageError,
    );
  }

  /// Get value from box
  Future<ServiceResult<T?>> getValue<T>({
    required String key,
    String? boxName,
  }) async {
    return executeOperation(
      operation: () async {
        final box = boxName != null
            ? (await openBox(boxName)).valueOrNull!
            : _openBoxes[_defaultBoxName]!;

        return box.get(key) as T?;
      },
      operationName: 'get value $key',
      errorCode: ErrorCodes.storageError,
    );
  }

  /// Delete value from box
  Future<ServiceResult<void>> deleteValue({
    required String key,
    String? boxName,
  }) async {
    return executeOperation(
      operation: () async {
        final box = boxName != null
            ? (await openBox(boxName)).valueOrNull!
            : _openBoxes[_defaultBoxName]!;

        await box.delete(key);
      },
      operationName: 'delete value $key',
      errorCode: ErrorCodes.storageError,
    );
  }

  /// Store encrypted value
  Future<ServiceResult<void>> setSecureValue({
    required String key,
    required String value,
    required String password,
  }) async {
    return executeOperation(
      operation: () async {
        // Encrypt the value using the production-ready encryption
        final encryptedResult = await _encryptionService.encryptWithPassword(
          plainText: value,
          password: password,
        );

        if (encryptedResult.isError) {
          throw encryptedResult.errorOrNull!;
        }

        // Store in secure storage
        await secureStorage.write(
          key: key,
          value: encryptedResult.valueOrNull!,
        );
      },
      operationName: 'set secure value $key',
      errorCode: ErrorCodes.storageError,
    );
  }

  /// Get encrypted value
  Future<ServiceResult<String?>> getSecureValue({
    required String key,
    required String password,
  }) async {
    return executeOperation(
      operation: () async {
        // Get encrypted value
        final encrypted = await secureStorage.read(key: key);
        if (encrypted == null) return null;

        // Decrypt the value using the production-ready decryption
        final decryptedResult = await _encryptionService.decryptWithPassword(
          encryptedData: encrypted,
          password: password,
        );

        if (decryptedResult.isError) {
          throw decryptedResult.errorOrNull!;
        }

        return decryptedResult.valueOrNull;
      },
      operationName: 'get secure value $key',
      errorCode: ErrorCodes.storageError,
    );
  }

  /// Clear all data (nuclear option)
  Future<ServiceResult<void>> nukeAllData() async {
    return executeOperation(
      operation: () async {
        // Clear all Hive boxes
        for (final box in _openBoxes.values) {
          await box.clear();
        }

        // Clear secure storage
        await secureStorage.deleteAll();

        // Clear shared preferences
        await prefs.clear();

        logWarning('All data has been nuked! 💥');
      },
      operationName: 'nuke all data',
      errorCode: ErrorCodes.storageError,
    );
  }

  /// Export wallet data
  Future<ServiceResult<String>> exportWalletData({
    required Map<String, dynamic> walletData,
    required String password,
  }) async {
    return executeOperation(
      operation: () async {
        final jsonData = jsonEncode(walletData);

        // Encrypt the export
        final encryptedResult = await _encryptionService.encryptWithPassword(
          plainText: jsonData,
          password: password,
        );

        if (encryptedResult.isError) {
          throw encryptedResult.errorOrNull!;
        }

        return encryptedResult.valueOrNull!;
      },
      operationName: 'export wallet data',
      errorCode: ErrorCodes.storageError,
    );
  }

  /// Import wallet data
  Future<ServiceResult<Map<String, dynamic>>> importWalletData({
    required String encryptedData,
    required String password,
  }) async {
    return executeOperation(
      operation: () async {
        // Decrypt the import
        final decryptedResult = await _encryptionService.decryptWithPassword(
          encryptedData: encryptedData,
          password: password,
        );

        if (decryptedResult.isError) {
          throw decryptedResult.errorOrNull!;
        }

        return jsonDecode(decryptedResult.valueOrNull!) as Map<String, dynamic>;
      },
      operationName: 'import wallet data',
      errorCode: ErrorCodes.storageError,
    );
  }
}

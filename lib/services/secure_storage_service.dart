import 'package:encrypt/encrypt.dart';
import '../main.dart';

/// Secure storage service for sensitive data
class SecureStorageService {
  static const _keyPrefix = 'brainrot_';

  /// Store encrypted value
  static Future<void> storeSecure(String key, String value) async {
    try {
      await secureStorage.write(
        key: '$_keyPrefix$key',
        value: value,
      );
      logger.d('Stored secure value for key: $key');
    } catch (e) {
      logger.e('Error storing secure value', error: e);
      rethrow;
    }
  }

  /// Retrieve encrypted value
  static Future<String?> getSecure(String key) async {
    try {
      final value = await secureStorage.read(key: '$_keyPrefix$key');
      logger.d('Retrieved secure value for key: $key');
      return value;
    } catch (e) {
      logger.e('Error retrieving secure value', error: e);
      return null;
    }
  }

  /// Delete encrypted value
  static Future<void> deleteSecure(String key) async {
    try {
      await secureStorage.delete(key: '$_keyPrefix$key');
      logger.d('Deleted secure value for key: $key');
    } catch (e) {
      logger.e('Error deleting secure value', error: e);
      rethrow;
    }
  }

  /// Clear all secure storage
  static Future<void> clearAll() async {
    try {
      await secureStorage.deleteAll();
      logger.w('Cleared all secure storage');
    } catch (e) {
      logger.e('Error clearing secure storage', error: e);
      rethrow;
    }
  }

  /// Additional encryption layer for ultra-sensitive data
  static String encryptData(String plainText, String password) {
    final key = Key.fromUtf8(password.padRight(32, '0').substring(0, 32));
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(key));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  /// Decrypt data
  static String decryptData(String encryptedData, String password) {
    try {
      final parts = encryptedData.split(':');
      if (parts.length != 2) throw Exception('Invalid encrypted data');

      final key = Key.fromUtf8(password.padRight(32, '0').substring(0, 32));
      final iv = IV.fromBase64(parts[0]);
      final encrypter = Encrypter(AES(key));
      final encrypted = Encrypted.fromBase64(parts[1]);

      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      logger.e('Error decrypting data', error: e);
      throw Exception('Decryption failed');
    }
  }
}

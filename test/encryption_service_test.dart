import 'dart:convert';
import 'package:brainrot_bitcoin_wallet_v1/services/base/service_result.dart';
import 'package:brainrot_bitcoin_wallet_v1/services/logger_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brainrot_bitcoin_wallet_v1/services/security/encryption_service.dart';
import 'package:brainrot_bitcoin_wallet_v1/main.dart' as app_main;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EncryptionService encryptionService;

  setUpAll(() async {
    app_main.logger = LoggerService.createLogger();
    print('Global logger initialized for testing.');

    encryptionService = await EncryptionService.create(isTest: true);

    print('EncryptionService initialized for testing.');
  });

  group('EncryptionService Tests -', () {
    test('Key Derivation should succeed', () async {
      print('🧪 Testing key derivation...');
      final salt = encryptionService.generateSalt();

      final keyResult = await encryptionService.deriveKey('MySecurePassword123!', salt);

      expect(keyResult.isSuccess, isTrue, reason: 'Key derivation failed: ${keyResult.errorOrNull}');
      expect(keyResult.valueOrNull, isNotNull);
      print('✅ Key derivation successful.');
    });

    test('SHA-256 Hashing should succeed', () async {
      print('🧪 Testing SHA-256 hashing...');
      final dataToHash = 'Hello, Brainrot Wallet!';
      final hashResult = await encryptionService.hashData(dataToHash);

      expect(hashResult.isSuccess, isTrue, reason: 'Hashing failed: ${hashResult.errorOrNull}');
      expect(hashResult.valueOrNull, isA<String>());
      expect(hashResult.valueOrNull!.isNotEmpty, isTrue);
      print('✅ Hash: ${hashResult.valueOrNull}');

      final hashResult2 = await encryptionService.hashData(dataToHash);
      expect(hashResult2.valueOrNull, equals(hashResult.valueOrNull));
    });

    test('AES-GCM Encryption and Decryption should succeed', () async {
      print('🧪 Testing AES-GCM encryption/decryption...');
      const testData = 'My Bitcoin seed phrase: moon lambo hodl wagmi ngmi gm';
      const password = 'ToTheMoon123!';

      final encryptResult = await encryptionService.encryptWithPassword(
        plainText: testData,
        password: password,
      );

      expect(encryptResult.isSuccess, isTrue, reason: 'Encryption failed: ${encryptResult.errorOrNull}');
      expect(encryptResult.valueOrNull, isA<String>());
      expect(encryptResult.valueOrNull!.isNotEmpty, isTrue);
      print('✅ Encrypted: ${encryptResult.valueOrNull!.substring(0, min(50, encryptResult.valueOrNull!.length))}...');

      final decryptResult = await encryptionService.decryptWithPassword(
        encryptedData: encryptResult.valueOrNull!,
        password: password,
      );

      expect(decryptResult.isSuccess, isTrue, reason: 'Decryption failed: ${decryptResult.errorOrNull}');
      expect(decryptResult.valueOrNull, equals(testData));
      print('✅ Decrypted: ${decryptResult.valueOrNull}');
    });

    test('AES-GCM Decryption should fail with wrong password', () async {
      print('🧪 Testing AES-GCM decryption with wrong password...');
      const testData = 'Another secret piece of data.';
      const correctPassword = 'CorrectPassword123';
      const wrongPassword = 'WrongPassword!!!';

      final encryptResult = await encryptionService.encryptWithPassword(
        plainText: testData,
        password: correctPassword,
      );
      expect(encryptResult.isSuccess, isTrue, reason: 'Encryption (setup for fail test) failed.');

      final decryptResult = await encryptionService.decryptWithPassword(
        encryptedData: encryptResult.valueOrNull!,
        password: wrongPassword,
      );

      expect(decryptResult.isError, isTrue, reason: 'Decryption should have failed with wrong password.');
      print('✅ Decryption correctly failed with wrong password: ${decryptResult.errorOrNull}');
    });


    test('Mnemonic Entropy Generation should succeed', () async {
      print('🧪 Testing mnemonic entropy generation...');
      final entropyResultDefault = await encryptionService.generateMnemonicEntropy();
      expect(entropyResultDefault.isSuccess, isTrue, reason: 'Entropy (default) generation failed: ${entropyResultDefault.errorOrNull}');
      final entropyDefault = entropyResultDefault.valueOrNull!;
      expect(entropyDefault.length, 128 ~/ 8);
      print('✅ Generated ${entropyDefault.length * 8}-bit entropy (default)');

      final entropyResult256 = await encryptionService.generateMnemonicEntropy(strength: 256);
      expect(entropyResult256.isSuccess, isTrue, reason: 'Entropy (256-bit) generation failed: ${entropyResult256.errorOrNull}');
      final entropy256 = entropyResult256.valueOrNull!;
      expect(entropy256.length, 256 ~/ 8);
      print('✅ Generated ${entropy256.length * 8}-bit entropy (256-bit)');
    });

    test('Mnemonic Entropy Generation should fail for invalid strength', () async {
      print('🧪 Testing mnemonic entropy generation with invalid strength...');
      // Test with invalid strength
      final entropyResultInvalid = await encryptionService.generateMnemonicEntropy(strength: 100); // Not a multiple of 32

      expect(entropyResultInvalid.isError, isTrue, reason: 'Entropy generation should fail for invalid strength.');

      expect(entropyResultInvalid.errorOrNull, isA<ServiceException>());

      expect((entropyResultInvalid.errorOrNull as ServiceException).originalError, isA<ArgumentError>());

      print('✅ Entropy generation correctly failed for invalid strength: ${entropyResultInvalid.errorOrNull}');
    });

    test('Secure PIN Generation should produce PIN of correct length', () {
      print('🧪 Testing secure PIN generation...');
      final pin6 = encryptionService.generateSecurePin();
      expect(pin6.length, 6);
      expect(int.tryParse(pin6), isNotNull);

      final pin8 = encryptionService.generateSecurePin(length: 8);
      expect(pin8.length, 8);
      expect(int.tryParse(pin8), isNotNull);
      print('✅ PINs generated successfully.');
    });

    test('Password Verification should succeed for correct password and fail for incorrect', () async {
      print('🧪 Testing password verification...');
      const password = "testVerifyPassword123";
      final salt = encryptionService.generateSalt();

      final keyDerivationResult = await encryptionService.deriveKey(password, salt);
      expect(keyDerivationResult.isSuccess, isTrue, reason: "Initial key derivation for test setup failed");
      final derivedKey = keyDerivationResult.valueOrNull!;
      final keyBytes = await derivedKey.extractBytes();
      final storedHashedKey = base64.encode(keyBytes);

      final verifyCorrectResult = await encryptionService.verifyPassword(
        password: password,
        hashedPassword: storedHashedKey,
        salt: salt,
      );
      expect(verifyCorrectResult.isSuccess, isTrue, reason: "Verification with correct password resulted in error state");
      expect(verifyCorrectResult.valueOrNull, isTrue, reason: "Verification with correct password failed");
      print('✅ Password verification successful for correct password.');

      final verifyIncorrectResult = await encryptionService.verifyPassword(
        password: "wrongTestPasswordXXX",
        hashedPassword: storedHashedKey,
        salt: salt,
      );
      expect(verifyIncorrectResult.isSuccess, isTrue, reason: "Verification with incorrect password resulted in error state (expected success state with false value)");
      expect(verifyIncorrectResult.valueOrNull, isFalse, reason: "Verification with incorrect password unexpectedly succeeded");
      print('✅ Password verification correctly failed for incorrect password.');
    });


    test('Hashing an empty string should produce a valid hash', () async {
      final hashResult = await encryptionService.hashData('');
      expect(hashResult.isSuccess, isTrue);
      expect(hashResult.valueOrNull, isNotNull);
      const knownBase64HashOfEmpty = '47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=';

      expect(hashResult.valueOrNull, equals(knownBase64HashOfEmpty));
    });

    test('Encrypting an empty string should succeed and decrypt back to empty', () async {
      final encryptResult = await encryptionService.encryptWithPassword(
        plainText: '',
        password: 'passwordForEmpty',
      );
      expect(encryptResult.isSuccess, isTrue);

      final decryptResult = await encryptionService.decryptWithPassword(
        encryptedData: encryptResult.valueOrNull!,
        password: 'passwordForEmpty',
      );
      expect(decryptResult.isSuccess, isTrue);
      expect(decryptResult.valueOrNull, equals(''));
    });

    test('Password Verification should fail with correct password but wrong salt', () async {
      print('🧪 Testing verification with wrong salt...');
      const password = "mySuperSecurePassword";
      final salt1 = encryptionService.generateSalt();
      final salt2 = encryptionService.generateSalt();

      // Derive key with the first salt
      final keyDerivationResult = await encryptionService.deriveKey(password, salt1);
      final storedHashedKey = base64.encode(await keyDerivationResult.valueOrNull!.extractBytes());

      // Try to verify with the second salt
      final verifyResult = await encryptionService.verifyPassword(
        password: password, // Correct password
        hashedPassword: storedHashedKey,
        salt: salt2, // INCORRECT salt
      );

      expect(verifyResult.isSuccess, isTrue);
      expect(verifyResult.valueOrNull, isFalse, reason: "Verification should fail with wrong salt");
      print('✅ Password verification correctly failed with the wrong salt.');
    });

    test('Decryption should fail with tampered data (corrupted payload)', () async {
      print('🧪 Testing decryption with tampered data...');
      const testData = 'This data must not be tampered with.';
      const password = 'securePassword123';

      final encryptResult = await encryptionService.encryptWithPassword(
        plainText: testData,
        password: password,
      );

      final validEncryptedString = encryptResult.valueOrNull!;

      // Tamper with the data
      final tamperedPayload = validEncryptedString.replaceFirst('A', 'B');

      final decryptResult = await encryptionService.decryptWithPassword(
        encryptedData: tamperedPayload,
        password: password,
      );

      expect(decryptResult.isError, isTrue);
      print('✅ Decryption correctly failed for tampered data: ${decryptResult.errorOrNull}');
    });
  });
}

// Helper for print statements
int min(int a, int b) => a < b ? a : b;

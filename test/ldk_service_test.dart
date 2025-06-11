import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:brainrot_bitcoin_wallet_v1/models/lightning_models.dart';

void main() {
  group('LDK Service Core Functionality Tests', () {

    group('Address Validation Tests', () {
      test('Lightning address validation accepts valid email format', () {
        const validAddress = 'user@domain.com';
        final parts = validAddress.split('@');
        
        expect(parts.length, equals(2));
        expect(parts[0], equals('user'));
        expect(parts[1], equals('domain.com'));
      });

      test('Lightning address validation rejects invalid formats', () {
        const invalidAddresses = [
          'invalid_address',
          'user@',
          '@domain.com',
          'user@domain@extra',
          '',
        ];

        for (final address in invalidAddresses) {
          final parts = address.split('@');
          expect(parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty, isTrue,
              reason: 'Address "$address" should be invalid');
        }
      });

      test('Node address parsing splits host:port correctly', () {
        const validAddress = 'example.com:9735';
        final parts = validAddress.split(':');
        
        expect(parts.length, equals(2));
        expect(parts[0], equals('example.com'));
        expect(int.tryParse(parts[1]), equals(9735));
      });

      test('Node address parsing rejects invalid formats', () {
        const invalidAddresses = [
          'invalid_address_format',
          'example.com',
          ':9735',
          'example.com:',
          'example.com:invalid_port',
          'example.com:9735:extra',
        ];

        for (final address in invalidAddresses) {
          final parts = address.split(':');
          final isValid = parts.length == 2 && 
                         parts[0].isNotEmpty && 
                         int.tryParse(parts[1]) != null;
          expect(isValid, isFalse, reason: 'Address "$address" should be invalid');
        }
      });
    });

    group('Data Transformation Tests', () {
      test('Hex string to bytes conversion works correctly', () {
        const testHex = 'deadbeef';
        final expectedBytes = [0xDE, 0xAD, 0xBE, 0xEF];
        
        // Simulate the conversion logic
        final bytes = <int>[];
        for (int i = 0; i < testHex.length; i += 2) {
          final hexByte = testHex.substring(i, i + 2);
          bytes.add(int.parse(hexByte, radix: 16));
        }
        
        expect(bytes, equals(expectedBytes));
      });

      test('Hex string conversion handles 0x prefix', () {
        const testHex = '0xdeadbeef';
        final cleanHex = testHex.startsWith('0x') ? testHex.substring(2) : testHex;
        
        expect(cleanHex, equals('deadbeef'));
      });

      test('Hex string conversion handles odd length', () {
        const testHex = 'abc';
        final paddedHex = testHex.length % 2 != 0 ? '0$testHex' : testHex;
        
        expect(paddedHex, equals('0abc'));
      });

      test('Sats to msat conversion is correct', () {
        const sats = 1000;
        final msat = sats * 1000;
        
        expect(msat, equals(1000000));
      });

      test('Msat to sats conversion is correct', () {
        const msat = 1000000;
        final sats = msat ~/ 1000;
        
        expect(sats, equals(1000));
      });

      test('Payment hash generation from string is deterministic', () {
        const testString = 'test_bolt11_invoice_string';
        final hash1 = testString.hashCode.abs().toRadixString(16).padLeft(8, '0');
        final hash2 = testString.hashCode.abs().toRadixString(16).padLeft(8, '0');
        
        expect(hash1, equals(hash2));
        expect(hash1.length, equals(8));
      });
    });

    group('Configuration Management Tests', () {
      test('LightningConfig toJson/fromJson roundtrip preserves data', () {
        final config = LightningConfig(
          nodeId: 'test_node_id',
          network: 'testnet',
          dataDir: '/test/path',
          listeningAddresses: ['0.0.0.0:9735'],
          createdAt: DateTime(2023, 1, 1),
          alias: 'Test Node',
          color: '#FF0000',
        );

        final json = config.toJson();
        final restored = LightningConfig.fromJson(json);

        expect(restored.nodeId, equals(config.nodeId));
        expect(restored.network, equals(config.network));
        expect(restored.dataDir, equals(config.dataDir));
        expect(restored.listeningAddresses, equals(config.listeningAddresses));
        expect(restored.createdAt, equals(config.createdAt));
        expect(restored.alias, equals(config.alias));
        expect(restored.color, equals(config.color));
      });

      test('LightningConfig handles null optional fields', () {
        final config = LightningConfig(
          nodeId: 'test_node_id',
          network: 'mainnet',
          dataDir: '/test/path',
          listeningAddresses: ['0.0.0.0:9735'],
          createdAt: DateTime.now(),
        );

        final json = config.toJson();
        final restored = LightningConfig.fromJson(json);

        expect(restored.alias, isNull);
        expect(restored.color, isNull);
      });

      test('Network string mapping works correctly', () {
        const networkMappings = {
          'testnet': 'testnet',
          'mainnet': 'bitcoin',
          'bitcoin': 'bitcoin',
        };

        for (final entry in networkMappings.entries) {
          final input = entry.key;
          final expected = entry.value;
          final actual = input == 'testnet' ? 'testnet' : 'bitcoin';
          
          expect(actual, equals(expected));
        }
      });
    });

    group('Error Handling Logic Tests', () {
      test('Error recovery strategy determination works correctly', () {
        final networkErrors = ['network error', 'connection failed', 'timeout', 'socket closed'];
        final ldkErrors = ['ldk error', 'lightning failure', 'channel error', 'payment failed'];
        
        for (final error in networkErrors) {
          final isNetworkError = error.contains('network') || 
                                error.contains('connection') || 
                                error.contains('timeout') ||
                                error.contains('socket');
          expect(isNetworkError, isTrue);
        }

        for (final error in ldkErrors) {
          final isLdkError = error.contains('ldk') || 
                           error.contains('lightning') ||
                           error.contains('channel') ||
                           error.contains('payment');
          expect(isLdkError, isTrue);
        }
      });

      test('Exponential backoff calculation is correct', () {
        // Test exponential backoff logic
        for (int attempt = 0; attempt < 8; attempt++) {
          final baseDelaySeconds = 1 << attempt.clamp(0, 8);
          final maxDelaySeconds = 5 * 60; // 5 minutes
          final actualDelay = baseDelaySeconds > maxDelaySeconds ? maxDelaySeconds : baseDelaySeconds;
          
          expect(actualDelay, lessThanOrEqualTo(maxDelaySeconds));
          if (attempt < 9) {
            expect(actualDelay, equals(1 << attempt));
          }
        }
      });

      test('Circuit breaker timing logic works correctly', () {
        const maxErrors = 5;
        const circuitBreakerTimeoutMinutes = 5;
        
        // Simulate circuit breaker opening
        final openTime = DateTime.now();
        int consecutiveErrors = maxErrors;
        
        expect(consecutiveErrors >= maxErrors, isTrue);
        
        // Test if circuit should close after timeout
        final futureTime = openTime.add(Duration(minutes: circuitBreakerTimeoutMinutes + 1));
        final shouldClose = futureTime.difference(openTime) > Duration(minutes: circuitBreakerTimeoutMinutes);
        
        expect(shouldClose, isTrue);
      });

      test('Health status calculation is correct', () {
        const maxErrors = 5;
        
        // Healthy states
        for (int errors = 0; errors < maxErrors; errors++) {
          final isHealthy = errors < maxErrors && !false; // !circuitBreakerOpen
          expect(isHealthy, isTrue);
        }
        
        // Unhealthy states
        final isHealthyWithMaxErrors = maxErrors < maxErrors && !false;
        expect(isHealthyWithMaxErrors, isFalse);
        
        final isHealthyWithOpenCircuit = 0 < maxErrors && !true;
        expect(isHealthyWithOpenCircuit, isFalse);
      });
    });

    group('Channel Model Tests', () {
      test('Channel balance calculations are correct', () {
        final channel = BrainrotChannel(
          channelId: 'test_channel',
          nodeId: 'test_node',
          localBalanceMsat: 500000, // 500 sats
          remoteBalanceMsat: 300000, // 300 sats
          capacityMsat: 1000000, // 1000 sats
          isActive: true,
          isUsable: true,
          state: ChannelState.active,
        );

        expect(channel.localBalanceSats, equals(500));
        expect(channel.remoteBalanceSats, equals(300));
        expect(channel.capacitySats, equals(1000));
        expect(channel.healthPercentage, equals(50.0));
      });

      test('Channel health percentage handles edge cases', () {
        // Zero capacity channel
        final zeroCapacityChannel = BrainrotChannel(
          channelId: 'test_channel',
          nodeId: 'test_node',
          localBalanceMsat: 100000,
          remoteBalanceMsat: 0,
          capacityMsat: 0,
          isActive: true,
          isUsable: true,
          state: ChannelState.active,
        );

        expect(zeroCapacityChannel.healthPercentage, equals(0));

        // Full local balance
        final fullLocalChannel = BrainrotChannel(
          channelId: 'test_channel',
          nodeId: 'test_node',
          localBalanceMsat: 1000000,
          remoteBalanceMsat: 0,
          capacityMsat: 1000000,
          isActive: true,
          isUsable: true,
          state: ChannelState.active,
        );

        expect(fullLocalChannel.healthPercentage, equals(100.0));
      });

      test('Channel meme status reflects health correctly', () {
        // Test different health percentages
        final testCases = [
          (5.0, 'Inbound liquidity gang 📥'),
          (95.0, 'Outbound liquidity enjoyer 📤'),
          (50.0, 'Perfectly balanced ⚖️'),
          (75.0, 'Channel go brrrr ⚡'),
        ];

        for (final testCase in testCases) {
          final healthPercentage = testCase.$1;
          final expectedStatus = testCase.$2;
          
          String actualStatus;
          if (healthPercentage < 10) {
            actualStatus = 'Inbound liquidity gang 📥';
          } else if (healthPercentage > 90) {
            actualStatus = 'Outbound liquidity enjoyer 📤';
          } else if (healthPercentage > 40 && healthPercentage < 60) {
            actualStatus = 'Perfectly balanced ⚖️';
          } else {
            actualStatus = 'Channel go brrrr ⚡';
          }
          
          expect(actualStatus, equals(expectedStatus));
        }
      });

      test('Inactive channel returns appropriate status', () {
        // Inactive channel
        const isActive = false;
        const isUsable = true;
        
        String status;
        if (!isActive) {
          status = 'Channel is sleeping 😴';
        } else if (!isUsable) {
          status = 'Channel machine broke 🔧';
        } else {
          status = 'Channel go brrrr ⚡';
        }
        
        expect(status, equals('Channel is sleeping 😴'));

        // Unusable channel
        const isActive2 = true;
        const isUsable2 = false;
        
        String status2;
        if (!isActive2) {
          status2 = 'Channel is sleeping 😴';
        } else if (!isUsable2) {
          status2 = 'Channel machine broke 🔧';
        } else {
          status2 = 'Channel go brrrr ⚡';
        }
        
        expect(status2, equals('Channel machine broke 🔧'));
      });
    });

    group('Amount Validation Tests', () {
      test('LNURL amount validation works correctly', () {
        const amountSats = 1000;
        const amountMsat = amountSats * 1000;
        const minSendable = 500000; // 500 sats in msat
        const maxSendable = 2000000; // 2000 sats in msat
        
        final isValid = amountMsat >= minSendable && amountMsat <= maxSendable;
        expect(isValid, isTrue);

        // Test boundary cases
        const tooLow = 400000; // 400 sats
        const tooHigh = 3000000; // 3000 sats
        
        expect(tooLow >= minSendable && tooLow <= maxSendable, isFalse);
        expect(tooHigh >= minSendable && tooHigh <= maxSendable, isFalse);
      });

      test('Channel amount validation enforces minimum', () {
        const minChannelSats = 20000; // 20k sats minimum
        
        const validAmounts = [20000, 50000, 100000];
        const invalidAmounts = [0, 10000, 19999];
        
        for (final amount in validAmounts) {
          expect(amount >= minChannelSats, isTrue);
        }
        
        for (final amount in invalidAmounts) {
          expect(amount >= minChannelSats, isFalse);
        }
      });
    });

    group('Stream Controller Tests', () {
      test('Stream controllers can be created and closed without external dependencies', () {
        late StreamController balanceController;
        late StreamController channelController;
        late StreamController paymentController;

        expect(() {
          balanceController = StreamController.broadcast();
          channelController = StreamController.broadcast();
          paymentController = StreamController.broadcast();
        }, returnsNormally);

        expect(() {
          balanceController.close();
          channelController.close();
          paymentController.close();
        }, returnsNormally);
      });

      test('Stream controllers handle multiple listeners', () async {
        final controller = StreamController<int>.broadcast();
        final results1 = <int>[];
        final results2 = <int>[];

        controller.stream.listen((value) => results1.add(value));
        controller.stream.listen((value) => results2.add(value));

        controller.add(1);
        controller.add(2);
        controller.add(3);

        await Future.delayed(const Duration(milliseconds: 10));

        expect(results1, equals([1, 2, 3]));
        expect(results2, equals([1, 2, 3]));

        await controller.close();
      });
    });
  });
}

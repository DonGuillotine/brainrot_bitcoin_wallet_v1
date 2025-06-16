import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import '../../theme/app_theme.dart';
import '../../widgets/animated/chaos_button.dart';
import '../../widgets/animated/meme_text.dart';
import '../../widgets/effects/particle_system.dart';
import '../../services/service_locator.dart';

/// Backup verification screen to ensure user has saved seed phrase
class BackupVerificationScreen extends StatefulWidget {
  final String mnemonic;

  const BackupVerificationScreen({
    super.key,
    required this.mnemonic,
  });

  @override
  State<BackupVerificationScreen> createState() => _BackupVerificationScreenState();
}

class _BackupVerificationScreenState extends State<BackupVerificationScreen> {
  late List<String> _mnemonicWords;
  late List<int> _verificationIndices;
  final Map<int, TextEditingController> _controllers = {};
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    _mnemonicWords = widget.mnemonic.split(' ');
    _generateVerificationIndices();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _generateVerificationIndices() {
    final random = math.Random();
    final indices = <int>{};

    // Select 4 random word indices to verify
    while (indices.length < 4) {
      indices.add(random.nextInt(_mnemonicWords.length));
    }

    _verificationIndices = indices.toList()..sort();

    // Create controllers for each verification word
    for (final index in _verificationIndices) {
      _controllers[index] = TextEditingController();
    }
  }

  void _verifyBackup() {
    bool allCorrect = true;

    for (final index in _verificationIndices) {
      final userWord = _controllers[index]!.text.trim().toLowerCase();
      final correctWord = _mnemonicWords[index].toLowerCase();

      if (userWord != correctWord) {
        allCorrect = false;
        _showError('Word ${index + 1} is incorrect');
        break;
      }
    }

    if (allCorrect) {
      setState(() => _verified = true);
      services.soundService.success();
      services.hapticService.success();

      // Navigate to home after delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          context.go('/home');
        }
      });
    }
  }

  void _showError(String message) {
    services.soundService.error();
    services.hapticService.error();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: MemeText(message, color: Colors.white),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkGrey,
      appBar: AppBar(
        title: const MemeText(
          'Verify Backup',
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          if (_verified)
            const ParticleSystem(
              particleType: ParticleType.stars,
              particleCount: 50,
              isActive: true,
            ),

          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                if (!_verified) ...[
                  // Instructions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withAlpha((0.1 * 255).round()),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.warning),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.quiz, color: AppTheme.warning),
                        const SizedBox(width: 12),
                        Expanded(
                          child: MemeText(
                            'Enter the following words from your seed phrase to verify you\'ve saved it',
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Verification inputs
                  ..._verificationIndices.map((index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TextField(
                        controller: _controllers[index],
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Monaco',
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Word #${index + 1}',
                          labelStyle: TextStyle(color: AppTheme.limeGreen),
                          filled: true,
                          fillColor: AppTheme.lightGrey,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppTheme.limeGreen,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),

                  const SizedBox(height: 32),

                  // Verify button
                  ChaosButton(
                    text: 'Verify Backup',
                    onPressed: _verifyBackup,
                    icon: Icons.check_circle,
                  ),
                ] else ...[
                  // Success state
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 80,
                          color: AppTheme.limeGreen,
                        )
                            .animate()
                            .scale(
                          begin: const Offset(0, 0),
                          end: const Offset(1, 1),
                          curve: Curves.elasticOut,
                          duration: const Duration(seconds: 1),
                        ),

                        const SizedBox(height: 24),

                        MemeText(
                          'Backup Verified!',
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          rainbow: true,
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 12),

                        MemeText(
                          'Your wallet is ready. LFG! 🚀',
                          fontSize: 16,
                          color: Colors.white70,
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 24),

                        MemeText(
                          'Redirecting to wallet...',
                          fontSize: 14,
                          color: Colors.white54,
                          textAlign: TextAlign.center,
                        )
                            .animate(
                          onPlay: (controller) => controller.repeat(),
                        )
                            .fadeIn()
                            .then()
                            .fadeOut(),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

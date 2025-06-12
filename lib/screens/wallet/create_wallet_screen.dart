import 'package:brainrot_bitcoin_wallet_v1/theme/theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:bdk_flutter/bdk_flutter.dart';
import '../../theme/app_theme.dart';
import '../../theme/chaos_theme.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/animated/chaos_button.dart';
import '../../widgets/animated/meme_text.dart';
import '../../widgets/effects/particle_system.dart';
import '../../services/service_locator.dart';
import '../../models/wallet_models.dart';

/// Wallet creation screen with chaos
class CreateWalletScreen extends StatefulWidget {
  const CreateWalletScreen({super.key});

  @override
  State<CreateWalletScreen> createState() => _CreateWalletScreenState();
}

class _CreateWalletScreenState extends State<CreateWalletScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _walletNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  int _currentStep = 0;
  bool _isCreating = false;
  String? _mnemonic;
  List<String>? _mnemonicWords;
  WalletType _selectedWalletType = WalletType.standard;
  bool _showPassword = false;
  bool _agreedToTerms = false;

  @override
  void initState() {
    super.initState();
    _walletNameController.text = _generateRandomWalletName();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _walletNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _generateRandomWalletName() {
    final adjectives = ['Diamond', 'Laser', 'Moon', 'Rocket', 'Chaos', 'Based'];
    final nouns = ['Wallet', 'Vault', 'Stash', 'Stack', 'Hodl', 'Safe'];
    final random = DateTime.now().millisecondsSinceEpoch;
    return '${adjectives[random % adjectives.length]} ${nouns[random % nouns.length]}';
  }

  void _nextStep() {
    if (_currentStep == 0 && !_validateWalletInfo()) return;
    if (_currentStep == 1 && !_validatePassword()) return;

    if (_currentStep < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);

      if (_currentStep == 3) {
        _createWallet();
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    }
  }

  bool _validateWalletInfo() {
    if (_walletNameController.text.trim().isEmpty) {
      _showError('Give your wallet a name, anon!');
      return false;
    }
    if (!_agreedToTerms) {
      _showError('You must understand the risks!');
      return false;
    }
    return true;
  }

  bool _validatePassword() {
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (password.length < 8) {
      _showError('Password too weak! At least 8 characters');
      return false;
    }
    if (password != confirm) {
      _showError('Passwords don\'t match! Try again');
      return false;
    }
    return true;
  }

  Future<void> _createWallet() async {
    if (_isCreating) return;

    setState(() => _isCreating = true);

    try {
      final walletProvider = context.read<WalletProvider>();
      final settingsProvider = context.read<SettingsProvider>();

      // Create wallet
      final mnemonic = await walletProvider.createWallet(
        name: _walletNameController.text.trim(),
        password: _passwordController.text,
        network: settingsProvider.isTestnet ? Network.testnet : Network.bitcoin,
        walletType: _selectedWalletType,
      );

      if (mnemonic != null) {
        setState(() {
          _mnemonic = mnemonic;
          _mnemonicWords = mnemonic.split(' ');
        });

        // Update app state
        final appState = context.read<AppStateProvider>();
        appState.setHasWallet(true);

        services.soundService.success();
        services.hapticService.success();
      } else {
        _showError('Failed to create wallet');
      }
    } catch (e) {
      _showError('Error: ${e.toString()}');
    } finally {
      setState(() => _isCreating = false);
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

  void _completeSetup() {
    // Navigate to backup verification
    context.go('/wallet/backup', extra: _mnemonic);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final chaosLevel = themeProvider.chaosLevel;

    return Scaffold(
      backgroundColor: AppTheme.darkGrey,
      body: Stack(
        children: [
          // Background effects
          if (chaosLevel >= 5)
            const ParticleSystem(
              particleType: ParticleType.bitcoin,
              particleCount: 20,
              isActive: true,
            ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(),

                // Progress indicator
                _buildProgressIndicator(),

                // Page content
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildWalletInfoStep(),
                      _buildPasswordStep(),
                      _buildTermsStep(),
                      _buildCreatingStep(),
                      _buildSeedPhraseStep(),
                    ],
                  ),
                ),

                // Navigation buttons
                if (_currentStep < 4)
                  _buildNavigationButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (_currentStep > 0 && _currentStep < 4)
            IconButton(
              onPressed: _previousStep,
              icon: const Icon(Icons.arrow_back),
              color: AppTheme.limeGreen,
            )
          else if (_currentStep == 0)
            IconButton(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.close),
              color: AppTheme.limeGreen,
            )
          else
            const SizedBox(width: 48),

          Expanded(
            child: MemeText(
              _currentStep == 4 ? 'Your Seed Phrase' : 'Create Wallet',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    if (_currentStep >= 4) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: List.generate(4, (index) {
          final isActive = index <= _currentStep;
          final isComplete = index < _currentStep;

          return Expanded(
            child: Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: isActive ? AppTheme.limeGreen : AppTheme.lightGrey,
                borderRadius: BorderRadius.circular(2),
              ),
            )
                .animate(target: isActive ? 1 : 0)
                .scaleX(begin: 0, end: 1, duration: 300.ms),
          );
        }),
      ),
    );
  }

  Widget _buildWalletInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MemeText(
            'Name Your Wallet',
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),

          const SizedBox(height: 8),

          MemeText(
            'Give your wallet a based name',
            fontSize: 16,
            color: Colors.white70,
          ),

          const SizedBox(height: 32),

          // Wallet name input
          TextField(
            controller: _walletNameController,
            style: const TextStyle(color: Colors.white),
            decoration: Theme.of(context).chaosInputDecoration(
              labelText: 'Wallet Name',
              chaosLevel: context.read<ThemeProvider>().chaosLevel,
              prefixIcon: const Icon(Icons.account_balance_wallet),
            ),
          ),

          const SizedBox(height: 32),

          // Wallet type selection
          MemeText(
            'Select Wallet Type',
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),

          const SizedBox(height: 16),

          ..._buildWalletTypeOptions(),

          const SizedBox(height: 32),

          // Terms checkbox
          CheckboxListTile(
            value: _agreedToTerms,
            onChanged: (value) => setState(() => _agreedToTerms = value ?? false),
            activeColor: AppTheme.limeGreen,
            title: MemeText(
              'I understand this is a non-custodial wallet and I am responsible for my funds',
              fontSize: 14,
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildWalletTypeOptions() {
    final types = [
      (WalletType.standard, 'Native SegWit', 'bc1...', '⚡ Lowest fees'),
      (WalletType.taproot, 'Taproot', 'bc1p...', '🌳 Latest tech'),
      (WalletType.legacy, 'Legacy', '1...', '👴 Old school'),
      (WalletType.nested, 'Nested SegWit', '3...', '📦 Compatibility'),
    ];

    return types.map((type) {
      final isSelected = _selectedWalletType == type.$1;

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _selectedWalletType = type.$1),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.deepPurple.withAlpha((0.3 * 255).round()) : AppTheme.lightGrey,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppTheme.limeGreen : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Radio<WalletType>(
                    value: type.$1,
                    groupValue: _selectedWalletType,
                    onChanged: (value) => setState(() => _selectedWalletType = value!),
                    activeColor: AppTheme.limeGreen,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MemeText(
                          type.$2,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            MemeText(
                              type.$3,
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 8),
                            MemeText(
                              type.$4,
                              fontSize: 12,
                              color: AppTheme.limeGreen,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildPasswordStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MemeText(
            'Secure Your Wallet',
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),

          const SizedBox(height: 8),

          MemeText(
            'Choose a strong password to encrypt your wallet',
            fontSize: 16,
            color: Colors.white70,
          ),

          const SizedBox(height: 32),

          // Password input
          TextField(
            controller: _passwordController,
            obscureText: !_showPassword,
            style: const TextStyle(color: Colors.white),
            decoration: Theme.of(context).chaosInputDecoration(
              labelText: 'Password',
              chaosLevel: context.read<ThemeProvider>().chaosLevel,
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Confirm password input
          TextField(
            controller: _confirmPasswordController,
            obscureText: !_showPassword,
            style: const TextStyle(color: Colors.white),
            decoration: Theme.of(context).chaosInputDecoration(
              labelText: 'Confirm Password',
              chaosLevel: context.read<ThemeProvider>().chaosLevel,
              prefixIcon: const Icon(Icons.lock_outline),
            ),
          ),

          const SizedBox(height: 32),

          // Password strength indicator
          _buildPasswordStrength(),

          const SizedBox(height: 32),

          // Tips
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.warning.withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.warning.withAlpha((0.3 * 255).round())),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info, color: AppTheme.warning, size: 20),
                    const SizedBox(width: 8),
                    MemeText(
                      'Password Tips',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                MemeText(
                  '• Use at least 8 characters\n'
                      '• Mix letters, numbers, and symbols\n'
                      '• Don\'t use common words\n'
                      '• Never share your password',
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStrength() {
    final password = _passwordController.text;
    final strength = _calculatePasswordStrength(password);
    final strengthText = ['Weak AF 💀', 'Mid 😐', 'Based 💪', 'Gigachad 🗿'];
    final strengthColors = [AppTheme.error, AppTheme.warning, AppTheme.limeGreen, AppTheme.deepPurple];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MemeText(
          'Password Strength',
          fontSize: 14,
          color: Colors.white70,
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(4, (index) {
            return Expanded(
              child: Container(
                height: 4,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: index < strength ? strengthColors[strength - 1] : AppTheme.lightGrey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        MemeText(
          strength > 0 ? strengthText[strength - 1] : '',
          fontSize: 14,
          color: strength > 0 ? strengthColors[strength - 1] : Colors.white70,
        ),
      ],
    );
  }

  int _calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0;
    if (password.length < 8) return 1;

    int strength = 1;
    if (password.length >= 12) strength++;
    if (RegExp(r'[A-Z]').hasMatch(password) && RegExp(r'[a-z]').hasMatch(password)) strength++;
    if (RegExp(r'[0-9]').hasMatch(password)) strength++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength++;

    return strength.clamp(1, 4);
  }

  Widget _buildTermsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MemeText(
            'Before We Begin...',
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),

          const SizedBox(height: 32),

          _buildWarningCard(
            '🔑 Your Keys, Your Coins',
            'You are the sole custodian of your funds. Lose your keys = lose your coins forever.',
            AppTheme.deepPurple,
          ),

          const SizedBox(height: 16),

          _buildWarningCard(
            '📝 Backup Responsibly',
            'Write down your seed phrase on paper. Screenshots = NGMI.',
            AppTheme.warning,
          ),

          const SizedBox(height: 16),

          _buildWarningCard(
            '🔒 Stay Safe',
            'Never share your seed phrase. Anyone who has it can steal your funds.',
            AppTheme.error,
          ),

          const SizedBox(height: 16),

          _buildWarningCard(
            '🧠 DYOR',
            'This wallet is provided as-is. No warranties, no refunds, just vibes.',
            AppTheme.limeGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildWarningCard(String title, String message, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha((0.3 * 255).round())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MemeText(
            title,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          const SizedBox(height: 8),
          MemeText(
            message,
            fontSize: 14,
            color: Colors.white70,
          ),
        ],
      ),
    );
  }

  Widget _buildCreatingStep() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated Bitcoin logo
          Icon(
            Icons.currency_bitcoin,
            size: 120,
            color: AppTheme.limeGreen,
          )
              .animate(
            onPlay: (controller) => controller.repeat(),
          )
              .rotate(duration: const Duration(seconds: 2))
              .scale(
            begin: const Offset(0.8, 0.8),
            end: const Offset(1.2, 1.2),
            duration: const Duration(seconds: 1),
          ),

          const SizedBox(height: 40),

          MemeText(
            'Creating Your Wallet...',
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),

          const SizedBox(height: 16),

          MemeText(
            'Generating maximum entropy 🎲',
            fontSize: 16,
            color: Colors.white70,
          ),

          const SizedBox(height: 40),

          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.limeGreen),
          ),
        ],
      ),
    );
  }

  Widget _buildSeedPhraseStep() {
    if (_mnemonicWords == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Warning
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.error.withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.error),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning, color: AppTheme.error),
                const SizedBox(width: 12),
                Expanded(
                  child: MemeText(
                    'Write these words down in order! No screenshots!',
                    fontSize: 14,
                    color: AppTheme.error,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Seed phrase grid
          Container(
            padding: const EdgeInsets.all(20),
            decoration: ChaosTheme.getChaosDecoration(
              chaosLevel: 0, // No chaos for seed phrase
              baseColor: AppTheme.lightGrey,
            ),
            child: Column(
              children: List.generate(3, (rowIndex) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: List.generate(4, (colIndex) {
                      final index = rowIndex * 4 + colIndex;
                      if (index >= _mnemonicWords!.length) return const Spacer();

                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.darkGrey,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.deepPurple.withAlpha((0.5 * 255).round()),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.limeGreen,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _mnemonicWords![index],
                                style: const TextStyle(
                                  fontFamily: 'Monaco',
                                  fontSize: 14,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )
                            .animate(delay: Duration(milliseconds: index * 100))
                            .fadeIn()
                            .scale(
                          begin: const Offset(0.8, 0.8),
                          end: const Offset(1, 1),
                        ),
                      );
                    }),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 32),

          // Action buttons
          ChaosButton(
            text: 'I\'ve Written It Down',
            onPressed: _completeSetup,
            icon: Icons.check,
          ),

          const SizedBox(height: 16),

          ChaosButton(
            text: 'Copy Seed Phrase',
            onPressed: () {
              services.hapticService.medium();
              if (_mnemonic != null) {
                Clipboard.setData(ClipboardData(text: _mnemonic!));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: MemeText('Seed phrase copied to clipboard!', color: Colors.white),
                    backgroundColor: AppTheme.limeGreen,
                  ),
                );
              }
            },
            isPrimary: false,
            icon: Icons.copy,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          if (_currentStep > 0 && _currentStep < 3)
            Expanded(
              child: ChaosButton(
                text: 'Back',
                onPressed: _previousStep,
                isPrimary: false,
              ),
            ),

          if (_currentStep > 0 && _currentStep < 3)
            const SizedBox(width: 16),

          Expanded(
            child: ChaosButton(
              text: _currentStep == 2 ? 'Create Wallet' : 'Continue',
              onPressed: _isCreating ? null : _nextStep,
              icon: Icons.arrow_forward,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:brainrot_bitcoin_wallet_v1/theme/theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:bdk_flutter/bdk_flutter.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/animated/chaos_button.dart';
import '../../widgets/animated/meme_text.dart';
import '../../services/service_locator.dart';
import '../../models/wallet_models.dart';

/// Wallet restoration screen
class RestoreWalletScreen extends StatefulWidget {
  const RestoreWalletScreen({super.key});

  @override
  State<RestoreWalletScreen> createState() => _RestoreWalletScreenState();
}

class _RestoreWalletScreenState extends State<RestoreWalletScreen> {
  final List<TextEditingController> _wordControllers = List.generate(
    12,
        (_) => TextEditingController(),
  );
  final TextEditingController _walletNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _pasteController = TextEditingController();

  bool _isRestoring = false;
  bool _showPassword = false;
  bool _usePasteMode = false;
  int _wordCount = 12;
  WalletType _selectedWalletType = WalletType.standard;

  @override
  void initState() {
    super.initState();
    _walletNameController.text = 'Restored Wallet';
  }

  @override
  void dispose() {
    for (final controller in _wordControllers) {
      controller.dispose();
    }
    _walletNameController.dispose();
    _passwordController.dispose();
    _pasteController.dispose();
    super.dispose();
  }

  void _handleWordCountChange(int count) {
    setState(() {
      _wordCount = count;

      // Add or remove controllers as needed
      while (_wordControllers.length < count) {
        _wordControllers.add(TextEditingController());
      }
    });
  }

  void _handlePaste() {
    final words = _pasteController.text.trim().split(RegExp(r'\s+'));

    if (words.length != _wordCount) {
      _showError('Expected $_wordCount words, got ${words.length}');
      return;
    }

    for (int i = 0; i < words.length && i < _wordControllers.length; i++) {
      _wordControllers[i].text = words[i].toLowerCase();
    }

    services.hapticService.success();
  }

  Future<void> _restoreWallet() async {
    if (_isRestoring) return;

    // Validate inputs
    if (!_validateInputs()) return;

    setState(() => _isRestoring = true);

    try {
      // Get mnemonic from word controllers
      final mnemonic = _wordControllers
          .take(_wordCount)
          .map((controller) => controller.text.trim().toLowerCase())
          .join(' ');

      final walletProvider = context.read<WalletProvider>();
      final settingsProvider = context.read<SettingsProvider>();

      // Restore wallet
      final success = await walletProvider.restoreWallet(
        name: _walletNameController.text.trim(),
        mnemonic: mnemonic,
        password: _passwordController.text,
        network: settingsProvider.isTestnet ? Network.testnet : Network.bitcoin,
        walletType: _selectedWalletType,
      );

      if (success) {
        // Update app state
        final appState = context.read<AppStateProvider>();
        await appState.setOnboarded(true);
        // Refresh app state to detect the restored wallet
        await appState.refreshAppState();

        services.soundService.success();
        services.hapticService.success();

        // Navigate to home
        if (mounted) {
          context.go('/home');
        }
      }
    } catch (e) {
      _showError('Failed to restore wallet: ${e.toString()}');
    } finally {
      setState(() => _isRestoring = false);
    }
  }

  bool _validateInputs() {
    if (_walletNameController.text.trim().isEmpty) {
      _showError('Please enter a wallet name');
      return false;
    }

    if (_passwordController.text.length < 8) {
      _showError('Password must be at least 8 characters');
      return false;
    }

    // Check all words are filled
    for (int i = 0; i < _wordCount; i++) {
      if (_wordControllers[i].text.trim().isEmpty) {
        _showError('Please enter word ${i + 1}');
        return false;
      }
    }

    return true;
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
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: AppTheme.darkGrey,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const MemeText(
          'Restore Wallet',
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wallet info section
            _buildWalletInfoSection(),

            const SizedBox(height: 32),

            // Word count selector
            _buildWordCountSelector(),

            const SizedBox(height: 24),

            // Input mode toggle
            _buildInputModeToggle(),

            const SizedBox(height: 24),

            // Seed phrase input
            if (_usePasteMode)
              _buildPasteMode()
            else
              _buildWordGrid(),

            const SizedBox(height: 32),

            // Restore button
            ChaosButton(
              text: _isRestoring ? 'Restoring...' : 'Restore Wallet',
              onPressed: _isRestoring ? null : _restoreWallet,
              icon: _isRestoring ? null : Icons.restore,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wallet name
        TextField(
          controller: _walletNameController,
          style: const TextStyle(color: Colors.white),
          decoration: Theme.of(context).chaosInputDecoration(
            labelText: 'Wallet Name',
            chaosLevel: context.read<ThemeProvider>().chaosLevel,
            prefixIcon: const Icon(Icons.account_balance_wallet),
          ),
        ),

        const SizedBox(height: 16),

        // Password
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

        // Wallet type
        MemeText(
          'Wallet Type',
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),

        const SizedBox(height: 8),

        DropdownButtonFormField<WalletType>(
          value: _selectedWalletType,
          onChanged: (value) => setState(() => _selectedWalletType = value!),
          dropdownColor: AppTheme.lightGrey,
          style: const TextStyle(color: Colors.white),
          decoration: Theme.of(context).chaosInputDecoration(
            labelText: '',
            chaosLevel: 0,
          ),
          items: [
            DropdownMenuItem(
              value: WalletType.standard,
              child: MemeText('Native SegWit (bc1...)'),
            ),
            DropdownMenuItem(
              value: WalletType.taproot,
              child: MemeText('Taproot (bc1p...)'),
            ),
            DropdownMenuItem(
              value: WalletType.legacy,
              child: MemeText('Legacy (1...)'),
            ),
            DropdownMenuItem(
              value: WalletType.nested,
              child: MemeText('Nested SegWit (3...)'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWordCountSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MemeText(
          'Seed Phrase Length',
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),

        const SizedBox(height: 8),

        Row(
          children: [12, 15, 18, 21, 24].map((count) {
            final isSelected = _wordCount == count;

            return Expanded(
              child: GestureDetector(
                onTap: () => _handleWordCountChange(count),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.deepPurple : AppTheme.lightGrey,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppTheme.limeGreen : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: MemeText(
                      '$count',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildInputModeToggle() {
    return Row(
      children: [
        Expanded(
          child: ChaosButton(
            text: 'Enter Words',
            onPressed: () => setState(() => _usePasteMode = false),
            isPrimary: !_usePasteMode,
            height: 48,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ChaosButton(
            text: 'Paste All',
            onPressed: () => setState(() => _usePasteMode = true),
            isPrimary: _usePasteMode,
            height: 48,
          ),
        ),
      ],
    );
  }

  Widget _buildPasteMode() {
    return Column(
      children: [
        TextField(
          controller: _pasteController,
          maxLines: 4,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Monaco',
          ),
          decoration: Theme.of(context).chaosInputDecoration(
            labelText: 'Paste your seed phrase',
            hintText: 'word1 word2 word3...',
            chaosLevel: 0,
          ),
        ),

        const SizedBox(height: 16),

        ChaosButton(
          text: 'Import Words',
          onPressed: _handlePaste,
          isPrimary: false,
          icon: Icons.download,
        ),
      ],
    );
  }

  Widget _buildWordGrid() {
    return Column(
      children: List.generate((_wordCount / 3).ceil(), (rowIndex) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: List.generate(3, (colIndex) {
              final index = rowIndex * 3 + colIndex;
              if (index >= _wordCount) return const Spacer();

              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: TextField(
                    controller: _wordControllers[index],
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Monaco',
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: '${index + 1}',
                      labelStyle: TextStyle(
                        color: AppTheme.limeGreen,
                        fontSize: 12,
                      ),
                      filled: true,
                      fillColor: AppTheme.lightGrey,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: AppTheme.limeGreen,
                          width: 2,
                        ),
                      ),
                    ),
                    onChanged: (_) {
                      // Auto-focus next field
                      if (index < _wordCount - 1 &&
                          _wordControllers[index].text.contains(' ')) {
                        _wordControllers[index].text =
                            _wordControllers[index].text.trim();
                        FocusScope.of(context).nextFocus();
                      }
                    },
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}

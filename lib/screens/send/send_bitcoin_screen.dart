import 'package:brainrot_bitcoin_wallet_v1/theme/theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../theme/app_theme.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/lightning_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/animated/chaos_button.dart';
import '../../widgets/animated/meme_text.dart';
import '../../widgets/effects/particle_system.dart';
import '../../services/service_locator.dart';
import '../../models/wallet_models.dart';
import 'widgets/amount_input.dart';
import 'widgets/fee_selector.dart';
import 'widgets/send_confirmation.dart';
import 'dart:math' as math;

/// Main send Bitcoin screen
class SendBitcoinScreen extends StatefulWidget {
  final String? scanData;

  const SendBitcoinScreen({
    super.key,
    this.scanData,
  });

  @override
  State<SendBitcoinScreen> createState() => _SendBitcoinScreenState();
}

class _SendBitcoinScreenState extends State<SendBitcoinScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  late AnimationController _scannerAnimationController;
  late AnimationController _successAnimationController;

  int _currentStep = 0;
  bool _isValidAddress = false;
  bool _isLightningInvoice = false;
  bool _isSending = false;
  bool _sendSuccess = false;
  String? _txid;

  // Amount state
  String _selectedUnit = 'sats';
  double _btcAmount = 0;
  int _satAmount = 0;

  // Fee state
  int _selectedFeeRate = 10;
  FeeEstimate? _feeEstimate;

  // Scanner state
  bool _scannerActive = false;
  MobileScannerController? _scannerController;

  @override
  void initState() {
    super.initState();
    _scannerAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _successAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _addressController.addListener(_validateAddress);
    _loadFeeEstimates();

    if (widget.scanData != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleQRScan(widget.scanData);
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _addressController.dispose();
    _labelController.dispose();
    _amountController.dispose();
    _scannerAnimationController.dispose();
    _successAnimationController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _loadFeeEstimates() async {
    final walletProvider = context.read<WalletProvider>();
    final estimate = await walletProvider.getFeeEstimates();

    if (mounted && estimate != null) {
      setState(() {
        _feeEstimate = estimate;
        _selectedFeeRate = estimate.halfHourFee;
      });
    }
  }

  void _validateAddress() async {
    final address = _addressController.text.trim();

    if (address.isEmpty) {
      setState(() {
        _isValidAddress = false;
        _isLightningInvoice = false;
      });
      return;
    }

    // Check if it's a Lightning invoice
    if (address.toLowerCase().startsWith('lnbc') ||
        address.toLowerCase().startsWith('lntb')) {
      setState(() {
        _isValidAddress = true;
        _isLightningInvoice = true;
      });
      return;
    }

    // Check if it's a Lightning address
    if (address.contains('@')) {
      setState(() {
        _isValidAddress = true;
        _isLightningInvoice = true;
      });
      return;
    }

    // Validate Bitcoin address
    final walletProvider = context.read<WalletProvider>();
    final isValid = await walletProvider.validateAddress(address);

    setState(() {
      _isValidAddress = isValid;
      _isLightningInvoice = false;
    });
  }

  void _handleQRScan(String? code) {
    if (code == null) return;

    // Parse Bitcoin URI or Lightning invoice
    String address = code;
    String? amount;
    String? label;

    if (code.toLowerCase().startsWith('bitcoin:')) {
      // Parse Bitcoin URI
      final uri = Uri.parse(code);
      address = uri.path;
      amount = uri.queryParameters['amount'];
      label = uri.queryParameters['label'];
    } else if (code.toLowerCase().startsWith('lightning:')) {
      // Parse Lightning URI
      address = code.substring(10);
    }

    setState(() {
      _addressController.text = address;
      if (amount != null) {
        _amountController.text = amount;
        _handleAmountChange(amount, 'BTC');
      }
      if (label != null) {
        _labelController.text = label;
      }
      _scannerActive = false;
    });

    _scannerController?.stop();
    services.playSoundSafely((sound) => sound.success());
    services.triggerHapticSafely((haptic) => haptic.success());
  }

  void _handleAmountChange(String value, String unit) {
    print('DEBUG: Amount change - value: "$value", unit: "$unit"');
    
    if (value.isEmpty) {
      setState(() {
        _btcAmount = 0;
        _satAmount = 0;
      });
      print('DEBUG: Amount cleared - _satAmount: $_satAmount');
      return;
    }

    try {
      final amount = double.parse(value);
      print('DEBUG: Parsed amount: $amount');

      setState(() {
        _selectedUnit = unit;

        switch (unit) {
          case 'BTC':
            _btcAmount = amount;
            _satAmount = (amount * 100000000).round();
            break;
          case 'mBTC':
            _btcAmount = amount / 1000;
            _satAmount = (amount * 100000).round();
            break;
          case 'bits':
            _btcAmount = amount / 1000000;
            _satAmount = (amount * 100).round();
            break;
          case 'sats':
            _btcAmount = amount / 100000000;
            _satAmount = amount.round();
            break;
        }
      });
      print('DEBUG: Final _satAmount: $_satAmount');
    } catch (e) {
      print('DEBUG: Amount parse error: $e');
    }
  }

  void _nextStep() {
    if (_currentStep == 0 && !_validateRecipient()) return;
    if (_currentStep == 1 && !_validateAmount()) return;

    setState(() => _currentStep++);
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    services.triggerHapticSafely((haptic) => haptic.light());
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _validateRecipient() {
    if (!_isValidAddress) {
      _showError('Invalid address! Check again 🧐');
      return false;
    }
    return true;
  }

  bool _validateAmount() {
    final walletProvider = context.read<WalletProvider>();
    final balance = walletProvider.balance?.confirmed ?? 0;

    const int dustLimitSats = 546;

    if (_satAmount <= 0) {
      _showError('Enter an amount, anon! 💸');
      return false;
    }

    // NEW: Dust limit check for on-chain transactions
    if (!_isLightningInvoice && _satAmount < dustLimitSats) {
      _showError('Amount is below the dust limit of $dustLimitSats sats! 🤏');
      return false;
    }

    if (_satAmount > balance) {
      _showError('Insufficient funds! You broke 😢');
      return false;
    }

    return true;
  }

  Future<void> _sendTransaction() async {
    if (_isSending) return;

    // Validate amount before sending as safety check
    if (!_validateAmount()) {
      return;
    }

    setState(() => _isSending = true);

    try {
      if (_isLightningInvoice) {
        await _sendLightningPayment();
      } else {
        await _sendOnChainTransaction();
      }
    } catch (e) {
      _showError('Send failed: ${e.toString()}');
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _sendOnChainTransaction() async {
    final walletProvider = context.read<WalletProvider>();

    // Debug logging
    print('DEBUG: Sending Bitcoin with amount: $_satAmount sats');
    print('DEBUG: Address: ${_addressController.text.trim()}');
    print('DEBUG: Fee rate: $_selectedFeeRate');

    String? txid = await walletProvider.sendBitcoin(
      address: _addressController.text.trim(),
      amountSats: _satAmount,
      feeRate: _selectedFeeRate,
      memo: _labelController.text.trim().isNotEmpty
          ? _labelController.text.trim()
          : null,
    );

    // Check if wallet needs to be unlocked
    print('DEBUG: txid=$txid, isReadOnlyMode=${walletProvider.isReadOnlyMode}, error=${walletProvider.error}');
    
    if (txid == null && 
        (walletProvider.isReadOnlyMode || 
         (walletProvider.error != null && walletProvider.error!.contains('read-only mode')))) {
      print('DEBUG: Showing password dialog...');
      // Show password prompt
      final password = await _showPasswordDialog();
      if (password != null) {
        print('DEBUG: Password provided, retrying transaction...');
        // Retry transaction with password
        txid = await walletProvider.sendBitcoin(
          address: _addressController.text.trim(),
          amountSats: _satAmount,
          feeRate: _selectedFeeRate,
          memo: _labelController.text.trim().isNotEmpty
              ? _labelController.text.trim()
              : null,
          password: password,
        );
        print('DEBUG: Retry result: $txid');
      } else {
        print('DEBUG: No password provided, transaction cancelled');
      }
    }

    if (txid != null) {
      setState(() {
        _sendSuccess = true;
        _txid = txid;
      });

      _successAnimationController.forward();

      // Navigate to success after delay
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          context.go('/home');
        }
      });
    }
  }

  Future<String?> _showPasswordDialog() async {
    final TextEditingController passwordController = TextEditingController();
    
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.deepPurple,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: MemeText(
            'Unlock Wallet 🔓',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.white,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MemeText(
                'Enter your wallet password to send this transaction:',
                fontSize: 16,
                color: Colors.white70,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Password',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: AppTheme.lightGrey,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(
                    Icons.lock,
                    color: AppTheme.white,
                  ),
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: MemeText(
                'Cancel',
                color: Colors.white54,
              ),
            ),
            ChaosButton(
              text: 'Unlock',
              onPressed: () {
                final password = passwordController.text.trim();
                if (password.isNotEmpty) {
                  Navigator.of(context).pop(password);
                }
              }
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendLightningPayment() async {
    final lightningProvider = context.read<LightningProvider>();
    final address = _addressController.text.trim();

    String? paymentId;

    if (address.contains('@')) {
      // Lightning address
      paymentId = await lightningProvider.sendToLightningAddress(
        address: address,
        amountSats: _satAmount,
        comment: _labelController.text.trim().isNotEmpty
            ? _labelController.text.trim()
            : null,
      );
    } else {
      // Lightning invoice
      paymentId = await lightningProvider.payInvoice(
        bolt11: address,
        amountSats: _satAmount > 0 ? _satAmount : null,
      );
    }

    if (paymentId != null) {
      setState(() {
        _sendSuccess = true;
        _txid = paymentId;
      });

      _successAnimationController.forward();

      // Navigate to success after delay
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          context.go('/home');
        }
      });
    }
  }

  void _showError(String message) {
    services.playSoundSafely((sound) => sound.error());
    services.triggerHapticSafely((haptic) => haptic.error());

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
    final chaosLevel = themeProvider.chaosLevel;

    return Scaffold(
      backgroundColor: AppTheme.darkGrey,
      body: Stack(
        children: [
          // Background effects
          if (chaosLevel >= 6 && _sendSuccess)
            const ParticleSystem(
              particleType: ParticleType.money,
              particleCount: 50,
              isActive: true,
            ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(),

                // Progress indicator
                if (!_sendSuccess)
                  _buildProgressIndicator(),

                // Page content
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildRecipientStep(),
                      _buildAmountStep(),
                      _buildFeeStep(),
                      _buildConfirmationStep(),
                      _buildSendingStep(),
                    ],
                  ),
                ),

                // Navigation buttons
                if (!_sendSuccess && _currentStep < 4)
                  _buildNavigationButtons(),
              ],
            ),
          ),

          // QR Scanner overlay
          if (_scannerActive)
            _buildQRScanner(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: _currentStep > 0 && _currentStep < 4
                ? _previousStep
                : () => context.go('/home'),
            icon: Icon(_currentStep > 0 && _currentStep < 4
                ? Icons.arrow_back
                : Icons.close),
            color: AppTheme.limeGreen,
          ),

          Expanded(
            child: MemeText(
              _sendSuccess
                  ? 'Transaction Sent! 🚀'
                  : _isLightningInvoice
                  ? 'Send Lightning ⚡'
                  : 'Send Bitcoin',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              textAlign: TextAlign.center,
              rainbow: _sendSuccess,
            ),
          ),

          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: List.generate(4, (index) {
          final isActive = index <= _currentStep;

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

  Widget _buildRecipientStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MemeText(
            'Who\'s getting the sats?',
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),

          const SizedBox(height: 32),

          // Address input
          TextField(
            controller: _addressController,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Monaco',
              fontSize: 14,
            ),
            maxLines: 3,
            decoration: Theme.of(context).chaosInputDecoration(
              labelText: 'Bitcoin Address or Lightning Invoice',
              chaosLevel: context.read<ThemeProvider>().chaosLevel,
              hintText: 'bc1q... or lnbc1...',
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isValidAddress)
                    Icon(
                      Icons.check_circle,
                      color: AppTheme.success,
                    ),
                  IconButton(
                    onPressed: () {
                      setState(() => _scannerActive = true);
                      _initializeScanner();
                    },
                    icon: const Icon(Icons.qr_code_scanner),
                    color: AppTheme.limeGreen,
                  ),
                ],
              ),
            ),
          ),

          if (_isValidAddress) ...[
            const SizedBox(height: 16),

            // Address type indicator
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: _isLightningInvoice
                    ? AppTheme.limeGreen.withAlpha((0.2 * 255).round())
                    : AppTheme.deepPurple.withAlpha((0.2 * 255).round()),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isLightningInvoice ? Icons.bolt : Icons.link,
                    size: 16,
                    color: _isLightningInvoice
                        ? AppTheme.limeGreen
                        : AppTheme.deepPurple,
                  ),
                  const SizedBox(width: 4),
                  MemeText(
                    _isLightningInvoice
                        ? 'Lightning Payment ⚡'
                        : 'On-chain Transaction',
                    fontSize: 14,
                    color: _isLightningInvoice
                        ? AppTheme.limeGreen
                        : AppTheme.deepPurple,
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Label input
          TextField(
            controller: _labelController,
            style: const TextStyle(color: Colors.white),
            decoration: Theme.of(context).chaosInputDecoration(
              labelText: 'Label (optional)',
              chaosLevel: 0,
              hintText: 'Coffee money ☕',
              prefixIcon: const Icon(Icons.label),
            ),
          ),

          const SizedBox(height: 32),

          // Recent addresses
          MemeText(
            'Recent Recipients',
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),

          const SizedBox(height: 16),

          _buildRecentAddressesList(),
        ],
      ),
    );
  }

  Widget _buildAmountStep() {
    final walletProvider = context.watch<WalletProvider>();
    final balance = walletProvider.balance;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MemeText(
            'How much?',
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),

          const SizedBox(height: 8),

          // Available balance
          if (balance != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.lightGrey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet,
                    color: AppTheme.limeGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  MemeText(
                    'Available: ${balance.btc.toStringAsFixed(8)} BTC',
                    fontSize: 14,
                    color: AppTheme.limeGreen,
                  ),
                ],
              ),
            ),

          const SizedBox(height: 32),

          // Amount input
          AmountInput(
            controller: _amountController,
            onAmountChanged: _handleAmountChange,
            selectedUnit: _selectedUnit,
          ),

          const SizedBox(height: 24),

          // Quick amount buttons
          MemeText(
            'Quick Amounts',
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickAmountButton('10k sats', 10000),
              _buildQuickAmountButton('50k sats', 50000),
              _buildQuickAmountButton('100k sats', 100000),
              _buildQuickAmountButton('1M sats', 1000000),
              _buildQuickAmountButton('ALL 🚀', balance?.confirmed ?? 0),
            ],
          ),

          const SizedBox(height: 32),

          // Conversion display
          if (_satAmount > 0)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.darkGrey,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.deepPurple.withAlpha((0.3 * 255).round()),
                ),
              ),
              child: Column(
                children: [
                  _buildConversionRow('BTC', _btcAmount.toStringAsFixed(8)),
                  const SizedBox(height: 8),
                  _buildConversionRow('Sats', _satAmount.toString()),
                  const SizedBox(height: 8),
                  _buildConversionRow('USD', _getUsdConversion()),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeeStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MemeText(
            'Choose your vibe',
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),

          const SizedBox(height: 8),

          MemeText(
            'Higher fee = Faster confirmation',
            fontSize: 16,
            color: Colors.white70,
          ),

          const SizedBox(height: 32),

          // Fee selector
          if (_feeEstimate != null)
            FeeSelector(
              feeEstimate: _feeEstimate!,
              selectedFeeRate: _selectedFeeRate,
              onFeeSelected: (rate) {
                setState(() => _selectedFeeRate = rate);
              },
            ),

          const SizedBox(height: 32),

          // Estimated confirmation time
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.lightGrey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.schedule,
                  color: AppTheme.limeGreen,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MemeText(
                        'Estimated Confirmation',
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                      MemeText(
                        _getConfirmationTimeEstimate(),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Network fee display
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkGrey,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.hotPink.withAlpha((0.3 * 255).round()),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.local_gas_station,
                  color: AppTheme.hotPink,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MemeText(
                        'Network Fee',
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                      MemeText(
                        '~${_calculateFee()} sats',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.hotPink,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationStep() {
    return SendConfirmation(
      address: _addressController.text,
      amountSats: _satAmount,
      feeRate: _selectedFeeRate,
      label: _labelController.text,
      isLightning: _isLightningInvoice,
      onConfirm: _sendTransaction,
      isLoading: _isSending,
    );
  }

  Widget _buildSendingStep() {
    if (_sendSuccess) {
      return _buildSuccessStep();
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated logo
          Icon(
            _isLightningInvoice ? Icons.bolt : Icons.send,
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
            _isLightningInvoice
                ? 'Zapping sats... ⚡'
                : 'Broadcasting transaction...',
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),

          const SizedBox(height: 16),

          MemeText(
            _getRandomSendingMessage(),
            fontSize: 16,
            color: Colors.white70,
          )
              .animate(
            onPlay: (controller) => controller.repeat(),
          )
              .fadeIn(duration: 500.ms)
              .then()
              .fadeOut(duration: 500.ms),

          const SizedBox(height: 40),

          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.limeGreen),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessStep() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Success animation
          Icon(
            Icons.check_circle,
            size: 120,
            color: AppTheme.limeGreen,
          )
              .animate(controller: _successAnimationController)
              .scale(
            begin: const Offset(0, 0),
            end: const Offset(1, 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
          ),

          const SizedBox(height: 32),

          MemeText(
            'Transaction Sent!',
            fontSize: 32,
            fontWeight: FontWeight.bold,
            rainbow: true,
          ),

          const SizedBox(height: 16),

          MemeText(
            _getSuccessMessage(),
            fontSize: 18,
            color: Colors.white70,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // Transaction ID
          if (_txid != null)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: AppTheme.lightGrey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  MemeText(
                    _isLightningInvoice ? 'Payment ID' : 'Transaction ID',
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                  const SizedBox(height: 8),
                  MemeText(
                    '${_txid!.substring(0, 16)}...${_txid!.substring(_txid!.length - 16)}',
                    fontSize: 12,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQRScanner() {
    return Positioned.fill(
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            // Scanner
            MobileScanner(
              controller: _scannerController,
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null) {
                    _handleQRScan(barcode.rawValue);
                    break;
                  }
                }
              },
            ),

            // Overlay
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withAlpha((0.5 * 255).round()),
              ),
              child: Stack(
                children: [
                  // Close button
                  Positioned(
                    top: 50,
                    right: 20,
                    child: IconButton(
                      onPressed: () {
                        setState(() => _scannerActive = false);
                        _scannerController?.stop();
                      },
                      icon: const Icon(Icons.close),
                      color: Colors.white,
                      iconSize: 32,
                    ),
                  ),

                  // Scan area
                  Center(
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppTheme.limeGreen,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Stack(
                        children: [
                          // Animated scan line
                          AnimatedBuilder(
                            animation: _scannerAnimationController,
                            builder: (context, child) {
                              return Positioned(
                                top: _scannerAnimationController.value * 250,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 2,
                                  color: AppTheme.limeGreen,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Instructions
                  Positioned(
                    bottom: 100,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: MemeText(
                        'Scan QR Code',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
              text: _currentStep == 3 ? 'Send' : 'Continue',
              onPressed: _currentStep == 3 ? _sendTransaction : _nextStep,
              icon: _currentStep == 3 ? Icons.send : Icons.arrow_forward,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAmountButton(String label, int sats) {
    return OutlinedButton(
      onPressed: () {
        _amountController.text = sats.toString();
        _handleAmountChange(sats.toString(), 'sats');
      },
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: AppTheme.limeGreen),
      ),
      child: MemeText(label, fontSize: 14),
    );
  }

  Widget _buildConversionRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        MemeText(
          label,
          fontSize: 14,
          color: Colors.white70,
        ),
        MemeText(
          value,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ],
    );
  }

  String _getConfirmationTimeEstimate() {
    if (_selectedFeeRate >= (_feeEstimate?.fastestFee ?? 50)) {
      return '~10 minutes (1-2 blocks)';
    } else if (_selectedFeeRate >= (_feeEstimate?.halfHourFee ?? 30)) {
      return '~30 minutes (3 blocks)';
    } else if (_selectedFeeRate >= (_feeEstimate?.hourFee ?? 20)) {
      return '~1 hour (6 blocks)';
    } else {
      return '2+ hours (12+ blocks)';
    }
  }

  int _calculateFee() {
    // Estimate transaction size (simplified)
    const int typicalTxSize = 250; // bytes
    return (typicalTxSize * _selectedFeeRate);
  }

  String _getRandomSendingMessage() {
    final messages = [
      'Mining some blocks... ⛏️',
      'Yeeting sats across the network... 🏃‍♂️',
      'Asking miners nicely... 🙏',
      'Bribing the mempool... 💰',
      'Doing blockchain stuff... 🔗',
      'Number go down (for you)... 📉',
    ];
    return messages[DateTime.now().second % messages.length];
  }

  String _getSuccessMessage() {
    final messages = [
      'Sats successfully yeeted! 🚀',
      'Transaction broadcasted! WAGMI! 💎',
      'Money printer go brrrr! 🖨️',
      'Funds are SAFU! 🔒',
      'Another one bites the dust! 🎵',
      'GG EZ! 🎮',
    ];
    return messages[math.Random().nextInt(messages.length)];
  }

  void _initializeScanner() {
    _scannerController = MobileScannerController(
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  Widget _buildRecentAddressesList() {
    final walletProvider = context.watch<WalletProvider>();
    final recentAddresses = walletProvider.recentSendAddresses;

    if (recentAddresses.isEmpty) {
      return Center(
        child: MemeText(
          'No recent addresses',
          fontSize: 14,
          color: Colors.white54,
        ),
      );
    }

    return Column(
      children: recentAddresses.take(5).map((recentAddress) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: AppTheme.lightGrey,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () {
                _addressController.text = recentAddress.address;
                if (recentAddress.label?.isNotEmpty == true) {
                  _labelController.text = recentAddress.label!;
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Address type icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.deepPurple.withAlpha((0.2 * 255).round()),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getAddressIcon(recentAddress.address),
                        color: AppTheme.deepPurple,
                        size: 20,
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Address info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MemeText(
                            recentAddress.label?.isNotEmpty == true
                                ? recentAddress.label!
                                : 'Unlabeled Address',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          const SizedBox(height: 2),
                          MemeText(
                            '${recentAddress.address.substring(0, 12)}...${recentAddress.address.substring(recentAddress.address.length - 8)}',
                            fontSize: 12,
                            color: Colors.white70
                          ),
                          const SizedBox(height: 2),
                          MemeText(
                            _formatLastUsed(recentAddress.lastUsed),
                            fontSize: 11,
                            color: Colors.white54,
                          ),
                        ],
                      ),
                    ),

                    // Usage count
                    if (recentAddress.usageCount > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.limeGreen.withAlpha((0.2 * 255).round()),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: MemeText(
                          '${recentAddress.usageCount}x',
                          fontSize: 10,
                          color: AppTheme.limeGreen,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _getAddressIcon(String address) {
    if (address.toLowerCase().startsWith('lnbc') || 
        address.toLowerCase().startsWith('lntb') || 
        address.contains('@')) {
      return Icons.bolt;
    } else if (address.startsWith('bc1p') || address.startsWith('tb1p')) {
      return Icons.park; // Taproot
    } else if (address.startsWith('bc1') || address.startsWith('tb1')) {
      return Icons.flash_on; // Native SegWit
    } else if (address.startsWith('3') || address.startsWith('2')) {
      return Icons.layers; // Nested SegWit
    } else {
      return Icons.money; // Legacy
    }
  }

  String _formatLastUsed(DateTime lastUsed) {
    final now = DateTime.now();
    final difference = now.difference(lastUsed);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String _getUsdConversion() {
    if (!services.isInitialized) {
      return '~\$-.--';
    }
    
    final priceData = services.priceService.getCurrentPrice('USD');
    if (priceData == null) {
      return '~\$-.--';
    }
    
    final usdValue = services.priceService.convertBtcToFiat(_btcAmount, priceData);
    return '~\$${usdValue.toStringAsFixed(2)}';
  }
}

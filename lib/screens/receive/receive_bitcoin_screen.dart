import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:confetti/confetti.dart';
import '../../theme/app_theme.dart';
import '../../theme/chaos_theme.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/lightning_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/animated/chaos_button.dart';
import '../../widgets/animated/meme_text.dart';
import '../../services/service_locator.dart';
import 'widgets/qr_code_display.dart';
import 'widgets/amount_request.dart';
import 'widgets/address_list.dart';

/// Main receive Bitcoin screen
class ReceiveBitcoinScreen extends StatefulWidget {
  const ReceiveBitcoinScreen({super.key});

  @override
  State<ReceiveBitcoinScreen> createState() => _ReceiveBitcoinScreenState();
}

class _ReceiveBitcoinScreenState extends State<ReceiveBitcoinScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _qrAnimationController;
  late ConfettiController _confettiController;

  // State
  bool _isGeneratingAddress = false;
  bool _showAmount = false;
  bool _isLightning = false;
  String? _currentAddress;
  String? _currentInvoice;
  int? _requestedAmount;
  String? _description;
  
  // Timer state
  DateTime? _invoiceCreatedAt;
  Timer? _expiryTimer;
  Duration _remainingTime = Duration.zero;
  bool _isInvoiceExpired = false;

  // Controllers
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _labelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _qrAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    _tabController.addListener(() {
      setState(() {
        _isLightning = _tabController.index == 1;
        _currentInvoice = null;
        _showAmount = false;
        _invoiceCreatedAt = null;
        _isInvoiceExpired = false;
      });
      _expiryTimer?.cancel();
    });

    _loadCurrentAddress();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _qrAnimationController.dispose();
    _confettiController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _labelController.dispose();
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentAddress() async {
    final walletProvider = context.read<WalletProvider>();

    if (walletProvider.currentReceiveAddress != null) {
      setState(() {
        _currentAddress = walletProvider.currentReceiveAddress!.address;
      });
    } else {
      await _generateNewAddress();
    }
  }

  Future<void> _generateNewAddress() async {
    if (_isGeneratingAddress) return;

    setState(() => _isGeneratingAddress = true);

    try {
      final walletProvider = context.read<WalletProvider>();
      await walletProvider.getNewReceiveAddress();

      if (walletProvider.currentReceiveAddress != null) {
        setState(() {
          _currentAddress = walletProvider.currentReceiveAddress!.address;
        });

        services.soundService.success();
        services.hapticService.success();
      }
    } catch (e) {
      _showError('Failed to generate address: ${e.toString()}');
    } finally {
      setState(() => _isGeneratingAddress = false);
    }
  }

  Future<void> _generateLightningInvoice() async {
    final lightningProvider = context.read<LightningProvider>();

    if (!lightningProvider.isInitialized) {
      _showError('Lightning not initialized! Set it up first ⚡');
      return;
    }

    setState(() => _isGeneratingAddress = true);

    try {
      final invoice = await lightningProvider.createInvoice(
        amountSats: _requestedAmount,
        description: _description,
        expirySecs: 3600, // 1 hour
      );

      if (invoice != null) {
        setState(() {
          _currentInvoice = invoice.bolt11;
          _invoiceCreatedAt = DateTime.now();
          _isInvoiceExpired = false;
        });

        // Start expiry timer
        _startExpiryTimer();

        services.soundService.success();
        services.hapticService.success();

        // Start QR animation
        _qrAnimationController.forward();
      }
    } catch (e) {
      _showError('Failed to create invoice: ${e.toString()}');
    } finally {
      setState(() => _isGeneratingAddress = false);
    }
  }

  void _copyToClipboard() {
    final textToCopy = _isLightning
        ? (_currentInvoice ?? '')
        : (_currentAddress ?? '');

    if (textToCopy.isEmpty) return;

    Clipboard.setData(ClipboardData(text: textToCopy));

    services.soundService.success();
    services.hapticService.success();

    // Show celebration
    _confettiController.play();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: MemeText(
          _isLightning ? 'Invoice copied! ⚡' : 'Address copied! 📋',
          color: Colors.white,
        ),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareAddress() {
    final textToShare = _isLightning
        ? (_currentInvoice ?? '')
        : _buildShareText();

    if (textToShare.isEmpty) return;

    Share.share(
      textToShare,
      subject: 'Bitcoin ${_isLightning ? "Lightning Invoice" : "Address"}',
    );

    services.soundService.tap();
    services.hapticService.medium();
  }

  String _buildShareText() {
    if (_currentAddress == null) return '';

    String text = _currentAddress!;

    if (_showAmount && _requestedAmount != null && _requestedAmount! > 0) {
      final btcAmount = _requestedAmount! / 100000000;
      text = 'bitcoin:$_currentAddress?amount=$btcAmount';

      if (_description != null && _description!.isNotEmpty) {
        text += '&label=${Uri.encodeComponent(_description!)}';
      }
    }

    return text;
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
    final chaosLevel = themeProvider.chaosLevel;

    return Scaffold(
      backgroundColor: AppTheme.darkGrey,
      body: Stack(
        children: [
          // Background effects
          if (chaosLevel >= 5)
            Container(
              decoration: BoxDecoration(
                gradient: ChaosTheme.getChaosGradient(chaosLevel),
              ),
            ).animate(
              onPlay: (controller) => controller.repeat(reverse: true),
            ).shimmer(
              duration: const Duration(seconds: 3),
              color: Colors.white.withAlpha((0.1 * 255).round()),
            ),

          // Confetti overlay
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            emissionFrequency: 0.05,
            numberOfParticles: 20,
            gravity: 0.05,
            colors: ChaosTheme.chaosColors,
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(),

                // Tab bar
                _buildTabBar(),

                // Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // On-chain receive
                      _buildOnChainReceive(),

                      // Lightning receive
                      _buildLightningReceive(),
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.go('/home'),
            icon: const Icon(Icons.close),
            color: AppTheme.limeGreen,
          ),

          const Expanded(
            child: Center(
              child: MemeText(
                'Receive Bitcoin',
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Address list button
          IconButton(
            onPressed: () => _showAddressList(),
            icon: const Icon(Icons.history),
            color: AppTheme.limeGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final themeProvider = context.watch<ThemeProvider>();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppTheme.lightGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppTheme.deepPurple,
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.link, size: 20),
                const SizedBox(width: 8),
                const Text('On-chain'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bolt, size: 20),
                const SizedBox(width: 8),
                const Text('Lightning'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnChainReceive() {
    final themeProvider = context.watch<ThemeProvider>();
    final chaosLevel = themeProvider.chaosLevel;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // QR Code
          if (_currentAddress != null)
            GestureDetector(
              onTap: _copyToClipboard,
              child: QRCodeDisplay(
                data: _buildShareText(),
                size: 250,
                isLightning: false,
                chaosLevel: chaosLevel,
              ),
            )
                .animate()
                .fadeIn(duration: 500.ms)
                .scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1, 1),
              curve: Curves.easeOutBack,
            ),

          const SizedBox(height: 24),

          // Address display
          if (_currentAddress != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.lightGrey,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.deepPurple.withAlpha((0.3 * 255).round()),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      MemeText(
                        'Bitcoin Address',
                        fontSize: 14,
                        color: Colors.white54,
                      ),

                      // Address type badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.deepPurple.withAlpha((0.2 * 255).round()),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: MemeText(
                          _getAddressType(),
                          fontSize: 12,
                          color: AppTheme.deepPurple,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  SelectableText(
                    _currentAddress!,
                    style: const TextStyle(
                      fontFamily: 'Monaco',
                      fontSize: 14,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // Amount toggle
          SwitchListTile(
            value: _showAmount,
            onChanged: (value) => setState(() => _showAmount = value),
            activeColor: AppTheme.limeGreen,
            title: MemeText(
              'Request specific amount',
              fontSize: 16,
            ),
            subtitle: MemeText(
              'Add amount to payment request',
              fontSize: 12,
              color: Colors.white54,
            ),
          ),

          // Amount input
          if (_showAmount)
            AmountRequest(
              controller: _amountController,
              descriptionController: _descriptionController,
              onAmountChanged: (amount) {
                setState(() => _requestedAmount = amount);
              },
            )
                .animate()
                .fadeIn()
                .slideY(begin: -0.2, end: 0),

          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ChaosButton(
                  text: 'Copy',
                  onPressed: _copyToClipboard,
                  isPrimary: false,
                  icon: Icons.copy,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ChaosButton(
                  text: 'Share',
                  onPressed: _shareAddress,
                  icon: Icons.share,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // New address button
          ChaosButton(
            text: _isGeneratingAddress ? 'Generating...' : 'New Address',
            onPressed: _isGeneratingAddress ? null : _generateNewAddress,
            isPrimary: false,
            icon: Icons.refresh,
          ),

          const SizedBox(height: 24),

          // Tips
          _buildTips(),
        ],
      ),
    );
  }

  Widget _buildLightningReceive() {
    final lightningProvider = context.watch<LightningProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final chaosLevel = themeProvider.chaosLevel;

    if (!lightningProvider.isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.bolt_outlined,
              size: 64,
              color: Colors.white24,
            ),
            const SizedBox(height: 16),
            MemeText(
              'Lightning not initialized',
              fontSize: 18,
              color: Colors.white54,
            ),
            const SizedBox(height: 8),
            MemeText(
              'Set up Lightning to receive instant payments',
              fontSize: 14,
              color: Colors.white38,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ChaosButton(
              text: 'Initialize Lightning',
              onPressed: () => context.go('/lightning/setup'),
              icon: Icons.flash_on,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Lightning balance info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.lightGrey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance,
                  color: AppTheme.limeGreen,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MemeText(
                        'Can Receive',
                        fontSize: 14,
                        color: Colors.white54,
                      ),
                      MemeText(
                        '${lightningProvider.receivableSats} sats',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.limeGreen,
                      ),
                    ],
                  ),
                ),

                if (lightningProvider.receivableSats == 0)
                  TextButton(
                    onPressed: () => context.go('/lightning/channels'),
                    child: MemeText(
                      'Need inbound',
                      fontSize: 12,
                      color: AppTheme.warning,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Amount input for invoice
          AmountRequest(
            controller: _amountController,
            descriptionController: _descriptionController,
            onAmountChanged: (amount) {
              setState(() => _requestedAmount = amount);
            },
            isLightning: true,
            required: false, // Lightning can have zero-amount invoices
          ),

          const SizedBox(height: 24),

          // Generate invoice button
          ChaosButton(
            text: _isGeneratingAddress ? 'Creating...' : 'Create Invoice',
            onPressed: _isGeneratingAddress ? null : _generateLightningInvoice,
            icon: Icons.receipt,
          ),

          const SizedBox(height: 24),

          // Invoice display
          if (_currentInvoice != null) ...[
            GestureDetector(
              onTap: _isInvoiceExpired ? null : _copyToClipboard,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  QRCodeDisplay(
                    data: _currentInvoice!,
                    size: 250,
                    isLightning: true,
                    chaosLevel: chaosLevel,
                  ),
                  
                  // Expired overlay
                  if (_isInvoiceExpired)
                    Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha((0.7 * 255).round()),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.timer_off,
                            size: 48,
                            color: AppTheme.error,
                          ),
                          const SizedBox(height: 8),
                          MemeText(
                            'EXPIRED',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.error,
                          ),
                          const SizedBox(height: 4),
                          MemeText(
                            'Generate new invoice',
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 300.ms),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 500.ms)
                .scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1, 1),
              curve: Curves.easeOutBack,
            ),

            const SizedBox(height: 24),

            // Invoice details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.lightGrey,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.limeGreen.withAlpha((0.3 * 255).round()),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      MemeText(
                        'Lightning Invoice',
                        fontSize: 14,
                        color: Colors.white54,
                      ),

                      // Expiry timer
                      _buildExpiryTimer(),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Invoice text (truncated)
                  GestureDetector(
                    onTap: _copyToClipboard,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.darkGrey,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_currentInvoice!.substring(0, 30)}...${_currentInvoice!.substring(_currentInvoice!.length - 20)}',
                        style: const TextStyle(
                          fontFamily: 'Monaco',
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                  if (_requestedAmount != null && _requestedAmount! > 0) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.bolt,
                          color: AppTheme.limeGreen,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        MemeText(
                          '$_requestedAmount sats',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.limeGreen,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ChaosButton(
                    text: _isInvoiceExpired ? 'Expired' : 'Copy Invoice',
                    onPressed: _isInvoiceExpired ? null : _copyToClipboard,
                    isPrimary: false,
                    icon: _isInvoiceExpired ? Icons.timer_off : Icons.copy,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ChaosButton(
                    text: _isInvoiceExpired ? 'Expired' : 'Share',
                    onPressed: _isInvoiceExpired ? null : _shareAddress,
                    icon: _isInvoiceExpired ? Icons.timer_off : Icons.share,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // Lightning address info
          _buildLightningAddressInfo(),
        ],
      ),
    );
  }

  Widget _buildExpiryTimer() {
    if (_invoiceCreatedAt == null) {
      return const SizedBox.shrink();
    }

    final isExpired = _isInvoiceExpired;
    final isNearExpiry = _remainingTime.inMinutes < 5;
    
    Color timerColor;
    IconData timerIcon;
    String timerText;
    
    if (isExpired) {
      timerColor = AppTheme.error;
      timerIcon = Icons.timer_off;
      timerText = 'EXPIRED';
    } else {
      timerColor = isNearExpiry ? AppTheme.warning : AppTheme.limeGreen;
      timerIcon = Icons.timer;
      
      final minutes = _remainingTime.inMinutes;
      final seconds = _remainingTime.inSeconds % 60;
      timerText = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: timerColor.withAlpha((0.2 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: isExpired ? Border.all(color: timerColor, width: 1) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            timerIcon,
            size: 14,
            color: timerColor,
          ),
          const SizedBox(width: 4),
          MemeText(
            timerText,
            fontSize: 12,
            color: timerColor,
            fontWeight: isExpired ? FontWeight.bold : FontWeight.normal,
          ),
        ],
      ),
    );
  }

  Widget _buildLightningAddressInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.deepPurple.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.deepPurple.withAlpha((0.3 * 255).round()),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.alternate_email,
                color: AppTheme.deepPurple,
              ),
              const SizedBox(width: 8),
              MemeText(
                'Lightning Address',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.deepPurple,
              ),
            ],
          ),
          const SizedBox(height: 8),
          MemeText(
            'Get your own Lightning address to receive payments anytime!',
            fontSize: 14,
            color: Colors.white70,
          ),
          const SizedBox(height: 12),
          ChaosButton(
            text: 'Coming Soon',
            onPressed: null,
            isPrimary: false,
            height: 40,
          ),
        ],
      ),
    );
  }

  Widget _buildTips() {
    final tips = [
      'Each address can only be used once for privacy',
      'Save addresses with labels to remember what they\'re for',
      'Bitcoin transactions need confirmations to be spendable',
      'Lightning payments are instant!',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.info.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.info.withAlpha((0.3 * 255).round()),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb,
                color: AppTheme.info,
                size: 20,
              ),
              const SizedBox(width: 8),
              MemeText(
                'Pro Tips',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.info,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...tips.map((tip) => Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MemeText('• ', fontSize: 14, color: AppTheme.info),
                Expanded(
                  child: MemeText(
                    tip,
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  String _getAddressType() {
    if (_currentAddress == null) return '';

    if (_currentAddress!.startsWith('bc1p') || _currentAddress!.startsWith('tb1p')) {
      return 'Taproot';
    } else if (_currentAddress!.startsWith('bc1') || _currentAddress!.startsWith('tb1')) {
      return 'Native SegWit';
    } else if (_currentAddress!.startsWith('3') || _currentAddress!.startsWith('2')) {
      return 'Nested SegWit';
    } else {
      return 'Legacy';
    }
  }

  void _showAddressList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddressList(
        onAddressSelected: (address) {
          setState(() => _currentAddress = address.address);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _startExpiryTimer() {
    _expiryTimer?.cancel();
    
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_invoiceCreatedAt == null) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      final elapsed = now.difference(_invoiceCreatedAt!);
      const expiryDuration = Duration(hours: 1); // 1 hour as set in createInvoice
      
      if (elapsed >= expiryDuration) {
        // Invoice expired
        setState(() {
          _isInvoiceExpired = true;
          _remainingTime = Duration.zero;
        });
        timer.cancel();
        
        // Play expiry sound
        services.soundService.error();
        services.hapticService.warning();
        
        // Show expiry message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: MemeText(
              'Invoice expired! Generate a new one ⚡',
              color: Colors.white,
            ),
            backgroundColor: AppTheme.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // Update remaining time
        setState(() {
          _remainingTime = expiryDuration - elapsed;
          _isInvoiceExpired = false;
        });
      }
    });
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../theme/chaos_theme.dart';
import '../../providers/lightning_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/animated/meme_text.dart';
import '../../widgets/animated/chaos_button.dart';
import '../../widgets/effects/glitch_effect.dart';
import '../../services/service_locator.dart';

class PayInvoiceScreen extends StatefulWidget {
  final String? initialInvoice;
  
  const PayInvoiceScreen({super.key, this.initialInvoice});

  @override
  State<PayInvoiceScreen> createState() => _PayInvoiceScreenState();
}

class _PayInvoiceScreenState extends State<PayInvoiceScreen>
    with TickerProviderStateMixin {
  late AnimationController _scanController;
  
  final _formKey = GlobalKey<FormState>();
  final _invoiceController = TextEditingController();
  final _amountController = TextEditingController();
  final _lightningAddressController = TextEditingController();
  
  bool _isPaying = false;
  bool _isParsingInvoice = false;
  bool _isLightningAddress = false;
  String? _paymentError;
  String? _paymentHash;
  
  // Parsed invoice details
  Map<String, dynamic>? _invoiceDetails;
  
  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    if (widget.initialInvoice != null) {
      _invoiceController.text = widget.initialInvoice!;
      _parseInvoice();
    }
  }

  @override
  void dispose() {
    _scanController.dispose();
    _invoiceController.dispose();
    _amountController.dispose();
    _lightningAddressController.dispose();
    super.dispose();
  }

  void _parseInvoice() {
    final invoice = _invoiceController.text.trim();
    if (invoice.isEmpty) {
      setState(() => _invoiceDetails = null);
      return;
    }

    setState(() => _isParsingInvoice = true);

    try {
      // Basic BOLT11 invoice parsing
      if (invoice.toLowerCase().startsWith('ln')) {
        // This is a simplified parser - in production you'd use a proper BOLT11 parser
        setState(() {
          _invoiceDetails = {
            'type': 'bolt11',
            'raw': invoice,
            'amount': null, // Would be parsed from invoice
            'description': 'Lightning Invoice',
            'expiry': null,
          };
        });
      } else if (invoice.contains('@') && !invoice.contains(' ')) {
        // Lightning address
        setState(() {
          _invoiceDetails = {
            'type': 'lightning_address',
            'address': invoice,
          };
          _isLightningAddress = true;
        });
      } else {
        setState(() => _invoiceDetails = null);
      }
    } catch (e) {
      setState(() => _invoiceDetails = null);
    } finally {
      setState(() => _isParsingInvoice = false);
    }
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text != null) {
        _invoiceController.text = clipboardData!.text!;
        _parseInvoice();
        services.hapticService.light();
      }
    } catch (e) {
      // Handle clipboard error
    }
  }

  Future<void> _scanQR() async {
    try {
      // Navigate to QR scanner
      final result = await context.push('/scan');
      if (result != null && result is String) {
        _invoiceController.text = result;
        _parseInvoice();
      }
    } catch (e) {
      // Handle scan error
    }
  }

  Future<void> _payInvoice() async {
    if (!_formKey.currentState!.validate() || _isPaying) return;
    
    setState(() {
      _isPaying = true;
      _paymentError = null;
      _paymentHash = null;
    });

    try {
      final lightningProvider = context.read<LightningProvider>();
      
      String? paymentHash;
      
      if (_isLightningAddress) {
        // Pay to Lightning address
        final address = _lightningAddressController.text.trim();
        final amount = int.parse(_amountController.text);
        
        paymentHash = await lightningProvider.sendToLightningAddress(
          address: address,
          amountSats: amount,
        );
      } else {
        // Pay BOLT11 invoice
        final invoice = _invoiceController.text.trim();
        final amount = _amountController.text.isNotEmpty 
            ? int.parse(_amountController.text) 
            : null;
            
        paymentHash = await lightningProvider.payInvoice(
          bolt11: invoice,
          amountSats: amount,
        );
      }

      if (paymentHash != null && mounted) {
        setState(() => _paymentHash = paymentHash);
        
        await services.soundService.success();
        await services.hapticService.success();
        
        _showSuccessDialog(paymentHash);
      } else {
        throw Exception(lightningProvider.error ?? 'Payment failed');
      }
    } catch (e) {
      setState(() {
        _paymentError = e.toString();
      });
      
      await services.soundService.error();
      await services.hapticService.error();
    } finally {
      setState(() {
        _isPaying = false;
      });
    }
  }

  void _showSuccessDialog(String paymentHash) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.limeGreen),
            const SizedBox(width: 8),
            MemeText('Payment Sent! ⚡', fontSize: 18),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MemeText(
              'Your Lightning payment has been sent successfully!',
              fontSize: 14,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.lightGrey,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MemeText('Payment Hash:', fontSize: 12, color: AppTheme.cyan),
                  MemeText(paymentHash.substring(0, 32) + '...', fontSize: 10),
                  if (!_isLightningAddress && _amountController.text.isNotEmpty)
                    MemeText('Amount: ${_amountController.text} sats', fontSize: 12),
                  if (_isLightningAddress)
                    MemeText('Sent to: ${_lightningAddressController.text}', fontSize: 12),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ChaosButton(
            text: 'View Payments',
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/transactions');
            },
            height: 40,
          ),
          const SizedBox(width: 8),
          ChaosButton(
            text: 'Done',
            onPressed: () {
              Navigator.of(context).pop();
              context.pop();
            },
            isPrimary: false,
            height: 40,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lightningProvider = context.watch<LightningProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final chaosLevel = themeProvider.chaosLevel;

    if (!lightningProvider.isInitialized) {
      return _buildUninitialized();
    }

    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        title: Row(
          children: [
            Icon(Icons.send, color: AppTheme.hotPink),
            const SizedBox(width: 8),
            MemeText('Pay Lightning Invoice', fontSize: 18),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Center(
                child: Column(
                  children: [
                    GlitchEffect(
                      child: Icon(
                        Icons.bolt,
                        size: 80,
                        color: AppTheme.hotPink,
                      ),
                    ).animate().scale(delay: 200.ms),
                    
                    const SizedBox(height: 16),
                    
                    MemeText(
                      'Send Lightning Payment ⚡',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 400.ms),
                    
                    const SizedBox(height: 8),
                    
                    MemeText(
                      'Pay a Lightning invoice or send to a Lightning address',
                      fontSize: 14,
                      color: Colors.white70,
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 600.ms),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Balance info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: ChaosTheme.getChaosDecoration(
                  chaosLevel: chaosLevel,
                  baseColor: AppTheme.darkGrey,
                ),
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: AppTheme.limeGreen),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MemeText('Available to Send', fontSize: 12, color: Colors.white60),
                          MemeText('${lightningProvider.spendableSats} sats', 
                                  fontSize: 16, fontWeight: FontWeight.bold),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 800.ms),

              const SizedBox(height: 24),

              // Payment type tabs
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.lightGrey,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildPaymentTypeTab(
                        title: 'Invoice',
                        isSelected: !_isLightningAddress,
                        onTap: () => setState(() => _isLightningAddress = false),
                      ),
                    ),
                    Expanded(
                      child: _buildPaymentTypeTab(
                        title: 'Address',
                        isSelected: _isLightningAddress,
                        onTap: () => setState(() => _isLightningAddress = true),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              if (_isLightningAddress) ...[
                // Lightning address input
                _buildInputField(
                  controller: _lightningAddressController,
                  label: 'Lightning Address',
                  hint: 'user@domain.com',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a Lightning address';
                    }
                    if (!value.contains('@') || value.split('@').length != 2) {
                      return 'Invalid Lightning address format';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Amount for Lightning address
                _buildInputField(
                  controller: _amountController,
                  label: 'Amount (sats)',
                  hint: 'e.g., 1000',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an amount';
                    }
                    final amount = int.tryParse(value);
                    if (amount == null) {
                      return 'Please enter a valid number';
                    }
                    if (amount <= 0) {
                      return 'Amount must be positive';
                    }
                    if (amount > lightningProvider.spendableSats) {
                      return 'Amount exceeds available balance';
                    }
                    return null;
                  },
                ),
              ] else ...[
                // Invoice input
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: MemeText('Lightning Invoice', fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.content_paste, color: AppTheme.cyan),
                              onPressed: _pasteFromClipboard,
                              tooltip: 'Paste',
                            ),
                            IconButton(
                              icon: Icon(Icons.qr_code_scanner, color: AppTheme.hotPink),
                              onPressed: _scanQR,
                              tooltip: 'Scan QR',
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    TextFormField(
                      controller: _invoiceController,
                      decoration: InputDecoration(
                        hintText: 'lnbc1000n1p...',
                        hintStyle: TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: AppTheme.lightGrey,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.hotPink, width: 2),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a Lightning invoice';
                        }
                        if (!value.toLowerCase().startsWith('ln')) {
                          return 'Invalid Lightning invoice format';
                        }
                        return null;
                      },
                      onChanged: (_) {
                        _parseInvoice();
                        setState(() => _paymentError = null);
                      },
                    ),
                  ],
                ),

                // Invoice details
                if (_invoiceDetails != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.limeGreen.withAlpha((0.1 * 255).round()),
                      border: Border.all(color: AppTheme.limeGreen.withAlpha((0.3 * 255).round())),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle, color: AppTheme.limeGreen, size: 20),
                            const SizedBox(width: 8),
                            MemeText('Invoice Parsed', fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.limeGreen),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_invoiceDetails!['amount'] != null)
                          MemeText('Amount: ${_invoiceDetails!['amount']} sats', fontSize: 12),
                        if (_invoiceDetails!['description'] != null)
                          MemeText('Description: ${_invoiceDetails!['description']}', fontSize: 12),
                        MemeText('Type: Lightning Invoice', fontSize: 12, color: Colors.white70),
                      ],
                    ),
                  ),
                ],

                // Variable amount input
                if (_invoiceDetails != null && _invoiceDetails!['amount'] == null) ...[
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _amountController,
                    label: 'Amount (sats)',
                    hint: 'Enter amount to pay',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an amount';
                      }
                      final amount = int.tryParse(value);
                      if (amount == null) {
                        return 'Please enter a valid number';
                      }
                      if (amount <= 0) {
                        return 'Amount must be positive';
                      }
                      if (amount > lightningProvider.spendableSats) {
                        return 'Amount exceeds available balance';
                      }
                      return null;
                    },
                  ),
                ],
              ],

              const SizedBox(height: 24),

              // Error display
              if (_paymentError != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withAlpha((0.1 * 255).round()),
                    border: Border.all(color: AppTheme.error),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.error, color: AppTheme.error, size: 20),
                          const SizedBox(width: 8),
                          MemeText('Payment Failed', fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.error),
                        ],
                      ),
                      const SizedBox(height: 8),
                      MemeText(_paymentError!, fontSize: 12, color: Colors.white70),
                    ],
                  ),
                ),

              if (_paymentError != null) const SizedBox(height: 24),

              // Pay button
              SizedBox(
                width: double.infinity,
                child: ChaosButton(
                  text: _isPaying ? 'Sending Payment...' : 'Send Payment',
                  onPressed: _isPaying ? null : _payInvoice,
                  height: 56,
                  icon: _isPaying ? null : Icons.send,
                ),
              ),

              const SizedBox(height: 16),

              // Info note
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cyan.withAlpha((0.1 * 255).round()),
                  border: Border.all(color: AppTheme.cyan.withAlpha((0.3 * 255).round())),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info, color: AppTheme.cyan, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MemeText('Lightning Payment Info', fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.cyan),
                          const SizedBox(height: 4),
                          MemeText(
                            '• Lightning payments are instant and low-cost\n'
                            '• Payments are final and cannot be reversed\n'
                            '• Ensure you have sufficient channel liquidity\n'
                            '• Lightning addresses work like email addresses',
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUninitialized() {
    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        title: MemeText('Pay Invoice', fontSize: 20),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bolt_outlined, size: 80, color: Colors.white38),
            const SizedBox(height: 24),
            MemeText(
              'Lightning Not Initialized',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            MemeText(
              'Initialize Lightning Network to send payments',
              fontSize: 16,
              textAlign: TextAlign.center,
              color: Colors.white60,
            ),
            const SizedBox(height: 32),
            ChaosButton(
              text: 'Initialize Lightning',
              onPressed: () => context.go('/lightning/setup'),
              icon: Icons.flash_on,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentTypeTab({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        onTap();
        services.hapticService.light();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.hotPink : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: MemeText(
            title,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.white60,
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MemeText(label, fontSize: 14, fontWeight: FontWeight.bold),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white38),
            filled: true,
            fillColor: AppTheme.lightGrey,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.hotPink, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.error, width: 2),
            ),
          ),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          onChanged: (_) => setState(() => _paymentError = null),
        ),
      ],
    );
  }
}
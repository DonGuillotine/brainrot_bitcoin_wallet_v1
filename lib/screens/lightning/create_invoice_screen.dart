import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../theme/app_theme.dart';
import '../../theme/chaos_theme.dart';
import '../../providers/lightning_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/animated/meme_text.dart';
import '../../widgets/animated/chaos_button.dart';
import '../../widgets/effects/glitch_effect.dart';
import '../../widgets/share_sheet.dart';
import '../../models/lightning_models.dart';
import '../../services/service_locator.dart';

class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen>
    with TickerProviderStateMixin {
  late AnimationController _qrController;
  
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  bool _isCreating = false;
  bool _isVariableAmount = true;
  int _expiryHours = 1;
  String? _creationError;
  BrainrotInvoice? _createdInvoice;
  
  @override
  void initState() {
    super.initState();
    _qrController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _qrController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createInvoice() async {
    if (_isCreating) return;
    
    if (!_isVariableAmount && !_formKey.currentState!.validate()) return;
    
    setState(() {
      _isCreating = true;
      _creationError = null;
    });

    try {
      final lightningProvider = context.read<LightningProvider>();
      
      final amountSats = _isVariableAmount || _amountController.text.isEmpty 
          ? null 
          : int.parse(_amountController.text);
      
      final description = _descriptionController.text.trim().isEmpty 
          ? null 
          : _descriptionController.text.trim();

      final invoice = await lightningProvider.createInvoice(
        amountSats: amountSats,
        description: description,
        expirySecs: _expiryHours * 3600,
      );

      if (invoice != null && mounted) {
        setState(() => _createdInvoice = invoice);
        _qrController.forward();
        
        await services.soundService.success();
        await services.hapticService.success();
      } else {
        throw Exception(lightningProvider.error ?? 'Failed to create invoice');
      }
    } catch (e) {
      setState(() {
        _creationError = e.toString();
      });
      
      await services.soundService.error();
      await services.hapticService.error();
    } finally {
      setState(() {
        _isCreating = false;
      });
    }
  }

  void _copyInvoice() {
    if (_createdInvoice != null) {
      Clipboard.setData(ClipboardData(text: _createdInvoice!.bolt11));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Invoice copied to clipboard! ⚡'),
          backgroundColor: AppTheme.limeGreen,
        ),
      );
      services.hapticService.light();
    }
  }

  void _shareInvoice() {
    if (_createdInvoice != null) {
      ShareSheet.show(
        context: context,
        data: _createdInvoice!.bolt11,
        type: 'invoice',
      );
    }
  }

  void _createNewInvoice() {
    setState(() {
      _createdInvoice = null;
      _creationError = null;
      _amountController.clear();
      _descriptionController.clear();
    });
    _qrController.reset();
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
            Icon(Icons.receipt, color: AppTheme.limeGreen),
            const SizedBox(width: 8),
            MemeText('Create Lightning Invoice', fontSize: 18),
          ],
        ),
        actions: [
          if (_createdInvoice != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _createNewInvoice,
              tooltip: 'Create New Invoice',
            ),
        ],
      ),
      body: _createdInvoice != null 
          ? _buildInvoiceDisplay(chaosLevel)
          : _buildInvoiceForm(chaosLevel),
    );
  }

  Widget _buildUninitialized() {
    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        title: MemeText('Create Invoice', fontSize: 20),
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
              'Initialize Lightning Network to create invoices',
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

  Widget _buildInvoiceForm(int chaosLevel) {
    return SingleChildScrollView(
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
                      Icons.receipt_long,
                      size: 80,
                      color: AppTheme.limeGreen,
                    ),
                  ).animate().scale(delay: 200.ms),
                  
                  const SizedBox(height: 16),
                  
                  MemeText(
                    'Create Lightning Invoice ⚡',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 400.ms),
                  
                  const SizedBox(height: 8),
                  
                  MemeText(
                    'Generate an invoice to receive Lightning payments',
                    fontSize: 14,
                    color: Colors.white70,
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 600.ms),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Amount type selection
            Container(
              padding: const EdgeInsets.all(16),
              decoration: ChaosTheme.getChaosDecoration(
                chaosLevel: chaosLevel,
                baseColor: AppTheme.darkGrey,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MemeText('Invoice Type', fontSize: 16, fontWeight: FontWeight.bold),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildAmountTypeOption(
                          title: 'Variable Amount',
                          description: 'Payer chooses amount',
                          isSelected: _isVariableAmount,
                          onTap: () => setState(() => _isVariableAmount = true),
                          icon: Icons.dynamic_form,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildAmountTypeOption(
                          title: 'Fixed Amount',
                          description: 'Set specific amount',
                          isSelected: !_isVariableAmount,
                          onTap: () => setState(() => _isVariableAmount = false),
                          icon: Icons.pin,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 800.ms),

            const SizedBox(height: 20),

            // Amount input (if fixed amount)
            if (!_isVariableAmount) ...[
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
                  return null;
                },
              ),
              const SizedBox(height: 20),
            ],

            // Description input
            _buildInputField(
              controller: _descriptionController,
              label: 'Description (Optional)',
              hint: 'What is this payment for?',
              maxLines: 3,
            ),

            const SizedBox(height: 20),

            // Expiry time selection
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.lightGrey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MemeText('Invoice Expiry', fontSize: 16, fontWeight: FontWeight.bold),
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Icon(Icons.timer, color: AppTheme.cyan, size: 20),
                      const SizedBox(width: 8),
                      MemeText('Expires in $_expiryHours hour${_expiryHours == 1 ? '' : 's'}', fontSize: 14),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  Slider(
                    value: _expiryHours.toDouble(),
                    min: 1,
                    max: 24,
                    divisions: 23,
                    activeColor: AppTheme.hotPink,
                    inactiveColor: AppTheme.darkGrey,
                    onChanged: (value) {
                      setState(() => _expiryHours = value.toInt());
                      services.hapticService.light();
                    },
                  ),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      MemeText('1 hour', fontSize: 12, color: Colors.white60),
                      MemeText('24 hours', fontSize: 12, color: Colors.white60),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Error display
            if (_creationError != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.error..withAlpha((0.1 * 255).round()),
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
                        MemeText('Invoice Creation Failed', fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.error),
                      ],
                    ),
                    const SizedBox(height: 8),
                    MemeText(_creationError!, fontSize: 12, color: Colors.white70),
                  ],
                ),
              ),

            if (_creationError != null) const SizedBox(height: 24),

            // Create button
            SizedBox(
              width: double.infinity,
              child: ChaosButton(
                text: _isCreating ? 'Creating Invoice...' : 'Create Invoice',
                onPressed: _isCreating ? null : _createInvoice,
                height: 56,
                icon: _isCreating ? null : Icons.receipt_long,
              ),
            ),

            const SizedBox(height: 16),

            // Info note
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cyan..withAlpha((0.1 * 255).round()),
                border: Border.all(color: AppTheme.cyan..withAlpha((0.3 * 255).round())),
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
                        MemeText('Lightning Invoice Info', fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.cyan),
                        const SizedBox(height: 4),
                        MemeText(
                          '• Invoices expire after the set time\n'
                          '• Variable amount invoices let the payer choose\n'
                          '• Add descriptions to help identify payments\n'
                          '• Share via QR code or copy the invoice text',
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
    );
  }

  Widget _buildInvoiceDisplay(int chaosLevel) {
    final invoice = _createdInvoice!;
    final timeLeft = invoice.timeUntilExpiry;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Header
          MemeText(
            'Invoice Created! 🎉',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            textAlign: TextAlign.center,
          ).animate().fadeIn()
              .scale(
            duration: 300.ms,
            begin: const Offset(0.8, 0.8), // Start slightly smaller
            end: const Offset(1.1, 1.1),   // Scale up
            curve: Curves.easeOut,
          ).then(delay: 0.ms) // Chain the next effect
              .scale(
            duration: 300.ms,
            begin: const Offset(1.1, 1.1),
            end: const Offset(1.0, 1.0),   // Scale back to normal
            curve: Curves.elasticOut, // Or another curve for bounciness
          ),

          const SizedBox(height: 8),

          MemeText(
            'Share this QR code or invoice text to receive payment',
            fontSize: 14,
            color: Colors.white70,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // QR Code
          Container(
            padding: const EdgeInsets.all(20),
            decoration: ChaosTheme.getChaosDecoration(
              chaosLevel: chaosLevel,
              baseColor: Colors.white,
            ),
            child: QrImageView(
              data: invoice.bolt11,
              version: QrVersions.auto,
              size: 280.0,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
          ).animate(controller: _qrController)
            .scale(begin: const Offset(0.8, 0.8))
            .fadeIn(),

          const SizedBox(height: 24),

          // Invoice details
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: ChaosTheme.getChaosDecoration(
              chaosLevel: chaosLevel,
              baseColor: AppTheme.darkGrey,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.receipt, color: AppTheme.hotPink),
                    const SizedBox(width: 8),
                    MemeText('Invoice Details', fontSize: 18, fontWeight: FontWeight.bold),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                _buildDetailRow('Amount:', invoice.amountSats != null 
                    ? '${invoice.amountSats} sats' 
                    : 'Variable (payer chooses)'),
                
                if (invoice.description != null && invoice.description!.isNotEmpty)
                  _buildDetailRow('Description:', invoice.description!),
                
                _buildDetailRow('Status:', invoice.getMemeStatus()),
                
                _buildDetailRow('Expires in:', timeLeft.inMinutes > 0 
                    ? '${timeLeft.inHours}h ${timeLeft.inMinutes.remainder(60)}m'
                    : 'Expired'),
                
                _buildDetailRow('Created:', _formatDateTime(invoice.createdAt)),

                const SizedBox(height: 16),

                // Invoice emojis
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: invoice.getEmojis().map((emoji) => 
                    Text(emoji, style: const TextStyle(fontSize: 24))
                      .animate(delay: Duration(milliseconds: invoice.getEmojis().indexOf(emoji) * 100))
                      .scale()
                  ).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ChaosButton(
                  text: 'Copy Invoice',
                  onPressed: _copyInvoice,
                  isPrimary: false,
                  height: 50,
                  icon: Icons.copy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChaosButton(
                  text: 'Share',
                  onPressed: _shareInvoice,
                  height: 50,
                  icon: Icons.share,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ChaosButton(
              text: 'Create New Invoice',
              onPressed: _createNewInvoice,
              isPrimary: false,
              height: 50,
              icon: Icons.add,
            ),
          ),

          const SizedBox(height: 16),

          // Invoice text (collapsible)
          ExpansionTile(
            title: MemeText('View Invoice Text', fontSize: 14),
            leading: Icon(Icons.code, color: AppTheme.cyan),
            iconColor: AppTheme.hotPink,
            collapsedIconColor: AppTheme.hotPink,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.lightGrey,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  invoice.bolt11,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountTypeOption({
    required String title,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: () {
        onTap();
        services.hapticService.light();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.hotPink.withAlpha((0.1 * 255).round()) : AppTheme.lightGrey,
          border: Border.all(
            color: isSelected ? AppTheme.hotPink : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppTheme.hotPink : Colors.white54, size: 24),
            const SizedBox(height: 8),
            MemeText(title, fontSize: 14, fontWeight: FontWeight.bold),
            const SizedBox(height: 4),
            MemeText(description, fontSize: 12, color: Colors.white60, textAlign: TextAlign.center),
          ],
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
          onChanged: (_) => setState(() => _creationError = null),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: MemeText(label, fontSize: 12, color: Colors.white60),
          ),
          Expanded(
            child: MemeText(value, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
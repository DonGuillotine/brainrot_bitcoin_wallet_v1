import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../theme/chaos_theme.dart';
import '../../providers/lightning_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/animated/meme_text.dart';
import '../../widgets/animated/chaos_button.dart';
import '../../widgets/effects/glitch_effect.dart';
import '../../services/service_locator.dart';

class OpenChannelScreen extends StatefulWidget {
  const OpenChannelScreen({super.key});

  @override
  State<OpenChannelScreen> createState() => _OpenChannelScreenState();
}

class _OpenChannelScreenState extends State<OpenChannelScreen>
    with TickerProviderStateMixin {
  late AnimationController _progressController;

  final _formKey = GlobalKey<FormState>();
  final _nodeIdController = TextEditingController();
  final _nodeAddressController = TextEditingController();
  final _amountController = TextEditingController();
  final _pushAmountController = TextEditingController();

  bool _isOpening = false;
  bool _announceChannel = false;
  String? _openingError;

  // Popular Lightning nodes for quick connect
  final List<Map<String, String>> _popularNodes = [
    {
      'name': 'ACINQ',
      'nodeId': '03864ef025fde8fb587d989186ce6a4a186895ee44a926bfc370e2c366597a3f8f',
      'address': '3.33.236.230:9735',
      'description': 'Reliable node by ACINQ team',
    },
    {
      'name': 'Bitrefill',
      'nodeId': '030c3f19d742ca294a55c00376b3b355c3c90d61c6b6b39554dbc7ac19b141c14f',
      'address': '52.50.244.44:9735',
      'description': 'Well-connected merchant node',
    },
    {
      'name': 'OpenNode',
      'nodeId': '02f1a8c87607f415c8f22c00593002775941dea48869ce23096af27b0cfdcc0b69',
      'address': '18.191.253.246:9735',
      'description': 'OpenNode payment processor',
    },
    {
      'name': 'WalletOfSatoshi',
      'nodeId': '035e4ff418fc8b5554c5d9eea66396c227bd429a3251c8cbc711002ba215bfc226',
      'address': '170.75.163.209:9735',
      'description': 'Popular custodial wallet',
    },
  ];

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _progressController.dispose();
    _nodeIdController.dispose();
    _nodeAddressController.dispose();
    _amountController.dispose();
    _pushAmountController.dispose();
    super.dispose();
  }

  void _selectPopularNode(Map<String, String> node) {
    setState(() {
      _nodeIdController.text = node['nodeId']!;
      _nodeAddressController.text = node['address']!;
    });

    services.hapticService.light();
  }

  Future<void> _openChannel() async {
    if (!_formKey.currentState!.validate() || _isOpening) return;

    setState(() {
      _isOpening = true;
      _openingError = null;
    });

    try {
      final lightningProvider = context.read<LightningProvider>();
      final walletProvider = context.read<WalletProvider>();

      final amountSats = int.parse(_amountController.text);
      final pushSats = _pushAmountController.text.isNotEmpty
          ? int.parse(_pushAmountController.text)
          : null;

      // Check wallet balance
      // FIX: Access balance via walletProvider.balance?.confirmed
      final confirmedBalance = walletProvider.balance?.confirmed ?? 0;
      if (confirmedBalance < amountSats) {
        throw Exception('Insufficient wallet balance. You need $amountSats sats but only have $confirmedBalance sats.');
      }

      final channelId = await lightningProvider.openChannel(
        nodeId: _nodeIdController.text.trim(),
        nodeAddress: _nodeAddressController.text.trim(),
        amountSats: amountSats,
        pushSats: pushSats,
        announceChannel: _announceChannel,
      );

      if (channelId != null && mounted) {
        await services.soundService.success();
        await services.hapticService.success();

        _showSuccessDialog(channelId);
      } else {
        throw Exception(lightningProvider.error ?? 'Failed to open channel');
      }
    } catch (e) {
      setState(() {
        _openingError = e.toString();
      });

      await services.soundService.error();
      await services.hapticService.error();
    } finally {
      if (mounted) {
        setState(() {
          _isOpening = false;
        });
      }
    }
  }

  void _showSuccessDialog(String channelId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: Row(
          children: [
            Icon(Icons.celebration, color: AppTheme.limeGreen),
            const SizedBox(width: 8),
            MemeText('Channel Opening! 🎉', fontSize: 18),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MemeText(
              'Your Lightning channel is being opened! It may take a few minutes to confirm on the network.',
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
                  MemeText('Channel ID:', fontSize: 12, color: AppTheme.cyan),
                  MemeText(channelId.substring(0, 32) + '...', fontSize: 10),
                  const SizedBox(height: 8),
                  MemeText('Amount: ${_amountController.text} sats', fontSize: 12),
                  if (_pushAmountController.text.isNotEmpty)
                    MemeText('Push Amount: ${_pushAmountController.text} sats', fontSize: 12),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ChaosButton(
            text: 'View Channels',
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/lightning/channels');
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
    final themeProvider = context.watch<ThemeProvider>();
    final walletProvider = context.watch<WalletProvider>();
    final chaosLevel = themeProvider.chaosLevel;

    // FIX: Access balance via walletProvider.balance?.confirmed and provide a default
    final confirmedBalance = walletProvider.balance?.confirmed ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        title: Row(
          children: [
            Icon(Icons.add_circle, color: AppTheme.hotPink),
            const SizedBox(width: 8),
            MemeText('Open Lightning Channel', fontSize: 20),
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
              // Header with animation
              Center(
                child: Column(
                  children: [
                    GlitchEffect(
                      child: Icon(
                        Icons.hub,
                        size: 80,
                        color: AppTheme.hotPink,
                      ),
                    ).animate().scale(delay: 200.ms),

                    const SizedBox(height: 16),

                    MemeText(
                      'Open a Lightning Channel ⚡',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 400.ms),

                    const SizedBox(height: 8),

                    MemeText(
                      'Connect to another Lightning node to enable payments',
                      fontSize: 14,
                      color: Colors.white70,
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 600.ms),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Wallet balance info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: ChaosTheme.getChaosDecoration(
                  chaosLevel: chaosLevel,
                  baseColor: AppTheme.darkGrey,
                ),
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: AppTheme.cyan),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MemeText('Available Balance', fontSize: 12, color: Colors.white60),
                          MemeText('$confirmedBalance sats', // <-- FIX: Use the local variable
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 800.ms),

              const SizedBox(height: 24),

              // Popular nodes section
              MemeText(
                'Quick Connect to Popular Nodes',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: ChaosTheme.getChaosDecoration(
                  chaosLevel: chaosLevel,
                  baseColor: AppTheme.lightGrey,
                ),
                child: Column(
                  children: _popularNodes.map((node) =>
                      _buildPopularNodeCard(node, chaosLevel)
                  ).toList(),
                ),
              ).animate().fadeIn(delay: 1000.ms),

              const SizedBox(height: 24),

              // Manual input section
              MemeText(
                'Or Enter Node Details Manually',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),

              const SizedBox(height: 16),

              // Node ID input
              _buildInputField(
                controller: _nodeIdController,
                label: 'Node Public Key',
                hint: '03abcd1234...',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a node public key';
                  }
                  if (value.length != 66) {
                    return 'Node public key must be 66 characters';
                  }
                  return null;
                },
                maxLines: 2,
              ),

              const SizedBox(height: 16),

              // Node address input
              _buildInputField(
                controller: _nodeAddressController,
                label: 'Node Address',
                hint: 'hostname:port (e.g., node.example.com:9735)',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a node address';
                  }
                  if (!value.contains(':')) {
                    return 'Address must include port (e.g., host:9735)';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Amount input
              _buildInputField(
                controller: _amountController,
                label: 'Channel Amount (sats)',
                hint: 'e.g., 100000',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter channel amount';
                  }
                  final amount = int.tryParse(value);
                  if (amount == null) {
                    return 'Please enter a valid number';
                  }
                  if (amount < 20000) {
                    return 'Minimum channel size is 20,000 sats';
                  }
                  // FIX: Use the local variable for balance
                  if (amount > confirmedBalance) {
                    return 'Amount exceeds wallet balance';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Push amount input (optional)
              _buildInputField(
                controller: _pushAmountController,
                label: 'Push Amount (sats) - Optional',
                hint: 'Amount to send to peer (optional)',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final pushAmount = int.tryParse(value);
                    final channelAmount = int.tryParse(_amountController.text);
                    if (pushAmount == null) {
                      return 'Please enter a valid number';
                    }
                    if (channelAmount != null && pushAmount > channelAmount) {
                      return 'Push amount cannot exceed channel amount';
                    }
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Announce channel option
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.lightGrey,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Switch(
                      value: _announceChannel,
                      onChanged: (value) {
                        setState(() => _announceChannel = value);
                        services.hapticService.light();
                      },
                      activeColor: AppTheme.hotPink,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MemeText('Announce Channel', fontSize: 14, fontWeight: FontWeight.bold),
                          MemeText(
                            'Make this channel public for routing payments',
                            fontSize: 12,
                            color: Colors.white60,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Error display
              if (_openingError != null)
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
                          MemeText('Channel Opening Failed', fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.error),
                        ],
                      ),
                      const SizedBox(height: 8),
                      MemeText(_openingError!, fontSize: 12, color: Colors.white70),
                    ],
                  ),
                ),

              if (_openingError != null) const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ChaosButton(
                      text: 'Cancel',
                      onPressed: () => context.pop(),
                      isPrimary: false,
                      height: 56,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ChaosButton(
                      text: _isOpening ? 'Opening Channel...' : 'Open Channel',
                      onPressed: _isOpening ? null : _openChannel,
                      height: 56,
                      icon: _isOpening ? null : Icons.rocket_launch,
                    ),
                  ),
                ],
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
                          MemeText('Channel Opening Process', fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.cyan),
                          const SizedBox(height: 4),
                          MemeText(
                            '• Channel opening requires an on-chain transaction\n'
                                '• It may take 10-30 minutes to confirm\n'
                                '• Once confirmed, you can send/receive Lightning payments\n'
                                '• Choose reliable, well-connected nodes for best routing',
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

  Widget _buildPopularNodeCard(Map<String, String> node, int chaosLevel) {
    return GestureDetector(
      onTap: () => _selectPopularNode(node),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.darkGrey,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (_nodeIdController.text == node['nodeId'])
                ? AppTheme.hotPink
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.hotPink.withAlpha((0.2 * 255).round()),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.hub, color: AppTheme.hotPink, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MemeText(node['name']!, fontSize: 16, fontWeight: FontWeight.bold),
                  MemeText(node['description']!, fontSize: 12, color: Colors.white60),
                  const SizedBox(height: 4),
                  MemeText('${node['nodeId']!.substring(0, 20)}...', fontSize: 10, color: AppTheme.cyan),
                ],
              ),
            ),
            if (_nodeIdController.text == node['nodeId'])
              Icon(Icons.check_circle, color: AppTheme.hotPink),
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
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.error, width: 2),
            ),
          ),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          onChanged: (_) {
            if (mounted) {
              setState(() => _openingError = null);
            }
          },
        ),
      ],
    );
  }
}

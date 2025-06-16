import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../theme/chaos_theme.dart';
import '../../providers/lightning_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/animated/meme_text.dart';
import '../../widgets/animated/chaos_button.dart';
import '../../widgets/effects/glitch_effect.dart';
import '../../models/lightning_models.dart';
import '../../services/service_locator.dart';

class ChannelListScreen extends StatefulWidget {
  const ChannelListScreen({super.key});

  @override
  State<ChannelListScreen> createState() => _ChannelListScreenState();
}

class _ChannelListScreenState extends State<ChannelListScreen>
    with TickerProviderStateMixin {
  late AnimationController _refreshController;
  bool _isRefreshing = false;
  BrainrotChannel? _selectedChannel;

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _refreshChannels();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _refreshChannels() async {
    if (_isRefreshing) return;
    
    setState(() => _isRefreshing = true);
    _refreshController.repeat();
    
    try {
      final lightningProvider = context.read<LightningProvider>();
      await lightningProvider.syncNode();
      await services.hapticService.light();
    } catch (e) {
      await services.soundService.error();
    } finally {
      _refreshController.stop();
      _refreshController.reset();
      setState(() => _isRefreshing = false);
    }
  }

  void _showChannelDetails(BrainrotChannel channel) {
    setState(() => _selectedChannel = channel);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildChannelDetailsSheet(channel),
    );
  }

  Future<void> _closeChannel(BrainrotChannel channel, bool force) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: Row(
          children: [
            Icon(
              force ? Icons.warning : Icons.info,
              color: force ? AppTheme.error : AppTheme.cyan,
            ),
            const SizedBox(width: 8),
            MemeText(force ? 'Force Close Channel' : 'Close Channel', fontSize: 18),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MemeText(
              force 
                ? 'Force closing will close the channel immediately but may result in higher fees.'
                : 'This will cooperatively close the channel with your peer.',
              fontSize: 14,
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
                  MemeText('Channel: ${channel.channelId.substring(0, 16)}...', fontSize: 12),
                  MemeText('Local Balance: ${channel.localBalanceSats} sats', fontSize: 12),
                  MemeText('Status: ${channel.getMemeStatus()}', fontSize: 12, color: AppTheme.hotPink),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ChaosButton(
            text: 'Cancel',
            onPressed: () => Navigator.of(context).pop(false),
            isPrimary: false,
            height: 40,
          ),
          const SizedBox(width: 8),
          ChaosButton(
            text: force ? 'Force Close' : 'Close',
            onPressed: () => Navigator.of(context).pop(true),
            height: 40,
            icon: force ? Icons.warning : Icons.close,
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final lightningProvider = context.read<LightningProvider>();
        await lightningProvider.closeChannel(
          channelId: channel.channelId,
          nodeId: channel.nodeId,
          force: force,
        );
        
        if (mounted) {
          Navigator.of(context).pop(); // Close bottom sheet
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(force ? 'Force closing channel...' : 'Closing channel...'),
              backgroundColor: AppTheme.darkGrey,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to close channel: $e'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lightningProvider = context.watch<LightningProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
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
            Icon(Icons.hub, color: AppTheme.limeGreen),
            const SizedBox(width: 8),
            MemeText('Lightning Channels', fontSize: 20),
          ],
        ),
        actions: [
          IconButton(
            icon: AnimatedBuilder(
              animation: _refreshController,
              builder: (context, child) => Transform.rotate(
                angle: _refreshController.value * 2 * 3.14159,
                child: Icon(Icons.refresh, color: AppTheme.hotPink),
              ),
            ),
            onPressed: _refreshChannels,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshChannels,
        color: AppTheme.hotPink,
        backgroundColor: AppTheme.darkGrey,
        child: lightningProvider.channels.isEmpty
            ? _buildEmptyState(chaosLevel)
            : _buildChannelList(lightningProvider, settingsProvider, chaosLevel),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/lightning/open-channel'),
        backgroundColor: AppTheme.hotPink,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: MemeText('Open Channel', fontSize: 14),
      ).animate().scale(delay: 500.ms),
    );
  }

  Widget _buildUninitialized() {
    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        title: MemeText('Lightning Channels', fontSize: 20),
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
              'Initialize Lightning Network to manage channels',
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

  Widget _buildEmptyState(int chaosLevel) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GlitchEffect(
              child: Icon(
                Icons.hub_outlined,
                size: 120,
                color: AppTheme.hotPink,
              ),
            ).animate().scale(delay: 200.ms),

            const SizedBox(height: 32),

            MemeText(
              'No Channels Yet! 📡',
              fontSize: 28,
              fontWeight: FontWeight.bold,
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 400.ms),

            const SizedBox(height: 16),

            MemeText(
              'Open your first Lightning channel to start sending and receiving instant payments!',
              fontSize: 16,
              textAlign: TextAlign.center,
              color: Colors.white70,
            ).animate().fadeIn(delay: 600.ms),

            const SizedBox(height: 32),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: ChaosTheme.getChaosDecoration(
                chaosLevel: chaosLevel,
                baseColor: AppTheme.darkGrey,
              ),
              child: Column(
                children: [
                  _buildEmptyStateFeature(Icons.speed, 'Instant Payments', 'Send sats in milliseconds'),
                  const SizedBox(height: 16),
                  _buildEmptyStateFeature(Icons.savings, 'Low Fees', 'Micro-fee transactions'),
                  const SizedBox(height: 16),
                  _buildEmptyStateFeature(Icons.network_check, 'Always Online', 'Receive payments 24/7'),
                ],
              ),
            ).animate().fadeIn(delay: 800.ms).slideY(),

            const SizedBox(height: 32),

            ChaosButton(
              text: 'Open Your First Channel',
              onPressed: () => context.go('/lightning/open-channel'),
              icon: Icons.add_circle,
            ).animate().scale(delay: 1000.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateFeature(IconData icon, String title, String description) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.limeGreen, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MemeText(title, fontSize: 14, fontWeight: FontWeight.bold),
              MemeText(description, fontSize: 12, color: Colors.white60),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChannelList(LightningProvider lightningProvider, SettingsProvider settingsProvider, int chaosLevel) {
    final channels = lightningProvider.channels;
    final hideBalance = settingsProvider.hideBalance;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: channels.length + 1, // +1 for summary card
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildChannelSummary(lightningProvider, hideBalance, chaosLevel);
        }
        
        final channel = channels[index - 1];
        return _buildChannelCard(channel, hideBalance, chaosLevel, index - 1);
      },
    );
  }

  Widget _buildChannelSummary(LightningProvider lightningProvider, bool hideBalance, int chaosLevel) {
    final totalChannels = lightningProvider.totalChannels;
    final activeChannels = lightningProvider.activeChannels;
    final totalCapacity = lightningProvider.totalCapacitySats;
    final spendable = lightningProvider.spendableSats;
    final receivable = lightningProvider.receivableSats;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
              Icon(Icons.dashboard, color: AppTheme.hotPink, size: 24),
              const SizedBox(width: 8),
              MemeText('Channel Overview', fontSize: 18, fontWeight: FontWeight.bold),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem('Total', '$totalChannels', Icons.hub),
              ),
              Expanded(
                child: _buildSummaryItem('Active', '$activeChannels', Icons.check_circle),
              ),
              Expanded(
                child: _buildSummaryItem('Capacity', hideBalance ? '****' : '$totalCapacity sats', Icons.account_balance_wallet),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.hotPink.withAlpha((0.1 * 255).round()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      MemeText('Can Send', fontSize: 12, color: Colors.white60),
                      const SizedBox(height: 4),
                      MemeText(
                        hideBalance ? '****' : '$spendable sats',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.hotPink,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.limeGreen.withAlpha((0.1 * 255).round()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      MemeText('Can Receive', fontSize: 12, color: Colors.white60),
                      const SizedBox(height: 4),
                      MemeText(
                        hideBalance ? '****' : '$receivable sats',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.limeGreen,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY();
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.cyan, size: 20),
        const SizedBox(height: 4),
        MemeText(value, fontSize: 14, fontWeight: FontWeight.bold),
        MemeText(label, fontSize: 10, color: Colors.white60),
      ],
    );
  }

  Widget _buildChannelCard(BrainrotChannel channel, bool hideBalance, int chaosLevel, int index) {
    return GestureDetector(
      onTap: () => _showChannelDetails(channel),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: ChaosTheme.getChaosDecoration(
          chaosLevel: chaosLevel,
          baseColor: AppTheme.lightGrey,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getChannelStateColor(channel.state).withAlpha((0.2 * 255).round()),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    _getChannelStateIcon(channel.state),
                    color: _getChannelStateColor(channel.state),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MemeText(
                        channel.alias ?? 'Unknown Node',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      MemeText(
                        '${channel.nodeId.substring(0, 16)}...',
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ],
                  ),
                ),
                Row(
                  children: channel.getEmojis().map((emoji) => 
                    Text(emoji, style: const TextStyle(fontSize: 16))
                  ).toList(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Balances
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MemeText('Local Balance', fontSize: 12, color: Colors.white60),
                      const SizedBox(height: 4),
                      MemeText(
                        hideBalance ? '****' : '${channel.localBalanceSats} sats',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.hotPink,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      MemeText('Remote Balance', fontSize: 12, color: Colors.white60),
                      const SizedBox(height: 4),
                      MemeText(
                        hideBalance ? '****' : '${channel.remoteBalanceSats} sats',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.limeGreen,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Capacity bar
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: AppTheme.darkGrey,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Stack(
                children: [
                  if (channel.capacitySats > 0)
                    FractionallySizedBox(
                      widthFactor: channel.localBalanceSats / channel.capacitySats,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.hotPink,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.darkGrey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: MemeText(
                channel.getMemeStatus(),
                fontSize: 12,
                color: AppTheme.cyan,
              ),
            ),
          ],
        ),
      ).animate(delay: Duration(milliseconds: index * 100))
        .fadeIn()
        .slideX(),
    );
  }

  Widget _buildChannelDetailsSheet(BrainrotChannel channel) {
    final themeProvider = context.watch<ThemeProvider>();
    final chaosLevel = themeProvider.chaosLevel;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: AppTheme.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getChannelStateColor(channel.state).withAlpha((0.2 * 255).round()),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Icon(
                    _getChannelStateIcon(channel.state),
                    color: _getChannelStateColor(channel.state),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MemeText(
                        'Channel Details',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      MemeText(
                        channel.alias ?? 'Unknown Node',
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: ChaosTheme.getChaosDecoration(
                      chaosLevel: chaosLevel,
                      baseColor: AppTheme.darkGrey,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: channel.getEmojis().map((emoji) => 
                            Text(emoji, style: const TextStyle(fontSize: 24))
                          ).toList(),
                        ),
                        const SizedBox(height: 8),
                        MemeText(
                          channel.getMemeStatus(),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.hotPink,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Channel info
                  _buildDetailItem('Channel ID', channel.channelId, copyable: true),
                  _buildDetailItem('Node ID', channel.nodeId, copyable: true),
                  _buildDetailItem('Local Balance', '${channel.localBalanceSats} sats'),
                  _buildDetailItem('Remote Balance', '${channel.remoteBalanceSats} sats'),
                  _buildDetailItem('Total Capacity', '${channel.capacitySats} sats'),
                  _buildDetailItem('Health', '${channel.healthPercentage.toStringAsFixed(1)}%'),
                  _buildDetailItem('Status', '${channel.state.name.toUpperCase()} ${channel.isActive ? "(Active)" : "(Inactive)"}'),
                  _buildDetailItem('Usable', channel.isUsable ? 'Yes' : 'No'),

                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ChaosButton(
                          text: 'Close Channel',
                          onPressed: () => _closeChannel(channel, false),
                          isPrimary: false,
                          height: 50,
                          icon: Icons.close,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChaosButton(
                          text: 'Force Close',
                          onPressed: () => _closeChannel(channel, true),
                          height: 50,
                          icon: Icons.warning,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: MemeText(
              label,
              fontSize: 14,
              color: Colors.white60,
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: copyable ? () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              } : null,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.lightGrey,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: MemeText(
                        value,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (copyable)
                      Icon(Icons.copy, size: 16, color: Colors.white60),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getChannelStateColor(ChannelState state) {
    switch (state) {
      case ChannelState.active:
        return AppTheme.limeGreen;
      case ChannelState.pending:
        return AppTheme.error;
      case ChannelState.inactive:
        return Colors.grey;
      case ChannelState.closing:
        return AppTheme.error;
      case ChannelState.closed:
        return Colors.red;
    }
  }

  IconData _getChannelStateIcon(ChannelState state) {
    switch (state) {
      case ChannelState.active:
        return Icons.check_circle;
      case ChannelState.pending:
        return Icons.pending;
      case ChannelState.inactive:
        return Icons.pause_circle;
      case ChannelState.closing:
        return Icons.close;
      case ChannelState.closed:
        return Icons.cancel;
    }
  }
}

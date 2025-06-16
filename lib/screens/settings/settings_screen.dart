import 'package:brainrot_bitcoin_wallet_v1/theme/theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/wallet_models.dart';
import '../../theme/app_theme.dart';
import '../../theme/chaos_theme.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/lightning_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/animated/chaos_button.dart';
import '../../widgets/animated/meme_text.dart';
import '../../widgets/effects/glitch_effect.dart';
import '../../widgets/meme/chaos_slider.dart';
import '../../services/service_locator.dart';
import 'dart:math' as math;

/// Settings screen with maximum chaos
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _showDangerZone = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleDangerZone() {
    setState(() => _showDangerZone = !_showDangerZone);
    if (_showDangerZone) {
      _animationController.forward();
      services.hapticService.warning();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final chaosLevel = themeProvider.chaosLevel;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) { // onPopInvokedWithResult is deprecated, using onPopInvoked
        if (!didPop) {
          context.go('/home');
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.darkGrey,
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => context.go('/home'),
            icon: const Icon(Icons.arrow_back),
            color: AppTheme.limeGreen,
          ),
          title: GlitchEffect(
            isActive: chaosLevel >= 9,
            child: const MemeText(
              'Settings',
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            // Easter egg button
            if (chaosLevel >= 7)
              IconButton(
                onPressed: _showEasterEgg,
                icon: Text(
                  '🥚',
                  style: TextStyle(fontSize: 20),
                ),
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Chaos level slider at the top
              _buildSection(
                title: 'CHAOS CONTROL 🎮',
                child: const ChaosSlider(),
              ),

              // Wallet settings
              _buildSection(
                title: 'WALLET 💰',
                child: _buildWalletSettings(),
              ),

              // Security settings
              _buildSection(
                title: 'SECURITY 🔐',
                child: _buildSecuritySettings(),
              ),

              // Display settings
              _buildSection(
                title: 'DISPLAY 🎨',
                child: _buildDisplaySettings(),
              ),

              // Network settings
              _buildSection(
                title: 'NETWORK 🌐',
                child: _buildNetworkSettings(),
              ),

              // Lightning settings
              _buildSection(
                title: 'LIGHTNING ⚡',
                child: _buildLightningSettings(),
              ),

              // Backup section
              _buildSection(
                title: 'BACKUP 💾',
                child: _buildBackupSettings(),
              ),

              // About section
              _buildSection(
                title: 'ABOUT 🧠',
                child: _buildAboutSection(),
              ),

              // Danger zone
              _buildDangerZone(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Widget child,
  }) {
    final themeProvider = context.watch<ThemeProvider>();
    final chaosLevel = themeProvider.chaosLevel;

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MemeText(
            title,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.limeGreen,
            glitch: chaosLevel >= 8,
          ),
          const SizedBox(height: 12),
          Container(
            decoration: ChaosTheme.getChaosDecoration(
              chaosLevel: chaosLevel,
              baseColor: AppTheme.lightGrey,
            ),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildWalletSettings() {
    final walletProvider = context.watch<WalletProvider>();
    final settingsProvider = context.watch<SettingsProvider>();

    return Column(
      children: [
        _buildSettingTile(
          icon: Icons.account_balance_wallet,
          title: 'Wallet Name',
          subtitle: walletProvider.walletConfig?.name ?? 'Unknown',
          onTap: () => _showEditWalletName(),
        ),

        _buildDivider(),

        _buildSettingTile(
          icon: Icons.fingerprint,
          title: 'Wallet Type',
          subtitle: _getWalletTypeDisplay(walletProvider.walletConfig?.walletType),
          onTap: null, // Can't change after creation
        ),

        _buildDivider(),

        _buildSettingTile(
          icon: Icons.key,
          title: 'View Seed Phrase',
          subtitle: 'Show your recovery words',
          onTap: () => context.go('/settings/seed'),
          trailing: const Icon(
            Icons.visibility,
            color: AppTheme.warning,
          ),
        ),
      ],
    );
  }

  Widget _buildSecuritySettings() {
    final settingsProvider = context.watch<SettingsProvider>();

    return Column(
      children: [
        _buildSwitchTile(
          icon: Icons.fingerprint,
          title: 'Biometric Authentication',
          subtitle: 'Use fingerprint/face to unlock',
          value: settingsProvider.biometricsEnabled,
          onChanged: (value) => _toggleBiometrics(value),
        ),

        _buildDivider(),

        _buildSettingTile(
          icon: Icons.pin,
          title: 'Change PIN',
          subtitle: 'Update your wallet PIN',
          onTap: () => context.go('/settings/pin'),
        ),

        _buildDivider(),

        _buildSwitchTile(
          icon: Icons.timer,
          title: 'Auto-lock',
          subtitle: 'Lock wallet after 5 minutes',
          value: true, // TODO: Implement auto-lock
          onChanged: (value) {},
        ),
      ],
    );
  }

  Widget _buildDisplaySettings() {
    final settingsProvider = context.watch<SettingsProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    return Column(
      children: [
        _buildSettingTile(
          icon: Icons.attach_money,
          title: 'Fiat Currency',
          subtitle: settingsProvider.fiatCurrency,
          onTap: () => _showCurrencyPicker(),
          trailing: Text(
            settingsProvider.fiatCurrency,
            style: TextStyle(
              color: AppTheme.limeGreen,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        _buildDivider(),

        _buildSwitchTile(
          icon: Icons.visibility_off,
          title: 'Hide Balance',
          subtitle: 'Hide your balance on main screen',
          value: settingsProvider.hideBalance,
          onChanged: (value) => settingsProvider.toggleBalanceVisibility(),
        ),

        _buildDivider(),

        _buildSwitchTile(
          icon: Icons.volume_up,
          title: 'Sound Effects',
          subtitle: 'Meme sounds on actions',
          value: themeProvider.soundEnabled,
          onChanged: (value) => themeProvider.toggleSound(),
        ),

        _buildDivider(),

        _buildSwitchTile(
          icon: Icons.vibration,
          title: 'Haptic Feedback',
          subtitle: 'Vibration on interactions',
          value: themeProvider.hapticsEnabled,
          onChanged: (value) => themeProvider.toggleHaptics(),
        ),

        _buildDivider(),

        _buildSwitchTile(
          icon: Icons.auto_awesome,
          title: 'Particle Effects',
          subtitle: 'Visual chaos particles',
          value: themeProvider.particlesEnabled,
          onChanged: (value) => themeProvider.toggleParticles(),
        ),
      ],
    );
  }

  Widget _buildNetworkSettings() {
    final settingsProvider = context.watch<SettingsProvider>();

    return Column(
      children: [
        _buildSwitchTile(
          icon: Icons.developer_mode,
          title: 'Testnet Mode',
          subtitle: settingsProvider.isTestnet
              ? 'Using Bitcoin testnet (fake money)'
              : 'Using Bitcoin mainnet (real money)',
          value: settingsProvider.isTestnet,
          onChanged: (value) => _confirmNetworkSwitch(value),
          activeColor: AppTheme.warning,
        ),

        _buildDivider(),

        _buildSettingTile(
          icon: Icons.electrical_services,
          title: 'Electrum Server',
          subtitle: 'Configure custom server',
          onTap: () => context.go('/settings/electrum'),
        ),

        _buildDivider(),

        _buildSettingTile(
          icon: Icons.api,
          title: 'API Settings',
          subtitle: 'Price feeds and services',
          onTap: () => context.go('/settings/api'),
        ),
      ],
    );
  }

  Widget _buildLightningSettings() {
    final lightningProvider = context.watch<LightningProvider>();

    return Column(
      children: [
        if (!lightningProvider.isInitialized) ...[
          _buildSettingTile(
            icon: Icons.flash_on,
            title: 'Enable Lightning',
            subtitle: 'Set up Lightning Network',
            onTap: () => context.go('/lightning/setup'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.limeGreen.withAlpha((0.2 * 255).round()),
                borderRadius: BorderRadius.circular(12),
              ),
              child: MemeText(
                'NEW',
                fontSize: 12,
                color: AppTheme.limeGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ] else ...[
          _buildSettingTile(
            icon: Icons.hub,
            title: 'Lightning Channels',
            subtitle: '${lightningProvider.activeChannels} active channels',
            onTap: () => context.go('/lightning/channels'),
          ),

          _buildDivider(),

          _buildSettingTile(
            icon: Icons.router,
            title: 'Lightning Node',
            subtitle: 'Node configuration',
            onTap: () => context.go('/lightning/node'),
          ),

          _buildDivider(),

          _buildSettingTile(
            icon: Icons.backup,
            title: 'Lightning Backup',
            subtitle: 'Backup channel states',
            onTap: () => _showLightningBackup(),
          ),
        ],
      ],
    );
  }

  Widget _buildBackupSettings() {
    return Column(
      children: [
        _buildSettingTile(
          icon: Icons.save,
          title: 'Backup Wallet',
          subtitle: 'Export encrypted backup',
          onTap: () => context.go('/settings/backup/export'),
        ),

        _buildDivider(),

        _buildSettingTile(
          icon: Icons.restore,
          title: 'Restore from Backup',
          subtitle: 'Import wallet backup',
          onTap: () => context.go('/settings/backup/import'),
        ),

        _buildDivider(),

        _buildSettingTile(
          icon: Icons.cloud_upload,
          title: 'Cloud Backup',
          subtitle: 'Encrypted cloud sync',
          onTap: () => _showCloudBackup(),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.deepPurple.withAlpha((0.2 * 255).round()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: MemeText(
              'SOON™',
              fontSize: 12,
              color: AppTheme.deepPurple,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return Column(
      children: [
        _buildSettingTile(
          icon: Icons.info,
          title: 'Version',
          subtitle: 'Maximum Chaos Edition',
          onTap: () => _showVersionInfo(),
        ),

        _buildDivider(),

        _buildSettingTile(
          icon: Icons.book,
          title: 'User Guide',
          subtitle: 'Learn how to use Brainrot',
          onTap: () => context.go('/guide'),
        ),

        _buildDivider(),

        _buildSettingTile(
          icon: Icons.code,
          title: 'Open Source',
          subtitle: 'View source code',
          onTap: () => _openGitHub(),
        ),

        _buildDivider(),

        _buildSettingTile(
          icon: Icons.favorite,
          title: 'Credits',
          subtitle: 'Made with chaos and love',
          onTap: () => _showCredits(),
        ),
      ],
    );
  }

  Widget _buildDangerZone() {
    final themeProvider = context.watch<ThemeProvider>();
    final chaosLevel = themeProvider.chaosLevel;

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _toggleDangerZone,
            child: Row(
              children: [
                AnimatedRotation(
                  turns: _showDangerZone ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    Icons.expand_more,
                    color: AppTheme.error,
                  ),
                ),
                const SizedBox(width: 8),
                MemeText(
                  'DANGER ZONE ☠️',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.error,
                  glitch: _showDangerZone,
                ),
              ],
            ),
          ),

          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: _showDangerZone
                ? Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withAlpha((0.1 * 255).round()),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.error,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Warning message
                      Row(
                        children: [
                          Icon(
                            Icons.warning,
                            color: AppTheme.error,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: MemeText(
                              'These actions cannot be undone! Proceed with extreme caution!',
                              fontSize: 14,
                              color: AppTheme.error,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Delete wallet button
                      ChaosButton(
                        text: 'DELETE WALLET',
                        onPressed: () => _confirmDeleteWallet(),
                        isPrimary: false,
                        icon: Icons.delete_forever,
                      )
                          .animate(
                        onPlay: (controller) {
                          if (chaosLevel >= 7) {
                            controller.repeat(reverse: true);
                          }
                        },
                      )
                          .shake(hz: 2)
                          .tint(color: AppTheme.error),

                      const SizedBox(height: 12),

                      // Reset everything button
                      ChaosButton(
                        text: 'FACTORY RESET',
                        onPressed: () => _confirmFactoryReset(),
                        isPrimary: false,
                        icon: Icons.restart_alt,
                      )
                          .animate(
                        onPlay: (controller) {
                          if (chaosLevel >= 8) {
                            controller.repeat(reverse: true);
                          }
                        },
                      )
                          .shake(hz: 3)
                          .tint(color: AppTheme.error),
                    ],
                  ),
                ),
              ],
            )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.limeGreen),
      title: MemeText(title, fontSize: 16),
      subtitle: MemeText(
        subtitle,
        fontSize: 14,
        color: Colors.white54,
      ),
      trailing: trailing ?? (onTap != null
          ? Icon(Icons.chevron_right, color: Colors.white54)
          : null),
      onTap: onTap == null ? null : () {
        services.hapticService.light();
        services.soundService.tap();
        onTap();
      },
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color? activeColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.limeGreen),
      title: MemeText(title, fontSize: 16),
      subtitle: MemeText(
        subtitle,
        fontSize: 14,
        color: Colors.white54,
      ),
      trailing: Switch(
        value: value,
        onChanged: (newValue) {
          services.hapticService.light();
          services.soundService.tap();
          onChanged(newValue);
        },
        activeColor: activeColor ?? AppTheme.limeGreen,
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      color: Colors.white12,
    );
  }

  String _getWalletTypeDisplay(WalletType? type) {
    if (type == null) return 'Unknown';

    switch (type) {
      case WalletType.standard:
        return 'Native SegWit (bc1...)';
      case WalletType.taproot:
        return 'Taproot (bc1p...)';
      case WalletType.legacy:
        return 'Legacy (1...)';
      case WalletType.nested:
        return 'Nested SegWit (3...)';
    }
  }

  // Dialog methods
  void _showEditWalletName() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: MemeText('Edit Wallet Name', fontSize: 20),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: Theme.of(context).chaosInputDecoration(
            labelText: 'New Name',
            chaosLevel: context.read<ThemeProvider>().chaosLevel,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: MemeText('Cancel', color: Colors.white54),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement wallet name update
              Navigator.pop(context);
            },
            child: MemeText('Save', color: AppTheme.limeGreen),
          ),
        ],
      ),
    );
  }

  void _showCurrencyPicker() {
    final currencies = ['USD', 'EUR', 'GBP', 'JPY', 'CAD', 'AUD'];
    final settingsProvider = context.read<SettingsProvider>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: MemeText('Select Currency', fontSize: 20),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: currencies.length,
            itemBuilder: (context, index) {
              final currency = currencies[index];
              final isSelected = currency == settingsProvider.fiatCurrency;

              return ListTile(
                title: MemeText(currency),
                trailing: isSelected
                    ? Icon(Icons.check, color: AppTheme.limeGreen)
                    : null,
                onTap: () {
                  settingsProvider.setFiatCurrency(currency);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _toggleBiometrics(bool enable) async {
    if (enable) {
      final biometricResult = await services.biometricService.isBiometricAvailable();

      if (biometricResult.isSuccess && biometricResult.valueOrNull == true) {
        final authResult = await services.biometricService.authenticateWithMemes(
          themeProvider: context.read<ThemeProvider>(),
        );

        if (authResult.isSuccess && authResult.valueOrNull == true) {
          context.read<SettingsProvider>().toggleBiometrics();
        } else {
          _showError('Biometric authentication failed');
        }
      } else {
        _showError('Biometrics not available on this device');
      }
    } else {
      context.read<SettingsProvider>().toggleBiometrics();
    }
  }

  void _confirmNetworkSwitch(bool toTestnet) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: MemeText(
          toTestnet ? 'Switch to Testnet?' : 'Switch to Mainnet?',
          fontSize: 20,
        ),
        content: MemeText(
          toTestnet
              ? 'Testnet uses fake Bitcoin for testing. Your mainnet funds will be safe but hidden.'
              : 'Mainnet uses real Bitcoin with real value. Make sure you know what you\'re doing!',
          fontSize: 14,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: MemeText('Cancel', color: Colors.white54),
          ),
          TextButton(
            onPressed: () {
              context.read<SettingsProvider>().toggleNetwork();
              Navigator.pop(context);
              // TODO: Reload wallet with new network
            },
            child: MemeText(
              'Switch',
              color: toTestnet ? AppTheme.warning : AppTheme.limeGreen,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteWallet() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: GlitchEffect(
          isActive: true,
          child: MemeText(
            'DELETE WALLET?',
            fontSize: 20,
            color: AppTheme.error,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning,
              color: AppTheme.error,
              size: 64,
            ),
            const SizedBox(height: 16),
            MemeText(
              'This will permanently delete your wallet! Make sure you have backed up your seed phrase!',
              fontSize: 14,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            MemeText(
              'Type "DELETE" to confirm',
              fontSize: 12,
              color: Colors.white54,
            ),
            const SizedBox(height: 8),
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.lightGrey,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                if (value == 'DELETE') {
                  Navigator.pop(context);
                  _deleteWallet();
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: MemeText('Cancel', color: Colors.white54),
          ),
        ],
      ),
    );
  }

  void _confirmFactoryReset() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: MemeText(
          'FACTORY RESET?',
          fontSize: 20,
          color: AppTheme.error,
        ),
        content: MemeText(
          'This will delete EVERYTHING and reset the app to its initial state. All wallets, settings, and data will be lost!',
          fontSize: 14,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: MemeText('Cancel', color: Colors.white54),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _factoryReset();
            },
            child: MemeText('RESET', color: AppTheme.error),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteWallet() async {
    final walletProvider = context.read<WalletProvider>();
    final lightningProvider = context.read<LightningProvider>();

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          color: AppTheme.darkGrey,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.error),
                ),
                const SizedBox(height: 16),
                MemeText('Deleting wallet...', fontSize: 16),
              ],
            ),
          ),
        ),
      ),
    );

    // Delete wallet
    await walletProvider.deleteWallet();

    // Delete lightning if exists
    if (lightningProvider.isInitialized) {
      await lightningProvider.deleteLightningNode();
    }

    // Navigate to onboarding
    if (mounted) {
      Navigator.pop(context); // Close loading dialog
      context.go('/onboarding');
    }
  }

  Future<void> _factoryReset() async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          color: AppTheme.darkGrey,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.error),
                ),
                const SizedBox(height: 16),
                MemeText('Factory resetting...', fontSize: 16),
              ],
            ),
          ),
        ),
      ),
    );

    // Clear everything
    await services.storageService.nukeAllData();

    // Reset app state
    final appState = context.read<AppStateProvider>();
    await appState.resetAppState();

    // Navigate to splash
    if (mounted) {
      Navigator.pop(context); // Close loading dialog
      context.go('/');
    }
  }

  void _showLightningBackup() {
    // TODO: Implement Lightning backup
    _showComingSoon();
  }

  void _showCloudBackup() {
    _showComingSoon();
  }

  void _showVersionInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: MemeText('Brainrot Wallet', fontSize: 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🧠', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            MemeText(
              'Version 4.2.0',
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            MemeText(
              'Maximum Chaos Edition',
              fontSize: 14,
              color: AppTheme.limeGreen,
            ),
            const SizedBox(height: 16),
            MemeText(
              'Built with Flutter, BDK & LDK',
              fontSize: 12,
              color: Colors.white54,
            ),
            const SizedBox(height: 8),
            MemeText(
              'Not your keys, not your cheese 🧀',
              fontSize: 12,
              color: AppTheme.hotPink,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: MemeText('Based', color: AppTheme.limeGreen),
          ),
        ],
      ),
    );
  }

  void _openGitHub() {
    // TODO: Open GitHub URL
    _showComingSoon();
  }

  void _showCredits() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: MemeText('Credits', fontSize: 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MemeText(
              'Made with chaos by:',
              fontSize: 14,
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            MemeText(
              'Donald Nwokoro',
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            const SizedBox(height: 16),
            MemeText(
              'Special thanks to:',
              fontSize: 14,
              color: Colors.white54,
            ),
            const SizedBox(height: 8),
            MemeText(
              'Bitcoin Core Devs 🙏',
              fontSize: 14,
            ),
            MemeText(
              'BDK & LDK Teams ⚡',
              fontSize: 14,
            ),
            MemeText(
              'All the HODLers 💎🙌',
              fontSize: 14,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: MemeText('WAGMI', color: AppTheme.limeGreen),
          ),
        ],
      ),
    );
  }

  void _showEasterEgg() {
    final messages = [
      'You found the easter egg! 🥚',
      'There is no second best 🥇',
      'Few understand this 🧠',
      'Have fun staying poor 💸',
      'Bitcoin fixes this 🔧',
      'Number go up technology 📈',
    ];

    final message = messages[math.Random().nextInt(messages.length)];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '🎉',
              style: TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),
            MemeText(
              message,
              fontSize: 16,
              textAlign: TextAlign.center,
              rainbow: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: MemeText('Nice', color: AppTheme.limeGreen),
          ),
        ],
      ),
    );
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: MemeText('Coming Soon™ 🚀', color: Colors.white),
        backgroundColor: AppTheme.deepPurple,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: MemeText(message, color: Colors.white),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

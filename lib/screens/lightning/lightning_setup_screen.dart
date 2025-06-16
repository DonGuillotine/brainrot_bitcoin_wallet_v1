import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:ldk_node/ldk_node.dart' as ldk;
import '../../theme/app_theme.dart';
import '../../theme/chaos_theme.dart';
import '../../providers/lightning_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/animated/meme_text.dart';
import '../../widgets/animated/chaos_button.dart';
import '../../widgets/effects/glitch_effect.dart';
import '../../services/service_locator.dart';

class LightningSetupScreen extends StatefulWidget {
  const LightningSetupScreen({super.key});

  @override
  State<LightningSetupScreen> createState() => _LightningSetupScreenState();
}

class _LightningSetupScreenState extends State<LightningSetupScreen>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isInitializing = false;
  String? _initializationError;
  ldk.Network _selectedNetwork = ldk.Network.testnet;
  
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
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeLightning() async {
    if (_isInitializing) return;
    
    setState(() {
      _isInitializing = true;
      _initializationError = null;
    });

    try {
      final walletProvider = context.read<WalletProvider>();
      final lightningProvider = context.read<LightningProvider>();
      
      // First try to get wallet mnemonic without password (might fail if encrypted)
      var mnemonicResult = await services.storageService.getSecureValue(
        key: 'wallet_mnemonic',
        password: '', // Try empty password first
      );
      
      String mnemonic;
      
      if (mnemonicResult.isError) {
        // If failed, prompt for password
        final password = await _showPasswordDialog();
        if (password == null) {
          throw Exception('Password required to access wallet for Lightning setup');
        }
        
        mnemonicResult = await services.storageService.getSecureValue(
          key: 'wallet_mnemonic',
          password: password,
        );
        
        if (mnemonicResult.isError || mnemonicResult.valueOrNull == null) {
          throw Exception('Unable to access wallet mnemonic with provided password');
        }
        
        mnemonic = mnemonicResult.valueOrNull!;
      } else {
        mnemonic = mnemonicResult.valueOrNull!;
      }

      // TEMPORARY: Lightning disabled due to flutter_rust_bridge version compatibility
      // TODO: Re-enable when ldk_node updates to flutter_rust_bridge 2.9.0
      throw Exception('Lightning Network temporarily unavailable due to package compatibility issues. The ldk_node package uses flutter_rust_bridge 2.0.0 while bdk_flutter requires 2.9.0. Lightning will be re-enabled once the packages are compatible.');

      // Success - play sounds and navigate
      await services.soundService.success();
      await services.hapticService.success();
      
      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      setState(() {
        _initializationError = e.toString();
      });
      
      await services.soundService.error();
      await services.hapticService.error();
    } finally {
      setState(() {
        _isInitializing = false;
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
                'Enter your wallet password to initialize Lightning:',
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

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        title: Row(
          children: [
            Icon(Icons.bolt, color: AppTheme.limeGreen),
            const SizedBox(width: 8),
            MemeText('Lightning Activated!', fontSize: 18),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MemeText(
              'Your Lightning node is now ready for instant payments! ⚡',
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
              child: MemeText(
                'Pro tip: Open some channels to start sending and receiving Lightning payments!',
                fontSize: 12,
                color: AppTheme.hotPink,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          ChaosButton(
            text: 'Open Channels',
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
              context.go('/');
            },
            isPrimary: false,
            height: 40,
          ),
        ],
      ),
    );
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final chaosLevel = themeProvider.chaosLevel;

    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        title: MemeText('Lightning Setup', fontSize: 24),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Progress indicator
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: List.generate(3, (index) {
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
                    decoration: BoxDecoration(
                      color: index <= _currentPage ? AppTheme.hotPink : AppTheme.lightGrey,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ).animate(delay: Duration(milliseconds: index * 100))
                    .fadeIn()
                    .slideX(),
                );
              }),
            ),
          ),

          // Page content
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) {
                setState(() => _currentPage = page);
                services.hapticService.light();
              },
              children: [
                _buildWelcomePage(chaosLevel),
                _buildConfigurationPage(chaosLevel),
                _buildInitializationPage(chaosLevel),
              ],
            ),
          ),

          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                if (_currentPage > 0)
                  Expanded(
                    child: ChaosButton(
                      text: 'Back',
                      onPressed: _previousPage,
                      isPrimary: false,
                      height: 50,
                    ),
                  ),
                
                if (_currentPage > 0) const SizedBox(width: 16),
                
                Expanded(
                  child: _currentPage == 2
                      ? ChaosButton(
                          text: _isInitializing ? 'Initializing...' : 'Initialize Lightning',
                          onPressed: _isInitializing ? null : _initializeLightning,
                          height: 50,
                          icon: _isInitializing ? null : Icons.bolt,
                        )
                      : ChaosButton(
                          text: _currentPage == 0 ? 'Get Started' : 'Continue',
                          onPressed: _nextPage,
                          height: 50,
                          icon: Icons.arrow_forward,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomePage(int chaosLevel) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Lightning bolt animation
          GlitchEffect(
            child: Icon(
              Icons.bolt,
              size: 120,
              color: AppTheme.limeGreen,
            ),
          ).animate().scale(delay: 200.ms, duration: 600.ms),

          const SizedBox(height: 32),

          MemeText(
            'Welcome to Lightning! ⚡',
            fontSize: 32,
            fontWeight: FontWeight.bold,
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 400.ms).slideY(),

          const SizedBox(height: 24),

          MemeText(
            'Lightning Network enables instant, low-cost Bitcoin payments. Perfect for small transactions and micropayments!',
            fontSize: 16,
            textAlign: TextAlign.center,
            color: Colors.white70,
          ).animate().fadeIn(delay: 600.ms),

          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: ChaosTheme.getChaosDecoration(
              chaosLevel: chaosLevel,
              baseColor: AppTheme.darkGrey,
            ),
            child: Column(
              children: [
                _buildFeatureItem(Icons.flash_on, 'Instant Payments', 'Send and receive in seconds'),
                const SizedBox(height: 12),
                _buildFeatureItem(Icons.attach_money, 'Low Fees', 'Fraction of on-chain costs'),
                const SizedBox(height: 12),
                _buildFeatureItem(Icons.security, 'Secure', 'Non-custodial, your keys'),
              ],
            ),
          ).animate().fadeIn(delay: 800.ms).slideY(),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.hotPink, size: 24),
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

  Widget _buildConfigurationPage(int chaosLevel) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.settings,
            size: 80,
            color: AppTheme.hotPink,
          ).animate().rotate(duration: 2.seconds).then().shimmer(),

          const SizedBox(height: 32),

          MemeText(
            'Lightning Configuration',
            fontSize: 28,
            fontWeight: FontWeight.bold,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          MemeText(
            'Choose your Lightning Network settings. Don\'t worry, you can change these later!',
            fontSize: 16,
            textAlign: TextAlign.center,
            color: Colors.white70,
          ),

          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: ChaosTheme.getChaosDecoration(
              chaosLevel: chaosLevel,
              baseColor: AppTheme.darkGrey,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MemeText(
                  'Network Selection',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                const SizedBox(height: 16),

                // Network selection
                Column(
                  children: [
                    _buildNetworkOption(
                      ldk.Network.testnet,
                      'Testnet',
                      'Safe for testing (Recommended)',
                      Icons.science,
                      AppTheme.limeGreen,
                    ),
                    const SizedBox(height: 12),
                    _buildNetworkOption(
                      ldk.Network.bitcoin,
                      'Mainnet',
                      'Real Bitcoin network',
                      Icons.warning,
                      AppTheme.error,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.lightGrey,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: AppTheme.cyan, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: MemeText(
                          'Your Lightning node will use the same seed as your Bitcoin wallet for security.',
                          fontSize: 12,
                          color: AppTheme.cyan,
                        ),
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

  Widget _buildNetworkOption(ldk.Network network, String title, String description, IconData icon, Color color) {
    final isSelected = _selectedNetwork == network;
    
    return GestureDetector(
      onTap: () {
        setState(() => _selectedNetwork = network);
        services.hapticService.light();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : AppTheme.lightGrey,
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MemeText(title, fontSize: 16, fontWeight: FontWeight.bold),
                  MemeText(description, fontSize: 12, color: Colors.white60),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInitializationPage(int chaosLevel) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isInitializing)
            Column(
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    strokeWidth: 6,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.hotPink),
                  ),
                ).animate().scale(),
                
                const SizedBox(height: 24),

                MemeText(
                'Initializing Lightning Node...',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                textAlign: TextAlign.center,
                ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                    .scale(
                duration: 1000.ms,
                begin: const Offset(1, 1),
                end: const Offset(1.1, 1.1),
                ),

                const SizedBox(height: 16),
                
                MemeText(
                  'This may take a few moments. We\'re setting up your Lightning node and connecting to the network.',
                  fontSize: 14,
                  textAlign: TextAlign.center,
                  color: Colors.white70,
                ),
              ],
            )
          else ...[
            Icon(
              _initializationError != null ? Icons.error : Icons.rocket_launch,
              size: 100,
              color: _initializationError != null ? AppTheme.error : AppTheme.limeGreen,
            ).animate().scale().then().shake(),

            const SizedBox(height: 32),

            MemeText(
              _initializationError != null ? 'Initialization Failed' : 'Ready to Launch!',
              fontSize: 28,
              fontWeight: FontWeight.bold,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            if (_initializationError != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.1),
                  border: Border.all(color: AppTheme.error),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    MemeText(
                      'Error Details:',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.error,
                    ),
                    const SizedBox(height: 8),
                    MemeText(
                      _initializationError!,
                      fontSize: 12,
                      color: Colors.white70,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ChaosButton(
                text: 'Try Again',
                onPressed: _initializeLightning,
                height: 50,
                icon: Icons.refresh,
              ),
            ] else ...[
              MemeText(
                'Your Lightning node is ready to be initialized on ${_selectedNetwork.name.toUpperCase()}.',
                fontSize: 16,
                textAlign: TextAlign.center,
                color: Colors.white70,
              ),

              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: ChaosTheme.getChaosDecoration(
                  chaosLevel: chaosLevel,
                  baseColor: AppTheme.darkGrey,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check, color: AppTheme.limeGreen),
                        const SizedBox(width: 8),
                        Expanded(
                          child: MemeText('Wallet seed ready', fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.check, color: AppTheme.limeGreen),
                        const SizedBox(width: 8),
                        Expanded(
                          child: MemeText('Network: ${_selectedNetwork.name.toUpperCase()}', fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.check, color: AppTheme.limeGreen),
                        const SizedBox(width: 8),
                        Expanded(
                          child: MemeText('LDK Node configured', fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

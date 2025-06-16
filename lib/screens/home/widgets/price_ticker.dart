import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/settings_provider.dart';
import '../../../widgets/animated/meme_text.dart';
import '../../../services/service_locator.dart';
import '../../../services/network/price_service.dart';

/// Price ticker widget
class PriceTicker extends StatefulWidget {
  const PriceTicker({super.key});

  @override
  State<PriceTicker> createState() => _PriceTickerState();
}

class _PriceTickerState extends State<PriceTicker> {
  PriceData? _currentPrice;
  PriceData? _previousPrice;

  @override
  void initState() {
    super.initState();
    _subscribeToPrice();
  }

  void _subscribeToPrice() {
    services.priceService.priceStream.listen((priceData) {
      if (mounted) {
        setState(() {
          _previousPrice = _currentPrice;
          _currentPrice = priceData;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final currency = settingsProvider.fiatCurrency;

    if (_currentPrice == null) {
      return Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.limeGreen),
          ),
        ),
      );
    }

    final isUp = _currentPrice!.change24h > 0;
    final priceChanged = _previousPrice != null &&
        _previousPrice!.price != _currentPrice!.price;

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Bitcoin icon
          Icon(
            Icons.currency_bitcoin,
            color: AppTheme.limeGreen,
            size: 32,
          ),

          const SizedBox(width: 12),

          // Price
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    MemeText(
                      '$currency ${_currentPrice!.price.toStringAsFixed(2)}',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    )
                        .animate(target: priceChanged ? 1 : 0)
                        .shake(hz: 2)
                        .tint(color: isUp ? AppTheme.success : AppTheme.error),

                    const SizedBox(width: 8),

                    // Change indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isUp
                            ? AppTheme.success.withAlpha((0.2 * 255).round())
                            : AppTheme.error.withAlpha((0.2 * 255).round()),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isUp ? Icons.arrow_upward : Icons.arrow_downward,
                            color: isUp ? AppTheme.success : AppTheme.error,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          MemeText(
                            '${_currentPrice!.change24h.abs().toStringAsFixed(2)}%',
                            fontSize: 12,
                            color: isUp ? AppTheme.success : AppTheme.error,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                MemeText(
                  _getMemeMessage(),
                  fontSize: 12,
                  color: Colors.white54,
                ),
              ],
            ),
          ),

          // Refresh button
          IconButton(
            onPressed: () async {
              services.hapticService.light();
              await services.priceService.fetchPrice(currency);
            },
            icon: const Icon(Icons.refresh),
            color: Colors.white54,
          ),
        ],
      ),
    );
  }

  String _getMemeMessage() {
    if (_currentPrice == null) return '';

    final change = _currentPrice!.change24h;

    if (change > 10) return 'TO THE MOON! 🚀';
    if (change > 5) return 'Number go up! 📈';
    if (change > 0) return 'Pumping 💪';
    if (change > -5) return 'Just a flesh wound 🩹';
    if (change > -10) return 'Buy the dip! 🛒';
    return 'GUH! Maximum pain 💀';
  }
}

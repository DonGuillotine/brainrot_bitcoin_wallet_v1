import 'dart:async';
import '../base/base_service.dart';
import '../base/service_result.dart';
import 'network_service.dart';

/// Service for fetching Bitcoin price data
class PriceService extends BaseService {
  final NetworkService _networkService;

  // Cache
  final Map<String, PriceData> _priceCache = {};
  final Duration _cacheExpiry = const Duration(minutes: 1);
  Timer? _priceTimer;

  // Price update stream
  final _priceStreamController = StreamController<PriceData>.broadcast();
  Stream<PriceData> get priceStream => _priceStreamController.stream;

  PriceService(this._networkService) : super('PriceService');

  /// Start price updates
  void startPriceUpdates({Duration interval = const Duration(minutes: 1)}) {
    stopPriceUpdates();

    // Initial fetch
    fetchPrice('USD');

    // Set up periodic updates
    _priceTimer = Timer.periodic(interval, (_) {
      fetchPrice('USD');
    });

    logInfo('Started price updates with ${interval.inSeconds}s interval');
  }

  /// Stop price updates
  void stopPriceUpdates() {
    _priceTimer?.cancel();
    _priceTimer = null;
    logInfo('Stopped price updates');
  }

  /// Fetch Bitcoin price
  Future<ServiceResult<PriceData>> fetchPrice(String currency) async {
    // Check cache first
    final cached = _priceCache[currency];
    if (cached != null && !cached.isExpired(_cacheExpiry)) {
      logDebug('Using cached price for $currency');
      return Success(cached);
    }

    return executeOperation(
      operation: () async {
        // Using CoinGecko API as example
        final result = await _networkService.get<Map<String, dynamic>>(
          url: 'https://api.coingecko.com/api/v3/simple/price',
          queryParameters: {
            'ids': 'bitcoin',
            'vs_currencies': currency.toLowerCase(),
            'include_24hr_change': true,
            'include_24hr_vol': true,
          },
        );

        if (result.isError) {
          throw result.errorOrNull!;
        }

        final data = result.valueOrNull!;
        final btcData = data['bitcoin'] as Map<String, dynamic>;

        final priceData = PriceData(
          currency: currency,
          price: btcData[currency.toLowerCase()].toDouble(),
          change24h: btcData['${currency.toLowerCase()}_24h_change']?.toDouble() ?? 0.0,
          volume24h: btcData['${currency.toLowerCase()}_24h_vol']?.toDouble() ?? 0.0,
          timestamp: DateTime.now(),
        );

        // Update cache
        _priceCache[currency] = priceData;

        // Emit to stream
        _priceStreamController.add(priceData);

        return priceData;
      },
      operationName: 'fetch $currency price',
      errorCode: ErrorCodes.networkError,
    );
  }

  /// Convert BTC to fiat
  double convertBtcToFiat(double btcAmount, PriceData priceData) {
    return btcAmount * priceData.price;
  }

  /// Convert fiat to BTC
  double convertFiatToBtc(double fiatAmount, PriceData priceData) {
    if (priceData.price == 0) return 0;
    return fiatAmount / priceData.price;
  }

  /// Format price with meme style
  String formatPriceWithMemes(PriceData priceData) {
    final isUp = priceData.change24h > 0;
    final emoji = isUp ? '🚀' : '📉';
    final mood = isUp ? 'TO THE MOON' : 'GUH';

    return '${priceData.currency} ${priceData.price.toStringAsFixed(2)} '
        '$emoji ${priceData.change24h.abs().toStringAsFixed(2)}% '
        '$mood';
  }

  /// Dispose
  void dispose() {
    stopPriceUpdates();
    _priceStreamController.close();
  }
}

/// Price data model
class PriceData {
  final String currency;
  final double price;
  final double change24h;
  final double volume24h;
  final DateTime timestamp;

  PriceData({
    required this.currency,
    required this.price,
    required this.change24h,
    required this.volume24h,
    required this.timestamp,
  });

  bool isExpired(Duration expiry) {
    return DateTime.now().difference(timestamp) > expiry;
  }
}

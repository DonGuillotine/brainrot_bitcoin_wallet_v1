import 'dart:async';
import 'package:dio/dio.dart';
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
        // Try multiple APIs for better reliability
        PriceData? priceData;
        
        // Try CoinGecko first (primary)
        try {
          priceData = await _fetchFromCoinGecko(currency);
        } catch (e) {
          logWarning('CoinGecko API failed: $e');
          
          // Fallback to CoinCap API
          try {
            priceData = await _fetchFromCoinCap(currency);
          } catch (e2) {
            logWarning('CoinCap API failed: $e2');
            
            // If both fail, throw the original error
            throw e;
          }
        }

        if (priceData == null) {
          throw Exception('All price APIs failed');
        }

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

  /// Fetch from CoinGecko API
  Future<PriceData> _fetchFromCoinGecko(String currency) async {
    final result = await _networkService.get<Map<String, dynamic>>(
      url: 'https://api.coingecko.com/api/v3/simple/price',
      queryParameters: {
        'ids': 'bitcoin',
        'vs_currencies': currency.toLowerCase(),
        'include_24hr_change': true,
        'include_24hr_vol': true,
      },
      options: Options(
        sendTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );

    if (result.isError) {
      throw result.errorOrNull!;
    }

    final data = result.valueOrNull!;
    final btcData = data['bitcoin'] as Map<String, dynamic>;

    return PriceData(
      currency: currency,
      price: btcData[currency.toLowerCase()].toDouble(),
      change24h: btcData['${currency.toLowerCase()}_24h_change']?.toDouble() ?? 0.0,
      volume24h: btcData['${currency.toLowerCase()}_24h_vol']?.toDouble() ?? 0.0,
      timestamp: DateTime.now(),
    );
  }

  /// Fetch from CoinCap API (fallback)
  Future<PriceData> _fetchFromCoinCap(String currency) async {
    final result = await _networkService.get<Map<String, dynamic>>(
      url: 'https://api.coincap.io/v2/assets/bitcoin',
      options: Options(
        sendTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );

    if (result.isError) {
      throw result.errorOrNull!;
    }

    final data = result.valueOrNull!;
    final btcData = data['data'] as Map<String, dynamic>;

    final priceUsd = double.parse(btcData['priceUsd']);
    final changePercent24Hr = double.parse(btcData['changePercent24Hr'] ?? '0');

    // For now, assume USD and convert if needed
    // In a real app, you'd use a currency conversion API
    double price = priceUsd;
    if (currency.toUpperCase() != 'USD') {
      // Simple mock conversion rates - in production use real rates
      switch (currency.toUpperCase()) {
        case 'EUR':
          price = priceUsd * 0.85;
          break;
        case 'GBP':
          price = priceUsd * 0.75;
          break;
        case 'JPY':
          price = priceUsd * 110;
          break;
        case 'CAD':
          price = priceUsd * 1.25;
          break;
        case 'AUD':
          price = priceUsd * 1.35;
          break;
        default:
          price = priceUsd;
      }
    }

    return PriceData(
      currency: currency,
      price: price,
      change24h: changePercent24Hr,
      volume24h: double.parse(btcData['volumeUsd24Hr'] ?? '0'),
      timestamp: DateTime.now(),
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

  /// Get current price data from cache
  PriceData? getCurrentPrice(String currency) {
    final cached = _priceCache[currency];
    if (cached != null && !cached.isExpired(_cacheExpiry)) {
      return cached;
    }
    return null;
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

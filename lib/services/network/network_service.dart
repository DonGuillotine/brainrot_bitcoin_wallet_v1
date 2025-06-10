import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import '../base/base_service.dart';
import '../base/service_result.dart';

/// Service for handling network operations
class NetworkService extends BaseService {
  late final Dio _dio;
  final List<CancelToken> _activeTokens = [];

  NetworkService() : super('NetworkService') {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'User-Agent': 'BrainrotWallet/1.0 (Based AF)',
        },
      ),
    );

    // Add interceptors
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (log) => logDebug(log.toString()),
    ));

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          logDebug('🌐 Request: ${options.method} ${options.uri}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          logInfo('✅ Response: ${response.statusCode}');
          handler.next(response);
        },
        onError: (error, handler) {
          logError('❌ Network error', error: error);
          handler.next(error);
        },
      ),
    );
  }

  /// Check if device is online
  Future<ServiceResult<bool>> isOnline() async {
    return executeOperation(
      operation: () async {
        try {
          final result = await InternetAddress.lookup('example.com');
          return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
        } on SocketException {
          return false;
        }
      },
      operationName: 'check network status',
      errorCode: ErrorCodes.networkError,
    );
  }

  /// Make GET request
  Future<ServiceResult<T>> get<T>({
    required String url,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return executeWithRetry(
      operation: () async {
        final cancelToken = CancelToken();
        _activeTokens.add(cancelToken);

        try {
          final response = await _dio.get<T>(
            url,
            queryParameters: queryParameters,
            options: options,
            cancelToken: cancelToken,
          );

          return response.data as T;
        } finally {
          _activeTokens.remove(cancelToken);
        }
      },
      operationName: 'GET $url',
      errorCode: ErrorCodes.networkError,
    );
  }

  /// Make POST request
  Future<ServiceResult<T>> post<T>({
    required String url,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return executeWithRetry(
      operation: () async {
        final cancelToken = CancelToken();
        _activeTokens.add(cancelToken);

        try {
          final response = await _dio.post<T>(
            url,
            data: data,
            queryParameters: queryParameters,
            options: options,
            cancelToken: cancelToken,
          );

          return response.data as T;
        } finally {
          _activeTokens.remove(cancelToken);
        }
      },
      operationName: 'POST $url',
      errorCode: ErrorCodes.networkError,
    );
  }

  /// Cancel all active requests
  void cancelAllRequests() {
    logWarning('Cancelling ${_activeTokens.length} active requests');

    for (final token in _activeTokens) {
      if (!token.isCancelled) {
        token.cancel('User cancelled');
      }
    }

    _activeTokens.clear();
  }

  /// Download file
  Future<ServiceResult<void>> downloadFile({
    required String url,
    required String savePath,
    void Function(int, int)? onReceiveProgress,
  }) async {
    return executeOperation(
      operation: () async {
        final cancelToken = CancelToken();
        _activeTokens.add(cancelToken);

        try {
          await _dio.download(
            url,
            savePath,
            onReceiveProgress: onReceiveProgress,
            cancelToken: cancelToken,
          );
        } finally {
          _activeTokens.remove(cancelToken);
        }
      },
      operationName: 'download file from $url',
      errorCode: ErrorCodes.networkError,
    );
  }

  /// Create WebSocket connection
  Future<ServiceResult<WebSocket>> createWebSocket({
    required String url,
    Map<String, dynamic>? headers,
  }) async {
    return executeOperation(
      operation: () async {
        final socket = await WebSocket.connect(
          url,
          headers: headers,
        );

        logInfo('WebSocket connected to $url');
        return socket;
      },
      operationName: 'create WebSocket to $url',
      errorCode: ErrorCodes.networkError,
    );
  }
}

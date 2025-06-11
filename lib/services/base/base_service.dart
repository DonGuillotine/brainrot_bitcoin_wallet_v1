import 'package:flutter/foundation.dart';
import '../../main.dart';
import 'service_result.dart';

/// Base service class with common functionality
abstract class BaseService {
  @protected
  final String serviceName;

  BaseService(this.serviceName);

  /// Execute operation with error handling
  @protected
  Future<ServiceResult<T>> executeOperation<T>({
    required Future<T> Function() operation,
    required String operationName,
    String? errorCode,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      logger.d('[$serviceName] Starting $operationName');
      final result = await operation();

      stopwatch.stop();
      logger.i('[$serviceName] $operationName completed in ${stopwatch.elapsedMilliseconds}ms');

      return Success(result);
    } catch (error, stackTrace) {
      stopwatch.stop();
      logger.e(
        '[$serviceName] $operationName failed after ${stopwatch.elapsedMilliseconds}ms',
        error: error,
        stackTrace: stackTrace,
      );

      // If error is already a ServiceException, preserve its code
      if (error is ServiceException) {
        return ServiceError(error);
      }
      
      return ServiceError(
        ServiceException(
          message: 'Failed to $operationName: ${error.toString()}',
          code: errorCode ?? ErrorCodes.unknown,
          originalError: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Execute operation with retry logic
  @protected
  Future<ServiceResult<T>> executeWithRetry<T>({
    required Future<T> Function() operation,
    required String operationName,
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 1),
    String? errorCode,
  }) async {
    int attempts = 0;
    ServiceResult<T>? lastResult;

    while (attempts < maxRetries) {
      attempts++;
      logger.d('[$serviceName] Attempt $attempts/$maxRetries for $operationName');

      lastResult = await executeOperation(
        operation: operation,
        operationName: operationName,
        errorCode: errorCode,
      );

      if (lastResult.isSuccess) {
        return lastResult;
      }

      if (attempts < maxRetries) {
        logger.w('[$serviceName] Retrying $operationName after ${retryDelay.inSeconds}s');
        await Future.delayed(retryDelay * attempts); // Exponential backoff
      }
    }

    return lastResult ?? ServiceError(
      ServiceException(
        message: 'Failed to $operationName after $maxRetries attempts',
        code: errorCode ?? ErrorCodes.unknown,
      ),
    );
  }

  /// Log debug message
  @protected
  void logDebug(String message) {
    logger.d('[$serviceName] $message');
  }

  /// Log info message
  @protected
  void logInfo(String message) {
    logger.i('[$serviceName] $message');
  }

  /// Log warning message
  @protected
  void logWarning(String message) {
    logger.w('[$serviceName] $message');
  }

  /// Log error message
  @protected
  void logError(String message, {dynamic error, StackTrace? stackTrace}) {
    logger.e('[$serviceName] $message', error: error, stackTrace: stackTrace);
  }
}

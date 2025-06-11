import 'package:flutter/foundation.dart';

/// Result wrapper for service operations with meme-themed error handling
sealed class ServiceResult<T> {
  const ServiceResult();

  /// Check if result is success
  bool get isSuccess => this is Success<T>;

  /// Check if result is error
  bool get isError => this is ServiceError<T>;

  /// Get value or null
  T? get valueOrNull => switch (this) {
    Success<T>(:final value) => value,
    ServiceError<T>() => null,
  };

  /// Get error or null
  ServiceException? get errorOrNull => switch (this) {
    Success<T>() => null,
    ServiceError<T>(:final error) => error,
  };

  /// Map result to another type
  ServiceResult<R> map<R>(R Function(T) mapper) {
    return switch (this) {
      Success<T>(:final value) => Success(mapper(value)),
      ServiceError<T>(:final error) => ServiceError(error),
    };
  }

  /// Fold result into a single value
  R fold<R>({
    required R Function(T) onSuccess,
    required R Function(ServiceException) onError,
  }) {
    return switch (this) {
      Success<T>(:final value) => onSuccess(value),
      ServiceError<T>(:final error) => onError(error),
    };
  }
}

/// Success result
class Success<T> extends ServiceResult<T> {
  final T value;
  const Success(this.value);
}

/// Error result
class ServiceError<T> extends ServiceResult<T> {
  final ServiceException error;
  const ServiceError(this.error);
}

/// Base exception class for all service errors
@immutable
class ServiceException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const ServiceException({
    required this.message,
    this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => 'ServiceException($code): $message';

  /// Convert to user-friendly meme message
  String toMemeMessage() {
    return switch (code) {
      'NETWORK_ERROR' => 'No internet? Touch grass fr fr 🌱',
      'WALLET_NOT_FOUND' => 'Wallet gone. Reduced to atoms 💀',
      'INVALID_ADDRESS' => 'That address sus af 🤨',
      'INVALID_AMOUNT' => 'Amount not valid. Math is hard 🧮',
      'INSUFFICIENT_FUNDS' => 'Broke boi alert! Get that bread 🍞',
      'TRANSACTION_FAILED' => 'Transaction failed. Skill issue? 🎮',
      'AUTH_FAILED' => 'Auth failed. You shall not pass! 🧙‍♂️',
      'STORAGE_ERROR' => 'Storage rekt. Try turning it off and on 🔌',
      'ENCRYPTION_ERROR' => 'Encryption machine broke 🔐',
      'LIGHTNING_ERROR' => 'Lightning go brrrr... then stopped ⚡',
      _ => 'Something went wrong. It\'s so over 😭',
    };
  }
}

/// Common error codes
class ErrorCodes {
  static const networkError = 'NETWORK_ERROR';
  static const walletNotFound = 'WALLET_NOT_FOUND';
  static const invalidAddress = 'INVALID_ADDRESS';
  static const invalidAmount = 'INVALID_AMOUNT';
  static const insufficientFunds = 'INSUFFICIENT_FUNDS';
  static const transactionFailed = 'TRANSACTION_FAILED';
  static const authFailed = 'AUTH_FAILED';
  static const storageError = 'STORAGE_ERROR';
  static const encryptionError = 'ENCRYPTION_ERROR';
  static const lightningError = 'LIGHTNING_ERROR';
  static const unknown = 'UNKNOWN_ERROR';
}

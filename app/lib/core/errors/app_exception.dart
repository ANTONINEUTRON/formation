/// Base class for application-specific exceptions.
abstract class AppException implements Exception {
  const AppException({
    required this.message,
    this.code,
    this.originalError,
  });

  final String message;
  final String? code;
  final Object? originalError;

  @override
  String toString() => 'AppException($code): $message';
}

/// Exception thrown when authentication fails.
class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Exception thrown when a network request fails.
class NetworkException extends AppException {
  const NetworkException({
    required super.message,
    super.code,
    super.originalError,
    this.statusCode,
  });

  final int? statusCode;
}

/// Exception thrown when data validation fails.
class ValidationException extends AppException {
  const ValidationException({
    required super.message,
    super.code,
    this.field,
  });

  final String? field;
}

/// Exception thrown when a resource is not found.
class NotFoundException extends AppException {
  const NotFoundException({
    required super.message,
    super.code,
    this.resourceType,
    this.resourceId,
  });

  final String? resourceType;
  final String? resourceId;
}

/// Thrown when a wallet action is rejected or cancelled by the player.
///
/// Not a failure of ours, so the message is theirs to read and act on.
class WalletException extends AppException {
  const WalletException({
    required super.message,
    super.code,
    super.originalError,
  });
}

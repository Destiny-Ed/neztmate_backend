import 'package:equatable/equatable.dart';

// Base abstract class for all failures
abstract class Failure extends Equatable {
  final String message;
  final Object? error; // optional: underlying exception
  final StackTrace? stackTrace;

  const Failure({required this.message, this.error, this.stackTrace});

  @override
  List<Object?> get props => [message, error, stackTrace];

  // Helper to create user-friendly message for API responses
  String get userMessage => message;

  // Optional: HTTP status code suggestion
  int get statusCode => 500;
}

// Generic / unexpected errors
class UnexpectedFailure extends Failure {
  UnexpectedFailure([String message = 'An unexpected error occurred', Object? error, StackTrace? stackTrace])
    : super(message: message, error: error, stackTrace: stackTrace);

  @override
  int get statusCode => 500;
}

// Authentication / Authorization failures
class AuthFailure extends Failure {
  AuthFailure(String message, {super.error, super.stackTrace}) : super(message: message);

  @override
  int get statusCode => 401;
}

class InvalidCredentialsFailure extends AuthFailure {
  InvalidCredentialsFailure([super.message = 'Invalid email or password']);

  @override
  int get statusCode => 401;
}

class TokenExpiredFailure extends AuthFailure {
  TokenExpiredFailure([super.message = 'Session expired. Please sign in again.']);

  @override
  int get statusCode => 401;
}

class InvalidTokenFailure extends AuthFailure {
  InvalidTokenFailure([super.message = 'Invalid authentication token']);

  @override
  int get statusCode => 401;
}

class ForbiddenFailure extends AuthFailure {
  ForbiddenFailure([super.message = 'You do not have permission to perform this action']);

  @override
  int get statusCode => 403;
}

// Not found / resource errors
class NotFoundFailure extends Failure {
  NotFoundFailure(String resource, {String? id})
    : super(message: id != null ? '$resource with ID $id not found' : '$resource not found');

  @override
  int get statusCode => 404;
}

// Validation / bad request failures
class ValidationFailure extends Failure {
  final Map<String, String>? fieldErrors;

  ValidationFailure({super.message = 'Validation failed', this.fieldErrors});

  @override
  List<Object?> get props => [message, fieldErrors];

  @override
  int get statusCode => 400;
}

// Database / infrastructure failures
class ServerFailure extends Failure {
  ServerFailure([
    String message = 'Server error. Please try again later.',
    Object? error,
    StackTrace? stackTrace,
  ]) : super(message: message, error: error, stackTrace: stackTrace);

  @override
  int get statusCode => 500;
}

class DatabaseFailure extends ServerFailure {
  DatabaseFailure([super.message = 'Database operation failed', super.error, super.stackTrace]);
}

class NetworkFailure extends ServerFailure {
  NetworkFailure([super.message = 'Network error. Please check your connection.']);

  @override
  int get statusCode => 503;
}

// Domain-specific failures (add as needed)
class PropertyNotFoundFailure extends NotFoundFailure {
  PropertyNotFoundFailure({String? id}) : super('Property', id: id);
}

class UnitAlreadyOccupiedFailure extends Failure {
  UnitAlreadyOccupiedFailure([String message = 'This unit is already occupied']) : super(message: message);

  @override
  int get statusCode => 409; // Conflict
}

class LeaseConflictFailure extends Failure {
  LeaseConflictFailure([String message = 'Lease dates conflict with existing lease'])
    : super(message: message);

  @override
  int get statusCode => 409;
}

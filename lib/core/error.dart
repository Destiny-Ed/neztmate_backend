import 'dart:convert';
import 'package:shelf/shelf.dart';

sealed class AppException implements Exception {
  final String message;
  final Object? cause;

  const AppException(this.message, {this.cause});

  @override
  // String toString() => '$runtimeType: $message${cause != null ? ' ($cause)' : ''}';
  String toString() => '$message${cause != null ? ' ($cause)' : ''}';
}

class NotFoundException extends AppException {
  NotFoundException(String resource, [String? id])
    : super(id != null ? '$resource not found (ID: $id)' : '$resource not found');
}

class InvalidCredentialsException extends AppException {
  InvalidCredentialsException() : super('Invalid email or password');
}

class EmailAlreadyExistsException extends AppException {
  EmailAlreadyExistsException(String email) : super('Email $email is already registered');
}

class InvalidRoleException extends AppException {
  InvalidRoleException(String role)
    : super('Invalid role: $role. Allowed: tenant, landowner, manager, artisan');
}

class InvalidTokenException extends AppException {
  InvalidTokenException() : super('Invalid or expired token');
}

class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  ValidationException(super.message, {this.fieldErrors});
}

class ServerException extends AppException {
  ServerException(super.message, [Object? cause]) : super(cause: cause);
}

///Handle error accross project
Response handleAppException(Object e, StackTrace stack) {
  print('Error: $e\n$stack');

  if (e is NotFoundException) {
    return Response(404, body: jsonEncode({'message': e.message.toString()}));
  }
  if (e is InvalidCredentialsException || e is InvalidTokenException) {
    return Response(401, body: jsonEncode({'message': e.toString()}));
  }
  if (e is EmailAlreadyExistsException || e is InvalidRoleException) {
    return Response(400, body: jsonEncode({'message': e.toString()}));
  }
  if (e is ValidationException) {
    return Response(
      400,
      body: jsonEncode({'message': e.message.toString(), if (e.fieldErrors != null) 'fields': e.fieldErrors}),
    );
  }
  return Response.internalServerError(body: jsonEncode({'message': 'An unexpected error occurred'}));
}

// Helper for consistent bad request responses
Response badRequest(String message) {
  return Response(400, body: jsonEncode({'message': message}), headers: {'Content-Type': 'application/json'});
}

Response unauthorized(String message) =>
    Response(401, body: jsonEncode({'message': message}), headers: {'Content-Type': 'application/json'});

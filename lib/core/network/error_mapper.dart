import 'dart:io';

import 'package:dio/dio.dart';

import '../error/failure.dart';

/// Translates transport-level errors into the domain's [Failure] types.
///
/// Centralising this is what lets the UI branch on *what went wrong* instead of
/// pattern-matching on message strings, and it is the only place that knows how
/// this backend shapes its error bodies.
abstract final class ErrorMapper {
  const ErrorMapper._();

  static Failure fromDio(DioException exception) {
    final response = exception.response;
    final statusCode = response?.statusCode;

    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutFailure(cause: exception);

      case DioExceptionType.cancel:
        return CancelledFailure(cause: exception);

      case DioExceptionType.connectionError:
        return NetworkFailure(cause: exception);

      case DioExceptionType.badCertificate:
        return NetworkFailure(
          message: 'Certificat du serveur invalide',
          cause: exception,
        );

      case DioExceptionType.unknown:
        if (exception.error is SocketException) {
          return NetworkFailure(cause: exception);
        }
        return UnexpectedFailure(cause: exception);

      case DioExceptionType.badResponse:
        return _fromStatusCode(statusCode, response, exception);
    }
  }

  static Failure _fromStatusCode(
    int? statusCode,
    Response<dynamic>? response,
    DioException exception,
  ) {
    final message = extractMessage(response?.data);

    return switch (statusCode) {
      400 || 422 => ValidationFailure(
        message: message ?? 'Données invalides',
        fieldErrors: _extractFieldErrors(response?.data),
        cause: exception,
      ),
      401 => UnauthorizedFailure(
        message: message ?? 'Session expirée, reconnectez-vous',
        cause: exception,
      ),
      403 => ForbiddenFailure(message: message ?? 'Accès refusé', cause: exception),
      404 => NotFoundFailure(
        message: message ?? 'Ressource introuvable',
        cause: exception,
      ),
      409 => ConflictFailure(
        message: message ?? 'Cette donnée a déjà été modifiée',
        cause: exception,
      ),
      _ when statusCode != null && statusCode >= 500 => ServerFailure(
        message: message ?? 'Erreur du serveur, réessayez',
        statusCode: statusCode,
        cause: exception,
      ),
      _ => UnexpectedFailure(
        message: message ?? 'Une erreur est survenue',
        cause: exception,
      ),
    };
  }

  /// Pulls the human-readable text out of an error body.
  ///
  /// The backend is inconsistent about this — it has been observed returning
  /// `{message}`, `{error}`, `{detail}`, and a bare string — so all are handled.
  static String? extractMessage(dynamic data) {
    if (data == null) return null;

    if (data is String) {
      final trimmed = data.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    if (data is Map) {
      for (final key in const ['message', 'error', 'detail', 'error_description']) {
        final value = data[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
      // Spring validation style: {"errors": [{"defaultMessage": "..."}]}
      final errors = data['errors'];
      if (errors is List && errors.isNotEmpty) {
        final first = errors.first;
        if (first is Map) {
          final value = first['defaultMessage'] ?? first['message'];
          if (value is String && value.trim().isNotEmpty) return value.trim();
        }
        if (first is String && first.trim().isNotEmpty) return first.trim();
      }
    }

    return null;
  }

  /// Extracts per-field messages so a form can mark the offending inputs.
  static Map<String, String> _extractFieldErrors(dynamic data) {
    if (data is! Map) return const {};

    final result = <String, String>{};

    // {"fieldErrors": {"email": "invalide"}} or {"errors": {...}}
    for (final key in const ['fieldErrors', 'errors', 'violations']) {
      final value = data[key];
      if (value is Map) {
        value.forEach((field, message) {
          if (message is String) result['$field'] = message;
        });
      } else if (value is List) {
        // [{"field": "email", "defaultMessage": "invalide"}]
        for (final entry in value) {
          if (entry is Map) {
            final field = entry['field'] ?? entry['propertyPath'];
            final message = entry['defaultMessage'] ?? entry['message'];
            if (field is String && message is String) result[field] = message;
          }
        }
      }
    }

    return result;
  }
}

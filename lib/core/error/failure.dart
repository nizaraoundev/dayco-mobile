import 'package:equatable/equatable.dart';

/// A typed, user-presentable description of why an operation did not succeed.
///
/// The previous implementation threw `Exception('some message')` everywhere and
/// the UI recovered the text with `e.toString().replaceFirst('Exception: ', '')`.
/// That made the error contract a string, impossible to branch on and impossible
/// to test. [Failure] replaces it: repositories return or throw failures, and the
/// presentation layer decides how to render each kind.
sealed class Failure extends Equatable {
  const Failure({required this.message, this.cause});

  /// Message safe to show to the representative, already localised by the
  /// backend when it supplied one.
  final String message;

  /// The originating error, kept for logging only — never shown to the user.
  final Object? cause;

  /// Whether retrying the identical request could plausibly succeed.
  bool get isRetryable => switch (this) {
    NetworkFailure() => true,
    TimeoutFailure() => true,
    ServerFailure() => true,
    CancelledFailure() => false,
    UnauthorizedFailure() => false,
    ForbiddenFailure() => false,
    NotFoundFailure() => false,
    ValidationFailure() => false,
    ConflictFailure() => false,
    StorageFailure() => false,
    PermissionFailure() => false,
    UnexpectedFailure() => false,
  };

  @override
  List<Object?> get props => [message];

  @override
  String toString() => '$runtimeType($message)';
}

/// No usable connection, DNS failure, or the host could not be reached.
final class NetworkFailure extends Failure {
  const NetworkFailure({super.message = 'Connexion indisponible', super.cause});
}

/// The request was sent but the backend did not answer in time.
final class TimeoutFailure extends Failure {
  const TimeoutFailure({super.message = 'Le serveur ne répond pas', super.cause});
}

/// 5xx — the backend failed to process a well-formed request.
final class ServerFailure extends Failure {
  const ServerFailure({super.message = 'Erreur du serveur', super.cause, this.statusCode});

  final int? statusCode;

  @override
  List<Object?> get props => [message, statusCode];
}

/// 401 — the token is missing, expired or was issued by a different backend.
final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({super.message = 'Session expirée', super.cause});
}

/// 403 — authenticated, but not allowed to perform this operation.
final class ForbiddenFailure extends Failure {
  const ForbiddenFailure({super.message = 'Accès refusé', super.cause});
}

/// 404 — the requested resource does not exist.
final class NotFoundFailure extends Failure {
  const NotFoundFailure({super.message = 'Ressource introuvable', super.cause});
}

/// 400/422 — the payload was rejected. [fieldErrors] maps a form field name to
/// the backend's complaint about it, so forms can highlight the offending input.
final class ValidationFailure extends Failure {
  const ValidationFailure({
    required super.message,
    this.fieldErrors = const {},
    super.cause,
  });

  final Map<String, String> fieldErrors;

  @override
  List<Object?> get props => [message, fieldErrors];
}

/// 409 — the resource changed underneath us.
final class ConflictFailure extends Failure {
  const ConflictFailure({super.message = 'Conflit de données', super.cause});
}

/// The request was deliberately aborted (widget disposed, newer request issued).
/// Never surface this to the user: it is the expected outcome of cancellation.
final class CancelledFailure extends Failure {
  const CancelledFailure({super.message = 'Requête annulée', super.cause});
}

/// Local persistence (preferences, secure storage, sqflite) failed.
final class StorageFailure extends Failure {
  const StorageFailure({super.message = 'Stockage local indisponible', super.cause});
}

/// A platform permission (location, camera, photos) is unavailable.
///
/// [isPermanentlyDenied] distinguishes "ask again" from "send the user to the
/// system settings", which the two cases require different UI for.
final class PermissionFailure extends Failure {
  const PermissionFailure({
    required super.message,
    this.isPermanentlyDenied = false,
    super.cause,
  });

  final bool isPermanentlyDenied;

  @override
  List<Object?> get props => [message, isPermanentlyDenied];
}

/// Anything not classifiable above. Always logged with its [cause].
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure({super.message = 'Une erreur est survenue', super.cause});
}

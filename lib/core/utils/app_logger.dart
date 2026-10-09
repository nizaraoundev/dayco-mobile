import 'package:flutter/foundation.dart';

/// Minimal structured logger.
///
/// Replaces the `print()` calls scattered through the previous implementation,
/// two of which leaked credentials: `AuthController.login()` printed the login
/// request including the plaintext password, and `AuthService.login()` printed
/// the whole response including both tokens (audit M-4).
///
/// Nothing is emitted in release builds, and [redact] exists so call sites can
/// include identifying context without ever writing a secret to the log.
abstract final class AppLogger {
  const AppLogger._();

  /// Field names whose values must never be logged, matched case-insensitively.
  static const Set<String> _secretKeys = {
    'password',
    'motdepasse',
    'accesstoken',
    'access_token',
    'refreshtoken',
    'refresh_token',
    'token',
    'authorization',
    'apikey',
    'api_key',
    'secret',
  };

  static void debug(String message) {
    if (kDebugMode) debugPrint('[DEBUG] $message');
  }

  static void info(String message) {
    if (kDebugMode) debugPrint('[INFO]  $message');
  }

  static void warn(String message, {Object? error}) {
    if (kDebugMode) {
      debugPrint('[WARN]  $message${error == null ? '' : ' — $error'}');
    }
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      debugPrint('[ERROR] $message${error == null ? '' : ' — $error'}');
      if (stackTrace != null) debugPrintStack(stackTrace: stackTrace);
    }
    // A crash reporter (Crashlytics/Sentry) would be forwarded to here.
  }

  /// Returns a copy of [data] with every secret value replaced by `***`,
  /// recursing into nested maps and lists.
  ///
  /// Use this instead of logging a payload directly:
  /// `AppLogger.debug('login ${AppLogger.redact(request.toJson())}')`.
  static Map<String, dynamic> redact(Map<String, dynamic> data) {
    return data.map((key, value) {
      if (_secretKeys.contains(key.toLowerCase().replaceAll('-', ''))) {
        return MapEntry(key, '***');
      }
      return MapEntry(key, _redactValue(value));
    });
  }

  static Object? _redactValue(Object? value) {
    if (value is Map<String, dynamic>) return redact(value);
    if (value is Map) return redact(Map<String, dynamic>.from(value));
    if (value is List) return value.map(_redactValue).toList();
    return value;
  }
}

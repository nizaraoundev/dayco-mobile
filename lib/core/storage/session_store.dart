import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../utils/app_logger.dart';

/// Tokens for one backend.
class AuthTokens {
  const AuthTokens({required this.accessToken, this.refreshToken});

  final String accessToken;
  final String? refreshToken;

  bool get isEmpty => accessToken.isEmpty;
}

/// Stores bearer tokens, **namespaced per [ApiBackend]**.
///
/// Two problems in the original implementation are fixed here:
///
/// * The stock backend wrote its token to the same `access_token` key the main
///   backend used, silently destroying the main session (audit C-1). Keys are
///   now derived from the backend, so the two can never collide.
/// * Every single request did `await SharedPreferences.getInstance()` to read
///   the token (audit M-5). Tokens are now read once into memory on [load] and
///   kept in sync on write, so the hot path does no I/O.
///
/// Tokens are held in [FlutterSecureStorage] (Keystore / Keychain) rather than
/// plain preferences. Tokens previously written to `SharedPreferences` are
/// migrated on first [load] so existing installs are not logged out.
class SessionStore {
  SessionStore({FlutterSecureStorage? secureStorage})
    : _secure =
          secureStorage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
          );

  final FlutterSecureStorage _secure;

  final Map<ApiBackend, AuthTokens> _cache = {};

  bool _loaded = false;

  /// Emits whenever the main backend's session is established or cleared, so
  /// the app shell can react to a 401-driven logout without polling.
  final StreamController<bool> _mainSessionChanges =
      StreamController<bool>.broadcast();

  Stream<bool> get mainSessionChanges => _mainSessionChanges.stream;

  static String _accessKey(ApiBackend b) => 'auth.${b.name}.access_token';

  static String _refreshKey(ApiBackend b) => 'auth.${b.name}.refresh_token';

  /// Keys the pre-refactor build used, all of them for the *main* backend
  /// except where the stock service overwrote them.
  static const String _legacyAccessKey = 'access_token';
  static const String _legacyRefreshKey = 'refresh_token';

  /// Reads every backend's tokens into memory. Safe to call more than once.
  Future<void> load() async {
    if (_loaded) return;

    for (final backend in ApiBackend.values) {
      try {
        final access = await _secure.read(key: _accessKey(backend)) ?? '';
        final refresh = await _secure.read(key: _refreshKey(backend));
        if (access.isNotEmpty) {
          _cache[backend] = AuthTokens(accessToken: access, refreshToken: refresh);
        }
      } on Object catch (error, stackTrace) {
        // A corrupt keystore entry must not prevent the app from starting; the
        // user is simply treated as signed out for that backend.
        AppLogger.error(
          'Failed to read tokens for ${backend.name}',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    await _migrateLegacyTokens();
    _loaded = true;
  }

  /// Moves a token written by the previous build into the main namespace.
  ///
  /// Only runs when the main namespace is still empty, so it can never clobber
  /// a token written by the current build.
  Future<void> _migrateLegacyTokens() async {
    if (_cache[ApiBackend.main] != null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final legacyAccess = prefs.getString(_legacyAccessKey) ?? '';
      if (legacyAccess.isEmpty) return;

      final legacyRefresh = prefs.getString(_legacyRefreshKey);
      await write(
        ApiBackend.main,
        AuthTokens(accessToken: legacyAccess, refreshToken: legacyRefresh),
      );

      await prefs.remove(_legacyAccessKey);
      await prefs.remove(_legacyRefreshKey);
      AppLogger.info('Migrated legacy session token to secure storage');
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'Legacy token migration failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// The cached access token for [backend], or `null` when signed out.
  /// Synchronous by design: this is called on every outbound request.
  String? accessToken(ApiBackend backend) {
    final token = _cache[backend]?.accessToken;
    return (token == null || token.isEmpty) ? null : token;
  }

  String? refreshToken(ApiBackend backend) => _cache[backend]?.refreshToken;

  bool hasSession(ApiBackend backend) => accessToken(backend) != null;

  Future<void> write(ApiBackend backend, AuthTokens tokens) async {
    _cache[backend] = tokens;

    try {
      await _secure.write(key: _accessKey(backend), value: tokens.accessToken);
      final refresh = tokens.refreshToken;
      if (refresh != null && refresh.isNotEmpty) {
        await _secure.write(key: _refreshKey(backend), value: refresh);
      } else {
        await _secure.delete(key: _refreshKey(backend));
      }
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'Failed to persist tokens for ${backend.name}',
        error: error,
        stackTrace: stackTrace,
      );
    }

    if (backend == ApiBackend.main) _mainSessionChanges.add(true);
  }

  Future<void> clear(ApiBackend backend) async {
    _cache.remove(backend);

    try {
      await _secure.delete(key: _accessKey(backend));
      await _secure.delete(key: _refreshKey(backend));
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'Failed to clear tokens for ${backend.name}',
        error: error,
        stackTrace: stackTrace,
      );
    }

    if (backend == ApiBackend.main) _mainSessionChanges.add(false);
  }

  /// Clears every backend. Used on sign-out.
  Future<void> clearAll() async {
    for (final backend in ApiBackend.values) {
      await clear(backend);
    }
  }

  Future<void> dispose() => _mainSessionChanges.close();
}

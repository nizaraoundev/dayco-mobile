import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../storage/session_store.dart';
import '../utils/app_logger.dart';

/// Attaches the correct credentials to every outbound request and reports
/// authentication loss once, centrally.
///
/// Replaces the previous arrangement where each of ~15 service methods
/// independently awaited `SharedPreferences`, read the token and hand-built an
/// `Options` object (audit M-5). Because [SessionStore] caches tokens in memory,
/// this does no I/O.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required ApiBackend backend,
    required SessionStore sessionStore,
    required this.onUnauthorized,
    this.userEmailProvider,
  }) : _backend = backend,
       _sessionStore = sessionStore;

  final ApiBackend _backend;
  final SessionStore _sessionStore;

  /// Called when the backend rejects our credentials. The app shell uses this
  /// to sign the representative out exactly once, rather than letting every
  /// in-flight request raise its own error dialog.
  final void Function(ApiBackend backend) onUnauthorized;

  /// Supplies the `X-User-Email` header the main backend expects on
  /// write operations. Optional because the stock backend does not use it.
  final String? Function()? userEmailProvider;

  /// Requests that must not carry a bearer token — notably login itself, where
  /// sending a stale token has been observed to make the backend answer 401.
  static const Set<String> _anonymousPaths = {ApiEndpoints.login};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!_anonymousPaths.contains(options.path)) {
      final token = _sessionStore.accessToken(_backend);
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }

      final email = userEmailProvider?.call();
      if (email != null && email.isNotEmpty) {
        options.headers['X-User-Email'] = email;
      }
    }

    if (_backend == ApiBackend.stock) {
      options.headers['X-Device-Id'] = ApiConfig.stockDeviceId;
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401 &&
        !_anonymousPaths.contains(err.requestOptions.path)) {
      AppLogger.warn('401 on ${_backend.name}${err.requestOptions.path}');
      onUnauthorized(_backend);
    }
    handler.next(err);
  }
}

import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../error/failure.dart';
import '../error/result.dart';
import '../utils/app_logger.dart';
import 'auth_interceptor.dart';
import 'error_mapper.dart';
import 'json_coercion.dart';

/// One HTTP client per backend.
///
/// The previous code constructed `Dio` ad hoc inside `AuthService`,
/// `CommercialStockService` and (via `AuthService()`) the splash page, the auth
/// controller and the map controller — several instances with separate
/// connection pools and no shared configuration. There is now exactly one
/// client per [ApiBackend], created in the dependency graph.
///
/// Every method returns [Result]; nothing throws. `DioException` never escapes
/// this class.
class ApiClient {
  ApiClient({
    required this.backend,
    required Dio dio,
  }) : _dio = dio;

  factory ApiClient.create({
    required ApiBackend backend,
    required AuthInterceptor authInterceptor,
    Dio? dio,
  }) {
    final client = dio ?? Dio();
    client.options = BaseOptions(
      baseUrl: ApiConfig.baseUrlOf(backend),
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      sendTimeout: ApiConfig.sendTimeout,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      // Non-2xx is surfaced as DioException and mapped by ErrorMapper, so the
      // success path never has to re-check the status code.
      validateStatus: (status) => status != null && status >= 200 && status < 300,
    );
    client.interceptors.add(authInterceptor);
    return ApiClient(backend: backend, dio: client);
  }

  final ApiBackend backend;
  final Dio _dio;

  /// Exposed so feature code can create [CancelToken]s against the right client
  /// and so tests can install a mock adapter.
  Dio get dio => _dio;

  // -------------------------------------------------------------- JSON object

  /// `GET` returning a JSON object.
  Future<Result<Map<String, dynamic>>> getObject(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) => _guard(
    () async => JsonCoercion.asMap(
      (await _dio.get<dynamic>(
        path,
        queryParameters: query,
        cancelToken: cancelToken,
      )).data,
    ),
  );

  Future<Result<Map<String, dynamic>>> postObject(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) => _guard(
    () async => JsonCoercion.asMap(
      (await _dio.post<dynamic>(
        path,
        data: body,
        queryParameters: query,
        cancelToken: cancelToken,
      )).data,
    ),
  );

  Future<Result<Map<String, dynamic>>> putObject(
    String path, {
    Object? body,
    CancelToken? cancelToken,
  }) => _guard(
    () async => JsonCoercion.asMap(
      (await _dio.put<dynamic>(path, data: body, cancelToken: cancelToken)).data,
    ),
  );

  Future<Result<Map<String, dynamic>>> patchObject(
    String path, {
    Object? body,
    CancelToken? cancelToken,
  }) => _guard(
    () async => JsonCoercion.asMap(
      (await _dio.patch<dynamic>(path, data: body, cancelToken: cancelToken)).data,
    ),
  );

  Future<Result<void>> delete(String path, {CancelToken? cancelToken}) =>
      _guard(() async {
        await _dio.delete<dynamic>(path, cancelToken: cancelToken);
      });

  // ---------------------------------------------------------------- JSON list

  /// `GET` returning a list of JSON objects.
  ///
  /// Tolerates the three shapes this backend uses interchangeably: a bare
  /// array, `{"content": [...]}` (Spring `Page`) and `{"data": [...]}`. That
  /// tolerance existed in the original `_asListOfMaps` and is preserved.
  Future<Result<List<Map<String, dynamic>>>> getList(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) => _guard(
    () async => JsonCoercion.asListOfMaps(
      (await _dio.get<dynamic>(
        path,
        queryParameters: query,
        cancelToken: cancelToken,
      )).data,
    ),
  );

  // ------------------------------------------------------------------- binary

  /// `GET` returning raw bytes, used for authenticated image downloads.
  Future<Result<Uint8List>> getBytes(
    String path, {
    CancelToken? cancelToken,
  }) => _guard(() async {
    final response = await _dio.get<List<int>>(
      path,
      cancelToken: cancelToken,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw const _EmptyBodyException();
    }
    return Uint8List.fromList(bytes);
  });

  /// `POST` of a `multipart/form-data` body.
  Future<Result<Map<String, dynamic>>> postMultipart(
    String path, {
    required FormData body,
    CancelToken? cancelToken,
  }) => _guard(
    () async => JsonCoercion.asMap(
      (await _dio.post<dynamic>(
        path,
        data: body,
        cancelToken: cancelToken,
        options: Options(contentType: 'multipart/form-data'),
      )).data,
    ),
  );

  // ----------------------------------------------------------------- fallback

  /// Runs [primary]; if it fails with [onStatus], runs [fallback] instead.
  ///
  /// The backend has two endpoints that moved: user lookup answers 404 on the
  /// singular path for some deployments, and client update answers 405 where
  /// only `PATCH` is routed. The original code expressed this with nested
  /// try/catch inside the service methods; expressing it here keeps the
  /// compatibility rule explicit and reusable.
  Future<Result<T>> withStatusFallback<T>({
    required Future<Result<T>> Function() primary,
    required Future<Result<T>> Function() fallback,
    required int onStatus,
  }) async {
    final result = await primary();

    final failure = result.failureOrNull;
    if (failure == null) return result;

    final matches = switch (failure) {
      NotFoundFailure() => onStatus == 404,
      ServerFailure(:final statusCode) => statusCode == onStatus,
      UnexpectedFailure(:final cause) =>
        cause is DioException && cause.response?.statusCode == onStatus,
      _ => false,
    };

    if (!matches) return result;

    AppLogger.debug('Falling back after $onStatus on ${backend.name}');
    return fallback();
  }

  // ------------------------------------------------------------------ interna

  /// Runs [action], converting any thrown error into a [Failure].
  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Result.success(await action());
    } on DioException catch (exception) {
      return Result.failure(ErrorMapper.fromDio(exception));
    } on _EmptyBodyException {
      return const Result.failure(
        NotFoundFailure(message: 'Réponse vide du serveur'),
      );
    } on FormatException catch (error, stackTrace) {
      AppLogger.error(
        'Malformed response from ${backend.name}',
        error: error,
        stackTrace: stackTrace,
      );
      return Result.failure(
        UnexpectedFailure(message: 'Réponse illisible du serveur', cause: error),
      );
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'Unexpected error calling ${backend.name}',
        error: error,
        stackTrace: stackTrace,
      );
      return Result.failure(UnexpectedFailure(cause: error));
    }
  }
}

class _EmptyBodyException implements Exception {
  const _EmptyBodyException();
}

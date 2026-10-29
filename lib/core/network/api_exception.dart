import 'package:dio/dio.dart';

/// A failed backend call, with enough of the failure kept to decide what to do
/// about it.
///
/// Everything used to be thrown as `Exception(message)`, which reads the same
/// to a user and tells the code nothing: a request that never left the device
/// because there was no signal and a payload the backend refused are opposite
/// problems. The first should be kept and sent later; the second will be
/// refused again on every retry until somebody changes it. The offline queue
/// cannot be written honestly without telling them apart.
///
/// [toString] is the message alone, so the screens that already show
/// `e.toString().replaceAll('Exception: ', '')` keep showing exactly what they
/// showed before.
class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.isConnectionFailure = false,
  });

  final String message;

  /// The HTTP status, when the backend answered at all.
  final int? statusCode;

  /// Whether the request never got an answer: no network, DNS failure,
  /// timeout, a connection dropped mid-flight.
  final bool isConnectionFailure;

  factory ApiException.fromDio(DioException error, String message) {
    const connectionFailures = {
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.unknown,
    };

    return ApiException(
      message,
      statusCode: error.response?.statusCode,
      // `unknown` covers the SocketException a device with no signal throws,
      // and it is only reached when no response came back at all.
      isConnectionFailure:
          error.response == null && connectionFailures.contains(error.type),
    );
  }

  /// Whether sending the same thing again could plausibly work.
  ///
  /// A connection failure, yes — that is what the queue is for. A 5xx, yes:
  /// the backend is having a bad minute. A 401 too, because the token can be
  /// refreshed by signing in again and the work should not be thrown away in
  /// the meantime. A 4xx, no: the request is wrong and will be just as wrong
  /// in ten minutes, so it has to be shown to somebody rather than retried
  /// into the void.
  bool get isRetryable {
    if (isConnectionFailure) return true;

    final status = statusCode;
    if (status == null) return true;
    if (status == 401 || status == 408 || status == 429) return true;

    return status >= 500;
  }

  @override
  String toString() => message;
}

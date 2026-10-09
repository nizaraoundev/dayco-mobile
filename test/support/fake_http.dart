import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// One canned HTTP response.
class StubResponse {
  const StubResponse({this.statusCode = 200, this.body, this.bytes});

  final int statusCode;
  final Object? body;
  final List<int>? bytes;
}

/// A request the stub observed, for assertions.
class RecordedRequest {
  RecordedRequest({
    required this.method,
    required this.path,
    required this.headers,
    required this.body,
  });

  final String method;
  final String path;
  final Map<String, dynamic> headers;
  final Object? body;

  String? get authorization => headers['Authorization']?.toString();

  Map<String, dynamic> get jsonBody {
    final raw = body;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String && raw.isNotEmpty) {
      return jsonDecode(raw) as Map<String, dynamic>;
    }
    return const {};
  }

  @override
  String toString() => '$method $path';
}

/// A [HttpClientAdapter] that answers from a routing table instead of the
/// network, so repository tests exercise the real `Dio` + interceptor stack
/// without a server.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter();

  final List<RecordedRequest> requests = <RecordedRequest>[];

  /// Maps `'METHOD /path'` to a response, or to a function of the request.
  final Map<String, Object> _routes = <String, Object>{};

  /// Registers a response for `method path`.
  void on(
    String method,
    String path, {
    int statusCode = 200,
    Object? body,
    List<int>? bytes,
  }) {
    _routes['${method.toUpperCase()} $path'] = StubResponse(
      statusCode: statusCode,
      body: body,
      bytes: bytes,
    );
  }

  /// Registers a handler that can vary its response per call — used to make an
  /// endpoint fail once and then succeed.
  void onDynamic(
    String method,
    String path,
    StubResponse Function(RecordedRequest request) handler,
  ) {
    _routes['${method.toUpperCase()} $path'] = handler;
  }

  int callsTo(String method, String path) => requests
      .where(
        (request) =>
            request.method == method.toUpperCase() && request.path == path,
      )
      .length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final record = RecordedRequest(
      method: options.method.toUpperCase(),
      path: options.path,
      headers: Map<String, dynamic>.from(options.headers),
      body: options.data,
    );
    requests.add(record);

    final route = _routes['${record.method} ${record.path}'];

    if (route == null) {
      return ResponseBody.fromString(
        jsonEncode({'message': 'No stub for ${record.method} ${record.path}'}),
        404,
        headers: _jsonHeaders,
      );
    }

    final stub = route is StubResponse
        ? route
        : (route as StubResponse Function(RecordedRequest))(record);

    if (stub.bytes != null) {
      return ResponseBody.fromBytes(stub.bytes!, stub.statusCode);
    }

    return ResponseBody.fromString(
      stub.body == null ? '' : jsonEncode(stub.body),
      stub.statusCode,
      headers: _jsonHeaders,
    );
  }

  static const Map<String, List<String>> _jsonHeaders = {
    Headers.contentTypeHeader: ['application/json'],
  };

  @override
  void close({bool force = false}) {}
}

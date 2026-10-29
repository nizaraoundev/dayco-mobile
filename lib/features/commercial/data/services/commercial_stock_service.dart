import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/commercial_stock_models.dart';

/// Raised when the stock backend refuses a call for want of a usable token.
///
/// A refused token and a dead network are different problems with different
/// ways out — sign in again versus retry — so the screen has to be able to
/// tell them apart, which a bare [Exception] carrying a message never allowed.
class CommercialStockAuthException implements Exception {
  CommercialStockAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CommercialStockService {
  static const String _baseUrl = 'https://b2b.stdp-dayco.com';

  /// The one session the app has: a commercial signs in once and the stock
  /// backend is reached with that same token. Nothing in this service writes
  /// auth state — it only reads what the login left behind.
  static const String _accessTokenKey = 'access_token';

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  Future<CommercialStockPageResponse> getStocksAdminAll({
    required int page,
    int size = 20,
    String? search,
    String? entrepot,
  }) async {
    try {
      final options = await _authorizedOptions();
      final query = <String, dynamic>{'page': page, 'size': size};

      final cleanSearch = search?.trim() ?? '';
      if (cleanSearch.isNotEmpty) {
        query['search'] = cleanSearch;
      }

      final cleanEntrepot = entrepot?.trim() ?? '';
      if (cleanEntrepot.isNotEmpty) {
        query['entrepot'] = cleanEntrepot;
      }

      final response = await _dio.get(
        '/api/v1/stocks/admin/all',
        queryParameters: query,
        options: options,
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Erreur de chargement du stock: ${response.statusCode}',
        );
      }

      return CommercialStockPageResponse.fromJson(_asMap(response.data));
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<CommercialStockProductDetails> getStockByReferenceOrId(
    String referenceOrId,
  ) async {
    try {
      final options = await _authorizedOptions();
      final response = await _dio.get(
        '/api/v1/stocks/produit/$referenceOrId',
        options: options,
      );

      if (response.statusCode != 200) {
        throw Exception('Produit introuvable: $referenceOrId');
      }

      return CommercialStockProductDetails.fromJson(_asMap(response.data));
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// The catalogue-wide stock figures, in one call.
  Future<CommercialStockStats> getStockStats() async {
    try {
      final options = await _authorizedOptions();
      final response = await _dio.get(
        '/api/v1/stocks/admin/stats',
        options: options,
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Erreur de chargement des statistiques stock: '
          '${response.statusCode}',
        );
      }

      return CommercialStockStats.fromJson(_asMap(response.data));
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// How many references are on the alert list.
  ///
  /// Asked as a page of one: the backend's `totalElements` is the count, so
  /// there is no reason to transfer the rows to find out how many there are.
  Future<int> countStockAlerts() async {
    try {
      final options = await _authorizedOptions();
      final response = await _dio.get(
        '/api/v1/stocks/admin/alertes/page',
        queryParameters: const {'page': 0, 'size': 1},
        options: options,
      );

      if (response.statusCode != 200) {
        throw Exception('Erreur de chargement des alertes stock.');
      }

      return CommercialStockPageResponse.fromJson(
        _asMap(response.data),
      ).totalElements;
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<List<CommercialPendingReservation>> getPendingReservations({
    required String produitId,
  }) async {
    try {
      final options = await _authorizedOptions();
      final response = await _dio.get(
        '/api/v1/stocks/admin/produit/$produitId/reservations-en-attente',
        options: options,
      );

      if (response.statusCode != 200) {
        throw Exception('Échec de chargement des réservations en attente.');
      }

      final list = _asListOfMaps(response.data);
      return list
          .map((item) => CommercialPendingReservation.fromJson(item))
          .toList();
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<Options> _authorizedOptions() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_accessTokenKey)?.trim() ?? '';

    if (token.isEmpty) {
      throw CommercialStockAuthException(
        'Session expirée. Reconnectez-vous à l\'application.',
      );
    }

    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Format de réponse invalide');
  }

  List<Map<String, dynamic>> _asListOfMaps(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    if (data is Map && data['content'] is List) {
      final content = data['content'] as List;
      return content
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  /// Keeps the backend's own wording, but tags the refusals the screen has
  /// to react to differently.
  Exception _mapDioError(DioException e) {
    final status = e.response?.statusCode;
    final message = _extractErrorMessage(e);

    if (status == 401 || status == 403) {
      return CommercialStockAuthException(message);
    }

    return Exception(message);
  }

  String _extractErrorMessage(DioException e) {
    final data = e.response?.data;

    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }

    if (data is String && data.trim().isNotEmpty) {
      return data;
    }

    if (e.response?.statusCode == 401) {
      return 'Session expirée. Reconnectez-vous.';
    }

    return e.message ?? 'Erreur réseau';
  }
}

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/commercial_stock_models.dart';

class CommercialStockService {
  static const String _baseUrl = 'https://b2b.stdp-dayco.com';
  static const String _deviceId = 'commercial-web';

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

  Future<String> loginAndGetToken({
    required String codeClient,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/auth/login',
        data: {'codeClient': codeClient, 'password': password},
        options: Options(headers: const {'X-Device-Id': _deviceId}),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Échec de connexion stock: ${response.statusMessage}');
      }

      final data = _asMap(response.data);
      final accessToken = (data['accessToken'] ?? '').toString();
      final refreshToken = (data['refreshToken'] ?? '').toString();

      if (accessToken.isEmpty) {
        throw Exception('Réponse de connexion invalide (accessToken absent).');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', accessToken);
      if (refreshToken.isNotEmpty) {
        await prefs.setString('refresh_token', refreshToken);
      }
      await prefs.setString(
        'user_email',
        (data['email'] ?? codeClient).toString(),
      );

      return accessToken;
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

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
      throw Exception(_extractErrorMessage(e));
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
      throw Exception(_extractErrorMessage(e));
    }
  }

  Future<CommercialStockAvailability> checkAvailability({
    required String referenceOrId,
    required int quantite,
  }) async {
    try {
      final options = await _authorizedOptions();
      final response = await _dio.get(
        '/api/v1/stocks/produit/$referenceOrId/disponibilite',
        queryParameters: {'quantite': quantite},
        options: options,
      );

      if (response.statusCode != 200) {
        throw Exception('Échec du contrôle de disponibilité.');
      }

      return CommercialStockAvailability.fromJson(_asMap(response.data));
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
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
      throw Exception(_extractErrorMessage(e));
    }
  }

  Future<Options> _authorizedOptions() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token == null || token.isEmpty) {
      throw Exception('Aucun token trouvé. Connectez-vous d\'abord.');
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

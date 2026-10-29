import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/env/env_prod.dart';
import '../models/commercial_order_models.dart';

/// Raised when the orders backend refuses a call for want of a usable token.
///
/// Mirrors the stock service's exception: a refused token and a dead network
/// need different ways out, so the screen has to be able to tell them apart.
class CommercialOrderAuthException implements Exception {
  CommercialOrderAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Raised when the token is accepted but does not carry the role an endpoint
/// wants, which is a different thing again: there is nothing to retry and
/// nothing to sign in to, so the caller falls back instead of reporting it.
class CommercialOrderForbiddenException implements Exception {
  CommercialOrderForbiddenException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Orders, read from `/api/v1/commandes` on the main backend.
///
/// The same host that issues the token the app signs in with, so the session
/// a commercial already has is the one used here. Nothing in this service
/// writes auth state.
class CommercialOrderService {
  static const String _accessTokenKey = 'access_token';

  /// The type the orders screen asks for. Orders and quotes share every
  /// endpoint below and are told apart by this value alone, so leaving it out
  /// would quietly mix quotes into a list of orders.
  static const String typeCommande = 'COMMANDE';

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: EnvProd.baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  /// One page of orders across every client.
  ///
  /// [statut] is applied by the backend, not here: `admin/statut` takes it
  /// alongside the type, so a filtered list costs one request and returns a
  /// true total instead of however many matches a local page happened to
  /// hold. Both endpoints page identically, so the caller does not care which
  /// one answered.
  Future<CommercialOrderPageResponse> getOrders({
    required int page,
    int size = 20,
    String? statut,
  }) async {
    final cleanStatut = statut?.trim() ?? '';

    final query = <String, dynamic>{
      'page': page,
      'size': size,
      'type': typeCommande,
    };

    if (cleanStatut.isNotEmpty) {
      query['statut'] = cleanStatut;
    }

    return _getPage(
      cleanStatut.isEmpty
          ? '/api/v1/commandes/admin/type'
          : '/api/v1/commandes/admin/statut',
      query,
    );
  }

  /// How many orders there are, optionally in one status.
  ///
  /// Asked as a page of one, because `totalElements` is the answer and the
  /// rows are not wanted — which is what makes a dashboard of six counts six
  /// cheap calls rather than six listings.
  Future<int> countOrders({CommercialOrderStatus? status}) async {
    final statut = status == null ? null : CommercialOrder.rawForStatus(status);

    final page = await getOrders(page: 0, size: 1, statut: statut);
    return page.totalElements;
  }

  /// One page of the signed-in account's own orders.
  ///
  /// The fallback for a token without the admin role. This endpoint takes no
  /// type, so quotes come back with the orders and are dropped here — the
  /// totals the backend reports then count both, which is why the caller
  /// prefers [getOrders] whenever it is allowed to use it.
  Future<CommercialOrderPageResponse> getMyOrders({
    required int page,
    int size = 20,
  }) async {
    final response = await _getPage('/api/v1/commandes/mes-commandes', {
      'page': page,
      'size': size,
    });

    return CommercialOrderPageResponse(
      content: response.content
          .where((order) => order.type != CommercialOrderType.devis)
          .toList(),
      totalElements: response.totalElements,
      totalPages: response.totalPages,
      number: response.number,
      size: response.size,
    );
  }

  /// Places an order for a client and returns it as the backend stored it.
  ///
  /// Three things about this payload are the backend's doing rather than a
  /// choice made here, and all three matter:
  ///
  /// * The client is identified by **headers**, not by the body. `X-User-Id`
  ///   is what the order gets attached to, so without it there is nothing to
  ///   send.
  /// * There is no `modeLivraison` field to send. It goes into `commentaire`
  ///   as a sentence, and the delivery address is only accepted alongside
  ///   [CommercialDeliveryMode.livraisonStdDayco].
  /// * Empty optional fields are left out of the body rather than sent as
  ///   empty strings, which is how the web client does it and the only
  ///   behaviour known to be accepted.
  Future<CommercialOrder> createOrder({
    required String clientId,
    String? clientRaisonSociale,
    required List<CommercialOrderDraftLine> lignes,
    required CommercialDeliveryMode modeLivraison,
    String? adresseLivraison,
    String? villeLivraison,
    String? codePostalLivraison,
    String? commentaire,
    String? referenceClient,
    String? dateLivraisonSouhaitee,
    String type = typeCommande,
  }) async {
    final client = clientId.trim();
    if (client.isEmpty) {
      throw Exception('Aucun client sélectionné pour la commande.');
    }

    if (lignes.isEmpty) {
      throw Exception('Une commande doit contenir au moins une ligne.');
    }

    final body = <String, dynamic>{
      'type': type,
      'lignes': lignes.map((line) => line.toJson()).toList(),
    };

    if (modeLivraison.needsAddress) {
      _putIfNotEmpty(body, 'adresseLivraison', adresseLivraison);
      _putIfNotEmpty(body, 'villeLivraison', villeLivraison);
      _putIfNotEmpty(body, 'codePostalLivraison', codePostalLivraison);
    }

    // The mode first, then whatever the commercial wrote, joined the way the
    // web client joins them so both read alike in the back office.
    final comment = [
      'Mode de livraison: ${modeLivraison.commentLabel}',
      commentaire?.trim() ?? '',
    ].where((part) => part.isNotEmpty).join(' | ');

    _putIfNotEmpty(body, 'commentaire', comment);
    _putIfNotEmpty(body, 'referenceClient', referenceClient);
    _putIfNotEmpty(body, 'dateLivraisonSouhaitee', dateLivraisonSouhaitee);

    final raisonSociale = clientRaisonSociale?.trim() ?? '';

    try {
      final options = await _authorizedOptions();
      final headers = Map<String, dynamic>.from(options.headers ?? {});
      headers['X-User-Id'] = client;
      if (raisonSociale.isNotEmpty) {
        headers['X-Client-Raison-Sociale'] = raisonSociale;
      }

      final response = await _dio.post(
        '/api/v1/commandes',
        data: body,
        options: Options(headers: headers),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          'La commande n\'a pas été enregistrée (${response.statusCode}).',
        );
      }

      return CommercialOrder.fromJson(_asMap(response.data));
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Validates an order. Returns it as the backend left it.
  Future<CommercialOrder> validateOrder(String id) {
    return _mutate(
      (options) => _dio.post(
        '/api/v1/commandes/$id/valider',
        data: null,
        options: options,
      ),
      'La validation a échoué',
    );
  }

  /// Cancels an order, with the reason the backend records against it.
  ///
  /// The reason is required here. The web admin substitutes "Annulation
  /// admin" when its field is left blank, which loses the one piece of
  /// information this call exists to capture, so it is asked for instead.
  Future<CommercialOrder> cancelOrder(String id, String motif) {
    final reason = motif.trim();
    if (reason.isEmpty) {
      throw Exception('Un motif est requis pour annuler une commande.');
    }

    return _mutate(
      (options) => _dio.post(
        '/api/v1/commandes/$id/annuler',
        data: {'motif': reason},
        options: options,
      ),
      'L\'annulation a échoué',
    );
  }

  /// Moves an order to another status.
  ///
  /// The status rides in the query string and the body is empty — a PATCH
  /// with no payload, which is how the backend takes it.
  Future<CommercialOrder> updateStatus(
    String id,
    CommercialOrderStatus status,
  ) {
    final raw = CommercialOrder.rawForStatus(status);
    if (raw == null) {
      throw Exception('Statut non reconnu.');
    }

    return _mutate(
      (options) => _dio.patch(
        '/api/v1/commandes/$id/statut',
        data: null,
        queryParameters: {'statut': raw},
        options: options,
      ),
      'Le changement de statut a échoué',
    );
  }

  /// The three actions differ only in the call they make and what to say when
  /// it fails; each returns the order as the backend stored it, which is what
  /// the list is then rebuilt from rather than a guess at the new state.
  Future<CommercialOrder> _mutate(
    Future<Response<dynamic>> Function(Options options) call,
    String failureMessage,
  ) async {
    try {
      final options = await _authorizedOptions();
      final response = await call(options);

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('$failureMessage (${response.statusCode}).');
      }

      return CommercialOrder.fromJson(_asMap(response.data));
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  static void _putIfNotEmpty(
    Map<String, dynamic> body,
    String key,
    String? value,
  ) {
    final clean = value?.trim() ?? '';
    if (clean.isNotEmpty) {
      body[key] = clean;
    }
  }

  /// One order with its lines. The list endpoints already return `lignes`, so
  /// this is only needed when a detail view is opened on an order that came
  /// from somewhere else.
  Future<CommercialOrder> getOrderById(String id) async {
    try {
      final options = await _authorizedOptions();
      final response = await _dio.get(
        '/api/v1/commandes/$id',
        options: options,
      );

      if (response.statusCode != 200) {
        throw Exception('Commande introuvable: $id');
      }

      return CommercialOrder.fromJson(_asMap(response.data));
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<CommercialOrderPageResponse> _getPage(
    String path,
    Map<String, dynamic> query,
  ) async {
    try {
      final options = await _authorizedOptions();
      final response = await _dio.get(
        path,
        queryParameters: query,
        options: options,
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Erreur de chargement des commandes: ${response.statusCode}',
        );
      }

      return CommercialOrderPageResponse.fromJson(_asMap(response.data));
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<Options> _authorizedOptions() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_accessTokenKey)?.trim() ?? '';

    if (token.isEmpty) {
      throw CommercialOrderAuthException(
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

  Exception _mapDioError(DioException e) {
    final status = e.response?.statusCode;
    final message = _extractErrorMessage(e);

    if (status == 401) {
      return CommercialOrderAuthException(message);
    }

    if (status == 403) {
      return CommercialOrderForbiddenException(message);
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

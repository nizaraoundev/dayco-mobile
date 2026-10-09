import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/env/env_prod.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/client_model.dart';
import '../models/login_request.dart';
import '../models/login_response.dart';
import '../models/user_model.dart';

class AuthService {
  static const String entityClient = 'client';
  static const String entitySubClient = 'sub-client';

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: EnvProd.baseUrl,
      connectTimeout: Duration(milliseconds: EnvProd.connectTimeout),
      receiveTimeout: Duration(milliseconds: EnvProd.receiveTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  // Login endpoint
  Future<LoginResponse> login(LoginRequest request) async {
    try {
      final response = await _dio.post(
        '/api/v1/auth/login',
        data: request.toJson(),
      );
      // The response body carries both the access and refresh tokens, so it is
      // never logged; only the status code is.
      AppLogger.debug('Login responded ${response.statusCode}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = _asMap(response.data);
        final loginResponse = LoginResponse.fromJson(responseData);

        // Tokens go to secure storage, under the *main* backend's namespace,
        // so the stock backend's own sign-in can never overwrite them.
        await locator<SessionStore>().write(
          ApiBackend.main,
          AuthTokens(
            accessToken: loginResponse.accessToken,
            refreshToken: loginResponse.refreshToken,
          ),
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', loginResponse.userId);
        await prefs.setString('user_email', loginResponse.email);
        await prefs.setString('user_name', loginResponse.raisonSociale);
        await prefs.setStringList('user_roles', loginResponse.roles);

        return loginResponse;
      } else {
        throw Exception('Login failed: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      // `e.response` echoes the request body on some Dio versions, so only the
      // status code and the backend's own message are logged.
      AppLogger.warn(
        'Login failed (${e.response?.statusCode}): ${_extractErrorMessage(e)}',
      );
      final errorMessage = _extractErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      AppLogger.error('Unexpected error during login', error: e);
      throw Exception('Unexpected error: $e');
    }
  }

  // Get user details
  Future<UserModel> getUserDetails(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // From SessionStore, not preferences: `login` writes the token to secure
      // storage, and the legacy `access_token` preference is deleted once
      // migrated. Reading the preference here made every sign-in fail with
      // "No authentication token found" immediately after a successful login.
      final token = _mainAccessToken;

      if (token == null || token.isEmpty) {
        throw Exception('No authentication token found');
      }

      final response = await _getUserDetailsResponse(userId, token);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = _asMap(response.data);
        final user = UserModel.fromJson(responseData);
        await _persistConnectedUser(prefs, user);
        await prefs.setString('user_profile', jsonEncode(user.toJson()));
        return user;
      } else {
        throw Exception(
          'Failed to get user details: ${response.statusMessage}',
        );
      }
    } on DioException catch (e) {
      final errorMessage = _extractErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  Future<UserModel> getConnectedUserDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    if (userId == null || userId.isEmpty) {
      throw Exception('No connected user id found');
    }

    return getUserDetails(userId);
  }

  // Create B2B client
  Future<Map<String, dynamic>> createClient(ClientModel client) async {
    try {
      final options = await _authorizedOptions();
      final prefs = await SharedPreferences.getInstance();

      final payload = client.toJson();
      final connectedCommercialId = prefs.getString('connected_user_id');
      final connectedCommercialName = prefs.getString('connected_user_name');

      if (!payload.containsKey('commercialId') &&
          connectedCommercialId != null &&
          connectedCommercialId.isNotEmpty) {
        payload['commercialId'] = connectedCommercialId;
      }

      if (!payload.containsKey('commercialName') &&
          connectedCommercialName != null &&
          connectedCommercialName.isNotEmpty) {
        payload['commercialName'] = connectedCommercialName;
      }

      final response = await _dio.post(
        '/api/v1/auth/register/client',
        data: payload,
        options: options,
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to create client: ${response.statusMessage}');
      }

      return _asMap(response.data);
    } on DioException catch (e) {
      final errorMessage = _extractErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  // Create B2B client with custom payload (supports marques/brands)
  Future<Map<String, dynamic>> createClientWithPayload({
    required Map<String, dynamic> payload,
  }) async {
    try {
      final options = await _authorizedOptions();
      final prefs = await SharedPreferences.getInstance();

      final normalizedPayload = Map<String, dynamic>.from(payload);
      final connectedCommercialId = prefs.getString('connected_user_id');
      final connectedCommercialName = prefs.getString('connected_user_name');

      if (!normalizedPayload.containsKey('commercialId') &&
          connectedCommercialId != null &&
          connectedCommercialId.isNotEmpty) {
        normalizedPayload['commercialId'] = connectedCommercialId;
      }

      if (!normalizedPayload.containsKey('commercialName') &&
          connectedCommercialName != null &&
          connectedCommercialName.isNotEmpty) {
        normalizedPayload['commercialName'] = connectedCommercialName;
      }

      final response = await _dio.post(
        '/api/v1/auth/register/client',
        data: normalizedPayload,
        options: options,
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to create client: ${response.statusMessage}');
      }

      return _asMap(response.data);
    } on DioException catch (e) {
      final errorMessage = _extractErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  Future<Map<String, dynamic>> createSubClient({
    required String? parentClientId,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final options = await _authorizedOptions();

      final normalizedPayload = Map<String, dynamic>.from(payload);
      final connectedCommercialId = prefs.getString('connected_user_id');

      // Ensure parentClientIds is an array
      if (!normalizedPayload.containsKey('parentClientIds')) {
        if (parentClientId != null && parentClientId.isNotEmpty) {
          normalizedPayload['parentClientIds'] = [parentClientId];
        } else {
          // Empty array will create PROSPECT type on backend
          normalizedPayload['parentClientIds'] = [];
        }
      }

      if (!normalizedPayload.containsKey('commercialId') &&
          connectedCommercialId != null &&
          connectedCommercialId.isNotEmpty) {
        normalizedPayload['commercialId'] = connectedCommercialId;
      }

      final response = await _dio.post(
        '/api/v1/sub-clients',
        data: normalizedPayload,
        options: options,
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          'Failed to create sub-client: ${response.statusMessage}',
        );
      }

      return _asMap(response.data);
    } on DioException catch (e) {
      final errorMessage = _extractErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  Future<Map<String, dynamic>> getClientById(String clientId) async {
    try {
      final response = await _authorizedGet('/api/v1/clients/$clientId');
      return _asMap(response.data);
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  Future<Map<String, dynamic>> updateClient({
    required String clientId,
    required Map<String, dynamic> payload,
  }) async {
    try {
      Response<dynamic> response;

      try {
        response = await _authorizedPut('/api/v1/clients/$clientId', payload);
      } on DioException catch (e) {
        if (e.response?.statusCode == 405) {
          response = await _authorizedPatch(
            '/api/v1/clients/$clientId',
            payload,
          );
        } else {
          rethrow;
        }
      }

      return _asMap(response.data);
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getMyClients() async {
    try {
      final response = await _authorizedGet('/api/v1/clients/my-clients');
      return _asListOfMaps(response.data);
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getClientsByCommercialId(
    String commercialId,
  ) async {
    try {
      final response = await _authorizedGet(
        '/api/v1/clients/commercial/$commercialId/clients',
      );
      return _asListOfMaps(response.data);
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  Future<Map<String, dynamic>> updateSubClient({
    required String subClientId,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final response = await _authorizedPut(
        '/api/v1/sub-clients/$subClientId',
        payload,
      );
      return _asMap(response.data);
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  Future<void> deleteSubClient(String subClientId) async {
    try {
      await _authorizedDelete('/api/v1/sub-clients/$subClientId');
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  Future<Map<String, dynamic>> getSubClientById(String subClientId) async {
    try {
      final response = await _authorizedGet('/api/v1/sub-clients/$subClientId');
      return _asMap(response.data);
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getSubClientsByParent(
    String parentClientId,
  ) async {
    try {
      final response = await _authorizedGet(
        '/api/v1/sub-clients/parent/$parentClientId',
      );
      return _asListOfMaps(response.data);
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  // Get all sub-clients and prospects for a commercial
  Future<List<Map<String, dynamic>>> getSubClientsByCommercial(
    String commercialId,
  ) async {
    try {
      final response = await _authorizedGet(
        '/api/v1/sub-clients/commercial/$commercialId',
      );
      return _asListOfMaps(response.data);
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  Future<Map<String, dynamic>> uploadEntityImage({
    required String entityType,
    required String entityId,
    required Uint8List imageBytes,
    String fileName = 'image.jpg',
  }) async {
    try {
      final options = await _authorizedOptions();

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(imageBytes, filename: fileName),
      });

      Response<dynamic> response;
      try {
        response = await _dio.post(
          '/api/v1/files/$entityType/$entityId/image',
          data: formData,
          options: options.copyWith(contentType: 'multipart/form-data'),
        );
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          response = await _dio.post(
            '/api/v1/files/upload/$entityType/$entityId/image',
            data: formData,
            options: options.copyWith(contentType: 'multipart/form-data'),
          );
        } else {
          rethrow;
        }
      }

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to upload image: ${response.statusMessage}');
      }

      if (response.data is List) {
        final list = response.data as List;
        if (list.isNotEmpty && list.first is Map) {
          return Map<String, dynamic>.from(list.first as Map);
        }
      }

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }

      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }

      return {'value': response.data?.toString() ?? ''};
    } on DioException catch (e) {
      final errorMessage = _extractErrorMessage(e);
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  String buildImageUrl(String fileName) {
    return '${EnvProd.baseUrl}/images/$fileName';
  }

  String buildClientImageUrl({
    required String clientId,
    required String imagePathOrUrl,
  }) {
    final raw = imagePathOrUrl.trim();
    if (raw.isEmpty) {
      return '';
    }

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }

    final cleaned = raw.startsWith('/') ? raw.substring(1) : raw;

    if (cleaned.startsWith('api/v1/files/download/')) {
      return '${EnvProd.baseUrl}/$cleaned';
    }

    if (cleaned.startsWith('images/')) {
      final withoutImages = cleaned.substring(7); // remove "images/"
      return '${EnvProd.baseUrl}/api/v1/files/download/$withoutImages';
    }

    if (cleaned.startsWith('clients/') || cleaned.startsWith('sub-clients/')) {
      return '${EnvProd.baseUrl}/api/v1/files/download/$cleaned';
    }

    if (cleaned.contains('/')) {
      return '${EnvProd.baseUrl}/api/v1/files/download/clients/$cleaned';
    }

    return '${EnvProd.baseUrl}/api/v1/files/download/clients/$clientId/$cleaned';
  }

  Future<Uint8List?> getProtectedImageBytes(String imageUrlOrPath) async {
    final raw = imageUrlOrPath.trim();
    if (raw.isEmpty) {
      return null;
    }

    final url = _normalizeImageUrl(raw);
    final options = await _authorizedOptions();

    try {
      final response = await _dio.get<List<int>>(
        url,
        options: options.copyWith(
          responseType: ResponseType.bytes,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
      );

      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        return null;
      }

      return Uint8List.fromList(bytes);
    } on DioException {
      return null;
    }
  }

  // Logout
  Future<void> logout() async {
    // Clears every backend's tokens from secure storage, and drops the cached
    // portfolio and marker icons so the next representative to sign in on this
    // device cannot see the previous one's data.
    await locator<SessionStore>().clearAll();
    await resetAfterSignOut();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    await prefs.remove('user_name');
    await prefs.remove('user_roles');
    await prefs.remove('user_profile');
    await prefs.remove('connected_user_id');
    await prefs.remove('connected_user_email');
    await prefs.remove('connected_user_name');
    await prefs.remove('connected_user_nom');
    await prefs.remove('connected_user_prenom');
    await prefs.remove('connected_user_telephone');
    await prefs.remove('connected_user_roles');
    await prefs.remove('connected_user_regions');
    await prefs.remove('connected_user_actif');
    await prefs.remove('connected_user_date_creation');
    await prefs.remove('connected_user_date_modification');
    await prefs.remove('connected_user_derniere_connexion');
  }

  // Check if user is authenticated
  Future<bool> isAuthenticated() async =>
      // Same reason as [getUserDetails]: the legacy preference no longer
      // exists once the token has been migrated to secure storage.
      _mainAccessToken != null;

  Future<bool> hasValidSession() async {
    final token = _mainAccessToken;

    if (token == null || token.isEmpty) {
      return false;
    }

    if (_isTokenExpired(token)) {
      await logout();
      return false;
    }

    return true;
  }

  bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return true;
      }

      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final payloadMap = jsonDecode(payload) as Map<String, dynamic>;
      final exp = payloadMap['exp'];

      if (exp is! int) {
        return true;
      }

      final expiry = DateTime.fromMillisecondsSinceEpoch(
        exp * 1000,
        isUtc: true,
      );
      return DateTime.now().toUtc().isAfter(expiry);
    } catch (_) {
      return true;
    }
  }

  // Get stored token
  Future<String?> getToken() async => _mainAccessToken;

  Future<Response<dynamic>> _getUserDetailsResponse(
    String userId,
    String token,
  ) async {
    final options = Options(headers: {'Authorization': 'Bearer $token'});

    try {
      return await _dio.get('/api/v1/user/$userId', options: options);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return await _dio.get('/api/v1/users/$userId', options: options);
      }
      rethrow;
    }
  }

  Future<void> _persistConnectedUser(
    SharedPreferences prefs,
    UserModel user,
  ) async {
    await prefs.setString('connected_user_id', user.id);
    await prefs.setString('connected_user_email', user.email);
    await prefs.setString('connected_user_name', user.fullName);
    await prefs.setString('connected_user_nom', user.nom);
    await prefs.setString('connected_user_prenom', user.prenom);
    await prefs.setString('connected_user_telephone', user.telephone);
    await prefs.setStringList('connected_user_roles', user.roles);
    await prefs.setStringList('connected_user_regions', user.regions);
    await prefs.setBool('connected_user_actif', user.actif);
    await prefs.setString('connected_user_date_creation', user.dateCreation);
    await prefs.setString(
      'connected_user_date_modification',
      user.dateModification,
    );
    await prefs.setString(
      'connected_user_derniere_connexion',
      user.derniereConnexion,
    );
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw Exception('Invalid response format from server');
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

    if (data is Map && data['data'] is List) {
      final dataList = data['data'] as List;
      return dataList
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    throw Exception('Invalid list response format from server');
  }

  /// The main backend's bearer token.
  ///
  /// Reads [SessionStore], **not** `SharedPreferences`. Tokens moved into
  /// secure storage and the legacy `access_token` key is deleted once migrated,
  /// so the old preference read would find nothing and every authorised call
  /// here — creating a client, updating one, uploading a shopfront photo —
  /// would fail with "No authentication token found".
  String? get _mainAccessToken =>
      locator<SessionStore>().accessToken(ApiBackend.main);

  Future<Options> _authorizedOptions() async {
    final prefs = await SharedPreferences.getInstance();
    final token = _mainAccessToken;
    if (token == null || token.isEmpty) {
      throw Exception('No authentication token found');
    }

    final userEmail =
        (prefs.getString('connected_user_email') ??
                prefs.getString('user_email') ??
                '')
            .trim();

    final headers = <String, dynamic>{'Authorization': 'Bearer $token'};
    if (userEmail.isNotEmpty) {
      headers['X-User-Email'] = userEmail;
    }

    return Options(headers: headers);
  }

  Future<Response<dynamic>> _authorizedGet(String path) async {
    final options = await _authorizedOptions();
    return _dio.get(path, options: options);
  }

  Future<Response<dynamic>> _authorizedPut(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final options = await _authorizedOptions();
    return _dio.put(path, data: payload, options: options);
  }

  Future<Response<dynamic>> _authorizedPatch(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final options = await _authorizedOptions();
    return _dio.patch(path, data: payload, options: options);
  }

  Future<Response<dynamic>> _authorizedDelete(String path) async {
    final options = await _authorizedOptions();
    return _dio.delete(path, options: options);
  }

  String _extractErrorMessage(DioException e) {
    final responseData = e.response?.data;

    if (responseData is Map && responseData['message'] != null) {
      return responseData['message'].toString();
    }

    if (responseData is String && responseData.isNotEmpty) {
      return responseData;
    }

    return e.message ?? 'Network error';
  }

  String _normalizeImageUrl(String raw) {
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }

    final cleaned = raw.startsWith('/') ? raw.substring(1) : raw;

    if (cleaned.startsWith('api/v1/files/download/')) {
      return '/$cleaned';
    }

    if (cleaned.startsWith('images/')) {
      final withoutImages = cleaned.substring(7); // remove "images/"
      return '/api/v1/files/download/$withoutImages';
    }

    if (cleaned.startsWith('clients/') || cleaned.startsWith('sub-clients/')) {
      return '/api/v1/files/download/$cleaned';
    }

    return '/api/v1/files/download/clients/$cleaned';
  }
}

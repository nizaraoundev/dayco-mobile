import 'dart:async';

import '../../../core/config/api_config.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/json_coercion.dart';
import '../../../core/storage/session_store.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/jwt.dart';
import '../../../core/utils/single_flight.dart';
import '../domain/entities/commercial_user.dart';
import '../domain/repositories/auth_repository.dart';
import 'user_profile_store.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required ApiClient apiClient,
    required SessionStore sessionStore,
    required UserProfileStore profileStore,
  }) : _api = apiClient,
       _session = sessionStore,
       _profiles = profileStore;

  final ApiClient _api;
  final SessionStore _session;
  final UserProfileStore _profiles;

  CommercialUser? _currentUser;

  final StreamController<CommercialUser?> _userChanges =
      StreamController<CommercialUser?>.broadcast();

  /// Guards sign-in and profile refresh so a double tap cannot issue two
  /// concurrent login round-trips (audit H-7).
  final Mutex<Result<CommercialUser>> _signInGuard =
      Mutex<Result<CommercialUser>>();
  final Mutex<Result<CommercialUser>> _refreshGuard =
      Mutex<Result<CommercialUser>>();

  @override
  CommercialUser? get currentUser => _currentUser;

  @override
  Stream<CommercialUser?> get userChanges => _userChanges.stream;

  @override
  bool get hasValidSession {
    final token = _session.accessToken(ApiBackend.main);
    return token != null && !Jwt.isExpired(token) && _currentUser != null;
  }

  @override
  Future<CommercialUser?> restoreSession() async {
    await _session.load();

    final token = _session.accessToken(ApiBackend.main);
    if (token == null) return null;

    if (Jwt.isExpired(token)) {
      // Clear eagerly: starting the app with a dead token produced a 401
      // cascade on the first screen instead of a clean sign-in prompt.
      AppLogger.info('Stored session token has expired; signing out');
      await signOut();
      return null;
    }

    final stored = await _profiles.read();
    if (stored == null) {
      // A token with no profile is not a usable session.
      await signOut();
      return null;
    }

    _emit(stored);

    // Refresh in the background so the profile is current without blocking
    // startup. Failure is non-fatal — the cached profile stays in use.
    unawaited(refreshProfile());

    return stored;
  }

  @override
  Future<Result<CommercialUser>> signIn({
    required String codeClient,
    required String password,
  }) async {
    final result = await _signInGuard.runOrSkip(
      () => _performSignIn(codeClient: codeClient, password: password),
    );

    // A second concurrent tap was dropped; report it as cancelled rather than
    // as a failure the user needs to see.
    return result ?? const Result.failure(CancelledFailure());
  }

  Future<Result<CommercialUser>> _performSignIn({
    required String codeClient,
    required String password,
  }) async {
    // Any previous session must go before we authenticate, so a failed sign-in
    // cannot leave the old user's token in place.
    await _session.clear(ApiBackend.main);

    final loginResult = await _api.postObject(
      ApiEndpoints.login,
      body: {'codeClient': codeClient.trim(), 'password': password},
    );

    if (loginResult case FailureResult<Map<String, dynamic>>(:final failure)) {
      return Result.failure(_humaniseSignInFailure(failure));
    }

    final body = loginResult.requireValue;
    final accessToken = JsonCoercion.string(body['accessToken']);
    final userId = JsonCoercion.string(body['userId']);

    if (accessToken.isEmpty) {
      return const Result.failure(
        UnexpectedFailure(message: 'Réponse de connexion invalide'),
      );
    }

    await _session.write(
      ApiBackend.main,
      AuthTokens(
        accessToken: accessToken,
        refreshToken: JsonCoercion.string(body['refreshToken']),
      ),
    );

    // Identity from the login response, used as the base profile so sign-in
    // still succeeds when the profile endpoint is unavailable.
    final base = CommercialUser(
      id: userId,
      email: JsonCoercion.string(body['email']),
      raisonSociale: JsonCoercion.string(body['raisonSociale']),
      codeClient: JsonCoercion.firstString(body, const ['codeClient']),
      userType: JsonCoercion.string(body['userType']),
      roles: JsonCoercion.stringList(body['roles']),
    );

    if (userId.isEmpty) {
      // No id means no profile lookup is possible, but the token is valid.
      await _profiles.write(base);
      _emit(base);
      return Result.success(base);
    }

    final profile = await _fetchProfile(userId);

    final user = profile.fold(
      onSuccess: (fetched) => _merge(base, fetched),
      onFailure: (failure) {
        AppLogger.warn('Profile fetch failed after sign-in', error: failure);
        return base;
      },
    );

    await _profiles.write(user);
    _emit(user);
    return Result.success(user);
  }

  @override
  Future<Result<CommercialUser>> refreshProfile() async {
    final existing = _currentUser;
    if (existing == null || existing.id.isEmpty) {
      return const Result.failure(UnauthorizedFailure());
    }

    final result = await _refreshGuard.runOrSkip(() async {
      final profile = await _fetchProfile(existing.id);

      if (profile case Success<CommercialUser>(:final value)) {
        final merged = _merge(existing, value);
        await _profiles.write(merged);
        _emit(merged);
        return Result.success(merged);
      }

      return profile;
    });

    return result ?? Result.success(existing);
  }

  /// `GET /api/v1/user/{id}`, falling back to the plural path on 404.
  ///
  /// Both paths exist across deployments; the original code expressed this with
  /// a nested try/catch inside the service.
  Future<Result<CommercialUser>> _fetchProfile(String userId) async {
    final result = await _api.withStatusFallback(
      primary: () => _api.getObject(ApiEndpoints.user(userId)),
      fallback: () => _api.getObject(ApiEndpoints.userFallback(userId)),
      onStatus: 404,
    );

    return result.map(
      (json) => CommercialUser(
        id: JsonCoercion.firstString(json, const ['id', 'userId']),
        email: JsonCoercion.string(json['email']),
        nom: JsonCoercion.string(json['nom']),
        prenom: JsonCoercion.string(json['prenom']),
        telephone: JsonCoercion.string(json['telephone']),
        raisonSociale: JsonCoercion.string(json['raisonSociale']),
        codeClient: JsonCoercion.string(json['codeClient']),
        userType: JsonCoercion.string(json['userType']),
        roles: JsonCoercion.stringList(json['roles']),
        regions: JsonCoercion.stringList(json['regions']),
        actif: JsonCoercion.toBool(json['actif'], fallback: true),
        derniereConnexion: JsonCoercion.string(json['derniereConnexion']),
      ),
    );
  }

  /// Overlays the profile response onto the login identity, preferring the
  /// profile's values but never losing a field the profile omits.
  CommercialUser _merge(CommercialUser base, CommercialUser profile) =>
      CommercialUser(
        id: profile.id.isNotEmpty ? profile.id : base.id,
        email: profile.email.isNotEmpty ? profile.email : base.email,
        nom: profile.nom.isNotEmpty ? profile.nom : base.nom,
        prenom: profile.prenom.isNotEmpty ? profile.prenom : base.prenom,
        telephone: profile.telephone.isNotEmpty
            ? profile.telephone
            : base.telephone,
        raisonSociale: profile.raisonSociale.isNotEmpty
            ? profile.raisonSociale
            : base.raisonSociale,
        codeClient: profile.codeClient.isNotEmpty
            ? profile.codeClient
            : base.codeClient,
        userType: profile.userType.isNotEmpty ? profile.userType : base.userType,
        roles: profile.roles.isNotEmpty ? profile.roles : base.roles,
        regions: profile.regions.isNotEmpty ? profile.regions : base.regions,
        actif: profile.actif,
        derniereConnexion: profile.derniereConnexion.isNotEmpty
            ? profile.derniereConnexion
            : base.derniereConnexion,
      );

  /// Turns a transport failure on the login call into something actionable.
  ///
  /// A 401 from `/auth/login` means "wrong credentials", not "session expired",
  /// and must not be reported with the generic expiry message — nor trigger the
  /// global sign-out path.
  Failure _humaniseSignInFailure(Failure failure) => switch (failure) {
    UnauthorizedFailure() => const ValidationFailure(
      message: 'Code client ou mot de passe incorrect',
    ),
    NotFoundFailure() => const ValidationFailure(
      message: 'Code client ou mot de passe incorrect',
    ),
    _ => failure,
  };

  @override
  Future<void> signOut() async {
    // Both backends are cleared: the stock session belongs to the same
    // representative and must not outlive their sign-out.
    await _session.clearAll();
    await _profiles.clear();
    _emit(null);
  }

  void _emit(CommercialUser? user) {
    _currentUser = user;
    if (!_userChanges.isClosed) _userChanges.add(user);
  }

  Future<void> dispose() => _userChanges.close();
}

extension on Result<Map<String, dynamic>> {
  Map<String, dynamic> get requireValue => (this as Success<Map<String, dynamic>>).value;
}

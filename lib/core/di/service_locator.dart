import 'package:get_it/get_it.dart';

import '../../features/auth/data/auth_repository_impl.dart';
import '../../features/auth/data/user_profile_store.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/cartography/presentation/marker_icon_cache.dart';
import '../../features/clients/data/clients_repository_impl.dart';
import '../../features/clients/domain/repositories/clients_repository.dart';
import '../config/api_config.dart';
import '../network/api_client.dart';
import '../network/auth_interceptor.dart';
import '../storage/session_store.dart';
import '../utils/app_logger.dart';

/// The application's composition root.
///
/// Replaces the previous arrangement, where dependencies were created wherever
/// they happened to be needed — `AuthService()` was constructed independently in
/// the splash page, the auth controller and the map controller, giving three
/// `Dio` instances with three connection pools — and where GetX bindings
/// registered controllers with `permanent: true`, so nothing was ever released
/// and a signed-out representative's data outlived their session.
///
/// Everything here is a singleton with an explicit lifetime, and
/// [resetAfterSignOut] defines exactly what is discarded when the session ends.
final GetIt locator = GetIt.instance;

/// Wires the object graph. Must be awaited before `runApp`, because
/// [SessionStore.load] decides whether the app starts signed in.
Future<void> configureDependencies() async {
  if (locator.isRegistered<SessionStore>()) return;

  // ------------------------------------------------------------------ storage
  final sessionStore = SessionStore();
  await sessionStore.load();
  locator.registerSingleton<SessionStore>(sessionStore);

  final profileStore = UserProfileStore();
  locator.registerSingleton<UserProfileStore>(profileStore);

  // ------------------------------------------------------------------ network
  // One client per backend. The interceptor reads the token for *its own*
  // backend, which is what keeps the stock session from overwriting the main
  // one (audit C-1).
  late final AuthRepositoryImpl authRepository;

  ApiClient buildClient(ApiBackend backend) => ApiClient.create(
    backend: backend,
    authInterceptor: AuthInterceptor(
      backend: backend,
      sessionStore: sessionStore,
      onUnauthorized: (rejected) => _handleUnauthorized(rejected),
      // Only the main backend expects the caller's e-mail on writes.
      userEmailProvider: backend == ApiBackend.main
          ? () => authRepository.currentUser?.email
          : null,
    ),
  );

  final mainClient = buildClient(ApiBackend.main);
  final stockClient = buildClient(ApiBackend.stock);

  locator.registerSingleton<ApiClient>(mainClient, instanceName: 'main');
  locator.registerSingleton<ApiClient>(stockClient, instanceName: 'stock');

  // ------------------------------------------------------------- repositories
  authRepository = AuthRepositoryImpl(
    apiClient: mainClient,
    sessionStore: sessionStore,
    profileStore: profileStore,
  );
  locator.registerSingleton<AuthRepository>(authRepository);
  locator.registerSingleton<AuthRepositoryImpl>(authRepository);

  final clientsRepository = ClientsRepositoryImpl(apiClient: mainClient);
  locator.registerSingleton<ClientsRepository>(clientsRepository);
  locator.registerSingleton<ClientsRepositoryImpl>(clientsRepository);

  // -------------------------------------------------------------- presentation
  // Shared across the map's lifetime so pins are rasterised once per icon, not
  // once per marker per refresh (audit H-2).
  locator.registerSingleton<MarkerIconCache>(MarkerIconCache());
}

void _handleUnauthorized(ApiBackend backend) {
  // Only the main backend's rejection ends the session; the stock backend has
  // its own, independent sign-in and losing it must not sign the user out of
  // the application.
  if (backend != ApiBackend.main) return;
  AppLogger.warn('Main session rejected by the backend');
  // The session is cleared, and the app shell reacts via
  // SessionStore.mainSessionChanges rather than navigating from here — routing
  // is not this layer's concern.
  locator<SessionStore>().clear(ApiBackend.main);
}

/// Discards everything tied to the signed-in representative.
///
/// Called on sign-out so the next user cannot see the previous one's portfolio,
/// cached images or marker icons.
Future<void> resetAfterSignOut() async {
  if (locator.isRegistered<ClientsRepository>()) {
    locator<ClientsRepository>().clearCache();
  }
  if (locator.isRegistered<MarkerIconCache>()) {
    locator<MarkerIconCache>().clear();
  }
}

/// Tears the graph down. Used by tests to get a clean slate.
Future<void> resetLocator() async {
  if (locator.isRegistered<ClientsRepositoryImpl>()) {
    await locator<ClientsRepositoryImpl>().dispose();
  }
  if (locator.isRegistered<AuthRepositoryImpl>()) {
    await locator<AuthRepositoryImpl>().dispose();
  }
  if (locator.isRegistered<MarkerIconCache>()) {
    locator<MarkerIconCache>().dispose();
  }
  if (locator.isRegistered<SessionStore>()) {
    await locator<SessionStore>().dispose();
  }
  await locator.reset();
}

import 'package:dayco_mobile/core/config/api_config.dart';
import 'package:dayco_mobile/core/di/service_locator.dart';
import 'package:dayco_mobile/core/storage/session_store.dart';
import 'package:dayco_mobile/features/auth/data/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/in_memory_secure_storage.dart';

/// Guards the seam between the legacy `AuthService` and the new
/// [SessionStore].
///
/// `SessionStore` migrates the old `access_token` preference into secure
/// storage **and deletes it**. `AuthService` is still the code path for
/// creating and updating clients and uploading shopfront photos, so if it kept
/// reading the preference it would find nothing and every one of those
/// operations would fail with "No authentication token found" — while the map
/// still loaded fine, because that goes through the new repository. These
/// tests exist so that asymmetry cannot come back unnoticed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore session;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await locator.reset();

    session = SessionStore(secureStorage: InMemorySecureStorage());
    await session.load();
    locator.registerSingleton<SessionStore>(session);
  });

  tearDown(() async {
    await session.dispose();
    await locator.reset();
  });

  test('AuthService reads the token from SessionStore, not preferences', () async {
    await session.write(
      ApiBackend.main,
      const AuthTokens(accessToken: 'secure-token'),
    );

    expect(await AuthService().getToken(), 'secure-token');
  });

  test('AuthService sees no token when the session is empty', () async {
    expect(await AuthService().getToken(), isNull);
    expect(await AuthService().isAuthenticated(), isFalse);
  });

  test('a token left only in preferences is not used directly', () async {
    // The legacy key alone must not count as a session: it is adopted by
    // SessionStore.load()'s migration, not read ad hoc.
    SharedPreferences.setMockInitialValues({'access_token': 'stale-legacy'});

    final fresh = SessionStore(secureStorage: InMemorySecureStorage());
    locator.unregister<SessionStore>();
    locator.registerSingleton<SessionStore>(fresh);

    // Before load(), nothing is migrated and nothing is visible.
    expect(await AuthService().getToken(), isNull);

    await fresh.load();
    expect(
      await AuthService().getToken(),
      'stale-legacy',
      reason: 'migration should adopt it exactly once',
    );

    await fresh.dispose();
  });

  test('stock tokens are invisible to the main backend path', () async {
    await session.write(
      ApiBackend.stock,
      const AuthTokens(accessToken: 'stock-token'),
    );

    // The regression that caused random logouts: a stock sign-in must never
    // look like a main-backend session.
    expect(await AuthService().getToken(), isNull);
    expect(await AuthService().isAuthenticated(), isFalse);
  });

  test('every token read goes through SessionStore, never preferences', () async {
    // The regression this pins: `login` writes to secure storage, but
    // `getUserDetails` and `isAuthenticated` were still reading the legacy
    // `access_token` preference. Signing in with correct credentials then
    // failed instantly with "No authentication token found".
    //
    // Simulated by putting a token *only* in secure storage, exactly as
    // `login` leaves things, and asserting every read sees it.
    await session.write(
      ApiBackend.main,
      const AuthTokens(accessToken: 'from-secure-storage'),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('access_token'),
      isNull,
      reason: 'login must not write the legacy key any more',
    );

    final service = AuthService();
    expect(await service.getToken(), 'from-secure-storage');
    expect(await service.isAuthenticated(), isTrue);
  });

  test('isAuthenticated is false when only the legacy preference is set', () async {
    // An unmigrated preference is not a session on its own; SessionStore.load()
    // adopts it. This guards against "fixing" the above by reading both.
    SharedPreferences.setMockInitialValues({'access_token': 'legacy-only'});

    expect(await AuthService().isAuthenticated(), isFalse);
  });

  test('hasValidSession rejects a malformed token', () async {
    await session.write(
      ApiBackend.main,
      const AuthTokens(accessToken: 'not-a-jwt'),
    );

    // An unreadable token is treated as expired rather than optimistically sent.
    expect(await AuthService().hasValidSession(), isFalse);
  });
}

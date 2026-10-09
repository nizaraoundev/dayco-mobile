import 'package:dayco_mobile/core/config/api_config.dart';
import 'package:dayco_mobile/core/storage/session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/in_memory_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemorySecureStorage storage;
  late SessionStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = InMemorySecureStorage();
    store = SessionStore(secureStorage: storage);
  });

  group('backend isolation (audit C-1)', () {
    test('writing the stock token leaves the main token untouched', () async {
      await store.load();

      await store.write(
        ApiBackend.main,
        const AuthTokens(accessToken: 'main-token', refreshToken: 'main-refresh'),
      );
      await store.write(
        ApiBackend.stock,
        const AuthTokens(accessToken: 'stock-token'),
      );

      // This is the exact regression that logged representatives out: the stock
      // screen's sign-in used to overwrite `access_token` for the main backend.
      expect(store.accessToken(ApiBackend.main), 'main-token');
      expect(store.accessToken(ApiBackend.stock), 'stock-token');
      expect(store.refreshToken(ApiBackend.main), 'main-refresh');
    });

    test('clearing one backend leaves the other signed in', () async {
      await store.load();
      await store.write(
        ApiBackend.main,
        const AuthTokens(accessToken: 'main-token'),
      );
      await store.write(
        ApiBackend.stock,
        const AuthTokens(accessToken: 'stock-token'),
      );

      await store.clear(ApiBackend.stock);

      expect(store.hasSession(ApiBackend.main), isTrue);
      expect(store.hasSession(ApiBackend.stock), isFalse);
    });

    test('clearAll signs out of every backend', () async {
      await store.load();
      await store.write(ApiBackend.main, const AuthTokens(accessToken: 'a'));
      await store.write(ApiBackend.stock, const AuthTokens(accessToken: 'b'));

      await store.clearAll();

      expect(store.hasSession(ApiBackend.main), isFalse);
      expect(store.hasSession(ApiBackend.stock), isFalse);
    });

    test('the two backends use distinct storage keys', () async {
      await store.load();
      await store.write(ApiBackend.main, const AuthTokens(accessToken: 'a'));
      await store.write(ApiBackend.stock, const AuthTokens(accessToken: 'b'));

      final keys = storage.snapshot.keys.toList();
      expect(keys, contains('auth.main.access_token'));
      expect(keys, contains('auth.stock.access_token'));
    });
  });

  group('persistence', () {
    test('tokens survive a restart', () async {
      await store.load();
      await store.write(
        ApiBackend.main,
        const AuthTokens(accessToken: 'persisted', refreshToken: 'r'),
      );

      final reopened = SessionStore(secureStorage: storage);
      await reopened.load();

      expect(reopened.accessToken(ApiBackend.main), 'persisted');
      expect(reopened.refreshToken(ApiBackend.main), 'r');
    });

    test('an empty token reads back as no session', () async {
      await store.load();
      await store.write(ApiBackend.main, const AuthTokens(accessToken: ''));

      expect(store.accessToken(ApiBackend.main), isNull);
      expect(store.hasSession(ApiBackend.main), isFalse);
    });

    test('writing without a refresh token clears any previous one', () async {
      await store.load();
      await store.write(
        ApiBackend.main,
        const AuthTokens(accessToken: 'a', refreshToken: 'old'),
      );
      await store.write(ApiBackend.main, const AuthTokens(accessToken: 'b'));

      final reopened = SessionStore(secureStorage: storage);
      await reopened.load();
      expect(reopened.refreshToken(ApiBackend.main), isNull);
    });
  });

  group('legacy migration', () {
    test('adopts a token written by the previous build', () async {
      SharedPreferences.setMockInitialValues({
        'access_token': 'legacy-token',
        'refresh_token': 'legacy-refresh',
      });

      await store.load();

      expect(store.accessToken(ApiBackend.main), 'legacy-token');
      expect(store.refreshToken(ApiBackend.main), 'legacy-refresh');
    });

    test('removes the legacy keys once migrated', () async {
      SharedPreferences.setMockInitialValues({'access_token': 'legacy-token'});

      await store.load();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('access_token'), isNull);
    });

    test('never overwrites a token the current build already wrote', () async {
      SharedPreferences.setMockInitialValues({'access_token': 'legacy-token'});
      final preloaded = InMemorySecureStorage({
        'auth.main.access_token': 'current-token',
      });

      final migrating = SessionStore(secureStorage: preloaded);
      await migrating.load();

      expect(migrating.accessToken(ApiBackend.main), 'current-token');
    });
  });

  group('resilience', () {
    test('a failing keystore does not prevent startup', () async {
      storage.throwOnAccess = true;

      // The user is treated as signed out rather than the app failing to boot.
      await expectLater(store.load(), completes);
      expect(store.hasSession(ApiBackend.main), isFalse);
    });

    test('load is idempotent', () async {
      await store.load();
      await store.write(ApiBackend.main, const AuthTokens(accessToken: 'a'));

      await store.load();

      expect(store.accessToken(ApiBackend.main), 'a');
    });
  });

  group('session change notifications', () {
    test('emits on main sign-in and sign-out only', () async {
      await store.load();
      final events = <bool>[];
      final subscription = store.mainSessionChanges.listen(events.add);

      await store.write(ApiBackend.main, const AuthTokens(accessToken: 'a'));
      await store.write(ApiBackend.stock, const AuthTokens(accessToken: 'b'));
      await store.clear(ApiBackend.main);

      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(events, [true, false]);
    });
  });

  tearDown(() async {
    await store.dispose();
  });
}

import 'dart:typed_data';

import 'package:dayco_mobile/core/config/api_config.dart';
import 'package:dayco_mobile/core/error/failure.dart';
import 'package:dayco_mobile/core/network/api_client.dart';
import 'package:dayco_mobile/core/network/auth_interceptor.dart';
import 'package:dayco_mobile/core/storage/session_store.dart';
import 'package:dayco_mobile/features/clients/data/clients_repository_impl.dart';
import 'package:dayco_mobile/features/clients/domain/entities/client.dart';
import 'package:dayco_mobile/features/clients/domain/entities/geo_position.dart';
import 'package:dayco_mobile/features/clients/domain/repositories/clients_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_http.dart';
import '../../support/in_memory_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const commercialId = 'COM-1';
  final clientsPath = ApiEndpoints.clientsByCommercial(commercialId);
  final subClientsPath = ApiEndpoints.subClientsByCommercial(commercialId);

  late FakeHttpAdapter http;
  late SessionStore session;
  late ClientsRepositoryImpl repository;

  Future<void> build({Duration? freshness}) async {
    SharedPreferences.setMockInitialValues({});
    http = FakeHttpAdapter();
    session = SessionStore(secureStorage: InMemorySecureStorage());
    await session.load();
    await session.write(
      ApiBackend.main,
      const AuthTokens(accessToken: 'main-token'),
    );

    final dio = Dio()..httpClientAdapter = http;
    final api = ApiClient.create(
      backend: ApiBackend.main,
      authInterceptor: AuthInterceptor(
        backend: ApiBackend.main,
        sessionStore: session,
        onUnauthorized: (_) {},
      ),
      dio: dio,
    );

    repository = ClientsRepositoryImpl(
      apiClient: api,
      freshnessWindow: freshness ?? const Duration(minutes: 2),
    );
  }

  setUp(() => build());

  tearDown(() async {
    await repository.dispose();
    await session.dispose();
  });

  group('loadPortfolio', () {
    test('merges B2B clients with sub-clients and prospects', () async {
      http.on('GET', clientsPath, body: [
        {'id': 'c1', 'raisonSociale': 'DAYCO Tunis', 'latitude': 36.8, 'longitude': 10.1},
      ]);
      http.on('GET', subClientsPath, body: [
        {'id': 's1', 'nomAgence': 'Agence Sfax', 'parentClientIds': ['c1']},
        {'id': 'p1', 'nom': 'Ben', 'prenom': 'Ali', 'parentClientIds': <String>[]},
      ]);

      final result = await repository.loadPortfolio(commercialId: commercialId);
      final clients = result.valueOrNull!;

      expect(clients, hasLength(3));
      expect(
        clients.firstWhere((c) => c.id == 'c1').kind,
        ClientKind.b2b,
      );
      expect(
        clients.firstWhere((c) => c.id == 's1').kind,
        ClientKind.subClient,
      );
      // No parent means the backend treats it as a prospect.
      expect(
        clients.firstWhere((c) => c.id == 'p1').kind,
        ClientKind.prospect,
      );
    });

    test('issues both requests concurrently, not sequentially', () async {
      http.on('GET', clientsPath, body: []);
      http.on('GET', subClientsPath, body: []);

      await repository.loadPortfolio(commercialId: commercialId);

      expect(http.callsTo('GET', clientsPath), 1);
      expect(http.callsTo('GET', subClientsPath), 1);
    });

    test('de-duplicates a client returned by both endpoints', () async {
      http.on('GET', clientsPath, body: [
        {'id': 'same', 'raisonSociale': 'From clients'},
      ]);
      http.on('GET', subClientsPath, body: [
        {'id': 'same', 'nomAgence': 'From sub-clients'},
      ]);

      final result = await repository.loadPortfolio(commercialId: commercialId);

      // Duplicate markers on the map came from exactly this overlap.
      expect(result.valueOrNull, hasLength(1));
    });

    test('surfaces the half that loaded when the other fails', () async {
      http.on('GET', clientsPath, body: [
        {'id': 'c1', 'raisonSociale': 'DAYCO'},
      ]);
      http.on('GET', subClientsPath, statusCode: 500, body: {'message': 'boom'});

      final result = await repository.loadPortfolio(commercialId: commercialId);

      // A weak connection must not cost the representative their whole screen.
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, hasLength(1));
    });

    test('fails only when both halves fail', () async {
      http.on('GET', clientsPath, statusCode: 500, body: {'message': 'boom'});
      http.on('GET', subClientsPath, statusCode: 500, body: {'message': 'boom'});

      final result = await repository.loadPortfolio(commercialId: commercialId);

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<ServerFailure>());
    });

    test('collapses concurrent loads into a single pair of requests', () async {
      http.on('GET', clientsPath, body: []);
      http.on('GET', subClientsPath, body: []);

      await Future.wait([
        repository.loadPortfolio(commercialId: commercialId),
        repository.loadPortfolio(commercialId: commercialId),
        repository.loadPortfolio(commercialId: commercialId),
      ]);

      expect(http.callsTo('GET', clientsPath), 1);
      expect(http.callsTo('GET', subClientsPath), 1);
    });

    test('serves a fresh cache without touching the network', () async {
      http.on('GET', clientsPath, body: []);
      http.on('GET', subClientsPath, body: []);

      await repository.loadPortfolio(commercialId: commercialId);
      await repository.loadPortfolio(commercialId: commercialId);

      expect(http.callsTo('GET', clientsPath), 1);
    });

    test('forceRefresh bypasses the cache', () async {
      http.on('GET', clientsPath, body: []);
      http.on('GET', subClientsPath, body: []);

      await repository.loadPortfolio(commercialId: commercialId);
      await repository.loadPortfolio(
        commercialId: commercialId,
        forceRefresh: true,
      );

      expect(http.callsTo('GET', clientsPath), 2);
    });

    test('re-fetches once the freshness window has elapsed', () async {
      await build(freshness: Duration.zero);
      http.on('GET', clientsPath, body: []);
      http.on('GET', subClientsPath, body: []);

      await repository.loadPortfolio(commercialId: commercialId);
      await repository.loadPortfolio(commercialId: commercialId);

      expect(http.callsTo('GET', clientsPath), 2);
    });

    test('falls back to /my-clients when no commercial id is known', () async {
      http.on('GET', ApiEndpoints.myClients, body: []);

      final result = await repository.loadPortfolio(commercialId: '');

      expect(result.isSuccess, isTrue);
      expect(http.callsTo('GET', ApiEndpoints.myClients), 1);
    });

    test('attaches the main backend bearer token', () async {
      http.on('GET', clientsPath, body: []);
      http.on('GET', subClientsPath, body: []);

      await repository.loadPortfolio(commercialId: commercialId);

      expect(http.requests.first.authorization, 'Bearer main-token');
    });
  });

  group('portfolioChanges', () {
    test('notifies every listener on load, so screens cannot disagree', () async {
      http.on('GET', clientsPath, body: [
        {'id': 'c1', 'raisonSociale': 'DAYCO'},
      ]);
      http.on('GET', subClientsPath, body: []);

      final seen = <List<Client>>[];
      final subscription = repository.portfolioChanges.listen(seen.add);

      await repository.loadPortfolio(commercialId: commercialId);
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(seen, hasLength(1));
      expect(seen.single.single.id, 'c1');
    });

    test('notifies after a creation without a full reload', () async {
      http.on('GET', clientsPath, body: []);
      http.on('GET', subClientsPath, body: []);
      http.on('POST', ApiEndpoints.subClients, body: {
        'id': 'new-1',
        'nomAgence': 'Nouvelle agence',
        'parentClientIds': <String>[],
      });

      await repository.loadPortfolio(commercialId: commercialId);

      final seen = <List<Client>>[];
      final subscription = repository.portfolioChanges.listen(seen.add);

      await repository.createClient(
        const ClientDraft(
          kind: ClientKind.prospect,
          nomAgence: 'Nouvelle agence',
          position: GeoPosition(latitude: 36.8, longitude: 10.1),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      // The map pin and the clients list both come from this one event, which
      // is why creating on the map now updates the list immediately.
      expect(seen.last.map((c) => c.id), contains('new-1'));
      expect(repository.cachedPortfolio!.map((c) => c.id), contains('new-1'));
    });
  });

  group('createClient', () {
    test('sends an empty parentClientIds to create a prospect', () async {
      http.on('POST', ApiEndpoints.subClients, body: {'id': 'p1'});

      await repository.createClient(
        const ClientDraft(
          kind: ClientKind.prospect,
          nom: 'Ben',
          prenom: 'Ali',
          position: GeoPosition(latitude: 36.8, longitude: 10.1),
        ),
      );

      final body = http.requests.last.jsonBody;
      // An empty array is how the backend is told to assign type PROSPECT;
      // omitting the key would leave the type unchanged instead.
      expect(body['parentClientIds'], isEmpty);
      expect(body['latitude'], 36.8);
    });

    test('sends B2B coordinates as strings, as the backend expects', () async {
      http.on('POST', ApiEndpoints.registerClient, body: {'userId': 'c9'});

      await repository.createClient(
        const ClientDraft(
          kind: ClientKind.b2b,
          raisonSociale: 'DAYCO SARL',
          position: GeoPosition(latitude: 36.8, longitude: 10.1),
        ),
      );

      final body = http.requests.last.jsonBody;
      expect(body['latitude'], isA<String>());
      expect(body['raisonSociale'], 'DAYCO SARL');
    });

    test('reads the new id from userId on the B2B registration response', () async {
      http.on('POST', ApiEndpoints.registerClient, body: {'userId': 'c9'});

      final result = await repository.createClient(
        const ClientDraft(
          kind: ClientKind.b2b,
          raisonSociale: 'DAYCO',
          position: GeoPosition(latitude: 36.8, longitude: 10.1),
        ),
      );

      expect(result.valueOrNull!.id, 'c9');
    });

    test('drops a double submit instead of creating two clients', () async {
      http.on('POST', ApiEndpoints.subClients, body: {'id': 'p1'});

      const draft = ClientDraft(
        kind: ClientKind.prospect,
        nomAgence: 'Agence',
        position: GeoPosition(latitude: 36.8, longitude: 10.1),
      );

      final results = await Future.wait([
        repository.createClient(draft),
        repository.createClient(draft),
      ]);

      expect(http.callsTo('POST', ApiEndpoints.subClients), 1);
      expect(
        results.where((r) => r.failureOrNull is CancelledFailure),
        hasLength(1),
      );
    });

    test('rejects a draft with no position rather than calling the backend', () async {
      final result = await repository.createClient(
        const ClientDraft(kind: ClientKind.prospect, nom: 'Ben'),
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(http.requests, isEmpty);
    });

    test('keeps the client when only the photo upload fails', () async {
      http.on('POST', ApiEndpoints.subClients, body: {'id': 'p1'});
      http.on(
        'POST',
        ApiEndpoints.entityImage(ApiEntityType.subClient, 'p1'),
        statusCode: 500,
        body: {'message': 'storage down'},
      );
      http.on(
        'POST',
        ApiEndpoints.entityImageFallback(ApiEntityType.subClient, 'p1'),
        statusCode: 500,
        body: {'message': 'storage down'},
      );

      final result = await repository.createClient(
        ClientDraft(
          kind: ClientKind.prospect,
          nomAgence: 'Agence',
          position: const GeoPosition(latitude: 36.8, longitude: 10.1),
          imageBytes: Uint8List.fromList([1, 2, 3]),
        ),
      );

      expect(result.isSuccess, isTrue, reason: 'the client was created');
    });
  });

  group('updateClientPosition', () {
    test('echoes the current parents so a sub-client stays a sub-client', () async {
      http.on('GET', clientsPath, body: []);
      http.on('GET', subClientsPath, body: [
        {'id': 's1', 'nomAgence': 'Agence', 'parentClientIds': ['c1']},
      ]);
      http.on('PUT', ApiEndpoints.subClient('s1'), body: {'id': 's1'});

      await repository.loadPortfolio(commercialId: commercialId);
      await repository.updateClientPosition(
        id: 's1',
        kind: ClientKind.subClient,
        position: const GeoPosition(latitude: 35.0, longitude: 9.0),
      );

      final body = http.requests.last.jsonBody;
      // Omitting parentClientIds here would silently demote the sub-client to
      // a prospect, because the backend derives the type from parentage.
      expect(body['parentClientIds'], ['c1']);
      expect(body['latitude'], 35.0);
    });

    test('sends only coordinates, never unopened form fields', () async {
      http.on('PUT', ApiEndpoints.client('c1'), body: {'id': 'c1'});

      await repository.updateClientPosition(
        id: 'c1',
        kind: ClientKind.b2b,
        position: const GeoPosition(latitude: 35.0, longitude: 9.0),
      );

      expect(http.requests.last.jsonBody.keys, {'latitude', 'longitude'});
    });

    test('falls back to PATCH when the deployment answers 405 to PUT', () async {
      http.on('PUT', ApiEndpoints.client('c1'), statusCode: 405, body: {});
      http.on('PATCH', ApiEndpoints.client('c1'), body: {'id': 'c1'});

      final result = await repository.updateClientPosition(
        id: 'c1',
        kind: ClientKind.b2b,
        position: const GeoPosition(latitude: 35.0, longitude: 9.0),
      );

      expect(result.isSuccess, isTrue);
      expect(http.callsTo('PATCH', ApiEndpoints.client('c1')), 1);
    });

    test('updates the cache so the pin moves without a reload', () async {
      http.on('GET', clientsPath, body: [
        {'id': 'c1', 'raisonSociale': 'DAYCO', 'latitude': 36.8, 'longitude': 10.1},
      ]);
      http.on('GET', subClientsPath, body: []);
      http.on('PUT', ApiEndpoints.client('c1'), body: {'id': 'c1'});

      await repository.loadPortfolio(commercialId: commercialId);
      await repository.updateClientPosition(
        id: 'c1',
        kind: ClientKind.b2b,
        position: const GeoPosition(latitude: 35.0, longitude: 9.0),
      );

      final cached = repository.cachedPortfolio!.single;
      expect(cached.position!.latitude, 35.0);
      expect(cached.raisonSociale, 'DAYCO', reason: 'other fields preserved');
    });
  });

  group('updateClient payload contract', () {
    test('B2B update sends coordinates as strings', () async {
      http.on('PUT', ApiEndpoints.client('c1'), body: {'id': 'c1'});

      await repository.updateClient(
        const ClientDraft(
          kind: ClientKind.b2b,
          id: 'c1',
          raisonSociale: 'DAYCO',
          position: GeoPosition(latitude: 36.8, longitude: 10.1),
        ),
      );

      final body = http.requests.last.jsonBody;
      // Matches the original B2B create and update payloads. The sub-client
      // endpoints take numbers; this asymmetry is the backend's.
      expect(body['latitude'], isA<String>());
      expect(body['longitude'], isA<String>());
    });

    test('sub-client update sends coordinates as numbers', () async {
      http.on('PUT', ApiEndpoints.subClient('s1'), body: {'id': 's1'});

      await repository.updateClient(
        const ClientDraft(
          kind: ClientKind.subClient,
          id: 's1',
          nomAgence: 'Agence',
          parentClientIds: ['c1'],
          position: GeoPosition(latitude: 36.8, longitude: 10.1),
        ),
      );

      final body = http.requests.last.jsonBody;
      expect(body['latitude'], isA<num>());
      expect(body['longitude'], isA<num>());
    });

    test('omits B2B fields left empty, so a locked field is never sent', () async {
      http.on('PUT', ApiEndpoints.client('c1'), body: {'id': 'c1'});

      // The commercial field-edit rule is expressed by leaving a field empty:
      // a representative may fill a blank field but not overwrite a set one.
      await repository.updateClient(
        const ClientDraft(
          kind: ClientKind.b2b,
          id: 'c1',
          telephone: '20123456',
        ),
      );

      final body = http.requests.last.jsonBody;
      expect(body.keys, ['telephone']);
      expect(body.containsKey('raisonSociale'), isFalse);
    });

    test('an empty B2B update is rejected without a round-trip', () async {
      final result = await repository.updateClient(
        const ClientDraft(kind: ClientKind.b2b, id: 'c1'),
      );

      // Sending an empty body would be a no-op the backend reports as success.
      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(http.requests, isEmpty);
    });

    test('clearing every parent converts a sub-client to a prospect', () async {
      http.on('PUT', ApiEndpoints.subClient('s1'), body: {'id': 's1'});

      await repository.updateClient(
        const ClientDraft(
          kind: ClientKind.prospect,
          id: 's1',
          nomAgence: 'Agence',
          parentClientIds: [],
        ),
      );

      // The empty array is the instruction; omitting the key would leave the
      // type unchanged instead.
      expect(http.requests.last.jsonBody['parentClientIds'], isEmpty);
    });

    test('drops a double submit of the same update', () async {
      http.on('PUT', ApiEndpoints.client('c1'), body: {'id': 'c1'});

      const draft = ClientDraft(
        kind: ClientKind.b2b,
        id: 'c1',
        raisonSociale: 'DAYCO',
      );

      final results = await Future.wait([
        repository.updateClient(draft),
        repository.updateClient(draft),
      ]);

      expect(http.callsTo('PUT', ApiEndpoints.client('c1')), 1);
      expect(
        results.where((r) => r.failureOrNull is CancelledFailure),
        hasLength(1),
      );
    });
  });

  group('deleteSubClient', () {
    test('removes the client from the cache on success', () async {
      http.on('GET', clientsPath, body: []);
      http.on('GET', subClientsPath, body: [
        {'id': 's1', 'nomAgence': 'Agence'},
      ]);
      http.on('DELETE', ApiEndpoints.subClient('s1'), statusCode: 204);

      await repository.loadPortfolio(commercialId: commercialId);
      final result = await repository.deleteSubClient('s1');

      expect(result.isSuccess, isTrue);
      expect(repository.cachedPortfolio, isEmpty);
    });

    test('leaves the cache alone when the delete fails', () async {
      http.on('GET', clientsPath, body: []);
      http.on('GET', subClientsPath, body: [
        {'id': 's1', 'nomAgence': 'Agence'},
      ]);
      http.on('DELETE', ApiEndpoints.subClient('s1'), statusCode: 500, body: {});

      await repository.loadPortfolio(commercialId: commercialId);
      await repository.deleteSubClient('s1');

      expect(repository.cachedPortfolio, hasLength(1));
    });
  });

  group('image handling', () {
    test('memoises a downloaded image', () async {
      http.on(
        'GET',
        '${ApiEndpoints.fileDownloadPrefix}/clients/c1/photo.jpg',
        bytes: [1, 2, 3],
      );

      await repository.fetchImageBytes('clients/c1/photo.jpg');
      await repository.fetchImageBytes('clients/c1/photo.jpg');

      expect(
        http.callsTo('GET', '${ApiEndpoints.fileDownloadPrefix}/clients/c1/photo.jpg'),
        1,
      );
    });

    test('resolves the backend\'s several file-reference shapes', () {
      expect(
        ClientsRepositoryImpl.resolveImagePath('https://cdn/x.jpg'),
        'https://cdn/x.jpg',
      );
      expect(
        ClientsRepositoryImpl.resolveImagePath('images/c1/x.jpg'),
        '/api/v1/files/download/c1/x.jpg',
      );
      expect(
        ClientsRepositoryImpl.resolveImagePath('clients/c1/x.jpg'),
        '/api/v1/files/download/clients/c1/x.jpg',
      );
      expect(
        ClientsRepositoryImpl.resolveImagePath('sub-clients/s1/x.jpg'),
        '/api/v1/files/download/sub-clients/s1/x.jpg',
      );
      expect(
        ClientsRepositoryImpl.resolveImagePath('x.jpg'),
        '/api/v1/files/download/clients/x.jpg',
      );
      expect(
        ClientsRepositoryImpl.resolveImagePath('/api/v1/files/download/a.jpg'),
        '/api/v1/files/download/a.jpg',
      );
    });
  });

  group('clearCache', () {
    test('drops the portfolio so the next user sees nothing stale', () async {
      http.on('GET', clientsPath, body: [
        {'id': 'c1', 'raisonSociale': 'DAYCO'},
      ]);
      http.on('GET', subClientsPath, body: []);

      await repository.loadPortfolio(commercialId: commercialId);
      expect(repository.cachedPortfolio, isNotEmpty);

      repository.clearCache();

      expect(repository.cachedPortfolio, isNull);
    });

    test('a load after clearing hits the network again', () async {
      http.on('GET', clientsPath, body: []);
      http.on('GET', subClientsPath, body: []);

      await repository.loadPortfolio(commercialId: commercialId);
      repository.clearCache();
      await repository.loadPortfolio(commercialId: commercialId);

      expect(http.callsTo('GET', clientsPath), 2);
    });
  });
}

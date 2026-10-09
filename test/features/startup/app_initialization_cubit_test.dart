import 'dart:async';
import 'dart:typed_data';

import 'package:dayco_mobile/core/error/failure.dart';
import 'package:dayco_mobile/core/error/result.dart';
import 'package:dayco_mobile/core/services/location_service.dart';
import 'package:dayco_mobile/features/auth/domain/entities/commercial_user.dart';
import 'package:dayco_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:dayco_mobile/features/cartography/presentation/marker_icon_cache.dart';
import 'package:dayco_mobile/features/clients/domain/entities/client.dart';
import 'package:dayco_mobile/features/clients/domain/entities/geo_position.dart';
import 'package:dayco_mobile/features/clients/domain/repositories/clients_repository.dart';
import 'package:dayco_mobile/features/startup/presentation/cubit/app_initialization_cubit.dart';
import 'package:dayco_mobile/features/startup/presentation/cubit/app_initialization_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeAuthRepository auth;
  late _FakeClientsRepository clients;
  late _FakeLocationService location;
  late _FakeMarkerIconCache icons;

  setUp(() {
    auth = _FakeAuthRepository(
      user: const CommercialUser(id: 'COM-1', roles: ['COMMERCIAL']),
    );
    clients = _FakeClientsRepository();
    location = _FakeLocationService();
    icons = _FakeMarkerIconCache();
  });

  AppInitializationCubit build() => AppInitializationCubit(
    authRepository: auth,
    clientsRepository: clients,
    locationService: location,
    markerIconCache: icons,
  );

  group('happy path', () {
    test('reaches ready with every step succeeded', () async {
      final cubit = build();
      addTearDown(cubit.close);

      await cubit.start();

      expect(cubit.state.phase, InitializationPhase.ready);
      for (final step in InitializationStep.values) {
        expect(
          cubit.state.statusOf(step),
          StepStatus.succeeded,
          reason: '${step.name} should have succeeded',
        );
      }
      expect(cubit.state.message, 'Prêt');
      expect(cubit.state.progress, 1.0);
    });

    test('loads the portfolio with the signed-in commercial id', () async {
      final cubit = build();
      addTearDown(cubit.close);

      await cubit.start();

      expect(clients.requestedCommercialIds, ['COM-1']);
    });

    test('does not force a refresh, so a warm cache costs nothing', () async {
      final cubit = build();
      addTearDown(cubit.close);

      await cubit.start();

      expect(clients.forceRefreshFlags, [false]);
    });

    test('starts the independent steps concurrently', () async {
      // Portfolio, location and icons are gated on one another only through
      // this latch: if the cubit ran them sequentially, the first would block
      // forever and the others would never be entered.
      final gate = Completer<void>();
      clients.gate = gate.future;
      location.gate = gate.future;
      icons.gate = gate.future;

      final cubit = build();
      addTearDown(cubit.close);

      final run = cubit.start();
      await Future<void>.delayed(Duration.zero);

      expect(
        cubit.state.runningSteps.toSet(),
        {
          InitializationStep.portfolio,
          InitializationStep.location,
          InitializationStep.mapAssets,
        },
      );

      gate.complete();
      await run;
      expect(cubit.state.isReady, isTrue);
    });
  });

  group('optional step failure', () {
    test('a refused location still reaches the map', () async {
      location.result = const Result.failure(
        PermissionFailure(message: 'refusée', isPermanentlyDenied: true),
      );

      final cubit = build();
      addTearDown(cubit.close);

      await cubit.start();

      // Not being able to locate the representative must not lock them out.
      expect(cubit.state.phase, InitializationPhase.ready);
      expect(
        cubit.state.statusOf(InitializationStep.location),
        StepStatus.failed,
      );
    });

    test('a failing icon prewarm still reaches the map', () async {
      icons.shouldThrow = true;

      final cubit = build();
      addTearDown(cubit.close);

      await cubit.start();

      expect(cubit.state.phase, InitializationPhase.ready);
    });
  });

  group('critical step failure', () {
    test('a failed portfolio stops at the error state', () async {
      clients.result = const Result.failure(
        NetworkFailure(message: 'Connexion indisponible'),
      );

      final cubit = build();
      addTearDown(cubit.close);

      await cubit.start();

      expect(cubit.state.phase, InitializationPhase.failed);
      expect(cubit.state.failedStep, InitializationStep.portfolio);
      expect(cubit.state.message, 'Connexion indisponible');
    });

    test('offers to continue, because the map works without the portfolio', () async {
      clients.result = const Result.failure(NetworkFailure());

      final cubit = build();
      addTearDown(cubit.close);
      await cubit.start();

      expect(cubit.state.canContinueDegraded, isTrue);

      cubit.continueDegraded();
      expect(cubit.state.phase, InitializationPhase.ready);
      expect(cubit.state.failure, isNull);
    });

    test('retry re-runs and can succeed', () async {
      clients.result = const Result.failure(NetworkFailure());

      final cubit = build();
      addTearDown(cubit.close);
      await cubit.start();
      expect(cubit.state.hasFailed, isTrue);

      clients.result = const Result.success(<Client>[]);
      await cubit.retry();

      expect(cubit.state.phase, InitializationPhase.ready);
    });

    test('an unexpected throw is contained, never left running', () async {
      clients.shouldThrow = true;

      final cubit = build();
      addTearDown(cubit.close);

      await cubit.start();

      // The decisive property: the screen settles instead of spinning forever.
      expect(cubit.state.phase, InitializationPhase.failed);
      expect(cubit.state.isRunning, isFalse);
    });
  });

  group('session handling', () {
    test('no session reports that re-authentication is required', () async {
      auth = _FakeAuthRepository(user: null);

      final cubit = build();
      addTearDown(cubit.close);

      await cubit.start();

      expect(cubit.state.phase, InitializationPhase.failed);
      expect(cubit.state.requiresReauthentication, isTrue);
      // Retrying would be pointless, so continuing is not offered either.
      expect(cubit.state.canContinueDegraded, isFalse);
    });

    test('restores a stored session when none is in memory', () async {
      auth = _FakeAuthRepository(
        user: null,
        restorable: const CommercialUser(id: 'COM-9'),
      );

      final cubit = build();
      addTearDown(cubit.close);

      await cubit.start();

      expect(cubit.state.isReady, isTrue);
      expect(clients.requestedCommercialIds, ['COM-9']);
    });

    test('does not re-fetch the profile when one is already loaded', () async {
      final cubit = build();
      addTearDown(cubit.close);

      await cubit.start();

      expect(auth.restoreCalls, 0, reason: 'sign-in already resolved the user');
    });
  });

  group('duplicate work', () {
    test('a second start while running is dropped', () async {
      final gate = Completer<void>();
      clients.gate = gate.future;

      final cubit = build();
      addTearDown(cubit.close);

      final first = cubit.start();
      final second = cubit.start();

      gate.complete();
      await Future.wait([first, second]);

      // The screen rebuilding must not trigger a second portfolio fetch.
      expect(clients.requestedCommercialIds, hasLength(1));
    });
  });

  group('honesty of reported progress', () {
    test('progress only advances as steps settle', () async {
      final gate = Completer<void>();
      clients.gate = gate.future;
      location.gate = gate.future;
      icons.gate = gate.future;

      final cubit = build();
      addTearDown(cubit.close);

      final run = cubit.start();
      await Future<void>.delayed(Duration.zero);

      // Only the profile has settled at this point.
      expect(cubit.state.progress, closeTo(0.25, 0.001));

      gate.complete();
      await run;
      expect(cubit.state.progress, 1.0);
    });

    test('the message names a step that is actually running', () async {
      final gate = Completer<void>();
      clients.gate = gate.future;
      location.gate = gate.future;
      icons.gate = gate.future;

      final cubit = build();
      addTearDown(cubit.close);

      final run = cubit.start();
      await Future<void>.delayed(Duration.zero);

      // Critical work is named in preference to the optional steps running
      // alongside it.
      expect(cubit.state.message, InitializationStep.portfolio.label);

      gate.complete();
      await run;
    });
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({required this.user, this.restorable});

  CommercialUser? user;
  final CommercialUser? restorable;
  int restoreCalls = 0;

  @override
  CommercialUser? get currentUser => user;

  @override
  Future<CommercialUser?> restoreSession() async {
    restoreCalls++;
    user = restorable;
    return restorable;
  }

  @override
  bool get hasValidSession => user != null;

  @override
  Stream<CommercialUser?> get userChanges => const Stream.empty();

  @override
  Future<Result<CommercialUser>> signIn({
    required String codeClient,
    required String password,
  }) async => const Result.failure(UnexpectedFailure());

  @override
  Future<Result<CommercialUser>> refreshProfile() async =>
      const Result.failure(UnexpectedFailure());

  @override
  Future<void> signOut() async => user = null;
}

class _FakeClientsRepository implements ClientsRepository {
  Result<List<Client>> result = const Result.success(<Client>[]);
  Future<void>? gate;
  bool shouldThrow = false;

  final List<String> requestedCommercialIds = [];
  final List<bool> forceRefreshFlags = [];

  @override
  Future<Result<List<Client>>> loadPortfolio({
    required String commercialId,
    bool forceRefresh = false,
  }) async {
    requestedCommercialIds.add(commercialId);
    forceRefreshFlags.add(forceRefresh);
    if (gate != null) await gate;
    if (shouldThrow) throw StateError('boom');
    return result;
  }

  @override
  List<Client>? get cachedPortfolio => null;

  @override
  Stream<List<Client>> get portfolioChanges => const Stream.empty();

  @override
  void clearCache() {}

  @override
  Future<Result<Client>> createClient(ClientDraft draft) async =>
      const Result.failure(UnexpectedFailure());

  @override
  Future<Result<void>> deleteSubClient(String id) async =>
      const Result.failure(UnexpectedFailure());

  @override
  Future<Result<Client>> fetchClient(String id, {required ClientKind kind}) async =>
      const Result.failure(UnexpectedFailure());

  @override
  Future<Result<Uint8List>> fetchImageBytes(String imagePathOrUrl) async =>
      const Result.failure(UnexpectedFailure());

  @override
  Future<Result<List<Client>>> fetchSubClientsOfParent(String parentClientId) async =>
      const Result.failure(UnexpectedFailure());

  @override
  Future<Result<Client>> updateClient(ClientDraft draft) async =>
      const Result.failure(UnexpectedFailure());

  @override
  Future<Result<Client>> updateClientPosition({
    required String id,
    required ClientKind kind,
    required GeoPosition position,
  }) async => const Result.failure(UnexpectedFailure());

  @override
  Future<Result<void>> uploadImage({
    required String id,
    required ClientKind kind,
    required Uint8List bytes,
  }) async => const Result.failure(UnexpectedFailure());
}

class _FakeLocationService implements LocationService {
  Result<GeoPosition> result = const Result.success(
    GeoPosition(latitude: 36.8065, longitude: 10.1815),
  );
  Future<void>? gate;

  @override
  Future<Result<void>> ensurePermission() async => const Result.success(null);

  @override
  Future<bool> isServiceEnabled() async => true;

  @override
  Future<Result<GeoPosition>> currentPosition({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (gate != null) await gate;
    return result;
  }
}

/// Overrides [MarkerIconCache.prewarm] so the test never enters the real
/// rasterisation pipeline, which requires a pumping test binding.
class _FakeMarkerIconCache extends MarkerIconCache {
  Future<void>? gate;
  bool shouldThrow = false;

  @override
  Future<void> prewarm({double pixelRatio = 1.0}) async {
    if (gate != null) await gate;
    if (shouldThrow) throw StateError('no raster');
  }
}

import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/single_flight.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../cartography/presentation/marker_icon_cache.dart';
import '../../../clients/domain/repositories/clients_repository.dart';
import 'app_initialization_state.dart';

/// Drives the screen shown between a successful sign-in and the map.
///
/// Three properties it is built to guarantee:
///
/// * **It always settles.** Every step resolves to succeeded, failed or
///   skipped, and the phase is recomputed from that table — so the screen can
///   never sit on a spinner. The two operations that could hang (the network
///   and the GPS fix) are bounded by the Dio timeouts and
///   [LocationService.currentPosition]'s own timeout respectively.
///
/// * **It does no redundant work.** The portfolio is fetched through
///   [ClientsRepository], which collapses concurrent calls and serves a fresh
///   cache without touching the network. The map controller later reads the
///   same repository, so opening the map does not refetch what this just
///   loaded.
///
/// * **It never fakes progress.** There is no `Future.delayed` anywhere here;
///   each message is shown only while that step is genuinely in flight, and the
///   progress fraction counts settled steps.
class AppInitializationCubit extends Cubit<AppInitializationState> {
  AppInitializationCubit({
    required AuthRepository authRepository,
    required ClientsRepository clientsRepository,
    required LocationService locationService,
    required MarkerIconCache markerIconCache,
  }) : _auth = authRepository,
       _clients = clientsRepository,
       _location = locationService,
       _icons = markerIconCache,
       super(AppInitializationState.initial());

  final AuthRepository _auth;
  final ClientsRepository _clients;
  final LocationService _location;
  final MarkerIconCache _icons;

  /// Guards against the screen being rebuilt and starting a second run.
  final Mutex<void> _runGuard = Mutex<void>();

  /// Runs initialization. Safe to call again; a second call while one is in
  /// flight is dropped rather than starting a parallel run.
  Future<void> start() async {
    await _runGuard.runOrSkip(_run);
  }

  /// Re-runs from a clean slate after a failure.
  Future<void> retry() async {
    if (_runGuard.isRunning) return;
    emit(AppInitializationState.initial());
    await start();
  }

  Future<void> _run() async {
    emit(
      AppInitializationState.initial().copyWith(
        phase: InitializationPhase.running,
      ),
    );

    // The profile gates everything else: the portfolio endpoints are keyed by
    // the representative's id, so this cannot be parallelised with them.
    final user = await _runStep(
      InitializationStep.profile,
      _resolveProfile,
    );

    if (user == null) return; // _runStep already emitted the failure.

    // These three are independent of one another, so they run concurrently
    // rather than adding their latencies together — which is what the previous
    // sequential `onInit` did.
    await Future.wait([
      _runStep(
        InitializationStep.portfolio,
        () => _loadPortfolio(user.commercialId),
      ),
      _runStep(InitializationStep.location, _primeLocation),
      _runStep(InitializationStep.mapAssets, _prewarmMarkerIcons),
    ]);

    _settle();
  }

  /// Executes one step, recording its status and stopping the run if a
  /// critical step fails.
  ///
  /// Returns the step's value, or `null` when it did not succeed.
  Future<T?> _runStep<T>(
    InitializationStep step,
    Future<Result<T>> Function() action,
  ) async {
    _setStatus(step, StepStatus.running);

    Result<T> result;
    try {
      result = await action();
    } on Object catch (error, stackTrace) {
      // A step must never throw past this point: an unhandled error here would
      // leave the screen running forever.
      AppLogger.error(
        'Initialization step ${step.name} threw',
        error: error,
        stackTrace: stackTrace,
      );
      result = Result.failure(UnexpectedFailure(cause: error));
    }

    if (result case Success<T>(:final value)) {
      _setStatus(step, StepStatus.succeeded);
      return value;
    }

    final failure = result.failureOrNull!;
    _setStatus(step, StepStatus.failed);

    if (step.isCritical) {
      AppLogger.warn('Critical step ${step.name} failed', error: failure);
      emit(
        state.copyWith(
          phase: InitializationPhase.failed,
          failure: failure,
          failedStep: step,
        ),
      );
    } else {
      // Non-critical: the user is not blocked, but it is worth knowing.
      AppLogger.info('Optional step ${step.name} skipped: ${failure.message}');
    }

    return null;
  }

  // -------------------------------------------------------------------- steps

  Future<Result<_ResolvedUser>> _resolveProfile() async {
    // Already resolved by sign-in, or restored at startup — no second call.
    final current = _auth.currentUser;
    if (current != null && current.id.isNotEmpty) {
      return Result.success(_ResolvedUser(commercialId: current.id));
    }

    // Only reached when the app was launched with a stored session that has
    // not been rehydrated yet.
    final restored = await _auth.restoreSession();
    if (restored != null && restored.id.isNotEmpty) {
      return Result.success(_ResolvedUser(commercialId: restored.id));
    }

    return const Result.failure(
      UnauthorizedFailure(message: 'Session introuvable, reconnectez-vous.'),
    );
  }

  Future<Result<void>> _loadPortfolio(String commercialId) async {
    // `forceRefresh` is deliberately false: if the portfolio was loaded moments
    // ago it is served from cache and this step costs nothing. That is what
    // makes a restart-with-session fast instead of re-downloading everything.
    final result = await _clients.loadPortfolio(commercialId: commercialId);
    return result.map((_) {});
  }

  Future<Result<void>> _primeLocation() async {
    // Only a permission check plus one bounded fix. No stream is started here:
    // continuous updates belong to the map's own lifecycle, not to startup.
    final result = await _location.currentPosition();
    return result.map((_) {});
  }

  Future<Result<void>> _prewarmMarkerIcons() async {
    final ratio = PlatformDispatcher.instance.views.isNotEmpty
        ? PlatformDispatcher.instance.views.first.devicePixelRatio
        : 1.0;

    await _icons.prewarm(pixelRatio: ratio);
    return const Result.success(null);
  }

  // ------------------------------------------------------------------ helpers

  void _setStatus(InitializationStep step, StepStatus status) {
    if (isClosed) return;
    emit(
      state.copyWith(steps: {...state.steps, step: status}),
    );
  }

  /// Computes the terminal phase from the step table.
  void _settle() {
    if (isClosed || state.phase == InitializationPhase.failed) return;

    final criticalFailed = InitializationStep.values.any(
      (step) => step.isCritical && state.statusOf(step) == StepStatus.failed,
    );

    emit(
      state.copyWith(
        phase: criticalFailed
            ? InitializationPhase.failed
            : InitializationPhase.ready,
      ),
    );
  }

  /// Proceeds to the application despite a non-fatal failure.
  void continueDegraded() {
    if (!state.canContinueDegraded) return;
    emit(state.copyWith(phase: InitializationPhase.ready, clearFailure: true));
  }
}

/// The only thing initialization needs out of the profile step.
class _ResolvedUser {
  const _ResolvedUser({required this.commercialId});

  final String commercialId;
}

import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';

/// The work that genuinely has to happen between a successful sign-in and the
/// map being usable.
///
/// Derived from what `CommercialMapController.onInit` actually did, not from a
/// wish list: it loaded the connected profile, fetched the representative's
/// clients and sub-clients/prospects, and asked for a GPS fix. Stock is
/// deliberately absent — it is a separate screen that loads its own data, so
/// pre-loading it here would delay the map for nothing.
enum InitializationStep {
  /// Resolve the signed-in representative. Everything else needs their id.
  profile,

  /// Fetch B2B clients plus sub-clients and prospects — the map's content.
  portfolio,

  /// Location permission and a first fix.
  location,

  /// Rasterise the map pin icons once, up front.
  mapAssets;

  /// Whether failing this step should stop the user reaching the map.
  ///
  /// Location is optional because permission can legitimately be refused and
  /// the map still works without it. Map assets are optional because the cache
  /// falls back to default markers. The profile is required because nothing can
  /// be fetched without the representative's id.
  bool get isCritical => switch (this) {
    InitializationStep.profile => true,
    InitializationStep.portfolio => true,
    InitializationStep.location => false,
    InitializationStep.mapAssets => false,
  };

  /// What the user is told is happening. These describe real work — each is
  /// shown only while that step is actually running.
  String get label => switch (this) {
    InitializationStep.profile => 'Préparation de votre espace',
    InitializationStep.portfolio => 'Chargement de vos clients',
    InitializationStep.location => 'Activation de la localisation',
    InitializationStep.mapAssets => 'Préparation de la carte',
  };
}

enum StepStatus {
  pending,
  running,
  succeeded,

  /// Finished unsuccessfully. For a non-critical step this is not fatal.
  failed,

  /// Deliberately not run — e.g. the portfolio was already cached and fresh.
  skipped,
}

/// Overall progress of the post-login initialization.
enum InitializationPhase {
  /// Nothing started yet.
  idle,

  /// At least one step is in flight.
  running,

  /// Everything required finished; the main application can open.
  ready,

  /// A required step failed. [AppInitializationState.failure] explains why.
  failed,
}

/// A deterministic snapshot of initialization.
///
/// There is no "loading" flag that can disagree with the data: [phase] is
/// derived from the step table every time it changes, so the screen cannot sit
/// on a spinner after the work has finished or failed.
class AppInitializationState extends Equatable {
  const AppInitializationState({
    this.phase = InitializationPhase.idle,
    this.steps = const {},
    this.failure,
    this.failedStep,
  });

  /// The starting state, with every step pending.
  factory AppInitializationState.initial() => AppInitializationState(
    steps: {for (final step in InitializationStep.values) step: StepStatus.pending},
  );

  final InitializationPhase phase;
  final Map<InitializationStep, StepStatus> steps;

  /// Set only when [phase] is [InitializationPhase.failed].
  final Failure? failure;
  final InitializationStep? failedStep;

  bool get isRunning => phase == InitializationPhase.running;

  bool get isReady => phase == InitializationPhase.ready;

  bool get hasFailed => phase == InitializationPhase.failed;

  /// Whether the failure means the session is gone and the user must sign in
  /// again, rather than retry.
  bool get requiresReauthentication => failure is UnauthorizedFailure;

  /// Whether the user may proceed to the map despite the failure.
  ///
  /// Offered when the session is still valid: the map is usable with an empty
  /// portfolio and the repository will retry on its own, so trapping the user
  /// on this screen would be worse than letting them through.
  bool get canContinueDegraded =>
      hasFailed &&
      !requiresReauthentication &&
      steps[InitializationStep.profile] == StepStatus.succeeded;

  StepStatus statusOf(InitializationStep step) =>
      steps[step] ?? StepStatus.pending;

  /// The steps currently in flight, in declaration order.
  List<InitializationStep> get runningSteps => InitializationStep.values
      .where((step) => statusOf(step) == StepStatus.running)
      .toList(growable: false);

  /// The headline message, describing what is genuinely happening right now.
  ///
  /// Never invented: it names a step that is actually running, or reports the
  /// terminal outcome.
  String get message {
    if (phase == InitializationPhase.ready) return 'Prêt';
    if (phase == InitializationPhase.failed) {
      return failure?.message ?? 'Initialisation impossible';
    }

    final running = runningSteps;
    if (running.isEmpty) return 'Connexion réussie';

    // Several independent steps run at once; name the most meaningful one
    // rather than claiming a single sequential pipeline.
    final primary = running.firstWhere(
      (step) => step.isCritical,
      orElse: () => running.first,
    );
    return primary.label;
  }

  /// Fraction of steps finished, for the progress indicator. Reflects real
  /// completion — it is never advanced on a timer.
  double get progress {
    if (steps.isEmpty) return 0;
    final settled = steps.values
        .where(
          (status) =>
              status == StepStatus.succeeded ||
              status == StepStatus.failed ||
              status == StepStatus.skipped,
        )
        .length;
    return settled / steps.length;
  }

  AppInitializationState copyWith({
    InitializationPhase? phase,
    Map<InitializationStep, StepStatus>? steps,
    Failure? failure,
    InitializationStep? failedStep,
    bool clearFailure = false,
  }) => AppInitializationState(
    phase: phase ?? this.phase,
    steps: steps ?? this.steps,
    failure: clearFailure ? null : (failure ?? this.failure),
    failedStep: clearFailure ? null : (failedStep ?? this.failedStep),
  );

  @override
  List<Object?> get props => [phase, steps, failure, failedStep];
}

import 'package:bloc_test/bloc_test.dart';
import 'package:dayco_mobile/core/error/failure.dart';
import 'package:dayco_mobile/features/startup/presentation/cubit/app_initialization_cubit.dart';
import 'package:dayco_mobile/features/startup/presentation/cubit/app_initialization_state.dart';
import 'package:dayco_mobile/features/startup/presentation/pages/initialization_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCubit extends MockCubit<AppInitializationState>
    implements AppInitializationCubit {}

void main() {
  late _MockCubit cubit;

  setUp(() => cubit = _MockCubit());
  tearDown(() => cubit.close());

  Future<void> pumpWith(
    WidgetTester tester,
    AppInitializationState state, {
    VoidCallback? onReady,
    VoidCallback? onReauth,
  }) async {
    whenListen(cubit, const Stream<AppInitializationState>.empty(),
        initialState: state);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AppInitializationCubit>.value(
          value: cubit,
          child: InitializationPage(
            onReady: onReady ?? () {},
            onReauthenticationRequired: onReauth ?? () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  AppInitializationState running({
    Map<InitializationStep, StepStatus>? steps,
  }) =>
      AppInitializationState(
        phase: InitializationPhase.running,
        steps: steps ??
            {
              InitializationStep.profile: StepStatus.succeeded,
              InitializationStep.portfolio: StepStatus.running,
              InitializationStep.location: StepStatus.running,
              InitializationStep.mapAssets: StepStatus.pending,
            },
      );

  group('running state', () {
    testWidgets('shows every step with the branding', (tester) async {
      await pumpWith(tester, running());

      for (final step in InitializationStep.values) {
        expect(find.text(step.label), findsWidgets);
      }
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('names the critical work in flight', (tester) async {
      await pumpWith(tester, running());

      // The headline reflects actual work, not a scripted sequence.
      expect(find.text(InitializationStep.portfolio.label), findsWidgets);
    });

    testWidgets('shows a determinate bar reflecting settled steps', (
      tester,
    ) async {
      await pumpWith(tester, running());
      // `pumpAndSettle` cannot be used here: the running steps show
      // indeterminate spinners, which animate forever by design. Pumping past
      // the progress tween's duration is enough.
      await tester.pump(const Duration(milliseconds: 400));

      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      // One of four steps has settled.
      expect(bar.value, closeTo(0.25, 0.01));
    });

    testWidgets('offers no retry while still running', (tester) async {
      await pumpWith(tester, running());

      expect(find.text('Réessayer'), findsNothing);
    });
  });

  group('failure state', () {
    testWidgets('shows the failure message and a retry action', (tester) async {
      await pumpWith(
        tester,
        AppInitializationState(
          phase: InitializationPhase.failed,
          failure: const NetworkFailure(message: 'Connexion indisponible'),
          failedStep: InitializationStep.portfolio,
          steps: const {
            InitializationStep.profile: StepStatus.succeeded,
            InitializationStep.portfolio: StepStatus.failed,
          },
        ),
      );

      expect(find.text('Initialisation interrompue'), findsOneWidget);
      expect(find.text('Connexion indisponible'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      // The screen is never a dead end.
      expect(find.text('Continuer sans ces données'), findsOneWidget);
    });

    testWidgets('a 401 offers re-authentication instead of retry', (
      tester,
    ) async {
      var reauthRequested = false;

      await pumpWith(
        tester,
        const AppInitializationState(
          phase: InitializationPhase.failed,
          failure: UnauthorizedFailure(message: 'Session expirée'),
          failedStep: InitializationStep.profile,
          steps: {InitializationStep.profile: StepStatus.failed},
        ),
        onReauth: () => reauthRequested = true,
      );

      expect(find.text('Se reconnecter'), findsOneWidget);
      // Retrying a dead session cannot help, so it is not offered.
      expect(find.text('Réessayer'), findsNothing);

      await tester.tap(find.text('Se reconnecter'));
      expect(reauthRequested, isTrue);
    });

    testWidgets('retry asks the cubit to re-run', (tester) async {
      when(() => cubit.retry()).thenAnswer((_) async {});

      await pumpWith(
        tester,
        const AppInitializationState(
          phase: InitializationPhase.failed,
          failure: NetworkFailure(),
          steps: {InitializationStep.profile: StepStatus.succeeded},
        ),
      );

      await tester.tap(find.text('Réessayer'));
      verify(() => cubit.retry()).called(1);
    });
  });

  group('navigation', () {
    testWidgets('calls onReady when the cubit reports ready', (tester) async {
      var ready = false;

      whenListen(
        cubit,
        Stream<AppInitializationState>.fromIterable([
          running(),
          const AppInitializationState(phase: InitializationPhase.ready),
        ]),
        initialState: running(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AppInitializationCubit>.value(
            value: cubit,
            child: InitializationPage(
              onReady: () => ready = true,
              onReauthenticationRequired: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(ready, isTrue);
    });

    testWidgets('does not navigate on intermediate step updates', (
      tester,
    ) async {
      var readyCalls = 0;

      whenListen(
        cubit,
        Stream<AppInitializationState>.fromIterable([
          running(),
          running(
            steps: const {
              InitializationStep.profile: StepStatus.succeeded,
              InitializationStep.portfolio: StepStatus.succeeded,
              InitializationStep.location: StepStatus.running,
              InitializationStep.mapAssets: StepStatus.running,
            },
          ),
        ]),
        initialState: running(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AppInitializationCubit>.value(
            value: cubit,
            child: InitializationPage(
              onReady: () => readyCalls++,
              onReauthenticationRequired: () {},
            ),
          ),
        ),
      );
      // Fixed pumps rather than pumpAndSettle: the running spinners never stop.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(readyCalls, 0);
    });
  });
}

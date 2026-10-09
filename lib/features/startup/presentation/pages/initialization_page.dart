import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/assets/images.dart';
import '../../../../core/theme/app_theme.dart';
import '../cubit/app_initialization_cubit.dart';
import '../cubit/app_initialization_state.dart';

/// The screen between a successful sign-in and the map.
///
/// It is driven entirely by [AppInitializationCubit]: every message and the
/// progress bar reflect real work, and the terminal states (ready / failed) are
/// states of the cubit rather than something this widget infers. There is no
/// timer here, so the screen cannot outlive the work it describes.
class InitializationPage extends StatelessWidget {
  const InitializationPage({
    super.key,
    required this.onReady,
    required this.onReauthenticationRequired,
  });

  /// Called once, when initialization completes successfully.
  final VoidCallback onReady;

  /// Called when the session turned out to be invalid and the user has to sign
  /// in again — retrying would be pointless.
  final VoidCallback onReauthenticationRequired;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AppInitializationCubit, AppInitializationState>(
      // Only terminal transitions navigate, so intermediate step updates cannot
      // trigger a second navigation.
      listenWhen: (previous, current) => previous.phase != current.phase,
      listener: (context, state) {
        if (state.isReady) onReady();
      },
      child: Scaffold(
        backgroundColor: ColorManager.backgroundColor,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: BlocBuilder<AppInitializationCubit, AppInitializationState>(
                  builder: (context, state) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const _Branding(),
                      const SizedBox(height: 40),
                      if (state.hasFailed)
                        _FailureView(
                          state: state,
                          onReauthenticationRequired: onReauthenticationRequired,
                        )
                      else
                        _ProgressView(state: state),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Branding extends StatelessWidget {
  const _Branding();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: ColorManager.cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: ColorManager.primaryColor.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Image.asset(AppImages.logo, width: 86, height: 86),
    );
  }
}

/// The running state: a determinate bar, the current activity, and the step
/// list so the user can see what is actually happening.
class _ProgressView extends StatelessWidget {
  const _ProgressView({required this.state});

  final AppInitializationState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Animates between real progress values rather than on a timer, so the
        // bar moves only when a step genuinely settles.
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: state.progress),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          builder: (context, value, _) => ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: ColorManager.lightGrey2,
              valueColor: const AlwaysStoppedAnimation<Color>(
                ColorManager.primaryColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            state.message,
            key: ValueKey(state.message),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: ColorManager.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 24),
        ...InitializationStep.values.map(
          (step) => _StepRow(step: step, status: state.statusOf(step)),
        ),
      ],
    );
  }
}

/// One line per step, showing its true status.
class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.status});

  final InitializationStep step;
  final StepStatus status;

  @override
  Widget build(BuildContext context) {
    final isPending = status == StepStatus.pending;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 20, height: 20, child: _indicator()),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              step.label,
              style: TextStyle(
                fontSize: 14,
                color: isPending
                    ? ColorManager.textSecondary.withValues(alpha: 0.6)
                    : ColorManager.textSecondary,
              ),
            ),
          ),
          if (status == StepStatus.failed && !step.isCritical)
            Text(
              'ignoré',
              style: TextStyle(
                fontSize: 12,
                color: ColorManager.textSecondary.withValues(alpha: 0.8),
              ),
            ),
        ],
      ),
    );
  }

  Widget _indicator() => switch (status) {
    StepStatus.running => const CircularProgressIndicator(
      strokeWidth: 2,
      valueColor: AlwaysStoppedAnimation<Color>(ColorManager.primaryColor),
    ),
    StepStatus.succeeded => const Icon(
      Icons.check_circle,
      size: 20,
      color: ColorManager.successColor,
    ),
    // A failed optional step is reported neutrally: the user is not blocked and
    // showing a red error for a refused location permission would be alarming.
    StepStatus.failed => Icon(
      step.isCritical ? Icons.error_outline : Icons.remove_circle_outline,
      size: 20,
      color: step.isCritical
          ? ColorManager.errorColor
          : ColorManager.textSecondary.withValues(alpha: 0.6),
    ),
    StepStatus.skipped => Icon(
      Icons.remove_circle_outline,
      size: 20,
      color: ColorManager.textSecondary.withValues(alpha: 0.6),
    ),
    StepStatus.pending => Icon(
      Icons.circle_outlined,
      size: 20,
      color: ColorManager.textSecondary.withValues(alpha: 0.35),
    ),
  };
}

/// The terminal failure state. Always offers a way forward — this screen must
/// never be a dead end.
class _FailureView extends StatelessWidget {
  const _FailureView({
    required this.state,
    required this.onReauthenticationRequired,
  });

  final AppInitializationState state;
  final VoidCallback onReauthenticationRequired;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AppInitializationCubit>();
    final mustSignInAgain = state.requiresReauthentication;

    return Column(
      children: [
        Icon(
          mustSignInAgain ? Icons.lock_outline : Icons.cloud_off_outlined,
          size: 44,
          color: ColorManager.errorColor,
        ),
        const SizedBox(height: 18),
        const Text(
          'Initialisation interrompue',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: ColorManager.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          state.message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.45,
            color: ColorManager.textSecondary,
          ),
        ),
        const SizedBox(height: 28),
        if (mustSignInAgain)
          _PrimaryButton(
            label: 'Se reconnecter',
            onPressed: onReauthenticationRequired,
          )
        else ...[
          _PrimaryButton(label: 'Réessayer', onPressed: cubit.retry),
          if (state.canContinueDegraded) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: cubit.continueDegraded,
              child: const Text(
                'Continuer sans ces données',
                style: TextStyle(color: ColorManager.textSecondary),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorManager.primaryColor,
          foregroundColor: ColorManager.textOnPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

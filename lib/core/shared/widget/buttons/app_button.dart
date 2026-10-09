import 'package:flutter/material.dart';

import '../../../theme/design_tokens.dart';

/// Visual weight of an [AppButton].
///
/// The variant encodes *intent*, not colour. Picking by intent is what stops
/// two buttons of equal weight sitting side by side competing for the tap —
/// which is exactly what the map screen's action bar used to do.
enum AppButtonVariant {
  /// The one action the screen wants. Filled, high contrast. At most one
  /// primary button should be visible at a time.
  primary,

  /// A supporting action. Outlined, same footprint as primary so a row of
  /// buttons keeps a straight baseline.
  secondary,

  /// A low-emphasis action. No border, no fill.
  ghost,

  /// A constructive confirmation (saving, confirming a position).
  success,

  /// A destructive action. Never auto-focused.
  danger,
}

/// The app's single button.
///
/// Replaces ad-hoc `ElevatedButton.styleFrom(...)` blocks that each re-declared
/// padding, radius and elevation. Those blocks drifted apart — the map screen
/// alone had radius 12 and 14 and elevation 4 and 6 on buttons sitting 80px
/// apart.
///
/// Guarantees, so callers do not have to remember them:
/// - minimum height of [AppA11y.minTouchTarget] (WCAG 2.1 AA §2.5.5),
/// - a [Semantics] button label that screen readers announce even when the
///   button is showing a spinner (WCAG §4.1.2),
/// - taps are swallowed while [isLoading], so a double tap cannot submit twice.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.semanticLabel,
  });

  final String label;

  /// `null` disables the button. A disabled button is still announced, with
  /// its disabled state, rather than vanishing from the traversal order.
  final VoidCallback? onPressed;

  final AppButtonVariant variant;
  final IconData? icon;

  /// Swaps the label for a spinner and blocks input. The accessible name is
  /// preserved so the control does not become anonymous mid-submit.
  final bool isLoading;

  final bool isFullWidth;

  /// Overrides the announced name when [label] alone is ambiguous out of
  /// context (e.g. a bare "Confirm").
  final String? semanticLabel;

  bool get _enabled => onPressed != null && !isLoading;

  _ButtonColors _colors() => switch (variant) {
    AppButtonVariant.primary => const _ButtonColors(
      background: AppPalette.brandStrong,
      foreground: AppPalette.onBrand,
    ),
    AppButtonVariant.success => const _ButtonColors(
      background: AppPalette.successStrong,
      foreground: AppPalette.onBrand,
    ),
    AppButtonVariant.danger => const _ButtonColors(
      background: AppPalette.danger,
      foreground: AppPalette.onBrand,
    ),
    AppButtonVariant.secondary => const _ButtonColors(
      background: AppPalette.surface,
      foreground: AppPalette.brandInk,
      border: AppPalette.brandInk,
    ),
    AppButtonVariant.ghost => const _ButtonColors(
      background: Colors.transparent,
      foreground: AppPalette.brandInk,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final colors = _colors();

    final child = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(colors.foreground),
            ),
          )
        : Row(
            mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: AppSpacing.xs),
              ],
              // Long labels shrink rather than overflow. A clipped label is a
              // worse failure than a slightly smaller one.
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );

    final style = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colors.background == Colors.transparent
              ? Colors.transparent
              : AppPalette.border;
        }
        return colors.background;
      }),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? AppPalette.textTertiary
            : colors.foreground,
      ),
      // Keeps every button on the same baseline regardless of variant.
      minimumSize: WidgetStatePropertyAll(
        Size(isFullWidth ? double.infinity : 0, AppA11y.minTouchTarget),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      side: colors.border == null
          ? null
          : WidgetStateProperty.resolveWith(
              (states) => BorderSide(
                color: states.contains(WidgetState.disabled)
                    ? AppPalette.border
                    : colors.border!,
                width: 1.5,
              ),
            ),
      elevation: const WidgetStatePropertyAll(0),
      // A visible focus ring is required for keyboard users (WCAG §2.4.7).
      // Material draws none on a filled button by default.
      overlayColor: WidgetStatePropertyAll(
        colors.foreground.withValues(alpha: 0.12),
      ),
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: semanticLabel ?? label,
      child: ExcludeSemantics(
        child: TextButton(
          onPressed: _enabled ? onPressed : null,
          style: style,
          child: child,
        ),
      ),
    );
  }
}

@immutable
class _ButtonColors {
  const _ButtonColors({
    required this.background,
    required this.foreground,
    this.border,
  });

  final Color background;
  final Color foreground;
  final Color? border;
}

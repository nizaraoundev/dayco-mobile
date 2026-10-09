import 'package:flutter/material.dart';

import '../../../../core/shared/widget/buttons/app_button.dart';
import '../../../../core/theme/design_tokens.dart';

/// The floating controls over the map.
///
/// What this replaces, and why:
///
/// * The two bottom buttons were both `ElevatedButton.icon` at equal width and
///   equal elevation — one white-on-blue, one blue-on-white. Equal weight means
///   neither reads as the main action. "My position" is a *utility*; opening
///   the client list is the screen's actual job, so they are no longer peers.
///
/// * "My position" was a full-width half of the bar for what is a one-shot map
///   recentre. It is now a compact circular control sitting directly above the
///   bar, which is where map apps put recentre and where a thumb expects it.
///
/// * The confirm-position button was absolutely positioned at `bottom: 100`,
///   a magic number that assumed the bar below was exactly 76px tall. It is now
///   a sibling in the same column, so the two can never overlap.
///
/// * The blue used for text on white measured 3.66:1. Buttons now come from
///   [AppButton], which uses the AA-safe `brandInk` / `brandStrong` pair.
class MapActionBar extends StatelessWidget {
  const MapActionBar({
    super.key,
    required this.onMyPosition,
    required this.onOpenClients,
    required this.clientsLabel,
    required this.myPositionLabel,
    this.onConfirmPosition,
    this.confirmLabel,
  });

  final VoidCallback onMyPosition;
  final VoidCallback onOpenClients;
  final String clientsLabel;

  /// Used as the recentre button's accessible name. The control is icon-only,
  /// so without this it would be announced as an unlabelled button (§4.1.2).
  final String myPositionLabel;

  /// When non-null a confirm bar appears above the main action.
  final VoidCallback? onConfirmPosition;
  final String? confirmLabel;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: AppSpacing.md,
      right: AppSpacing.md,
      bottom: AppSpacing.lg,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (onConfirmPosition != null) ...[
              AppButton(
                label: confirmLabel ?? '',
                icon: Icons.check_circle_outline,
                variant: AppButtonVariant.success,
                onPressed: onConfirmPosition,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            _RecentreButton(label: myPositionLabel, onPressed: onMyPosition),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: clientsLabel,
              icon: Icons.group_outlined,
              onPressed: onOpenClients,
            ),
          ],
        ),
      ),
    );
  }
}

/// Icon-only recentre control.
///
/// 48x48 so it meets the touch-target minimum despite being visually compact,
/// and it carries an explicit semantic label because an icon alone has no
/// accessible name.
class _RecentreButton extends StatelessWidget {
  const _RecentreButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: Container(
          decoration: BoxDecoration(
            color: AppPalette.surface,
            shape: BoxShape.circle,
            boxShadow: AppElevation.raised,
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: const SizedBox(
                width: AppA11y.minTouchTarget,
                height: AppA11y.minTouchTarget,
                child: Icon(
                  Icons.my_location,
                  color: AppPalette.brandInk,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The floating top bar: menu button plus screen title.
///
/// The title was previously a white `Material` pill stretched across the
/// remaining width, which made a non-interactive label look exactly like the
/// tappable menu button next to it. It is now visually distinct from the
/// control and marked as a header for assistive tech (§1.3.1).
class MapTopBar extends StatelessWidget {
  const MapTopBar({
    super.key,
    required this.title,
    required this.onMenuPressed,
    required this.menuLabel,
  });

  final String title;
  final VoidCallback onMenuPressed;

  /// Accessible name for the icon-only menu button.
  final String menuLabel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Semantics(
              button: true,
              label: menuLabel,
              child: ExcludeSemantics(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppPalette.surface,
                    borderRadius: AppRadius.mdAll,
                    boxShadow: AppElevation.raised,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: AppRadius.mdAll,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onMenuPressed,
                      child: const SizedBox(
                        width: AppA11y.minTouchTarget,
                        height: AppA11y.minTouchTarget,
                        child: Icon(
                          Icons.menu,
                          color: AppPalette.textPrimary,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Semantics(
                header: true,
                child: Container(
                  height: AppA11y.minTouchTarget,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    // Translucent rather than solid: it reads as a label over
                    // the map instead of as another button.
                    color: AppPalette.surface.withValues(alpha: 0.92),
                    borderRadius: AppRadius.mdAll,
                    boxShadow: AppElevation.surface,
                  ),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

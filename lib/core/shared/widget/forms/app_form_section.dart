import 'package:flutter/material.dart';

import '../../../theme/design_tokens.dart';

/// A titled group of form fields.
///
/// The client form was a single flat column of ~20 controls with no structure
/// — identity, contact, commercial and location inputs all ran together. A
/// flat run of inputs is hard to scan and, for a screen-reader user, offers no
/// landmarks to jump between (WCAG 2.1 AA §1.3.1 Info and Relationships).
///
/// Grouping them does three things at once: it shortens the perceived form, it
/// gives the heading a real `header` semantic, and it gives the code somewhere
/// to put a field instead of appending to a 700-line `children:` list.
class AppFormSection extends StatelessWidget {
  const AppFormSection({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  /// The controls in this group. Spacing between them is applied here so no
  /// caller has to sprinkle `SizedBox(height: 16)` between fields.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: AppPalette.brandInk),
                const SizedBox(width: AppSpacing.xs),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.textSecondary,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: AppA11y.minFontSize,
              color: AppPalette.textTertiary,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        // Interleaves the gaps so callers pass a plain list of fields.
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          children[i],
        ],
      ],
    );
  }
}

/// A bordered container for a composite control that is not a plain input —
/// the brand picker, the parent-client picker, the coordinate readout.
///
/// Without this they were hand-rolled `Container`s with three different border
/// colours (`Colors.black12`, `Colors.grey[300]`, none) inside the same form.
class AppFieldGroup extends StatelessWidget {
  const AppFieldGroup({
    super.key,
    required this.label,
    required this.child,
    this.trailing,
  });

  final String label;
  final Widget child;

  /// Optional badge or counter shown opposite the label.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        border: Border.all(color: AppPalette.border),
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.textPrimary,
                    ),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          child,
        ],
      ),
    );
  }
}

/// A count badge, e.g. the number of selected brands.
///
/// Uses [AppPalette.brandInk] on a tint rather than raw brand-on-tint, which
/// measured 3.1:1 and failed for 12px text.
class AppCountBadge extends StatelessWidget {
  const AppCountBadge({super.key, required this.count, this.semanticsLabel});

  final int count;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel == null ? null : '$semanticsLabel: $count',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: AppPalette.brandSurface,
            borderRadius: AppRadius.smAll,
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: AppA11y.minFontSize,
              color: AppPalette.brandInk,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../theme/dayco_colors.dart';
import '../../../theme/text_styles.dart';

/// The app's title bar: the brand gradient, with white contents.
///
/// Every page was building `AppBar(backgroundColor: ColorManager.primaryColor)`
/// by hand, which gave a flat blue bar and a second place to forget the
/// foreground colour. The gradient cannot live in [AppBarTheme] — that holds a
/// colour, not a decoration — so it lives in a widget instead, and the theme's
/// own [AppBarTheme] is set to the flat brand blue as the fallback for any bar
/// built directly.
///
/// Drop-in for [AppBar]: same `title`, `actions`, `bottom` and `leading`.
class DaycoAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DaycoAppBar({
    super.key,
    this.title,
    this.titleText,
    this.actions,
    this.leading,
    this.bottom,
    this.centerTitle,
    this.automaticallyImplyLeading = true,
    this.gradient,
    this.elevation = 0,
  });

  /// The title widget. Most callers want [titleText] instead.
  final Widget? title;

  /// A plain title, styled for the bar so the caller does not restate the
  /// colour and weight — which is where white-on-blue bars tend to go wrong.
  final String? titleText;

  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final bool? centerTitle;
  final bool automaticallyImplyLeading;

  /// Overrides the brand gradient, for a bar that has to carry a different
  /// meaning — a client's own colour on their detail page, say. Pass a colour
  /// through `AppGradients.fromColor` to get one that matches the house
  /// gradient's shape.
  final Gradient? gradient;

  final double elevation;

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final colors = context.dayco;

    return AppBar(
      title: title ??
          (titleText == null
              ? null
              : Text(
                  titleText!,
                  style:
                      AppTextStyles.appBarTitle.copyWith(color: colors.onBrand),
                )),
      actions: actions,
      leading: leading,
      bottom: bottom,
      centerTitle: centerTitle,
      automaticallyImplyLeading: automaticallyImplyLeading,
      elevation: elevation,
      // The gradient is painted by flexibleSpace, so the bar itself has to be
      // transparent or it would cover it.
      backgroundColor: Colors.transparent,
      foregroundColor: colors.onBrand,
      // Material 3 tints the bar's surface once content scrolls under it.
      // With a transparent background that tint is all you see, so it is
      // switched off and the gradient is left to carry the colour.
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      flexibleSpace: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient ?? colors.brandGradient,
        ),
        // A DecoratedBox with no child takes no space under loose
        // constraints, which leaves the bar unpainted.
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// A [SliverAppBar] in the same clothes, for the pages that collapse their
/// header as the content scrolls.
class DaycoSliverAppBar extends StatelessWidget {
  const DaycoSliverAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.bottom,
    this.flexibleContent,
    this.expandedHeight = 200,
    this.pinned = true,
    this.gradient,
  });

  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;

  /// Drawn inside the expanded area, on top of the gradient.
  final Widget? flexibleContent;

  final double expandedHeight;
  final bool pinned;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final colors = context.dayco;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: pinned,
      title: title,
      actions: actions,
      leading: leading,
      bottom: bottom,
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: colors.onBrand,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient ?? colors.brandGradient,
        ),
        child: flexibleContent,
      ),
    );
  }
}

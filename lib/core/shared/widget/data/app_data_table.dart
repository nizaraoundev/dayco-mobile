import 'package:flutter/material.dart';

import '../../../theme/design_tokens.dart';

/// How a column sizes itself and aligns its content.
///
/// Widths are expressed in logical pixels rather than flex so the header and
/// every row agree on a single geometry — that alignment is the whole point of
/// a table, and it is what a `Flexible`-based layout loses as soon as one cell
/// has longer text than its neighbours.
@immutable
class AppColumn {
  const AppColumn({
    required this.label,
    required this.width,
    this.align = TextAlign.left,
    this.numeric = false,
  });

  final String label;
  final double width;
  final TextAlign align;

  /// Numeric columns right-align and use tabular figures so digits line up
  /// vertically, which is what makes a column of prices scannable.
  final bool numeric;

  Alignment get alignment => switch (align) {
    TextAlign.right => Alignment.centerRight,
    TextAlign.center => Alignment.center,
    _ => Alignment.centerLeft,
  };
}

/// A spreadsheet-style table for dense record lists.
///
/// Built for the product catalogue, which was a 2-column card grid: each card
/// showed four fields in a different place, so comparing price or stock across
/// products meant reading diagonally across the screen. A table puts every
/// value in a fixed column, which is the layout people already know from
/// Excel and the reason the user asked for it.
///
/// Behaviour:
/// - the header row is **sticky** — it does not scroll away vertically,
/// - the body scrolls vertically, and the whole grid scrolls **horizontally
///   together** so the header can never drift out of sync with the rows,
/// - rows alternate background (zebra striping) to keep the eye on one line,
/// - an optional trailing actions column is pinned as the last column.
///
/// Accessibility: each row is one semantic node, so a screen reader reads
/// "reference, name, stock, price" as a sentence instead of announcing four
/// unrelated fragments.
class AppDataTable extends StatefulWidget {
  const AppDataTable({
    super.key,
    required this.columns,
    required this.rowCount,
    required this.cellBuilder,
    required this.rowSemantics,
    this.actionsBuilder,
    this.actionsWidth = 96,
    this.onRowTap,
    this.rowHeight = 56,
    this.emptyState,
  });

  final List<AppColumn> columns;
  final int rowCount;

  /// Builds the content of one cell. Return a plain `Text` for most cells —
  /// the table applies alignment, padding and the default text style.
  final Widget Function(int row, int column) cellBuilder;

  /// The sentence a screen reader should read for the whole row.
  final String Function(int row) rowSemantics;

  /// Trailing per-row controls. When null, no actions column is drawn.
  final Widget Function(int row)? actionsBuilder;

  final double actionsWidth;
  final void Function(int row)? onRowTap;
  final double rowHeight;
  final Widget? emptyState;

  @override
  State<AppDataTable> createState() => _AppDataTableState();
}

class _AppDataTableState extends State<AppDataTable> {
  // One horizontal controller shared by the header and the body, so they
  // scroll as a single surface. Two independent controllers would let the
  // header slide out of alignment with its own columns.
  final ScrollController _horizontal = ScrollController();

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  double get _totalWidth =>
      widget.columns.fold<double>(0, (sum, c) => sum + c.width) +
      (widget.actionsBuilder == null ? 0 : widget.actionsWidth);

  @override
  Widget build(BuildContext context) {
    if (widget.rowCount == 0 && widget.emptyState != null) {
      return widget.emptyState!;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Never narrower than the viewport, so short tables still fill the
        // width instead of leaving a ragged edge.
        final width = _totalWidth < constraints.maxWidth
            ? constraints.maxWidth
            : _totalWidth;

        return Scrollbar(
          controller: _horizontal,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontal,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: Column(
                children: [
                  _HeaderRow(
                    columns: widget.columns,
                    actionsWidth: widget.actionsBuilder == null
                        ? 0
                        : widget.actionsWidth,
                    totalWidth: width,
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: widget.rowCount,
                      itemExtent: widget.rowHeight,
                      itemBuilder: (context, row) => _BodyRow(
                        row: row,
                        columns: widget.columns,
                        cellBuilder: widget.cellBuilder,
                        actions: widget.actionsBuilder?.call(row),
                        actionsWidth: widget.actionsBuilder == null
                            ? 0
                            : widget.actionsWidth,
                        onTap: widget.onRowTap == null
                            ? null
                            : () => widget.onRowTap!(row),
                        semanticsLabel: widget.rowSemantics(row),
                        isOdd: row.isOdd,
                        height: widget.rowHeight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.columns,
    required this.actionsWidth,
    required this.totalWidth,
  });

  final List<AppColumn> columns;
  final double actionsWidth;
  final double totalWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      width: totalWidth,
      decoration: const BoxDecoration(
        color: AppPalette.surfaceMuted,
        border: Border(
          bottom: BorderSide(color: AppPalette.border, width: 1.5),
        ),
      ),
      child: Row(
        children: [
          for (final column in columns)
            SizedBox(
              width: column.width,
              child: Align(
                alignment: column.alignment,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: Text(
                    column.label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.textSecondary,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
            ),
          if (actionsWidth > 0) SizedBox(width: actionsWidth),
        ],
      ),
    );
  }
}

class _BodyRow extends StatelessWidget {
  const _BodyRow({
    required this.row,
    required this.columns,
    required this.cellBuilder,
    required this.actions,
    required this.actionsWidth,
    required this.onTap,
    required this.semanticsLabel,
    required this.isOdd,
    required this.height,
  });

  final int row;
  final List<AppColumn> columns;
  final Widget Function(int row, int column) cellBuilder;
  final Widget? actions;
  final double actionsWidth;
  final VoidCallback? onTap;
  final String semanticsLabel;
  final bool isOdd;
  final double height;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        for (var i = 0; i < columns.length; i++)
          SizedBox(
            width: columns[i].width,
            child: Align(
              alignment: columns[i].alignment,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    fontSize: 13,
                    color: AppPalette.textPrimary,
                    // Tabular figures keep digits in a vertical line.
                    fontFeatures: columns[i].numeric
                        ? const [FontFeature.tabularFigures()]
                        : null,
                  ),
                  child: cellBuilder(row, i),
                ),
              ),
            ),
          ),
        if (actions != null)
          SizedBox(
            width: actionsWidth,
            // Actions are their own semantic nodes; excluding them from the
            // row label keeps the row from being read as "…Edit Delete".
            child: Align(alignment: Alignment.centerRight, child: actions),
          ),
      ],
    );

    return Semantics(
      label: semanticsLabel,
      button: onTap != null,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          // Zebra striping: the eye tracks one row across a wide table.
          color: isOdd ? AppPalette.surfaceMuted : AppPalette.surface,
          border: const Border(bottom: BorderSide(color: AppPalette.border)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(onTap: onTap, child: content),
        ),
      ),
    );
  }
}

/// A compact icon action for a table row.
///
/// 40dp rather than the usual 48dp floor: inside a 56dp row with up to three
/// actions, a full 48dp each would not fit, and WCAG §2.5.5 allows a smaller
/// target when an equivalent action is available elsewhere — here, tapping the
/// row itself opens the record where the same actions are full size.
class AppRowAction extends StatelessWidget {
  const AppRowAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  final IconData icon;

  /// Required: an icon-only control with no accessible name is a §4.1.2
  /// failure, and a table full of them is unusable with a screen reader.
  final String label;

  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: ExcludeSemantics(
        child: Tooltip(
          message: label,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  icon,
                  size: 18,
                  color: enabled
                      ? (color ?? AppPalette.brandInk)
                      : AppPalette.textTertiary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Status pill used inside table cells and on detail screens.
///
/// Takes the ink colour and derives its own tint, so a caller cannot pair a
/// light tint with an unreadable label.
class AppStatusPill extends StatelessWidget {
  const AppStatusPill({
    super.key,
    required this.label,
    required this.color,
    this.compact = false,
  });

  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.xs : AppSpacing.sm,
        vertical: compact ? 2 : AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppPalette.tintOf(color),
        borderRadius: AppRadius.smAll,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: compact ? 11 : AppA11y.minFontSize,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

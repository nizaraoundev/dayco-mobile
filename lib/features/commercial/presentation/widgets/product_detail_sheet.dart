import 'package:flutter/material.dart';

import '../../../../core/shared/widget/buttons/app_button.dart';
import '../../../../core/shared/widget/data/app_data_table.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/models/product_model.dart';

/// Product detail, organised into labelled sections.
///
/// The previous sheet was one unbroken column: image, badge, name, reference,
/// brand, two price cards, a stock strip, compatibility chips and the cart
/// row, with nothing saying where one topic ended and the next began. Related
/// values were also split up — `quantityInStock` sat far from the status badge
/// that describes it, and `minStockAlert`, `barcode`, `weight` and
/// `dimensions` were not shown at all despite existing on the model.
///
/// It is now five sections — identification, pricing, stock, vehicle fit and
/// specifications — each a labelled group of label/value rows, with the header
/// and the cart action pinned so they stay reachable while the body scrolls.
class ProductDetailSheet extends StatefulWidget {
  const ProductDetailSheet({
    super.key,
    required this.product,
    required this.onAddToCart,
    required this.categoryIcon,
  });

  final ProductModel product;

  /// Receives the quantity chosen with the stepper.
  final void Function(int quantity) onAddToCart;

  final IconData categoryIcon;

  @override
  State<ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends State<ProductDetailSheet> {
  // The old sheet rendered a hardcoded "1" between two IconButtons whose
  // onPressed were empty closures — the control looked interactive but could
  // not change anything, and addToCart always received the default quantity.
  int _quantity = 1;

  ProductModel get _product => widget.product;

  bool get _inStock => _product.stockStatus != StockStatus.outOfStock;

  /// Never offer more than exists. Falls back to 1 so the stepper still has a
  /// valid range when stock is zero (the add button is disabled anyway).
  int get _maxQuantity =>
      _product.quantityInStock > 0 ? _product.quantityInStock : 1;

  void _setQuantity(int value) {
    final clamped = value.clamp(1, _maxQuantity);
    if (clamped != _quantity) setState(() => _quantity = clamped);
  }

  String _money(double value) => '${value.toStringAsFixed(2)} TND';

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          _header(),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              children: [
                _identificationSection(),
                const SizedBox(height: AppSpacing.xl),
                _pricingSection(),
                const SizedBox(height: AppSpacing.xl),
                _stockSection(),
                if (_product.vehicleCompatibility.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  _compatibilitySection(),
                ],
                if (_hasSpecs) ...[
                  const SizedBox(height: AppSpacing.xl),
                  _specsSection(),
                ],
              ],
            ),
          ),
          _footer(),
        ],
      ),
    );
  }

  bool get _hasSpecs =>
      _product.weight != null ||
      (_product.dimensions != null && _product.dimensions!.isNotEmpty) ||
      (_product.barcode != null && _product.barcode!.isNotEmpty);

  // --- Header / footer ---------------------------------------------------

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppPalette.surface,
        border: Border(bottom: BorderSide(color: AppPalette.border)),
      ),
      child: Column(
        children: [
          // Drag handle, marked decorative so it is not announced.
          ExcludeSemantics(
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppPalette.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppPalette.brandSurface,
                  borderRadius: AppRadius.mdAll,
                ),
                child: ExcludeSemantics(
                  child: Icon(
                    widget.categoryIcon,
                    color: AppPalette.brandInk,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        _product.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_product.reference} · ${_product.brand}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppPalette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              AppStatusPill(
                label: _product.stockStatusLabel,
                color: _product.stockStatusColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppPalette.surfaceMuted,
        border: Border(top: BorderSide(color: AppPalette.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _QuantityStepper(
              value: _quantity,
              min: 1,
              max: _maxQuantity,
              enabled: _inStock,
              onChanged: _setQuantity,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppButton(
                // Stating the total removes the guesswork about what tapping
                // actually adds.
                label: _inStock
                    ? 'Ajouter · ${_money(_product.wholesalePrice * _quantity)}'
                    : 'Rupture de stock',
                icon: _inStock ? Icons.add_shopping_cart : null,
                onPressed: _inStock
                    ? () => widget.onAddToCart(_quantity)
                    : null,
                semanticLabel: _inStock
                    ? 'Ajouter $_quantity au panier, '
                          '${_money(_product.wholesalePrice * _quantity)}'
                    : 'Rupture de stock',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Sections ----------------------------------------------------------

  Widget _identificationSection() {
    return _Section(
      title: 'Identification',
      icon: Icons.qr_code_2_outlined,
      rows: [
        _Row('Référence', _product.reference),
        _Row('Désignation', _product.name),
        _Row('Marque', _product.brand),
        _Row('Catégorie', _product.categoryLabel),
        if (_product.description.isNotEmpty)
          _Row('Description', _product.description),
      ],
    );
  }

  Widget _pricingSection() {
    final margin = _product.retailPrice - _product.wholesalePrice;
    final marginPct = _product.wholesalePrice > 0
        ? (margin / _product.wholesalePrice) * 100
        : 0.0;

    return _Section(
      title: 'Tarifs',
      icon: Icons.sell_outlined,
      rows: [
        _Row('Prix grossiste', _money(_product.wholesalePrice), emphasis: true),
        _Row('Prix détail', _money(_product.retailPrice)),
        // Derived, not stored — the previous sheet showed both prices and
        // left the representative to work out the spread in their head.
        _Row('Marge', '${_money(margin)}  (${marginPct.toStringAsFixed(0)} %)'),
      ],
    );
  }

  Widget _stockSection() {
    return _Section(
      title: 'Stock',
      icon: Icons.inventory_2_outlined,
      rows: [
        _Row('Quantité disponible', '${_product.quantityInStock} unités'),
        _Row('Seuil d\'alerte', '${_product.minStockAlert} unités'),
      ],
      trailing: AppStatusPill(
        label: _product.stockStatusLabel,
        color: _product.stockStatusColor,
        compact: true,
      ),
    );
  }

  Widget _compatibilitySection() {
    return _Section(
      title: 'Compatibilité véhicules',
      icon: Icons.directions_car_outlined,
      body: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: _product.vehicleCompatibility
            .map(
              (vehicle) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xxs + 2,
                ),
                decoration: BoxDecoration(
                  color: AppPalette.surfaceMuted,
                  borderRadius: AppRadius.smAll,
                  border: Border.all(color: AppPalette.border),
                ),
                child: Text(
                  vehicle,
                  style: const TextStyle(
                    fontSize: AppA11y.minFontSize,
                    color: AppPalette.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _specsSection() {
    return _Section(
      title: 'Caractéristiques',
      icon: Icons.straighten_outlined,
      rows: [
        if (_product.weight != null) _Row('Poids', '${_product.weight} kg'),
        if (_product.dimensions != null && _product.dimensions!.isNotEmpty)
          _Row('Dimensions', _product.dimensions!),
        if (_product.barcode != null && _product.barcode!.isNotEmpty)
          _Row('Code-barres', _product.barcode!),
      ],
    );
  }
}

/// One label/value pair.
@immutable
class _Row {
  const _Row(this.label, this.value, {this.emphasis = false});

  final String label;
  final String value;

  /// Renders larger and in brand ink. Reserved for the single figure that
  /// matters most in a section — the wholesale price.
  final bool emphasis;
}

/// A labelled block of rows, or arbitrary [body] content.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    this.rows = const [],
    this.body,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final List<_Row> rows;
  final Widget? body;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppPalette.brandInk),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          decoration: BoxDecoration(
            color: AppPalette.surface,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: AppPalette.border),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xxs,
          ),
          child:
              body ??
              Column(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, color: AppPalette.border),
                    _SectionRow(row: rows[i]),
                  ],
                ],
              ),
        ),
      ],
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({required this.row});

  final _Row row;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${row.label}: ${row.value}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fixed label column: the values line up down the sheet, which
              // is what makes a spec list scannable.
              SizedBox(
                width: 132,
                child: Text(
                  row.label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppPalette.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  row.value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: row.emphasis ? 16 : 13,
                    fontWeight: row.emphasis
                        ? FontWeight.w700
                        : FontWeight.w600,
                    color: row.emphasis
                        ? AppPalette.brandInk
                        : AppPalette.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quantity stepper with working buttons and real bounds.
class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.value,
    required this.min,
    required this.max,
    required this.enabled,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Quantité',
      value: '$value',
      child: Container(
        decoration: BoxDecoration(
          color: AppPalette.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppPalette.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StepButton(
              icon: Icons.remove,
              label: 'Diminuer la quantité',
              onPressed: enabled && value > min
                  ? () => onChanged(value - 1)
                  : null,
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 28),
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.textPrimary,
                ),
              ),
            ),
            _StepButton(
              icon: Icons.add,
              label: 'Augmenter la quantité',
              onPressed: enabled && value < max
                  ? () => onChanged(value + 1)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: AppA11y.minTouchTarget,
              height: AppA11y.minTouchTarget,
              child: Icon(
                icon,
                size: 18,
                color: onPressed == null
                    ? AppPalette.textTertiary
                    : AppPalette.brandInk,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

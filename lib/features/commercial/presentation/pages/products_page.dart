import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/shared/widget/buttons/app_button.dart';
import '../../../../core/shared/widget/data/app_data_table.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/models/models.dart';
import '../controllers/commercial_controller.dart';
import '../widgets/product_detail_sheet.dart';

/// Products page — catalogue as a spreadsheet-style table.
class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key});

  /// Column geometry for the catalogue table.
  ///
  /// Widths are fixed so every row agrees with the header. Reference comes
  /// first because that is what representatives search and quote by; price is
  /// last before the actions because it is the figure most often compared.
  static const List<AppColumn> _columns = [
    AppColumn(label: 'Référence', width: 110),
    AppColumn(label: 'Désignation', width: 200),
    AppColumn(label: 'Marque', width: 110),
    AppColumn(label: 'Statut', width: 120),
    AppColumn(label: 'Stock', width: 80, align: TextAlign.right, numeric: true),
    AppColumn(
      label: 'Prix gros.',
      width: 110,
      align: TextAlign.right,
      numeric: true,
    ),
  ];

  /// Renders one cell. Index matches [_columns].
  Widget _cell(ProductModel product, int column) {
    switch (column) {
      case 0:
        return Text(
          product.reference,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppPalette.brandInk,
          ),
        );
      case 1:
        return Text(
          product.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        );
      case 2:
        return Text(
          product.brand,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppPalette.textSecondary),
        );
      case 3:
        return AppStatusPill(
          label: product.stockStatusLabel,
          color: product.stockStatusColor,
          compact: true,
        );
      case 4:
        return Text(
          '${product.quantityInStock}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            // The number itself carries the warning, so a low count is
            // readable as low without having to cross-reference the status
            // column.
            color: product.stockStatus == StockStatus.outOfStock
                ? AppPalette.danger
                : product.stockStatus == StockStatus.lowStock
                ? AppPalette.warningInk
                : AppPalette.textPrimary,
          ),
        );
      case 5:
        return Text(
          product.wholesalePrice.toStringAsFixed(2),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppPalette.textPrimary,
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CommercialController>();

    return Scaffold(
      backgroundColor: AppPalette.surfaceMuted,
      // Colours come from the global `appBarTheme`; overriding them per page
      // is what let the bars drift apart in the first place.
      appBar: AppBar(
        title: const Text('Catalogue produits'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scanner un code-barres',
            onPressed: () {
              // Scan barcode
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            color: AppPalette.surface,
            child: TextField(
              onChanged: controller.searchProducts,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Référence, nom ou marque',
                prefixIcon: const Icon(
                  Icons.search,
                  size: 20,
                  color: AppPalette.textSecondary,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.tune, size: 20),
                  tooltip: 'Filtrer',
                  color: AppPalette.brandInk,
                  onPressed: () => _showFilterSheet(context, controller),
                ),
                constraints: const BoxConstraints(
                  minHeight: AppA11y.minTouchTarget,
                ),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.mdAll,
                  borderSide: const BorderSide(color: AppPalette.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.mdAll,
                  borderSide: const BorderSide(color: AppPalette.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.mdAll,
                  borderSide: const BorderSide(
                    color: AppPalette.brandInk,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: AppPalette.surface,
              ),
            ),
          ),

          // Category filter row
          Container(
            height: 56,
            color: AppPalette.surface,
            child: Obx(
              () => ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                children: [
                  _CategoryChip(
                    label: 'Tous',
                    isSelected:
                        controller.selectedProductCategory.value == null,
                    onTap: () => controller.filterProductsByCategory(null),
                  ),
                  ...ProductCategory.values.map(
                    (cat) => _CategoryChip(
                      label: _getCategoryLabel(cat),
                      isSelected:
                          controller.selectedProductCategory.value == cat,
                      onTap: () => controller.filterProductsByCategory(cat),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Products Grid
          Expanded(
            child: Obx(() {
              final products = controller.filteredProducts;

              if (products.isEmpty) {
                return const _EmptyCatalogue();
              }

              // Spreadsheet layout. The previous 2-column card grid put each
              // field in a different spot per card, so comparing price or
              // stock across products meant reading diagonally. Fixed columns
              // make a vertical scan possible.
              return AppDataTable(
                columns: _columns,
                rowCount: products.length,
                rowHeight: 60,
                actionsWidth: 96,
                onRowTap: (row) =>
                    _showProductDetail(context, products[row], controller),
                rowSemantics: (row) {
                  final p = products[row];
                  return '${p.reference}, ${p.name}, ${p.brand}, '
                      '${p.stockStatusLabel}, ${p.quantityInStock} unités, '
                      '${p.wholesalePrice.toStringAsFixed(2)} dinars';
                },
                cellBuilder: (row, column) => _cell(products[row], column),
                actionsBuilder: (row) {
                  final product = products[row];
                  final inStock = product.stockStatus != StockStatus.outOfStock;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppRowAction(
                        icon: Icons.visibility_outlined,
                        label: 'Voir ${product.name}',
                        onPressed: () =>
                            _showProductDetail(context, product, controller),
                      ),
                      AppRowAction(
                        icon: Icons.add_shopping_cart,
                        label: inStock
                            ? 'Ajouter ${product.name} au panier'
                            : '${product.name} en rupture de stock',
                        onPressed: inStock
                            ? () => controller.addToCart(product)
                            : null,
                      ),
                    ],
                  );
                },
              );
            }),
          ),
        ],
      ),
      // Cart FAB
      floatingActionButton: Obx(() {
        final cartCount = controller.cartItems.length;
        if (cartCount == 0) return const SizedBox();

        return FloatingActionButton.extended(
          onPressed: () => _showCartSheet(context, controller),
          backgroundColor: AppPalette.brandStrong,
          foregroundColor: AppPalette.onBrand,
          // The badge count and total are both visual; the label states them
          // once for assistive tech instead of announcing two loose numbers.
          tooltip: 'Ouvrir le panier',
          icon: Badge(
            label: Text(cartCount.toString()),
            backgroundColor: AppPalette.danger,
            child: const Icon(Icons.shopping_cart_outlined),
          ),
          label: Text(
            '${controller.cartTotal.toStringAsFixed(0)} TND',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      }),
    );
  }

  void _showFilterSheet(BuildContext context, CommercialController controller) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filtres',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            const Text(
              'Disponibilité',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('En stock'),
                  selected: true,
                  onSelected: (val) {},
                ),
                FilterChip(
                  label: const Text('Stock faible'),
                  selected: false,
                  onSelected: (val) {},
                ),
                FilterChip(
                  label: const Text('Rupture'),
                  selected: false,
                  onSelected: (val) {},
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Marque', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Bosch'),
                  selected: false,
                  onSelected: (val) {},
                ),
                FilterChip(
                  label: const Text('Mann Filter'),
                  selected: false,
                  onSelected: (val) {},
                ),
                FilterChip(
                  label: const Text('Total'),
                  selected: false,
                  onSelected: (val) {},
                ),
                FilterChip(
                  label: const Text('Brembo'),
                  selected: false,
                  onSelected: (val) {},
                ),
              ],
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'Appliquer les filtres',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the product detail sheet.
  ///
  /// The sheet itself lives in [ProductDetailSheet]; this only wires it to
  /// the cart and reports the result.
  void _showProductDetail(
    BuildContext context,
    ProductModel product,
    CommercialController controller,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
      builder: (sheetContext) => ProductDetailSheet(
        product: product,
        categoryIcon: _getCategoryIcon(product.category),
        onAddToCart: (quantity) {
          controller.addToCart(product, quantity: quantity);
          Navigator.pop(sheetContext);
          Get.snackbar(
            "Ajoute au panier",
            "$quantity x ${product.name}",
            backgroundColor: AppPalette.successStrong,
            colorText: AppPalette.onBrand,
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(AppSpacing.md),
          );
        },
      ),
    );
  }

  void _showCartSheet(BuildContext context, CommercialController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Obx(
          () => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Panier',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    AppButton(
                      label: 'Vider',
                      variant: AppButtonVariant.ghost,
                      isFullWidth: false,
                      onPressed: controller.clearCart,
                      semanticLabel: 'Vider le panier',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: controller.cartItems.length,
                  itemBuilder: (context, index) {
                    final item = controller.cartItems[index];
                    return ListTile(
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getCategoryIcon(item.product.category),
                          color: Colors.grey[600],
                        ),
                      ),
                      title: Text(
                        item.product.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        '${item.product.wholesalePrice.toStringAsFixed(0)} TND x ${item.quantity}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${item.total.toStringAsFixed(0)} TND',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () =>
                                controller.removeFromCart(item.product),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${controller.cartTotal.toStringAsFixed(0)} TND',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: ColorManager.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      label: 'Créer la commande',
                      icon: Icons.receipt_long_outlined,
                      onPressed: () {
                        Navigator.pop(context);
                        // Navigate to order confirmation
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getCategoryLabel(ProductCategory category) {
    switch (category) {
      case ProductCategory.engine:
        return 'Moteur';
      case ProductCategory.brakes:
        return 'Freins';
      case ProductCategory.suspension:
        return 'Suspension';
      case ProductCategory.electrical:
        return 'Électrique';
      case ProductCategory.filters:
        return 'Filtres';
      case ProductCategory.oils:
        return 'Huiles';
      case ProductCategory.cooling:
        return 'Refroidissement';
      case ProductCategory.transmission:
        return 'Transmission';
      case ProductCategory.bodyParts:
        return 'Carrosserie';
      case ProductCategory.accessories:
        return 'Accessoires';
      case ProductCategory.other:
        return 'Autres';
    }
  }

  IconData _getCategoryIcon(ProductCategory category) {
    switch (category) {
      case ProductCategory.engine:
        return Icons.engineering;
      case ProductCategory.brakes:
        return Icons.warning;
      case ProductCategory.suspension:
        return Icons.car_repair;
      case ProductCategory.electrical:
        return Icons.bolt;
      case ProductCategory.filters:
        return Icons.filter_alt;
      case ProductCategory.oils:
        return Icons.water_drop;
      case ProductCategory.cooling:
        return Icons.ac_unit;
      case ProductCategory.transmission:
        return Icons.settings;
      case ProductCategory.bodyParts:
        return Icons.directions_car;
      case ProductCategory.accessories:
        return Icons.build;
      case ProductCategory.other:
        return Icons.category;
    }
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        backgroundColor: AppPalette.surface,
        selectedColor: AppPalette.brandSurface,
        side: BorderSide(
          color: isSelected ? AppPalette.brandInk : AppPalette.border,
          width: isSelected ? 1.5 : 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        labelStyle: TextStyle(
          fontSize: 13,
          // brandInk rather than brand: chip labels are small text and the
          // raw brand blue is 3.66:1 on these light fills.
          color: isSelected ? AppPalette.brandInk : AppPalette.textSecondary,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

/// Empty state for the catalogue.
///
/// Says what is missing and what to do about it, rather than only reporting
/// the absence.
class _EmptyCatalogue extends StatelessWidget {
  const _EmptyCatalogue();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 56,
              color: AppPalette.textTertiary,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Aucun produit trouvé',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppPalette.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            const Text(
              'Modifiez votre recherche ou choisissez une autre catégorie.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppPalette.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

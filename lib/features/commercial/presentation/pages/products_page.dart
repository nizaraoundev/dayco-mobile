import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../controllers/commercial_controller.dart';

/// Products page - catalog with search and filters
class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CommercialController>();

    return Scaffold(
      backgroundColor: ColorManager.backgroundColor,
      appBar: AppBar(
        title: const Text('Catalogue Produits'),
        backgroundColor: ColorManager.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              // Scan barcode
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              onChanged: controller.searchProducts,
              decoration: InputDecoration(
                hintText: 'Rechercher par référence, nom ou marque...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: () => _showFilterSheet(context, controller),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: ColorManager.primaryColor,
                  ),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ),

          // Category Chips
          SizedBox(
            height: 50,
            child: Obx(
              () => ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucun produit trouvé',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return _ProductCard(
                    product: product,
                    onTap: () =>
                        _showProductDetail(context, product, controller),
                    onAddToCart: () => controller.addToCart(product),
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
          backgroundColor: ColorManager.primaryColor,
          icon: Badge(
            label: Text(cartCount.toString()),
            child: const Icon(Icons.shopping_cart, color: Colors.white),
          ),
          label: Text(
            '${controller.cartTotal.toStringAsFixed(0)} TND',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorManager.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Appliquer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProductDetail(
    BuildContext context,
    ProductModel product,
    CommercialController controller,
  ) {
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
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Product Image Placeholder
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getCategoryIcon(product.category),
                    size: 64,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 16),
                // Stock Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: product.stockStatusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    product.stockStatusLabel,
                    style: TextStyle(
                      color: product.stockStatusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Réf: ${product.reference}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  product.brand,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: ColorManager.primaryColor,
                  ),
                ),
                const SizedBox(height: 24),
                // Pricing
                Row(
                  children: [
                    Expanded(
                      child: _PriceCard(
                        label: 'Prix grossiste',
                        price: product.wholesalePrice,
                        isHighlighted: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PriceCard(
                        label: 'Prix détail',
                        price: product.retailPrice,
                        isHighlighted: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Stock Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.inventory_2,
                        color: ColorManager.primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Stock: ${product.quantityInStock} unités',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (product.vehicleCompatibility.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Compatibilité véhicules',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: product.vehicleCompatibility
                        .map(
                          (v) => Chip(
                            label: Text(
                              v,
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor: Colors.grey[100],
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 24),
                // Add to Cart
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () {},
                          ),
                          const Text(
                            '1',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: product.stockStatus != StockStatus.outOfStock
                            ? () {
                                controller.addToCart(product);
                                Navigator.pop(context);
                                Get.snackbar(
                                  'Ajouté au panier',
                                  product.name,
                                  backgroundColor:
                                      ColorManager.secondaryVariant,
                                  colorText: Colors.white,
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorManager.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Ajouter au panier',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
                    TextButton(
                      onPressed: controller.clearCart,
                      child: const Text('Vider'),
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
                      color: Colors.black.withOpacity(0.05),
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
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          // Navigate to order confirmation
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorManager.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Créer la commande',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
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
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: ColorManager.primaryColor.withOpacity(0.2),
        checkmarkColor: ColorManager.primaryColor,
        labelStyle: TextStyle(
          color: isSelected ? ColorManager.primaryColor : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onAddToCart,
  });

  IconData _getCategoryIcon() {
    switch (product.category) {
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

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: ColorManager.lightCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image/Icon
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        _getCategoryIcon(),
                        size: 48,
                        color: Colors.grey[400],
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: product.stockStatusColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          product.quantityInStock.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.brand,
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${product.wholesalePrice.toStringAsFixed(0)} TND',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: ColorManager.primaryColor,
                          ),
                        ),
                        GestureDetector(
                          onTap: product.stockStatus != StockStatus.outOfStock
                              ? onAddToCart
                              : null,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color:
                                  product.stockStatus != StockStatus.outOfStock
                                  ? ColorManager.primaryColor
                                  : Colors.grey,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  final String label;
  final double price;
  final bool isHighlighted;

  const _PriceCard({
    required this.label,
    required this.price,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlighted
            ? ColorManager.primaryColor.withOpacity(0.1)
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: isHighlighted
            ? Border.all(color: ColorManager.primaryColor)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isHighlighted
                  ? ColorManager.primaryColor
                  : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${price.toStringAsFixed(0)} TND',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isHighlighted
                  ? ColorManager.primaryColor
                  : ColorManager.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

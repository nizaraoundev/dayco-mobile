import 'product_model.dart';

/// Cart item model for shopping cart
class CartItemModel {
  final ProductModel product;
  final int quantity;

  CartItemModel({
    required this.product,
    this.quantity = 1,
  });

  double get total => product.wholesalePrice * quantity;

  CartItemModel copyWith({
    ProductModel? product,
    int? quantity,
  }) {
    return CartItemModel(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }
}

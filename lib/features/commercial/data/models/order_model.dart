import 'product_model.dart';

/// Order status
enum OrderStatus { draft, confirmed, processing, shipped, delivered, cancelled }

/// Order item in a sale
class OrderItemModel {
  final String id;
  final String productId;
  final String productReference;
  final String productName;
  final String brand;
  final int quantity;
  final double unitPrice;
  final double discount; // Percentage discount
  final double totalPrice;

  OrderItemModel({
    required this.id,
    required this.productId,
    required this.productReference,
    required this.productName,
    required this.brand,
    required this.quantity,
    required this.unitPrice,
    this.discount = 0,
    required this.totalPrice,
  });

  /// Calculate total with discount
  double get discountedTotal {
    return totalPrice * (1 - discount / 100);
  }

  /// Get total (alias for discountedTotal)
  double get total => discountedTotal;

  /// Create from product
  factory OrderItemModel.fromProduct(
    ProductModel product,
    int quantity, {
    double discount = 0,
  }) {
    final total = product.wholesalePrice * quantity;
    return OrderItemModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      productId: product.id,
      productReference: product.reference,
      productName: product.name,
      brand: product.brand,
      quantity: quantity,
      unitPrice: product.wholesalePrice,
      discount: discount,
      totalPrice: total,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'productReference': productReference,
      'productName': productName,
      'brand': brand,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'discount': discount,
      'totalPrice': totalPrice,
    };
  }

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'],
      productId: json['productId'],
      productReference: json['productReference'],
      productName: json['productName'],
      brand: json['brand'],
      quantity: json['quantity'],
      unitPrice: (json['unitPrice'] ?? 0).toDouble(),
      discount: (json['discount'] ?? 0).toDouble(),
      totalPrice: (json['totalPrice'] ?? 0).toDouble(),
    );
  }

  OrderItemModel copyWith({
    String? id,
    String? productId,
    String? productReference,
    String? productName,
    String? brand,
    int? quantity,
    double? unitPrice,
    double? discount,
    double? totalPrice,
  }) {
    return OrderItemModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productReference: productReference ?? this.productReference,
      productName: productName ?? this.productName,
      brand: brand ?? this.brand,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discount: discount ?? this.discount,
      totalPrice: totalPrice ?? this.totalPrice,
    );
  }
}

/// Order Model for B2B sales
class OrderModel {
  final String id;
  final String orderNumber;
  final String clientId;
  final String clientName;
  final List<OrderItemModel> items;
  final double subtotal;
  final double totalDiscount;
  final double totalAmount;
  final OrderStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? syncStatus; // 'synced', 'pending', 'conflict'
  final String createdByUserId;
  final String? visitId; // Link to visit if created during visit

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.clientId,
    required this.clientName,
    required this.items,
    required this.subtotal,
    this.totalDiscount = 0,
    required this.totalAmount,
    this.status = OrderStatus.draft,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = 'pending',
    required this.createdByUserId,
    this.visitId,
  });

  /// Number of items in order
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  /// Get order date (alias for createdAt)
  DateTime get orderDate => createdAt;

  /// Get status label in French
  String get statusLabel {
    switch (status) {
      case OrderStatus.draft:
        return 'Brouillon';
      case OrderStatus.confirmed:
        return 'Confirmée';
      case OrderStatus.processing:
        return 'En cours';
      case OrderStatus.shipped:
        return 'Expédiée';
      case OrderStatus.delivered:
        return 'Livrée';
      case OrderStatus.cancelled:
        return 'Annulée';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderNumber': orderNumber,
      'clientId': clientId,
      'clientName': clientName,
      'items': items.map((e) => e.toJson()).toList(),
      'subtotal': subtotal,
      'totalDiscount': totalDiscount,
      'totalAmount': totalAmount,
      'status': status.index,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'syncStatus': syncStatus,
      'createdByUserId': createdByUserId,
      'visitId': visitId,
    };
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'],
      orderNumber: json['orderNumber'],
      clientId: json['clientId'],
      clientName: json['clientName'],
      items: (json['items'] as List)
          .map((e) => OrderItemModel.fromJson(e))
          .toList(),
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      totalDiscount: (json['totalDiscount'] ?? 0).toDouble(),
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      status: OrderStatus.values[json['status'] ?? 0],
      notes: json['notes'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      syncStatus: json['syncStatus'] ?? 'pending',
      createdByUserId: json['createdByUserId'],
      visitId: json['visitId'],
    );
  }

  OrderModel copyWith({
    String? id,
    String? orderNumber,
    String? clientId,
    String? clientName,
    List<OrderItemModel>? items,
    double? subtotal,
    double? totalDiscount,
    double? totalAmount,
    OrderStatus? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? syncStatus,
    String? createdByUserId,
    String? visitId,
  }) {
    return OrderModel(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      totalDiscount: totalDiscount ?? this.totalDiscount,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      visitId: visitId ?? this.visitId,
    );
  }
}

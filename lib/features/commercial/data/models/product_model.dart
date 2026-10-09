import 'package:flutter/material.dart';

import '../../../../core/theme/design_tokens.dart';

/// Stock status for products
enum StockStatus { available, lowStock, outOfStock }

/// Product category
enum ProductCategory {
  engine, // Moteur
  brakes, // Freinage
  suspension, // Suspension
  electrical, // Électrique
  filters, // Filtres
  oils, // Huiles
  cooling, // Refroidissement
  transmission, // Transmission
  bodyParts, // Carrosserie
  accessories, // Accessoires
  other, // Autres
}

/// Product Model for auto spare parts
class ProductModel {
  final String id;
  final String reference;
  final String name;
  final String description;
  final String brand;
  final ProductCategory category;
  final List<String>
  vehicleCompatibility; // e.g., ["Renault Clio", "Peugeot 208"]
  final double wholesalePrice; // Prix grossiste (B2B)
  final double retailPrice; // Prix détail (pour info)
  final int quantityInStock;
  final int minStockAlert;
  final String? imageUrl;
  final String? barcode;
  final double? weight;
  final String? dimensions;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductModel({
    required this.id,
    required this.reference,
    required this.name,
    required this.description,
    required this.brand,
    required this.category,
    this.vehicleCompatibility = const [],
    required this.wholesalePrice,
    required this.retailPrice,
    required this.quantityInStock,
    this.minStockAlert = 5,
    this.imageUrl,
    this.barcode,
    this.weight,
    this.dimensions,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get stock status
  StockStatus get stockStatus {
    if (quantityInStock <= 0) return StockStatus.outOfStock;
    if (quantityInStock <= minStockAlert) return StockStatus.lowStock;
    return StockStatus.available;
  }

  /// Colour for the stock-status badge.
  ///
  /// These come from the app palette rather than Material's defaults so the
  /// catalogue matches the rest of the product. The Material colours that used
  /// to be here all failed WCAG AA as label text on white: #4CAF50 at 2.78:1,
  /// #FF9800 at 2.16:1 and #F44336 at 3.68:1. The replacements clear 4.5:1 and
  /// reuse the semantic colours the rest of the app already uses for success,
  /// warning and danger.
  Color get stockStatusColor {
    switch (stockStatus) {
      case StockStatus.available:
        return AppPalette.successStrong;
      case StockStatus.lowStock:
        return AppPalette.warningInk;
      case StockStatus.outOfStock:
        return AppPalette.danger;
    }
  }

  /// Get stock status label in French
  String get stockStatusLabel {
    switch (stockStatus) {
      case StockStatus.available:
        return 'Disponible';
      case StockStatus.lowStock:
        return 'Stock faible';
      case StockStatus.outOfStock:
        return 'Rupture de stock';
    }
  }

  /// Get category label in French
  String get categoryLabel {
    switch (category) {
      case ProductCategory.engine:
        return 'Moteur';
      case ProductCategory.brakes:
        return 'Freinage';
      case ProductCategory.suspension:
        return 'Suspension';
      case ProductCategory.electrical:
        return 'Électrique';
      case ProductCategory.filters:
        return 'Filtres';
      case ProductCategory.oils:
        return 'Huiles & Lubrifiants';
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

  /// Profit margin percentage
  double get marginPercentage {
    if (wholesalePrice == 0) return 0;
    return ((retailPrice - wholesalePrice) / wholesalePrice) * 100;
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reference': reference,
      'name': name,
      'description': description,
      'brand': brand,
      'category': category.index,
      'vehicleCompatibility': vehicleCompatibility,
      'wholesalePrice': wholesalePrice,
      'retailPrice': retailPrice,
      'quantityInStock': quantityInStock,
      'minStockAlert': minStockAlert,
      'imageUrl': imageUrl,
      'barcode': barcode,
      'weight': weight,
      'dimensions': dimensions,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create from JSON
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'],
      reference: json['reference'],
      name: json['name'],
      description: json['description'] ?? '',
      brand: json['brand'],
      category: ProductCategory.values[json['category'] ?? 9],
      vehicleCompatibility: json['vehicleCompatibility'] != null
          ? List<String>.from(json['vehicleCompatibility'])
          : [],
      wholesalePrice: (json['wholesalePrice'] ?? 0).toDouble(),
      retailPrice: (json['retailPrice'] ?? 0).toDouble(),
      quantityInStock: json['quantityInStock'] ?? 0,
      minStockAlert: json['minStockAlert'] ?? 5,
      imageUrl: json['imageUrl'],
      barcode: json['barcode'],
      weight: json['weight']?.toDouble(),
      dimensions: json['dimensions'],
      isActive: json['isActive'] == 1 || json['isActive'] == true,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  /// Copy with modifications
  ProductModel copyWith({
    String? id,
    String? reference,
    String? name,
    String? description,
    String? brand,
    ProductCategory? category,
    List<String>? vehicleCompatibility,
    double? wholesalePrice,
    double? retailPrice,
    int? quantityInStock,
    int? minStockAlert,
    String? imageUrl,
    String? barcode,
    double? weight,
    String? dimensions,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      reference: reference ?? this.reference,
      name: name ?? this.name,
      description: description ?? this.description,
      brand: brand ?? this.brand,
      category: category ?? this.category,
      vehicleCompatibility: vehicleCompatibility ?? this.vehicleCompatibility,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      retailPrice: retailPrice ?? this.retailPrice,
      quantityInStock: quantityInStock ?? this.quantityInStock,
      minStockAlert: minStockAlert ?? this.minStockAlert,
      imageUrl: imageUrl ?? this.imageUrl,
      barcode: barcode ?? this.barcode,
      weight: weight ?? this.weight,
      dimensions: dimensions ?? this.dimensions,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

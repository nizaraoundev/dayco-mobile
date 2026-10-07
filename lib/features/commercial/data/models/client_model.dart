import 'package:flutter/material.dart';
import 'brands_model.dart';

/// Client category enum for B2B clients
enum ClientCategory { vip, standard, PROSPECT }

/// Payment terms for B2B clients
enum PaymentTerms {
  cash,
  credit7Days,
  credit15Days,
  credit30Days,
  credit60Days,
}

/// Visit priority level
enum VisitPriority { high, medium, low }

/// B2B Client Model - Boutiques only (NOT end consumers)
class ClientModel {
  final String id;
  final String businessName;
  final String contactPerson;
  final String phone;
  final String? whatsapp;
  final String address;
  final double latitude;
  final double longitude;
  final ClientCategory category;
  final PaymentTerms paymentTerms;
  final double creditLimit;
  final double currentCredit;
  final DateTime? lastVisitDate;
  final int visitFrequencyDays; // How often to visit (in days)
  final String? notes;
  final String? profileImageUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? syncStatus; // 'synced', 'pending', 'conflict'
  final CarBrandsModel availableBrands; // Car brands sold at the boutique

  ClientModel({
    required this.id,
    required this.businessName,
    required this.contactPerson,
    required this.phone,
    this.whatsapp,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.category = ClientCategory.standard,
    this.paymentTerms = PaymentTerms.cash,
    this.creditLimit = 0,
    this.currentCredit = 0,
    this.lastVisitDate,
    this.visitFrequencyDays = 7,
    this.notes,
    this.profileImageUrl,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = 'synced',
    CarBrandsModel? availableBrands,
  }) : availableBrands = availableBrands ?? CarBrandsModel(selectedBrands: []);

  /// Check if client needs a visit based on frequency
  bool get needsVisit {
    if (lastVisitDate == null) return true;
    final daysSinceLastVisit = DateTime.now().difference(lastVisitDate!).inDays;
    return daysSinceLastVisit >= visitFrequencyDays;
  }

  /// Days since last visit
  int get daysSinceLastVisit {
    if (lastVisitDate == null) return -1;
    return DateTime.now().difference(lastVisitDate!).inDays;
  }

  /// Get category color
  Color get categoryColor {
    switch (category) {
      case ClientCategory.vip:
        return const Color(0xFFFFD700); // Gold
      case ClientCategory.standard:
        return const Color(0xFF008DD2); // Blue
      case ClientCategory.PROSPECT:
        return const Color(0xFF7ED6C9); // Teal
    }
  }

  /// Get category label in French
  String get categoryLabel {
    switch (category) {
      case ClientCategory.vip:
        return 'VIP';
      case ClientCategory.standard:
        return 'Standard';
      case ClientCategory.PROSPECT:
        return 'PROSPECT';
    }
  }

  /// Get payment terms label in French
  String get paymentTermsLabel {
    switch (paymentTerms) {
      case PaymentTerms.cash:
        return 'Comptant';
      case PaymentTerms.credit7Days:
        return 'Crédit 7 jours';
      case PaymentTerms.credit15Days:
        return 'Crédit 15 jours';
      case PaymentTerms.credit30Days:
        return 'Crédit 30 jours';
      case PaymentTerms.credit60Days:
        return 'Crédit 60 jours';
    }
  }

  /// Convert to JSON for storage/API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'businessName': businessName,
      'contactPerson': contactPerson,
      'phone': phone,
      'whatsapp': whatsapp,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'category': category.index,
      'paymentTerms': paymentTerms.index,
      'creditLimit': creditLimit,
      'currentCredit': currentCredit,
      'lastVisitDate': lastVisitDate?.toIso8601String(),
      'visitFrequencyDays': visitFrequencyDays,
      'notes': notes,
      'profileImageUrl': profileImageUrl,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'availableBrands': availableBrands.toJson(),
      'syncStatus': syncStatus,
    };
  }

  /// Create from JSON
  factory ClientModel.fromJson(Map<String, dynamic> json) {
    return ClientModel(
      id: json['id'],
      businessName: json['businessName'],
      contactPerson: json['contactPerson'],
      phone: json['phone'],
      whatsapp: json['whatsapp'],
      address: json['address'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      category: ClientCategory.values[json['category'] ?? 1],
      paymentTerms: PaymentTerms.values[json['paymentTerms'] ?? 0],
      creditLimit: (json['creditLimit'] ?? 0).toDouble(),
      currentCredit: (json['currentCredit'] ?? 0).toDouble(),
      lastVisitDate: json['lastVisitDate'] != null
          ? DateTime.parse(json['lastVisitDate'])
          : null,
      visitFrequencyDays: json['visitFrequencyDays'] ?? 7,
      notes: json['notes'],
      profileImageUrl: json['profileImageUrl'],
      isActive: json['isActive'] == 1 || json['isActive'] == true,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      availableBrands: json['availableBrands'] != null
          ? CarBrandsModel.fromJson(json['availableBrands'])
          : CarBrandsModel(selectedBrands: []),
      syncStatus: json['syncStatus'] ?? 'synced',
    );
  }

  /// Copy with modifications
  ClientModel copyWith({
    String? id,
    String? businessName,
    String? contactPerson,
    String? phone,
    String? whatsapp,
    String? address,
    double? latitude,
    double? longitude,
    ClientCategory? category,
    PaymentTerms? paymentTerms,
    double? creditLimit,
    double? currentCredit,
    DateTime? lastVisitDate,
    int? visitFrequencyDays,
    String? notes,
    String? profileImageUrl,
    CarBrandsModel? availableBrands,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? syncStatus,
  }) {
    return ClientModel(
      id: id ?? this.id,
      businessName: businessName ?? this.businessName,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      category: category ?? this.category,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      creditLimit: creditLimit ?? this.creditLimit,
      currentCredit: currentCredit ?? this.currentCredit,
      lastVisitDate: lastVisitDate ?? this.lastVisitDate,
      visitFrequencyDays: visitFrequencyDays ?? this.visitFrequencyDays,
      notes: notes ?? this.notes,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      availableBrands: availableBrands ?? this.availableBrands,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

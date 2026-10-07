/// Client type definitions for NEOS mobility app
enum ClientType {
  normal,
  business,
}

enum BusinessRole {
  manager, // Manager / Superviseur (illimité)
  employeeLimited, // Employé avec quota limité
  employeeRestricted, // Employé restreint (bloqué)
}

enum BusinessUsageType {
  nonPlanned, // Business Non Planifié (libre)
  planned, // Business Planifié (courses programmées)
}

/// Client model
class ClientModel {
  final String id;
  final String name;
  final String phone;
  final String email;
  final ClientType clientType;
  final BusinessProfile? businessProfile;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final bool isActive;

  ClientModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.clientType,
    this.businessProfile,
    required this.createdAt,
    this.lastLoginAt,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'clientType': clientType.name,
      'businessProfile': businessProfile?.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    return ClientModel(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      email: json['email'],
      clientType: ClientType.values.firstWhere(
        (e) => e.name == json['clientType'],
        orElse: () => ClientType.normal,
      ),
      businessProfile: json['businessProfile'] != null
          ? BusinessProfile.fromJson(json['businessProfile'])
          : null,
      createdAt: DateTime.parse(json['createdAt']),
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.parse(json['lastLoginAt'])
          : null,
      isActive: json['isActive'] ?? true,
    );
  }

  ClientModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    ClientType? clientType,
    BusinessProfile? businessProfile,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isActive,
  }) {
    return ClientModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      clientType: clientType ?? this.clientType,
      businessProfile: businessProfile ?? this.businessProfile,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Business profile for business clients
class BusinessProfile {
  final String companyName;
  final String companyId;
  final BusinessRole role;
  final BusinessUsageType usageType;
  final QuotaLimits? quotaLimits;
  final List<String> predefinedRoutes; // Pour Business Planifié
  final bool canCreateRides;
  final bool hasUnlimitedAccess;

  BusinessProfile({
    required this.companyName,
    required this.companyId,
    required this.role,
    required this.usageType,
    this.quotaLimits,
    this.predefinedRoutes = const [],
    this.canCreateRides = true,
    this.hasUnlimitedAccess = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'companyName': companyName,
      'companyId': companyId,
      'role': role.name,
      'usageType': usageType.name,
      'quotaLimits': quotaLimits?.toJson(),
      'predefinedRoutes': predefinedRoutes,
      'canCreateRides': canCreateRides,
      'hasUnlimitedAccess': hasUnlimitedAccess,
    };
  }

  factory BusinessProfile.fromJson(Map<String, dynamic> json) {
    return BusinessProfile(
      companyName: json['companyName'],
      companyId: json['companyId'],
      role: BusinessRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => BusinessRole.employeeLimited,
      ),
      usageType: BusinessUsageType.values.firstWhere(
        (e) => e.name == json['usageType'],
        orElse: () => BusinessUsageType.nonPlanned,
      ),
      quotaLimits: json['quotaLimits'] != null
          ? QuotaLimits.fromJson(json['quotaLimits'])
          : null,
      predefinedRoutes: List<String>.from(json['predefinedRoutes'] ?? []),
      canCreateRides: json['canCreateRides'] ?? true,
      hasUnlimitedAccess: json['hasUnlimitedAccess'] ?? false,
    );
  }
}

/// Quota limits for business clients
class QuotaLimits {
  final double? monthlyBudget;
  final int? monthlyRides;
  final double budgetUsed;
  final int ridesUsed;
  final DateTime periodStart;
  final DateTime periodEnd;

  QuotaLimits({
    this.monthlyBudget,
    this.monthlyRides,
    this.budgetUsed = 0.0,
    this.ridesUsed = 0,
    required this.periodStart,
    required this.periodEnd,
  });

  bool get isBudgetExceeded =>
      monthlyBudget != null && budgetUsed >= monthlyBudget!;

  bool get isRideQuotaExceeded =>
      monthlyRides != null && ridesUsed >= monthlyRides!;

  bool get canCreateRide => !isBudgetExceeded && !isRideQuotaExceeded;

  double get budgetPercentageUsed =>
      monthlyBudget != null ? (budgetUsed / monthlyBudget!) * 100 : 0;

  double get ridePercentageUsed =>
      monthlyRides != null ? (ridesUsed / monthlyRides!) * 100 : 0;

  Map<String, dynamic> toJson() {
    return {
      'monthlyBudget': monthlyBudget,
      'monthlyRides': monthlyRides,
      'budgetUsed': budgetUsed,
      'ridesUsed': ridesUsed,
      'periodStart': periodStart.toIso8601String(),
      'periodEnd': periodEnd.toIso8601String(),
    };
  }

  factory QuotaLimits.fromJson(Map<String, dynamic> json) {
    return QuotaLimits(
      monthlyBudget: json['monthlyBudget']?.toDouble(),
      monthlyRides: json['monthlyRides'],
      budgetUsed: json['budgetUsed']?.toDouble() ?? 0.0,
      ridesUsed: json['ridesUsed'] ?? 0,
      periodStart: DateTime.parse(json['periodStart']),
      periodEnd: DateTime.parse(json['periodEnd']),
    );
  }

  QuotaLimits copyWith({
    double? monthlyBudget,
    int? monthlyRides,
    double? budgetUsed,
    int? ridesUsed,
    DateTime? periodStart,
    DateTime? periodEnd,
  }) {
    return QuotaLimits(
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      monthlyRides: monthlyRides ?? this.monthlyRides,
      budgetUsed: budgetUsed ?? this.budgetUsed,
      ridesUsed: ridesUsed ?? this.ridesUsed,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
    );
  }
}

/// Predefined route for planned business clients
class PredefinedRoute {
  final String id;
  final String name;
  final String fromAddress;
  final String toAddress;
  final double estimatedPrice;
  final int estimatedDuration; // in minutes
  final bool isActive;
  final List<String> allowedDays; // ['monday', 'tuesday', etc.]
  final String? description;

  PredefinedRoute({
    required this.id,
    required this.name,
    required this.fromAddress,
    required this.toAddress,
    required this.estimatedPrice,
    required this.estimatedDuration,
    this.isActive = true,
    this.allowedDays = const [],
    this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'fromAddress': fromAddress,
      'toAddress': toAddress,
      'estimatedPrice': estimatedPrice,
      'estimatedDuration': estimatedDuration,
      'isActive': isActive,
      'allowedDays': allowedDays,
      'description': description,
    };
  }

  factory PredefinedRoute.fromJson(Map<String, dynamic> json) {
    return PredefinedRoute(
      id: json['id'],
      name: json['name'],
      fromAddress: json['fromAddress'],
      toAddress: json['toAddress'],
      estimatedPrice: json['estimatedPrice']?.toDouble() ?? 0.0,
      estimatedDuration: json['estimatedDuration'] ?? 0,
      isActive: json['isActive'] ?? true,
      allowedDays: List<String>.from(json['allowedDays'] ?? []),
      description: json['description'],
    );
  }
}

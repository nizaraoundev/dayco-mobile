import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Route waypoint
class RouteWaypoint {
  final String id;
  final String clientId;
  final String clientName;
  final double latitude;
  final double longitude;
  final int order;
  final double? distanceFromPrevious; // in meters
  final int? durationFromPrevious; // in seconds
  final String? eta; // Estimated time of arrival

  RouteWaypoint({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.latitude,
    required this.longitude,
    required this.order,
    this.distanceFromPrevious,
    this.durationFromPrevious,
    this.eta,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clientId': clientId,
      'clientName': clientName,
      'latitude': latitude,
      'longitude': longitude,
      'order': order,
      'distanceFromPrevious': distanceFromPrevious,
      'durationFromPrevious': durationFromPrevious,
      'eta': eta,
    };
  }

  factory RouteWaypoint.fromJson(Map<String, dynamic> json) {
    return RouteWaypoint(
      id: json['id'],
      clientId: json['clientId'],
      clientName: json['clientName'],
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      order: json['order'] ?? 0,
      distanceFromPrevious: json['distanceFromPrevious']?.toDouble(),
      durationFromPrevious: json['durationFromPrevious'],
      eta: json['eta'],
    );
  }

  RouteWaypoint copyWith({
    String? id,
    String? clientId,
    String? clientName,
    double? latitude,
    double? longitude,
    int? order,
    double? distanceFromPrevious,
    int? durationFromPrevious,
    String? eta,
  }) {
    return RouteWaypoint(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      order: order ?? this.order,
      distanceFromPrevious: distanceFromPrevious ?? this.distanceFromPrevious,
      durationFromPrevious: durationFromPrevious ?? this.durationFromPrevious,
      eta: eta ?? this.eta,
    );
  }
}

/// Route status
enum RouteStatus { draft, active, completed, cancelled }

/// Route Model - Optimized route for visits
class RouteModel {
  final String id;
  final String name;
  final DateTime date;
  final RouteStatus status;
  final double startLatitude;
  final double startLongitude;
  final String startAddress; // Usually warehouse
  final double? endLatitude;
  final double? endLongitude;
  final String? endAddress;
  final List<RouteWaypoint> waypoints;
  final double totalDistance; // in meters
  final int totalDuration; // in seconds
  final List<LatLng> polylinePoints; // For drawing route on map
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? syncStatus;

  RouteModel({
    required this.id,
    required this.name,
    required this.date,
    this.status = RouteStatus.draft,
    required this.startLatitude,
    required this.startLongitude,
    required this.startAddress,
    this.endLatitude,
    this.endLongitude,
    this.endAddress,
    this.waypoints = const [],
    this.totalDistance = 0,
    this.totalDuration = 0,
    this.polylinePoints = const [],
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = 'pending',
  });

  /// Get formatted total distance
  String get formattedDistance {
    if (totalDistance < 1000) {
      return '${totalDistance.toStringAsFixed(0)} m';
    }
    return '${(totalDistance / 1000).toStringAsFixed(1)} km';
  }

  /// Get formatted total duration
  String get formattedDuration {
    final hours = totalDuration ~/ 3600;
    final minutes = (totalDuration % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    }
    return '${minutes} min';
  }

  /// Get status label in French
  String get statusLabel {
    switch (status) {
      case RouteStatus.draft:
        return 'Brouillon';
      case RouteStatus.active:
        return 'En cours';
      case RouteStatus.completed:
        return 'Terminée';
      case RouteStatus.cancelled:
        return 'Annulée';
    }
  }

  LatLng get startLatLng => LatLng(startLatitude, startLongitude);
  LatLng? get endLatLng => endLatitude != null && endLongitude != null
      ? LatLng(endLatitude!, endLongitude!)
      : null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'date': date.toIso8601String(),
      'status': status.index,
      'startLatitude': startLatitude,
      'startLongitude': startLongitude,
      'startAddress': startAddress,
      'endLatitude': endLatitude,
      'endLongitude': endLongitude,
      'endAddress': endAddress,
      'waypoints': waypoints.map((e) => e.toJson()).toList(),
      'totalDistance': totalDistance,
      'totalDuration': totalDuration,
      'polylinePoints': polylinePoints
          .map((e) => {'lat': e.latitude, 'lng': e.longitude})
          .toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'syncStatus': syncStatus,
    };
  }

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    return RouteModel(
      id: json['id'],
      name: json['name'],
      date: DateTime.parse(json['date']),
      status: RouteStatus.values[json['status'] ?? 0],
      startLatitude: (json['startLatitude'] ?? 0).toDouble(),
      startLongitude: (json['startLongitude'] ?? 0).toDouble(),
      startAddress: json['startAddress'] ?? '',
      endLatitude: json['endLatitude']?.toDouble(),
      endLongitude: json['endLongitude']?.toDouble(),
      endAddress: json['endAddress'],
      waypoints: json['waypoints'] != null
          ? (json['waypoints'] as List)
                .map((e) => RouteWaypoint.fromJson(e))
                .toList()
          : [],
      totalDistance: (json['totalDistance'] ?? 0).toDouble(),
      totalDuration: json['totalDuration'] ?? 0,
      polylinePoints: json['polylinePoints'] != null
          ? (json['polylinePoints'] as List)
                .map((e) => LatLng(e['lat'], e['lng']))
                .toList()
          : [],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      syncStatus: json['syncStatus'] ?? 'pending',
    );
  }

  RouteModel copyWith({
    String? id,
    String? name,
    DateTime? date,
    RouteStatus? status,
    double? startLatitude,
    double? startLongitude,
    String? startAddress,
    double? endLatitude,
    double? endLongitude,
    String? endAddress,
    List<RouteWaypoint>? waypoints,
    double? totalDistance,
    int? totalDuration,
    List<LatLng>? polylinePoints,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? syncStatus,
  }) {
    return RouteModel(
      id: id ?? this.id,
      name: name ?? this.name,
      date: date ?? this.date,
      status: status ?? this.status,
      startLatitude: startLatitude ?? this.startLatitude,
      startLongitude: startLongitude ?? this.startLongitude,
      startAddress: startAddress ?? this.startAddress,
      endLatitude: endLatitude ?? this.endLatitude,
      endLongitude: endLongitude ?? this.endLongitude,
      endAddress: endAddress ?? this.endAddress,
      waypoints: waypoints ?? this.waypoints,
      totalDistance: totalDistance ?? this.totalDistance,
      totalDuration: totalDuration ?? this.totalDuration,
      polylinePoints: polylinePoints ?? this.polylinePoints,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

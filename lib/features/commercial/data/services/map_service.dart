import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';

/// Google Maps API Key
const String googleMapsApiKey = 'AIzaSyBQyBRLDvdrrGQk3NT8Sm9c5lX7Nizvj24';

/// Map service for route optimization and directions
class MapService extends GetxService {
  /// Calculate distance between two points in meters
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Get route polyline between two points
  Future<List<LatLng>> getRouteBetweenPoints({
    required LatLng origin,
    required LatLng destination,
    List<LatLng>? waypoints,
  }) async {
    List<LatLng> polylineCoordinates = [];

    try {
      // Build waypoints string
      String waypointsStr = '';
      if (waypoints != null && waypoints.isNotEmpty) {
        waypointsStr = waypoints
            .map((w) => '${w.latitude},${w.longitude}')
            .join('|');
      }

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '${waypointsStr.isNotEmpty ? '&waypoints=optimize:true|$waypointsStr' : ''}'
        '&key=$googleMapsApiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'OK') {
          final routes = data['routes'] as List;
          if (routes.isNotEmpty) {
            final route = routes[0];
            final overviewPolyline = route['overview_polyline']['points'];

            // Decode polyline
            final decodedPoints = PolylinePoints.decodePolyline(
              overviewPolyline,
            );
            polylineCoordinates = decodedPoints
                .map((point) => LatLng(point.latitude, point.longitude))
                .toList();
          }
        }
      }
    } catch (e) {
      print('Error getting route: $e');
    }

    return polylineCoordinates;
  }

  /// Get optimized route for multiple clients
  Future<RouteModel?> optimizeRoute({
    required LatLng startPoint,
    required String startAddress,
    required List<ClientModel> clients,
    LatLng? endPoint,
    String? endAddress,
  }) async {
    if (clients.isEmpty) return null;

    try {
      // Build waypoints from clients
      final waypoints = clients
          .map((c) => LatLng(c.latitude, c.longitude))
          .toList();

      // Use first client as intermediate if no end point
      final destination = endPoint ?? waypoints.last;
      final intermediateWaypoints = endPoint == null
          ? waypoints.sublist(0, waypoints.length - 1)
          : waypoints;

      // Build request URL
      String waypointsStr = intermediateWaypoints
          .map((w) => '${w.latitude},${w.longitude}')
          .join('|');

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${startPoint.latitude},${startPoint.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '${waypointsStr.isNotEmpty ? '&waypoints=optimize:true|$waypointsStr' : ''}'
        '&key=$googleMapsApiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'OK') {
          final routes = data['routes'] as List;
          if (routes.isNotEmpty) {
            final route = routes[0];

            // Get optimized order
            final waypointOrder = route['waypoint_order'] as List? ?? [];

            // Decode polyline
            final overviewPolyline = route['overview_polyline']['points'];
            final decodedPoints = PolylinePoints.decodePolyline(
              overviewPolyline,
            );
            final polylineCoordinates = decodedPoints
                .map((point) => LatLng(point.latitude, point.longitude))
                .toList();

            // Calculate total distance and duration
            double totalDistance = 0;
            int totalDuration = 0;
            final legs = route['legs'] as List;
            for (final leg in legs) {
              totalDistance += leg['distance']['value'];
              totalDuration += leg['duration']['value'] as int;
            }

            // Build optimized waypoints
            List<RouteWaypoint> optimizedWaypoints = [];
            for (int i = 0; i < waypointOrder.length; i++) {
              final originalIndex = waypointOrder[i] as int;
              final client = clients[originalIndex];
              final leg = legs[i];

              optimizedWaypoints.add(
                RouteWaypoint(
                  id: '${DateTime.now().millisecondsSinceEpoch}_$i',
                  clientId: client.id,
                  clientName: client.businessName,
                  latitude: client.latitude,
                  longitude: client.longitude,
                  order: i,
                  distanceFromPrevious: leg['distance']['value'].toDouble(),
                  durationFromPrevious: leg['duration']['value'],
                  eta: _calculateEta(totalDuration, legs, i),
                ),
              );
            }

            // Add last client if no end point was specified
            if (endPoint == null && clients.isNotEmpty) {
              final lastClient = clients.last;
              final lastLeg = legs.last;
              optimizedWaypoints.add(
                RouteWaypoint(
                  id: '${DateTime.now().millisecondsSinceEpoch}_last',
                  clientId: lastClient.id,
                  clientName: lastClient.businessName,
                  latitude: lastClient.latitude,
                  longitude: lastClient.longitude,
                  order: waypointOrder.length,
                  distanceFromPrevious: lastLeg['distance']['value'].toDouble(),
                  durationFromPrevious: lastLeg['duration']['value'],
                ),
              );
            }

            final now = DateTime.now();
            return RouteModel(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: 'Route du ${now.day}/${now.month}/${now.year}',
              date: now,
              status: RouteStatus.draft,
              startLatitude: startPoint.latitude,
              startLongitude: startPoint.longitude,
              startAddress: startAddress,
              endLatitude: endPoint?.latitude,
              endLongitude: endPoint?.longitude,
              endAddress: endAddress,
              waypoints: optimizedWaypoints,
              totalDistance: totalDistance,
              totalDuration: totalDuration,
              polylinePoints: polylineCoordinates,
              createdAt: now,
              updatedAt: now,
            );
          }
        }
      }
    } catch (e) {
      print('Error optimizing route: $e');
    }

    return null;
  }

  String _calculateEta(int totalDuration, List<dynamic> legs, int index) {
    int durationToPoint = 0;
    for (int i = 0; i <= index; i++) {
      durationToPoint += legs[i]['duration']['value'] as int;
    }

    final arrival = DateTime.now().add(Duration(seconds: durationToPoint));
    return '${arrival.hour.toString().padLeft(2, '0')}:${arrival.minute.toString().padLeft(2, '0')}';
  }

  /// Get directions info between two points
  Future<Map<String, dynamic>?> getDirectionsInfo(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&key=$googleMapsApiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'OK') {
          final routes = data['routes'] as List;
          if (routes.isNotEmpty) {
            final route = routes[0];
            final leg = route['legs'][0];

            return {
              'distance': leg['distance']['text'],
              'distanceValue': leg['distance']['value'],
              'duration': leg['duration']['text'],
              'durationValue': leg['duration']['value'],
              'startAddress': leg['start_address'],
              'endAddress': leg['end_address'],
            };
          }
        }
      }
    } catch (e) {
      print('Error getting directions info: $e');
    }
    return null;
  }

  /// Create markers for clients on map
  Set<Marker> createClientMarkers({
    required List<ClientModel> clients,
    required Function(ClientModel) onTap,
    BitmapDescriptor? vipIcon,
    BitmapDescriptor? standardIcon,
    BitmapDescriptor? prospectIcon,
  }) {
    return clients.map((client) {
      BitmapDescriptor icon;
      switch (client.category) {
        case ClientCategory.vip:
          icon =
              vipIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
          break;
        case ClientCategory.standard:
          icon =
              standardIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
          break;
        case ClientCategory.PROSPECT:
          icon =
              prospectIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
          break;
      }

      return Marker(
        markerId: MarkerId(client.id),
        position: LatLng(client.latitude, client.longitude),
        icon: icon,
        infoWindow: InfoWindow(
          title: client.businessName,
          snippet: client.address,
        ),
        onTap: () => onTap(client),
      );
    }).toSet();
  }

  /// Create polyline from route
  Polyline createRoutePolyline(RouteModel route, {Color? color}) {
    return Polyline(
      polylineId: PolylineId(route.id),
      points: route.polylinePoints,
      color: color ?? const Color(0xFF008DD2),
      width: 5,
      patterns: [PatternItem.dash(20), PatternItem.gap(10)],
    );
  }

  /// Sort clients by distance from a point
  List<ClientModel> sortClientsByDistance(
    List<ClientModel> clients,
    LatLng fromPoint,
  ) {
    final sortedClients = List<ClientModel>.from(clients);
    sortedClients.sort((a, b) {
      final distA = calculateDistance(
        fromPoint.latitude,
        fromPoint.longitude,
        a.latitude,
        a.longitude,
      );
      final distB = calculateDistance(
        fromPoint.latitude,
        fromPoint.longitude,
        b.latitude,
        b.longitude,
      );
      return distA.compareTo(distB);
    });
    return sortedClients;
  }

  /// Get bounds for a list of clients
  LatLngBounds getBoundsForClients(
    List<ClientModel> clients, {
    LatLng? includePoint,
  }) {
    if (clients.isEmpty) {
      // Default to Tunisia center if no clients
      return LatLngBounds(
        southwest: const LatLng(36.7, 10.1),
        northeast: const LatLng(36.9, 10.3),
      );
    }

    double minLat = clients.first.latitude;
    double maxLat = clients.first.latitude;
    double minLng = clients.first.longitude;
    double maxLng = clients.first.longitude;

    for (final client in clients) {
      if (client.latitude < minLat) minLat = client.latitude;
      if (client.latitude > maxLat) maxLat = client.latitude;
      if (client.longitude < minLng) minLng = client.longitude;
      if (client.longitude > maxLng) maxLng = client.longitude;
    }

    if (includePoint != null) {
      if (includePoint.latitude < minLat) minLat = includePoint.latitude;
      if (includePoint.latitude > maxLat) maxLat = includePoint.latitude;
      if (includePoint.longitude < minLng) minLng = includePoint.longitude;
      if (includePoint.longitude > maxLng) maxLng = includePoint.longitude;
    }

    // Add padding
    const padding = 0.01;
    return LatLngBounds(
      southwest: LatLng(minLat - padding, minLng - padding),
      northeast: LatLng(maxLat + padding, maxLng + padding),
    );
  }
}

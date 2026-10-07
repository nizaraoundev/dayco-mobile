import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../data/models/models.dart';
import '../../data/services/services.dart';
import '../../data/services/fake_data_service.dart';
import 'commercial_controller.dart';

/// Controller for map and route management
class MapController extends GetxController {
  final CommercialController _commercialController =
      Get.find<CommercialController>();
  final MapService _mapService = Get.find<MapService>();

  // Map controller
  GoogleMapController? mapController;
  final Completer<GoogleMapController> mapCompleter = Completer();

  // Observable state
  final RxSet<Marker> markers = <Marker>{}.obs;
  final RxSet<Polyline> polylines = <Polyline>{}.obs;
  final RxSet<Circle> circles = <Circle>{}.obs;

  final RxBool isMapReady = false.obs;
  final RxBool showTraffic = false.obs;
  final RxBool isNavigating = false.obs;

  final Rx<MapType> mapType = MapType.normal.obs;
  final Rx<ClientModel?> selectedClientOnMap = Rx<ClientModel?>(null);
  final Rx<RouteModel?> currentRoute = Rx<RouteModel?>(null);

  // Current navigation target
  final Rx<RouteWaypoint?> currentWaypoint = Rx<RouteWaypoint?>(null);
  final RxInt currentWaypointIndex = 0.obs;

  // Tunisia center (Tunis)
  static const LatLng tunisiaCenter = LatLng(36.8065, 10.1815);

  // Default camera position
  CameraPosition get initialCameraPosition {
    final location = _commercialController.currentLocation.value;
    return CameraPosition(target: location ?? tunisiaCenter, zoom: 12);
  }

  @override
  void onInit() {
    super.onInit();
    _setupListeners();
  }

  void _setupListeners() {
    // Update markers when clients change
    ever(_commercialController.clients, (_) => _updateClientMarkers());
    ever(_commercialController.activeRoute, (_) => _updateRoutePolyline());
  }

  void onMapCreated(GoogleMapController controller) {
    if (!mapCompleter.isCompleted) {
      mapCompleter.complete(controller);
    }
    mapController = controller;
    isMapReady.value = true;

    // Load initial markers
    _updateClientMarkers();

    // If there's an active route, show it
    if (_commercialController.activeRoute.value != null) {
      _updateRoutePolyline();
    }
  }

  void _updateClientMarkers() {
    final clients = _commercialController.clients;

    markers.clear();

    // Add client markers
    for (final client in clients) {
      final marker = Marker(
        markerId: MarkerId(client.id),
        position: LatLng(client.latitude, client.longitude),
        icon: _getMarkerIcon(client),
        infoWindow: InfoWindow(
          title: client.businessName,
          snippet: '${client.categoryLabel} • ${client.address}',
        ),
        onTap: () => _onClientMarkerTap(client),
      );
      markers.add(marker);
    }

    // Add current location marker
    final currentLoc = _commercialController.currentLocation.value;
    if (currentLoc != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: currentLoc,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: const InfoWindow(title: 'Ma position'),
        ),
      );
    }

    // Add warehouse marker
    final warehouse = FakeDataService.getWarehouseLocation();
    markers.add(
      Marker(
        markerId: const MarkerId('warehouse'),
        position: LatLng(warehouse['latitude'], warehouse['longitude']),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        infoWindow: InfoWindow(
          title: warehouse['name'],
          snippet: warehouse['address'],
        ),
      ),
    );
  }

  BitmapDescriptor _getMarkerIcon(ClientModel client) {
    // Check if client needs visit
    if (client.needsVisit) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }

    switch (client.category) {
      case ClientCategory.vip:
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueYellow,
        );
      case ClientCategory.standard:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      case ClientCategory.PROSPECT:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
    }
  }

  void _onClientMarkerTap(ClientModel client) {
    selectedClientOnMap.value = client;
    _commercialController.selectClient(client);
  }

  void _updateRoutePolyline() {
    polylines.clear();

    final route = _commercialController.activeRoute.value;
    if (route == null || route.polylinePoints.isEmpty) return;

    currentRoute.value = route;

    // Main route polyline
    polylines.add(
      Polyline(
        polylineId: PolylineId('route_${route.id}'),
        points: route.polylinePoints,
        color: const Color(0xFF008DD2),
        width: 5,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    );

    // Add waypoint circles
    circles.clear();
    for (int i = 0; i < route.waypoints.length; i++) {
      final waypoint = route.waypoints[i];
      circles.add(
        Circle(
          circleId: CircleId('waypoint_$i'),
          center: waypoint.latLng,
          radius: 50,
          fillColor: const Color(0xFF008DD2).withOpacity(0.3),
          strokeColor: const Color(0xFF008DD2),
          strokeWidth: 2,
        ),
      );
    }

    // Fit map to show entire route
    _fitMapToRoute(route);
  }

  Future<void> _fitMapToRoute(RouteModel route) async {
    if (mapController == null) return;

    final bounds = _mapService.getBoundsForClients(
      _commercialController.clients,
      includePoint: route.startLatLng,
    );

    await mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
  }

  // ========== Map Controls ==========

  void toggleMapType() {
    mapType.value = mapType.value == MapType.normal
        ? MapType.satellite
        : MapType.normal;
  }

  void toggleTraffic() {
    showTraffic.value = !showTraffic.value;
  }

  Future<void> centerOnCurrentLocation() async {
    final location = _commercialController.currentLocation.value;
    if (location != null && mapController != null) {
      await mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: location, zoom: 15),
        ),
      );
    }
  }

  Future<void> centerOnClient(ClientModel client) async {
    if (mapController != null) {
      await mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(client.latitude, client.longitude),
            zoom: 16,
          ),
        ),
      );
    }
    selectedClientOnMap.value = client;
  }

  Future<void> showAllClients() async {
    if (mapController == null) return;

    final bounds = _mapService.getBoundsForClients(
      _commercialController.clients,
      includePoint: _commercialController.currentLocation.value,
    );

    await mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
  }

  // ========== Route Navigation ==========

  Future<void> startNavigation() async {
    final route = _commercialController.activeRoute.value;
    if (route == null || route.waypoints.isEmpty) return;

    isNavigating.value = true;
    currentWaypointIndex.value = 0;
    currentWaypoint.value = route.waypoints.first;

    // Center on first waypoint
    await mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: route.waypoints.first.latLng, zoom: 15),
      ),
    );
  }

  void stopNavigation() {
    isNavigating.value = false;
    currentWaypoint.value = null;
    currentWaypointIndex.value = 0;
  }

  Future<void> goToNextWaypoint() async {
    final route = currentRoute.value;
    if (route == null) return;

    if (currentWaypointIndex.value < route.waypoints.length - 1) {
      currentWaypointIndex.value++;
      currentWaypoint.value = route.waypoints[currentWaypointIndex.value];

      await mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: currentWaypoint.value!.latLng, zoom: 15),
        ),
      );
    } else {
      // Route completed
      stopNavigation();
      Get.snackbar(
        'Route terminée',
        'Vous avez terminé votre itinéraire',
        backgroundColor: const Color(0xFF009846),
        colorText: Colors.white,
      );
    }
  }

  Future<void> goToPreviousWaypoint() async {
    final route = currentRoute.value;
    if (route == null) return;

    if (currentWaypointIndex.value > 0) {
      currentWaypointIndex.value--;
      currentWaypoint.value = route.waypoints[currentWaypointIndex.value];

      await mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: currentWaypoint.value!.latLng, zoom: 15),
        ),
      );
    }
  }

  // ========== Route Generation ==========

  Future<void> generateRoute() async {
    await _commercialController.generateOptimizedRoute();

    if (_commercialController.activeRoute.value != null) {
      Get.snackbar(
        'Itinéraire généré',
        '${_commercialController.activeRoute.value!.waypoints.length} étapes • ${_commercialController.activeRoute.value!.formattedDistance}',
        backgroundColor: const Color(0xFF008DD2),
        colorText: Colors.white,
      );
    }
  }

  Future<void> clearRoute() async {
    currentRoute.value = null;
    _commercialController.activeRoute.value = null;
    polylines.clear();
    circles.clear();
    stopNavigation();
  }

  // ========== Client Filtering on Map ==========

  void showOnlyVipClients() {
    _updateMarkersForClients(_commercialController.vipClients);
  }

  void showClientsNeedingVisit() {
    _updateMarkersForClients(_commercialController.clientsNeedingVisit);
  }

  void showAllClientMarkers() {
    _updateClientMarkers();
  }

  void _updateMarkersForClients(List<ClientModel> clients) {
    markers.clear();

    for (final client in clients) {
      final marker = Marker(
        markerId: MarkerId(client.id),
        position: LatLng(client.latitude, client.longitude),
        icon: _getMarkerIcon(client),
        infoWindow: InfoWindow(
          title: client.businessName,
          snippet: '${client.categoryLabel} • ${client.address}',
        ),
        onTap: () => _onClientMarkerTap(client),
      );
      markers.add(marker);
    }

    // Keep current location and warehouse
    final currentLoc = _commercialController.currentLocation.value;
    if (currentLoc != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: currentLoc,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: const InfoWindow(title: 'Ma position'),
        ),
      );
    }
  }

  @override
  void onClose() {
    mapController?.dispose();
    super.onClose();
  }
}

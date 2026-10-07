import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../controllers/commercial_controller.dart';
import '../controllers/map_controller.dart';
import '../widgets/client_info_card.dart';
import '../widgets/route_info_panel.dart';
import '../widgets/map_filter_chip.dart';

/// Map page with client pins, route, and navigation
class MapPage extends StatelessWidget {
  final ClientModel? initialClient;

  const MapPage({super.key, this.initialClient});

  @override
  Widget build(BuildContext context) {
    final mapController = Get.put(MapController());
    final commercialController = Get.find<CommercialController>();

    // Navigate to initial client if provided
    if (initialClient != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        mapController.centerOnClient(initialClient!);
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          Obx(
            () => GoogleMap(
              initialCameraPosition: mapController.initialCameraPosition,
              onMapCreated: mapController.onMapCreated,
              markers: mapController.markers.toSet(),
              polylines: mapController.polylines.toSet(),
              circles: mapController.circles.toSet(),
              mapType: mapController.mapType.value,
              trafficEnabled: mapController.showTraffic.value,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: true,
              mapToolbarEnabled: false,
            ),
          ),

          // Top Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Search & Menu Row
                  Row(
                    children: [
                      // Back Button
                      _buildCircleButton(
                        icon: Icons.arrow_back,
                        onTap: () => Get.back(),
                      ),
                      const SizedBox(width: 12),

                      // Search Bar
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: ColorManager.cardShadow,
                          ),
                          child: TextField(
                            onChanged: (value) {
                              commercialController.searchQuery.value = value;
                            },
                            decoration: InputDecoration(
                              hintText: 'Rechercher un client...',
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Colors.grey,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Map Type Toggle
                      _buildCircleButton(
                        icon: Icons.layers,
                        onTap: () => mapController.toggleMapType(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        MapFilterChip(
                          label: 'Tous',
                          icon: Icons.people,
                          isSelected: true,
                          onTap: () => mapController.showAllClientMarkers(),
                        ),
                        const SizedBox(width: 8),
                        MapFilterChip(
                          label: 'VIP',
                          icon: Icons.star,
                          color: Colors.amber,
                          onTap: () => mapController.showOnlyVipClients(),
                        ),
                        const SizedBox(width: 8),
                        MapFilterChip(
                          label: 'À visiter',
                          icon: Icons.schedule,
                          color: Colors.orange,
                          onTap: () => mapController.showClientsNeedingVisit(),
                        ),
                        const SizedBox(width: 8),
                        Obx(
                          () => MapFilterChip(
                            label: 'Trafic',
                            icon: Icons.traffic,
                            color: mapController.showTraffic.value
                                ? ColorManager.primaryColor
                                : Colors.grey,
                            isSelected: mapController.showTraffic.value,
                            onTap: () => mapController.toggleTraffic(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Right Side Controls
          Positioned(
            right: 16,
            bottom: 200,
            child: Column(
              children: [
                _buildCircleButton(
                  icon: Icons.my_location,
                  onTap: () => mapController.centerOnCurrentLocation(),
                ),
                const SizedBox(height: 8),
                _buildCircleButton(
                  icon: Icons.zoom_out_map,
                  onTap: () => mapController.showAllClients(),
                ),
              ],
            ),
          ),

          // Route Info Panel (shown when route is active)
          Obx(() {
            final route = commercialController.activeRoute.value;
            if (route == null) return const SizedBox.shrink();

            return Positioned(
              left: 16,
              right: 16,
              bottom: 120,
              child: RouteInfoPanel(
                route: route,
                currentWaypoint: mapController.currentWaypoint.value,
                currentIndex: mapController.currentWaypointIndex.value,
                isNavigating: mapController.isNavigating.value,
                onStartNavigation: () => mapController.startNavigation(),
                onStopNavigation: () => mapController.stopNavigation(),
                onNextWaypoint: () => mapController.goToNextWaypoint(),
                onPreviousWaypoint: () => mapController.goToPreviousWaypoint(),
                onClearRoute: () => mapController.clearRoute(),
              ),
            );
          }),

          // Selected Client Card (shown when client is selected)
          Obx(() {
            final client = mapController.selectedClientOnMap.value;
            if (client == null) return const SizedBox.shrink();

            return Positioned(
              left: 16,
              right: 16,
              bottom: commercialController.activeRoute.value != null
                  ? 280
                  : 120,
              child: ClientInfoCard(
                client: client,
                onClose: () => mapController.selectedClientOnMap.value = null,
                onCall: () => _launchPhone(client.phone),
                onWhatsApp: client.whatsapp != null
                    ? () => _launchWhatsApp(client.whatsapp!)
                    : null,
                onNavigate: () => _launchNavigation(client),
                onStartVisit: () => _startClientVisit(client),
              ),
            );
          }),

          // Bottom Action Buttons
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Obx(() {
              final hasRoute = commercialController.activeRoute.value != null;

              return Row(
                children: [
                  // Generate Route Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: hasRoute
                          ? null
                          : () => mapController.generateRoute(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorManager.primaryColor,
                        disabledBackgroundColor: Colors.grey[300],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(
                        hasRoute ? Icons.check : Icons.route,
                        color: hasRoute ? Colors.grey : Colors.white,
                      ),
                      label: Text(
                        hasRoute ? 'Itinéraire actif' : 'Générer itinéraire',
                        style: TextStyle(
                          color: hasRoute ? Colors.grey : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (hasRoute) ...[
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => mapController.clearRoute(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[400],
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Icon(Icons.clear, color: Colors.white),
                    ),
                  ],
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      elevation: 4,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
          child: Icon(icon, color: ColorManager.textPrimary),
        ),
      ),
    );
  }

  void _launchPhone(String phone) {
    // Launch phone dialer
    Get.snackbar(
      'Appel',
      'Appel vers $phone',
      backgroundColor: ColorManager.primaryColor,
      colorText: Colors.white,
    );
  }

  void _launchWhatsApp(String whatsapp) {
    // Launch WhatsApp
    Get.snackbar(
      'WhatsApp',
      'Ouverture WhatsApp pour $whatsapp',
      backgroundColor: const Color(0xFF25D366),
      colorText: Colors.white,
    );
  }

  void _launchNavigation(ClientModel client) {
    // Launch Google Maps navigation
    Get.snackbar(
      'Navigation',
      'Navigation vers ${client.businessName}',
      backgroundColor: ColorManager.primaryColor,
      colorText: Colors.white,
    );
  }

  void _startClientVisit(ClientModel client) {
    final controller = Get.find<CommercialController>();

    // Find or create visit for this client
    final existingVisit = controller.todayVisits.firstWhereOrNull(
      (v) => v.clientId == client.id && v.status == VisitStatus.planned,
    );

    if (existingVisit != null) {
      controller.startVisit(existingVisit);
      Get.snackbar(
        'Visite démarrée',
        'Visite chez ${client.businessName} démarrée',
        backgroundColor: ColorManager.secondaryVariant,
        colorText: Colors.white,
      );
    } else {
      // Create new visit
      final visit = VisitModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        clientId: client.id,
        clientName: client.businessName,
        clientAddress: client.address,
        clientLatitude: client.latitude,
        clientLongitude: client.longitude,
        status: VisitStatus.inProgress,
        plannedDate: DateTime.now(),
        startTime: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      controller.todayVisits.add(visit);
      controller.activeVisit.value = visit;

      Get.snackbar(
        'Nouvelle visite',
        'Visite créée pour ${client.businessName}',
        backgroundColor: ColorManager.secondaryVariant,
        colorText: Colors.white,
      );
    }
  }
}

import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/models.dart';

/// Route info panel shown when navigating
class RouteInfoPanel extends StatelessWidget {
  final RouteModel route;
  final RouteWaypoint? currentWaypoint;
  final int currentIndex;
  final bool isNavigating;
  final VoidCallback? onStartNavigation;
  final VoidCallback? onStopNavigation;
  final VoidCallback? onNextWaypoint;
  final VoidCallback? onPreviousWaypoint;
  final VoidCallback? onClearRoute;

  const RouteInfoPanel({
    super.key,
    required this.route,
    this.currentWaypoint,
    required this.currentIndex,
    required this.isNavigating,
    this.onStartNavigation,
    this.onStopNavigation,
    this.onNextWaypoint,
    this.onPreviousWaypoint,
    this.onClearRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Route summary
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ColorManager.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.route,
                  color: ColorManager.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: ColorManager.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${route.waypoints.length} étapes • ${route.formattedDistance} • ${route.formattedDuration}',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (isNavigating && currentWaypoint != null) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Current waypoint info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ColorManager.primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: ColorManager.primaryColor.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: ColorManager.primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${currentIndex + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentWaypoint!.clientName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (currentWaypoint!.eta != null)
                              Text(
                                'ETA: ${currentWaypoint!.eta}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (currentWaypoint!.distanceFromPrevious != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatDistance(
                                currentWaypoint!.distanceFromPrevious!,
                              ),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: ColorManager.primaryColor,
                              ),
                            ),
                            if (currentWaypoint!.durationFromPrevious != null)
                              Text(
                                _formatDuration(
                                  currentWaypoint!.durationFromPrevious!,
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Navigation controls
            Row(
              children: [
                // Previous button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: currentIndex > 0 ? onPreviousWaypoint : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ColorManager.primaryColor,
                      side: BorderSide(
                        color: currentIndex > 0
                            ? ColorManager.primaryColor
                            : Colors.grey[300]!,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Précédent'),
                  ),
                ),
                const SizedBox(width: 8),

                // Stop button
                IconButton(
                  onPressed: onStopNavigation,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.all(12),
                  ),
                  icon: const Icon(Icons.stop),
                ),
                const SizedBox(width: 8),

                // Next button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: currentIndex < route.waypoints.length - 1
                        ? onNextWaypoint
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorManager.primaryColor,
                      disabledBackgroundColor: Colors.grey[300],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('Suivant'),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 16),

            // Waypoints preview
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: route.waypoints.length,
                itemBuilder: (context, index) {
                  final waypoint = route.waypoints[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      avatar: CircleAvatar(
                        backgroundColor: ColorManager.primaryColor,
                        radius: 12,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      label: Text(
                        waypoint.clientName.length > 15
                            ? '${waypoint.clientName.substring(0, 15)}...'
                            : waypoint.clientName,
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Colors.grey[100],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Start navigation button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onStartNavigation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorManager.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.navigation),
                label: const Text(
                  'Démarrer la navigation',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}min';
  }
}

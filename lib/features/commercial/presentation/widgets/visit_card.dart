import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/models.dart';

/// Visit card widget for daily jobs list
class VisitCard extends StatelessWidget {
  final VisitModel visit;
  final VoidCallback? onTap;
  final VoidCallback? onStart;
  final VoidCallback? onComplete;
  final VoidCallback? onNavigate;

  const VisitCard({
    super.key,
    required this.visit,
    this.onTap,
    this.onStart,
    this.onComplete,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = visit.status == VisitStatus.inProgress;
    final isCompleted = visit.status == VisitStatus.completed;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isActive
                ? ColorManager.primaryColor.withOpacity(0.05)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isActive
                ? Border.all(color: ColorManager.primaryColor, width: 2)
                : null,
            boxShadow: ColorManager.lightCardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Status indicator
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: visit.statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Time
                  Text(
                    '${visit.plannedDate.hour.toString().padLeft(2, '0')}:${visit.plannedDate.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isActive
                          ? ColorManager.primaryColor
                          : ColorManager.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: visit.statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      visit.statusLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: visit.statusColor,
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Sort order
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: ColorManager.surfaceColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${visit.sortOrder + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Client name
              Text(
                visit.clientName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ColorManager.textPrimary,
                ),
              ),
              const SizedBox(height: 4),

              // Address
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      visit.clientAddress,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // Duration (if completed)
              if (isCompleted && visit.durationMinutes != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${visit.durationMinutes} min',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    if (visit.orderIds.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Icon(
                        Icons.shopping_cart,
                        size: 16,
                        color: ColorManager.secondaryVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${visit.orderIds.length} commande(s)',
                        style: TextStyle(
                          fontSize: 13,
                          color: ColorManager.secondaryVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ],

              const SizedBox(height: 12),

              // Action buttons
              Row(
                children: [
                  // Navigate button
                  if (onNavigate != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onNavigate,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ColorManager.primaryColor,
                          side: const BorderSide(
                            color: ColorManager.primaryColor,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.navigation, size: 18),
                        label: const Text('Naviguer'),
                      ),
                    ),

                  if (onNavigate != null &&
                      (onStart != null || onComplete != null))
                    const SizedBox(width: 8),

                  // Start/Complete button
                  if (onStart != null)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onStart,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorManager.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('Démarrer'),
                      ),
                    ),

                  if (onComplete != null)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onComplete,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorManager.secondaryVariant,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Terminer'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

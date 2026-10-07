import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/models.dart';

/// Client info card shown on map when client is selected
class ClientInfoCard extends StatelessWidget {
  final ClientModel client;
  final VoidCallback? onClose;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;
  final VoidCallback? onNavigate;
  final VoidCallback? onStartVisit;

  const ClientInfoCard({
    super.key,
    required this.client,
    this.onClose,
    this.onCall,
    this.onWhatsApp,
    this.onNavigate,
    this.onStartVisit,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              // Category indicator
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: client.categoryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (client.category == ClientCategory.vip)
                      const Icon(Icons.star, size: 14, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      client.categoryLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: client.categoryColor,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Last visit indicator
              if (client.lastVisitDate != null)
                Text(
                  'Il y a ${client.daysSinceLastVisit} jours',
                  style: TextStyle(
                    fontSize: 11,
                    color: client.needsVisit ? Colors.orange : Colors.grey[600],
                  ),
                ),

              const SizedBox(width: 8),

              // Close button
              if (onClose != null)
                InkWell(
                  onTap: onClose,
                  borderRadius: BorderRadius.circular(12),
                  child: const Icon(Icons.close, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Client name
          Text(
            client.businessName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ColorManager.textPrimary,
            ),
          ),
          const SizedBox(height: 4),

          // Contact person
          Row(
            children: [
              Icon(Icons.person_outline, size: 16, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                client.contactPerson,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
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
                  client.address,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Credit info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ColorManager.surfaceColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Crédit en cours',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      Text(
                        '${client.currentCredit.toStringAsFixed(0)} TND',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: client.currentCredit > client.creditLimit * 0.8
                              ? Colors.red
                              : ColorManager.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 30, color: Colors.grey[300]),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Limite crédit',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      Text(
                        '${client.creditLimit.toStringAsFixed(0)} TND',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: ColorManager.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              // Call button
              if (onCall != null)
                Expanded(
                  child: _ActionButton(
                    icon: Icons.phone,
                    label: 'Appeler',
                    color: ColorManager.primaryColor,
                    onTap: onCall!,
                  ),
                ),

              const SizedBox(width: 8),

              // WhatsApp button
              if (onWhatsApp != null)
                Expanded(
                  child: _ActionButton(
                    icon: Icons.chat,
                    label: 'WhatsApp',
                    color: const Color(0xFF25D366),
                    onTap: onWhatsApp!,
                  ),
                ),

              const SizedBox(width: 8),

              // Navigate button
              if (onNavigate != null)
                Expanded(
                  child: _ActionButton(
                    icon: Icons.navigation,
                    label: 'Y aller',
                    color: Colors.orange,
                    onTap: onNavigate!,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Start visit button
          if (onStartVisit != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onStartVisit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorManager.secondaryVariant,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.play_arrow),
                label: const Text(
                  'Démarrer une visite',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

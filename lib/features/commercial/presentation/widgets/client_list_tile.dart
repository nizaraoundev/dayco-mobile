import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/models.dart';

/// Client list tile widget
class ClientListTile extends StatelessWidget {
  final ClientModel client;
  final VoidCallback? onTap;
  final VoidCallback? onNavigate;
  final VoidCallback? onCall;

  const ClientListTile({
    super.key,
    required this.client,
    this.onTap,
    this.onNavigate,
    this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: ColorManager.lightCardShadow,
          ),
          child: Row(
            children: [
              // Avatar with category color
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: client.categoryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    client.businessName.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: client.categoryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Client info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            client.businessName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: ColorManager.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (client.category == ClientCategory.vip)
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      client.contactPerson,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            client.address,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Last visit indicator
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: client.needsVisit
                                ? Colors.orange.withOpacity(0.1)
                                : ColorManager.secondaryVariant.withOpacity(
                                    0.1,
                                  ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            client.lastVisitDate != null
                                ? 'Il y a ${client.daysSinceLastVisit}j'
                                : 'Jamais visité',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: client.needsVisit
                                  ? Colors.orange
                                  : ColorManager.secondaryVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Payment terms
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: ColorManager.surfaceColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            client.paymentTermsLabel,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action buttons
              Column(
                children: [
                  if (onCall != null)
                    IconButton(
                      icon: const Icon(Icons.phone, size: 20),
                      color: ColorManager.primaryColor,
                      onPressed: onCall,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                  if (onNavigate != null)
                    IconButton(
                      icon: const Icon(Icons.navigation, size: 20),
                      color: Colors.orange,
                      onPressed: onNavigate,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
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

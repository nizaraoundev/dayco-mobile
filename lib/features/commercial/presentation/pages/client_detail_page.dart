import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../controllers/commercial_controller.dart';
import '../widgets/brand_selection_widget.dart';
import 'map_page.dart';

/// Client detail page
class ClientDetailPage extends StatelessWidget {
  final ClientModel client;

  const ClientDetailPage({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CommercialController>();

    return Scaffold(
      backgroundColor: ColorManager.backgroundColor,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: client.categoryColor,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                client.businessName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      client.categoryColor,
                      client.categoryColor.withOpacity(0.7),
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            client.businessName.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: client.categoryColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (client.category == ClientCategory.vip)
                              const Icon(
                                Icons.star,
                                size: 14,
                                color: Colors.white,
                              ),
                            const SizedBox(width: 4),
                            Text(
                              client.categoryLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(icon: const Icon(Icons.edit), onPressed: () {}),
            ],
          ),

          // Quick Actions
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.phone,
                      label: 'Appeler',
                      color: ColorManager.primaryColor,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.chat,
                      label: 'WhatsApp',
                      color: const Color(0xFF25D366),
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.navigation,
                      label: 'Y aller',
                      color: Colors.orange,
                      onTap: () => Get.to(() => MapPage(initialClient: client)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Contact Info
          SliverToBoxAdapter(
            child: _Section(
              title: 'Informations de contact',
              children: [
                _InfoRow(
                  icon: Icons.person,
                  label: 'Contact',
                  value: client.contactPerson,
                ),
                _InfoRow(
                  icon: Icons.phone,
                  label: 'Téléphone',
                  value: client.phone,
                ),
                if (client.whatsapp != null)
                  _InfoRow(
                    icon: Icons.chat,
                    label: 'WhatsApp',
                    value: client.whatsapp!,
                  ),
                _InfoRow(
                  icon: Icons.location_on,
                  label: 'Adresse',
                  value: client.address,
                ),
              ],
            ),
          ),

          // Financial Info
          SliverToBoxAdapter(
            child: _Section(
              title: 'Informations financières',
              children: [
                _InfoRow(
                  icon: Icons.payment,
                  label: 'Conditions de paiement',
                  value: client.paymentTermsLabel,
                ),
                _InfoRow(
                  icon: Icons.credit_card,
                  label: 'Crédit en cours',
                  value: '${client.currentCredit.toStringAsFixed(0)} TND',
                  valueColor: client.currentCredit > client.creditLimit * 0.8
                      ? Colors.red
                      : null,
                ),
                _InfoRow(
                  icon: Icons.account_balance,
                  label: 'Limite de crédit',
                  value: '${client.creditLimit.toStringAsFixed(0)} TND',
                ),
              ],
            ),
          ),

          // Visit Info
          SliverToBoxAdapter(
            child: _Section(
              title: 'Informations de visite',
              children: [
                _InfoRow(
                  icon: Icons.calendar_today,
                  label: 'Dernière visite',
                  value: client.lastVisitDate != null
                      ? 'Il y a ${client.daysSinceLastVisit} jours'
                      : 'Jamais visité',
                  valueColor: client.needsVisit ? Colors.orange : null,
                ),
                _InfoRow(
                  icon: Icons.repeat,
                  label: 'Fréquence de visite',
                  value: 'Tous les ${client.visitFrequencyDays} jours',
                ),
              ],
            ),
          ),

          // Available Car Brands
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: ColorManager.lightCardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Marques automobiles',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: ColorManager.textSecondary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () => _showBrandSelectionDialog(
                            context,
                            client,
                            controller,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    BrandDisplayWidget(
                      brands: client.availableBrands,
                      onEdit: () => _showBrandSelectionDialog(
                        context,
                        client,
                        controller,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Notes
          if (client.notes != null && client.notes!.isNotEmpty)
            SliverToBoxAdapter(
              child: _Section(
                title: 'Notes',
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ColorManager.surfaceColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      client.notes!,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),

          // Recent Orders
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Dernières commandes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text('Voir tout'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Placeholder for orders
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: ColorManager.lightCardShadow,
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Aucune commande récente',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Visit History
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Historique des visites',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text('Voir tout'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: ColorManager.lightCardShadow,
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.history,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Aucun historique',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Start visit
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
            'Visite démarrée',
            'Visite chez ${client.businessName}',
            backgroundColor: ColorManager.secondaryVariant,
            colorText: Colors.white,
          );
        },
        backgroundColor: ColorManager.primaryColor,
        icon: const Icon(Icons.play_arrow, color: Colors.white),
        label: const Text(
          'Démarrer une visite',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// Show brand selection dialog
  void _showBrandSelectionDialog(
    BuildContext context,
    ClientModel client,
    CommercialController controller,
  ) {
    Get.bottomSheet(
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                BrandSelectionWidget(
                  initialBrands: client.availableBrands,
                  onBrandsChanged: (brands) {
                    // Update the client with new brands
                    final updatedClient = client.copyWith(
                      availableBrands: brands,
                      updatedAt: DateTime.now(),
                      syncStatus: 'pending',
                    );
                    // TODO: Save this updated client to the database
                    // For now, just update in memory
                  },
                  isEditing: true,
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: Get.back,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.close, size: 18),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
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

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: ColorManager.lightCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: ColorManager.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? ColorManager.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

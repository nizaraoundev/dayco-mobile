import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../data/services/sync_service.dart';
import '../controllers/commercial_controller.dart';
import '../widgets/stats_card.dart';
import '../widgets/visit_card.dart';
import '../widgets/quick_action_button.dart';
import '../widgets/sync_indicator.dart';
import '../pages/map_page.dart';
import '../pages/clients_page.dart';
import '../pages/products_page.dart';
import '../pages/orders_page.dart';

/// Main dashboard for commercial app
class CommercialDashboardPage extends StatelessWidget {
  const CommercialDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CommercialController>();
    final syncService = Get.find<SyncService>();

    return Scaffold(
      backgroundColor: ColorManager.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => controller.refreshData(),
          color: ColorManager.primaryColor,
          child: CustomScrollView(
            slivers: [
              // App Bar
              SliverAppBar(
                expandedHeight: 120,
                floating: true,
                pinned: true,
                backgroundColor: ColorManager.primaryColor,
                flexibleSpace: FlexibleSpaceBar(
                  title: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bonjour, Commercial 👋',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getGreeting(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                ),
                actions: [
                  // Sync indicator
                  Obx(
                    () => SyncIndicator(
                      isOnline: syncService.isOnline.value,
                      isSyncing: syncService.isSyncing.value,
                      pendingCount: syncService.syncSummary.value.totalPending,
                      onTap: () => syncService.syncAll(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                    ),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              // Stats Cards
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Obx(
                    () => Row(
                      children: [
                        Expanded(
                          child: StatsCard(
                            title: 'Visites',
                            value:
                                '${controller.completedVisitsToday.value}/${controller.todayVisits.length}',
                            subtitle: 'Terminées',
                            icon: Icons.location_on,
                            color: ColorManager.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatsCard(
                            title: 'Ventes',
                            value:
                                '${controller.todaySales.value.toStringAsFixed(0)} TND',
                            subtitle: "Aujourd'hui",
                            icon: Icons.shopping_cart,
                            color: ColorManager.secondaryVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatsCard(
                            title: 'Clients',
                            value: '${controller.vipClients.length}',
                            subtitle: 'VIP',
                            icon: Icons.star,
                            color: ColorManager.tertiaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Quick Actions
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Actions rapides',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: ColorManager.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: QuickActionButton(
                              icon: Icons.map,
                              label: 'Carte',
                              color: ColorManager.primaryColor,
                              onTap: () => Get.to(() => const MapPage()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: QuickActionButton(
                              icon: Icons.route,
                              label: 'Itinéraire',
                              color: ColorManager.secondaryColor,
                              onTap: () async {
                                await controller.generateOptimizedRoute();
                                Get.to(() => const MapPage());
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: QuickActionButton(
                              icon: Icons.add_business,
                              label: 'Client',
                              color: ColorManager.tertiaryColor,
                              onTap: () => _showAddClientDialog(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: QuickActionButton(
                              icon: Icons.receipt_long,
                              label: 'Commande',
                              color: ColorManager.secondaryVariant,
                              onTap: () => Get.to(() => const OrdersPage()),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Today's Visits
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Visites d'aujourd'hui",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: ColorManager.textPrimary,
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text('Voir tout'),
                      ),
                    ],
                  ),
                ),
              ),

              // Visits List
              Obx(() {
                if (controller.isLoading.value) {
                  return const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (controller.todayVisits.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Aucune visite planifiée pour aujourd'hui",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final visit = controller.todayVisits[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: VisitCard(
                          visit: visit,
                          onTap: () => _showVisitDetails(context, visit),
                          onStart: visit.status == VisitStatus.planned
                              ? () => controller.startVisit(visit)
                              : null,
                          onComplete: visit.status == VisitStatus.inProgress
                              ? () => _showCompleteVisitDialog(context, visit)
                              : null,
                          onNavigate: () {
                            final client = controller.clients.firstWhere(
                              (c) => c.id == visit.clientId,
                            );
                            Get.to(() => MapPage(initialClient: client));
                          },
                        ),
                      );
                    }, childCount: controller.todayVisits.length),
                  ),
                );
              }),

              // Bottom padding
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),

      // Bottom Navigation
      bottomNavigationBar: _buildBottomNav(),

      // FAB
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await controller.generateOptimizedRoute();
          Get.to(() => const MapPage());
        },
        backgroundColor: ColorManager.primaryColor,
        icon: const Icon(Icons.route, color: Colors.white),
        label: const Text(
          'Démarrer',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bonne matinée!';
    if (hour < 18) return 'Bon après-midi!';
    return 'Bonne soirée!';
  }

  Widget _buildBottomNav() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.home,
                    color: ColorManager.primaryColor,
                  ),
                  onPressed: () {},
                  tooltip: 'Accueil',
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.people_outline),
                  onPressed: () => Get.to(() => const ClientsPage()),
                  tooltip: 'Clients',
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.inventory_2_outlined),
                  onPressed: () => Get.to(() => const ProductsPage()),
                  tooltip: 'Produits',
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.person_outline),
                  onPressed: () {},
                  tooltip: 'Profil',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddClientDialog(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('Nouveau client'),
        content: const Text('Fonctionnalité en cours de développement'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showVisitDetails(BuildContext context, VisitModel visit) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: visit.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    visit.statusLabel,
                    style: TextStyle(
                      color: visit.statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              visit.clientName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    visit.clientAddress,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Planifiée à ${visit.plannedDate.hour.toString().padLeft(2, '0')}:${visit.plannedDate.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            if (visit.notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Notes',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...visit.notes.map(
                (note) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: note.tagColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          note.tagLabel,
                          style: TextStyle(fontSize: 10, color: note.tagColor),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(note.content)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Get.back();
                  final controller = Get.find<CommercialController>();
                  final client = controller.clients.firstWhere(
                    (c) => c.id == visit.clientId,
                  );
                  Get.to(() => MapPage(initialClient: client));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorManager.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Naviguer vers ce client',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCompleteVisitDialog(BuildContext context, VisitModel visit) {
    final outcomeController = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: const Text('Terminer la visite'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: outcomeController,
              decoration: const InputDecoration(
                labelText: 'Résultat de la visite',
                hintText: 'Ex: Commande passée, RDV pris...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              Get.find<CommercialController>().completeVisit(
                visit,
                outcome: outcomeController.text,
              );
              Get.back();
              Get.snackbar(
                'Visite terminée',
                'La visite a été enregistrée avec succès',
                backgroundColor: ColorManager.secondaryVariant,
                colorText: Colors.white,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorManager.primaryColor,
            ),
            child: const Text(
              'Terminer',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

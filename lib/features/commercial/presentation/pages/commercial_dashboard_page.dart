import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/shared/widget/app_bar/dayco_app_bar.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/commercial_order_models.dart';
import '../../data/services/sync_service.dart';
import '../controllers/commercial_controller.dart';
import '../controllers/commercial_dashboard_controller.dart';
import '../widgets/order_palette.dart';
import '../widgets/stats_card.dart';
import '../widgets/quick_action_button.dart';
import '../widgets/sync_indicator.dart';
import '../pages/map_page.dart';
import '../pages/clients_page.dart';
import '../pages/products_page.dart';
import '../pages/orders_page.dart';
import '../../../../core/theme/dayco_colors.dart';

/// Main dashboard for commercial app
class CommercialDashboardPage extends StatelessWidget {
  const CommercialDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CommercialController>();
    final syncService = Get.find<SyncService>();
    final dashboard = Get.isRegistered<CommercialDashboardController>()
        ? Get.find<CommercialDashboardController>()
        : Get.put(CommercialDashboardController());

    return Scaffold(
      backgroundColor: ColorManager.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await dashboard.refreshDashboard();
            controller.refreshData();
          },
          color: ColorManager.primaryColor,
          child: CustomScrollView(
            slivers: [
              // App Bar
              DaycoSliverAppBar(
                expandedHeight: 120,
                pinned: true,
                flexibleContent: FlexibleSpaceBar(
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

              // Stats Cards — every figure below is one the backend counted.
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Obx(
                    () => Row(
                      children: [
                        Expanded(
                          child: StatsCard(
                            title: 'Commandes',
                            value: dashboard.hasOrderError.value
                                ? '—'
                                : '${dashboard.ordersEnAttente.value}',
                            subtitle: dashboard.hasOrderError.value
                                ? 'Indisponible'
                                : 'En attente',
                            icon: Icons.receipt_long,
                            color: ColorManager.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatsCard(
                            title: 'Stock',
                            value: dashboard.hasStockError.value
                                ? '—'
                                : '${dashboard.stockAlertCount.value}',
                            subtitle: dashboard.hasStockError.value
                                ? 'Indisponible'
                                : 'En alerte',
                            icon: Icons.inventory_2_outlined,
                            color: ColorManager.secondaryVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatsCard(
                            title: 'Clients',
                            value: dashboard.hasClientError.value
                                ? '—'
                                : '${dashboard.clientCount.value}',
                            subtitle: dashboard.hasClientError.value
                                ? 'Indisponible'
                                : 'Rattachés',
                            icon: Icons.people_outline,
                            color: ColorManager.tertiaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // The rest of the order pipeline, which does not need a tile
              // each but is the shape of a commercial's week.
              SliverToBoxAdapter(
                child: Obx(() {
                  if (dashboard.hasOrderError.value) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        _PipelineChip(
                          label: 'En préparation',
                          count: dashboard.ordersEnPreparation.value,
                        ),
                        const SizedBox(width: 8),
                        _PipelineChip(
                          label: 'Expédiées',
                          count: dashboard.ordersExpediees.value,
                        ),
                        const SizedBox(width: 8),
                        _PipelineChip(
                          label: 'Livrées',
                          count: dashboard.ordersLivrees.value,
                        ),
                      ],
                    ),
                  );
                }),
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

              // Recent orders. This section used to list today's visits from
              // sample data; there is no visits endpoint on this backend, so
              // it shows the latest real orders instead of inventing a day.
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Commandes récentes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: ColorManager.textPrimary,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Get.to(() => const OrdersPage()),
                        child: const Text('Voir tout'),
                      ),
                    ],
                  ),
                ),
              ),

              // Recent orders list
              Obx(() {
                if (dashboard.isLoading.value &&
                    dashboard.recentOrders.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }

                if (dashboard.isAuthError.value) {
                  return SliverToBoxAdapter(
                    child: _DashboardNotice(
                      icon: Icons.lock_outline,
                      message:
                          'Session expirée. Reconnectez-vous à '
                          "l'application pour voir vos chiffres.",
                      onRetry: dashboard.refreshDashboard,
                    ),
                  );
                }

                if (dashboard.hasOrderError.value) {
                  return SliverToBoxAdapter(
                    child: _DashboardNotice(
                      icon: Icons.cloud_off_outlined,
                      message: 'Les commandes n\'ont pas pu être chargées.',
                      onRetry: dashboard.refreshDashboard,
                    ),
                  );
                }

                if (dashboard.recentOrders.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: context.dayco.textTertiary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Aucune commande enregistrée.',
                            style: TextStyle(
                              fontSize: 16,
                              color: context.dayco.textSecondary,
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
                      final order = dashboard.recentOrders[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RecentOrderTile(
                          order: order,
                          onTap: () => Get.to(() => const OrdersPage()),
                        ),
                      );
                    }, childCount: dashboard.recentOrders.length),
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
}

/// One count from the order pipeline. Smaller than a stat card because these
/// are context for the figure above, not figures to act on.
class _PipelineChip extends StatelessWidget {
  final String label;
  final int count;

  const _PipelineChip({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: ColorManager.cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ColorManager.lightGrey2),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: ColorManager.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                color: ColorManager.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A recent order, as a line on the dashboard: number, client, status, total.
class _RecentOrderTile extends StatelessWidget {
  final CommercialOrder order;
  final VoidCallback onTap;

  const _RecentOrderTile({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = OrderPalette.forStatus(order.status);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ColorManager.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ColorManager.lightGrey2),
        ),
        child: Row(
          children: [
            Container(width: 3, height: 34, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.numeroCommande,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: ColorManager.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    order.clientRaisonSociale,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: ColorManager.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${order.montantTtc.toStringAsFixed(0)} DT',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: ColorManager.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  OrderPalette.labelFor(order.status).toUpperCase(),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Why a section of the dashboard is empty, with the way to try again. A
/// figure that could not be read says so; it does not show a zero.
class _DashboardNotice extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback onRetry;

  const _DashboardNotice({
    required this.icon,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icon, size: 40, color: ColorManager.textTertiary),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: ColorManager.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}

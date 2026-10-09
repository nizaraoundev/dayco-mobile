import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/commercial_controller.dart';
import '../widgets/client_list_tile.dart';
import 'client_detail_page.dart';
import 'map_page.dart';

/// Clients list page
class ClientsPage extends StatelessWidget {
  const ClientsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CommercialController>();
    final searchController = TextEditingController();

    return Scaffold(
      backgroundColor: ColorManager.backgroundColor,
      appBar: AppBar(
        title: const Text('Mes Clients B2B'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: () => Get.to(() => const MapPage()),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: searchController,
              onChanged: (value) => controller.searchQuery.value = value,
              decoration: InputDecoration(
                hintText: 'Rechercher un client...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: Obx(() {
                  if (controller.searchQuery.value.isNotEmpty) {
                    return IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchController.clear();
                        controller.searchQuery.value = '';
                      },
                    );
                  }
                  return const SizedBox.shrink();
                }),
                filled: true,
                fillColor: ColorManager.surfaceColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),

          // Stats summary
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Obx(
              () => Row(
                children: [
                  _StatBadge(
                    label: 'Total',
                    count: controller.clients.length,
                    color: ColorManager.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  _StatBadge(
                    label: 'VIP',
                    count: controller.vipClients.length,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 8),
                  _StatBadge(
                    label: 'À visiter',
                    count: controller.clientsNeedingVisit.length,
                    color: Colors.orange,
                  ),
                ],
              ),
            ),
          ),

          // Client list
          Expanded(
            child: Obx(() {
              final clients = controller.filteredClients;

              if (clients.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Aucun client trouvé',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: clients.length,
                itemBuilder: (context, index) {
                  final client = clients[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ClientListTile(
                      client: client,
                      onTap: () =>
                          Get.to(() => ClientDetailPage(client: client)),
                      onNavigate: () =>
                          Get.to(() => MapPage(initialClient: client)),
                      onCall: () => _launchPhone(client.phone),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddClientDialog(context),
        backgroundColor: ColorManager.primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Nouveau client',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
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
            const Text(
              'Filtrer les clients',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // Category filter
            const Text(
              'Catégorie',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Tous'),
                  selected: true,
                  onSelected: (_) {},
                ),
                FilterChip(
                  label: const Text('VIP'),
                  selected: false,
                  onSelected: (_) {},
                ),
                FilterChip(
                  label: const Text('Standard'),
                  selected: false,
                  onSelected: (_) {},
                ),
                FilterChip(
                  label: const Text('Prospect'),
                  selected: false,
                  onSelected: (_) {},
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Visit filter
            const Text(
              'Visites',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('À visiter'),
                  selected: false,
                  onSelected: (_) {},
                ),
                FilterChip(
                  label: const Text('Récemment visités'),
                  selected: false,
                  onSelected: (_) {},
                ),
              ],
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Get.back(),
                    child: const Text('Réinitialiser'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Get.back(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorManager.primaryColor,
                    ),
                    child: const Text(
                      'Appliquer',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
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
        title: const Text('Nouveau client B2B'),
        content: const Text(
          'La création de client sera disponible dans une prochaine version.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('OK')),
        ],
      ),
    );
  }

  void _launchPhone(String phone) {
    Get.snackbar(
      'Appel',
      'Appel vers $phone',
      backgroundColor: ColorManager.primaryColor,
      colorText: Colors.white,
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}

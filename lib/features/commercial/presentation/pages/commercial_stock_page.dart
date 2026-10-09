import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/commercial_stock_models.dart';
import '../controllers/commercial_stock_controller.dart';

class CommercialStockPage extends StatefulWidget {
  const CommercialStockPage({super.key});

  @override
  State<CommercialStockPage> createState() => _CommercialStockPageState();
}

class _CommercialStockPageState extends State<CommercialStockPage> {
  late final CommercialStockController controller;
  late final TextEditingController searchController;
  late final TextEditingController warehouseController;

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<CommercialStockController>()
        ? Get.find<CommercialStockController>()
        : Get.put(CommercialStockController());

    searchController = TextEditingController(
      text: controller.searchQuery.value,
    );
    warehouseController = TextEditingController(
      text: controller.warehouseFilter.value,
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    warehouseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorManager.backgroundColor,
      appBar: AppBar(
        title: const Text('Stock Commercial'),
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(child: _buildStockList()),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            onChanged: controller.setSearchQuery,
            decoration: InputDecoration(
              hintText: 'Rechercher référence / produit / fabricant',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildStockList() {
    return Obx(() {
      if (controller.isLoading.value && controller.stocks.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      if (controller.errorMessage.value != null && controller.stocks.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 42),
                const SizedBox(height: 8),
                Text(
                  controller.errorMessage.value!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: controller.refreshStocks,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _showStockLoginSheet,
                  icon: const Icon(Icons.login),
                  label: const Text('Connexion stock'),
                ),
              ],
            ),
          ),
        );
      }

      if (controller.stocks.isEmpty) {
        return const Center(child: Text('Aucun produit trouvé.'));
      }

      return RefreshIndicator(
        onRefresh: controller.refreshStocks,
        child: ListView.builder(
          controller: controller.scrollController,
          padding: const EdgeInsets.all(12),
          itemCount:
              controller.stocks.length + (controller.hasMore.value ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= controller.stocks.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final stock = controller.stocks[index];
            return _StockCard(
              stock: stock,
              onReservationsTap: () => _showReservationsSheet(stock),
              onAvailabilityTap: () => _showAvailabilityDialog(stock),
            );
          },
        ),
      );
    });
  }

  Future<void> _showReservationsSheet(CommercialStockItem stock) async {
    controller.loadReservationsForStock(stock);

    await Get.bottomSheet(
      SafeArea(
        child: Container(
          height: Get.height * 0.70,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.pending_actions),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Réservations en attente - ${stock.referenceProduit}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Obx(() {
                  if (controller.isLoadingReservations.value) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (controller.reservationError.value != null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Text(
                          controller.reservationError.value!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    );
                  }

                  if (controller.reservations.isEmpty) {
                    return const Center(
                      child: Text(
                        'Aucune réservation en attente pour ce produit.',
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                    itemBuilder: (_, index) {
                      final reservation = controller.reservations[index];
                      return _ReservationTile(reservation: reservation);
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemCount: controller.reservations.length,
                  );
                }),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Future<void> _showAvailabilityDialog(CommercialStockItem stock) async {
    final qtyController = TextEditingController(text: '1');

    await showDialog<void>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Vérifier disponibilité'),
          content: TextField(
            controller: qtyController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Quantité demandée',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final qty = int.tryParse(qtyController.text.trim()) ?? 0;
                if (qty <= 0) {
                  Get.snackbar(
                    'Disponibilité',
                    'Veuillez entrer une quantité valide.',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                  return;
                }

                final result = await controller.checkAvailability(
                  stock: stock,
                  quantite: qty,
                );

                if (!mounted) {
                  return;
                }

                Navigator.pop(context);

                if (result == null) {
                  return;
                }

                Get.dialog(
                  AlertDialog(
                    title: const Text('Résultat disponibilité'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Statut: ${_displayStockStatus(result.statut)}'),
                        const SizedBox(height: 4),
                        Text(
                          'Disponible: ${result.disponible ? 'Oui' : 'Non'}',
                        ),
                        const SizedBox(height: 4),
                        Text('Qté disponible: ${result.quantiteDisponible}'),
                        const SizedBox(height: 4),
                        Text('Message: ${result.message}'),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: Get.back,
                        child: const Text('Fermer'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Vérifier'),
            ),
          ],
        );
      },
    );

    qtyController.dispose();
  }

  Future<void> _showStockLoginSheet() async {
    final codeClientController = TextEditingController();
    final passwordController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeClientController,
                decoration: const InputDecoration(
                  labelText: 'Code client / email',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mot de passe'),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final codeClient = codeClientController.text.trim();
                    final password = passwordController.text;

                    if (codeClient.isEmpty || password.isEmpty) {
                      Get.snackbar(
                        'Connexion stock',
                        'Code client et mot de passe sont requis.',
                        backgroundColor: Colors.red,
                        colorText: Colors.white,
                      );
                      return;
                    }

                    await controller.loginForStocks(
                      codeClient: codeClient,
                      password: password,
                    );

                    if (mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Se connecter'),
                ),
              ),
            ],
          ),
        );
      },
    );

    codeClientController.dispose();
    passwordController.dispose();
  }
}

class _StockCard extends StatelessWidget {
  final CommercialStockItem stock;
  final VoidCallback onReservationsTap;
  final VoidCallback onAvailabilityTap;

  const _StockCard({
    required this.stock,
    required this.onReservationsTap,
    required this.onAvailabilityTap,
  });

  Color _statusColor(String status) {
    if (_isHorsStockStatus(status)) {
      return Colors.red;
    }
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    stock.referenceProduit,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(stock.statut).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _displayStockStatus(stock.statut),
                    style: TextStyle(
                      color: _statusColor(stock.statut),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              stock.designationProduit,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              'Fabricant: ${stock.fabricant}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  label: 'Prix HT',
                  value: stock.prixHt.toStringAsFixed(2),
                ),
                _InfoChip(label: 'Qté', value: stock.quantite.toString()),
                _InfoChip(
                  label: 'Réservée',
                  value: stock.quantiteReservee.toString(),
                ),
                _InfoChip(
                  label: 'Disponible',
                  value: stock.quantiteDisponible.toString(),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 12, color: Colors.black87),
      ),
    );
  }
}

class _ReservationTile extends StatelessWidget {
  final CommercialPendingReservation reservation;

  const _ReservationTile({required this.reservation});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reservation.clientRaisonSociale,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text('Commande: ${reservation.numeroCommande}'),
          Text(
            'Qté initiale: ${reservation.quantiteInitiale} | Restante: ${reservation.quantiteRestante}',
          ),
          Text('Utilisateur: ${reservation.utilisateur}'),
          Text('Date création: ${reservation.dateCreation}'),
        ],
      ),
    );
  }
}

bool _isHorsStockStatus(String? rawStatus) {
  final normalized = (rawStatus ?? '').toUpperCase().trim();
  return normalized.contains('HORS') || normalized.contains('RUPTURE');
}

String _displayStockStatus(String? rawStatus) {
  return _isHorsStockStatus(rawStatus) ? 'HORS STOCK' : 'DISPONIBLE';
}

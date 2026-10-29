import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/commercial_order_models.dart';
import '../../data/models/commercial_stock_models.dart';
import '../controllers/commercial_order_draft_controller.dart';
import '../controllers/commercial_orders_controller.dart';
import '../widgets/stock_palette.dart';
import '../../../../core/shared/widget/app_bar/dayco_app_bar.dart';

/// Writes a new order and posts it to `/api/v1/commandes`.
///
/// The products offered are stock rows, so what is available shows while the
/// line is being added — the one thing a commercial needs to know before
/// promising a quantity to a client.
class NewOrderPage extends StatefulWidget {
  const NewOrderPage({super.key});

  @override
  State<NewOrderPage> createState() => _NewOrderPageState();
}

class _NewOrderPageState extends State<NewOrderPage> {
  late final CommercialOrderDraftController controller;

  /// Tags this screen's draft, so opening the screen twice gives two drafts
  /// rather than one that the second visit quietly took over.
  late final String _draftTag;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _clientReferenceController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    // A draft is per visit to this screen: a half-written order left behind
    // from last time is not something a commercial should have to notice.
    _draftTag = DateTime.now().microsecondsSinceEpoch.toString();
    controller = Get.put(CommercialOrderDraftController(), tag: _draftTag);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _commentController.dispose();
    _clientReferenceController.dispose();
    Get.delete<CommercialOrderDraftController>(tag: _draftTag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorManager.backgroundColor,
      appBar: DaycoAppBar(
        titleText: 'Nouvelle commande',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          _buildSection(title: 'Client', child: _buildClientPicker()),
          const SizedBox(height: 14),
          _buildSection(title: 'Produits', child: _buildProductSection()),
          const SizedBox(height: 14),
          _buildSection(title: 'Livraison', child: _buildDeliverySection()),
          const SizedBox(height: 14),
          _buildSection(title: 'Références', child: _buildReferenceSection()),
          const SizedBox(height: 14),
          _buildTotals(),
        ],
      ),
      bottomNavigationBar: _buildSubmitBar(),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColorManager.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorManager.lightGrey2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: ColorManager.textTertiary,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  // --- Client --------------------------------------------------------------

  Widget _buildClientPicker() {
    return Obx(() {
      if (controller.isLoadingClients.value) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text(
                'Chargement de vos clients…',
                style: TextStyle(
                  fontSize: 12.5,
                  color: ColorManager.textSecondary,
                ),
              ),
            ],
          ),
        );
      }

      final error = controller.clientsError.value;
      if (error != null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              error,
              style: const TextStyle(
                fontSize: 12.5,
                color: ColorManager.errorColor,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: controller.loadClients,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Réessayer'),
            ),
          ],
        );
      }

      final selected = controller.selectedClient.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: controller.clients.isEmpty ? null : _showClientPicker,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: ColorManager.greybg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ColorManager.lightGrey2),
              ),
              child: Row(
                children: [
                  Icon(
                    selected == null
                        ? Icons.person_search_outlined
                        : Icons.person,
                    size: 18,
                    color: selected == null
                        ? ColorManager.textTertiary
                        : ColorManager.primaryColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selected == null
                          ? 'Choisir un client'
                          : controller.clientDisplayName(selected),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: selected == null
                            ? FontWeight.w500
                            : FontWeight.w700,
                        color: selected == null
                            ? ColorManager.textSecondary
                            : ColorManager.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: ColorManager.textTertiary,
                  ),
                ],
              ),
            ),
          ),
          if (controller.clients.isEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Aucun client rattaché à votre compte.',
              style: TextStyle(fontSize: 12, color: ColorManager.textSecondary),
            ),
          ],
        ],
      );
    });
  }

  Future<void> _showClientPicker() async {
    final query = ''.obs;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ColorManager.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  child: TextField(
                    autofocus: true,
                    onChanged: (value) => query.value = value,
                    decoration: InputDecoration(
                      hintText: 'Rechercher un client',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Obx(() {
                    final needle = query.value.trim().toLowerCase();
                    final matches = needle.isEmpty
                        ? controller.clients.toList()
                        : controller.clients.where((client) {
                            final name = controller
                                .clientDisplayName(client)
                                .toLowerCase();
                            final code = (client['codeClient'] ?? '')
                                .toString()
                                .toLowerCase();
                            return name.contains(needle) ||
                                code.contains(needle);
                          }).toList();

                    if (matches.isEmpty) {
                      return const Center(
                        child: Text(
                          'Aucun client ne correspond.',
                          style: TextStyle(color: ColorManager.textSecondary),
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      itemCount: matches.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final client = matches[index];
                        final code = (client['codeClient'] ?? '')
                            .toString()
                            .trim();

                        return ListTile(
                          title: Text(
                            controller.clientDisplayName(client),
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: code.isEmpty ? null : Text(code),
                          onTap: () {
                            controller.selectClient(client);
                            Navigator.pop(sheetContext);
                          },
                        );
                      },
                    );
                  }),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Products ------------------------------------------------------------

  Widget _buildProductSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: controller.setProductQuery,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Rechercher une référence à ajouter',
            prefixIcon: const Icon(Icons.search),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        Obx(() {
          if (controller.isSearching.value) {
            return const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          final error = controller.searchError.value;
          if (error != null) {
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                error,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: ColorManager.errorColor,
                ),
              ),
            );
          }

          if (controller.searchResults.isEmpty) {
            return const SizedBox.shrink();
          }

          return Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              children: [
                for (final stock in controller.searchResults)
                  _SearchResultTile(
                    stock: stock,
                    onAdd: () => _addProduct(stock),
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 4),
        Obx(() {
          if (controller.lines.isEmpty) {
            return const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Aucun produit sur cette commande.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: ColorManager.textSecondary,
                ),
              ),
            );
          }

          return Column(
            children: [
              const SizedBox(height: 8),
              const Divider(height: 1),
              for (var index = 0; index < controller.lines.length; index++)
                _DraftLineTile(
                  line: controller.lines[index],
                  onQuantityChanged: (value) =>
                      controller.setLineQuantity(index, value),
                  onDiscountTap: () => _editDiscount(index),
                  onRemove: () => controller.removeLine(index),
                ),
            ],
          );
        }),
      ],
    );
  }

  void _addProduct(CommercialStockItem stock) {
    controller.addLine(stock);
    _searchController.clear();
    controller.setProductQuery('');
    HapticFeedback.selectionClick();
  }

  Future<void> _editDiscount(int index) async {
    final line = controller.lines[index];
    final textController = TextEditingController(
      text: line.remisePourcentage == 0
          ? ''
          : line.remisePourcentage.toStringAsFixed(
              line.remisePourcentage.truncateToDouble() ==
                      line.remisePourcentage
                  ? 0
                  : 2,
            ),
    );

    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remise de ligne'),
          content: TextField(
            controller: textController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(suffixText: '%', hintText: '0'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                final parsed =
                    double.tryParse(textController.text.replaceAll(',', '.')) ??
                    0;
                Navigator.pop(dialogContext, parsed);
              },
              child: const Text('Appliquer'),
            ),
          ],
        );
      },
    );

    textController.dispose();

    if (value != null) {
      controller.setLineDiscount(index, value);
    }
  }

  // --- Delivery ------------------------------------------------------------

  Widget _buildDeliverySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Obx(() {
          final mode = controller.deliveryMode.value;

          return Row(
            children: [
              for (final option in CommercialDeliveryMode.values) ...[
                Expanded(
                  child: _ModeButton(
                    label: option.label,
                    isSelected: option == mode,
                    onTap: () => controller.setDeliveryMode(option),
                  ),
                ),
                if (option != CommercialDeliveryMode.values.last)
                  const SizedBox(width: 8),
              ],
            ],
          );
        }),
        Obx(() {
          if (!controller.deliveryMode.value.needsAddress) {
            // The backend only accepts an address with a delivery, so there is
            // nothing to ask for here when the client collects.
            return const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Le client retire la commande au comptoir STDP DAYCO.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: ColorManager.textSecondary,
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                _buildField(
                  controller: _addressController,
                  label: 'Adresse de livraison',
                  onChanged: (value) =>
                      controller.adresseLivraison.value = value,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildField(
                        controller: _cityController,
                        label: 'Ville',
                        onChanged: (value) =>
                            controller.villeLivraison.value = value,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildField(
                        controller: _postalCodeController,
                        label: 'Code postal',
                        keyboardType: TextInputType.number,
                        onChanged: (value) =>
                            controller.codePostalLivraison.value = value,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
        Obx(() {
          final date = controller.dateLivraisonSouhaitee.value;

          return InkWell(
            onTap: _pickDeliveryDate,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: ColorManager.greybg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ColorManager.lightGrey2),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.event_outlined,
                    size: 18,
                    color: ColorManager.textTertiary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      date == null
                          ? 'Date de livraison souhaitée (facultatif)'
                          : '${date.day.toString().padLeft(2, '0')}'
                                '/${date.month.toString().padLeft(2, '0')}'
                                '/${date.year}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: date == null
                            ? FontWeight.w500
                            : FontWeight.w700,
                        color: date == null
                            ? ColorManager.textSecondary
                            : ColorManager.textPrimary,
                      ),
                    ),
                  ),
                  if (date != null)
                    IconButton(
                      onPressed: () => controller.setDeliveryDate(null),
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Retirer la date',
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _pickDeliveryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.dateLivraisonSouhaitee.value ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (picked != null) {
      controller.setDeliveryDate(picked);
    }
  }

  // --- References ----------------------------------------------------------

  Widget _buildReferenceSection() {
    return Column(
      children: [
        _buildField(
          controller: _clientReferenceController,
          label: 'Référence client (facultatif)',
          onChanged: (value) => controller.referenceClient.value = value,
        ),
        const SizedBox(height: 10),
        _buildField(
          controller: _commentController,
          label: 'Commentaire (facultatif)',
          maxLines: 3,
          onChanged: (value) => controller.commentaire.value = value,
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // --- Totals and submit ---------------------------------------------------

  Widget _buildTotals() {
    return Obx(() {
      // Read so this rebuilds as lines and discounts change.
      final lineCount = controller.lines.length;

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ColorManager.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ColorManager.lightGrey2),
        ),
        child: Column(
          children: [
            _TotalRow(
              label:
                  '$lineCount ligne${lineCount > 1 ? 's' : ''} · '
                  '${controller.totalQuantite} u.',
              value: '',
            ),
            const Divider(height: 18),
            _TotalRow(
              label: 'Total HT',
              value: _formatAmount(controller.totalHt),
            ),
            _TotalRow(
              label:
                  'TVA ${CommercialOrderDraftLine.tauxTva.toStringAsFixed(0)} %',
              value: _formatAmount(controller.totalTva),
            ),
            const SizedBox(height: 4),
            _TotalRow(
              label: 'Total TTC',
              value: _formatAmount(controller.totalTtc),
              emphasize: true,
            ),
          ],
        ),
      );
    });
  }

  Widget _buildSubmitBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: Obx(() {
          final error = controller.submitError.value;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error != null) ...[
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: ColorManager.errorColor,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: controller.canSubmit ? _confirmAndSubmit : null,
                  icon: controller.isSubmitting.value
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: ColorManager.white,
                          ),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: Text(
                    controller.isSubmitting.value
                        ? 'Enregistrement…'
                        : 'Enregistrer la commande',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorManager.primaryColor,
                    foregroundColor: ColorManager.white,
                    disabledBackgroundColor: ColorManager.lightGrey2,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  /// Placing the order is not undoable from this screen, so it is read back
  /// before it is sent: client, line count and total are what a commercial
  /// would want to check against what the client just said.
  Future<void> _confirmAndSubmit() async {
    final client = controller.selectedClient.value;
    if (client == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Enregistrer la commande ?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                controller.clientDisplayName(client),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                '${controller.lines.length} ligne'
                '${controller.lines.length > 1 ? 's' : ''} · '
                '${controller.totalQuantite} unités',
              ),
              const SizedBox(height: 4),
              Text(
                '${_formatAmount(controller.totalTtc)} TTC',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                controller.deliveryMode.value.commentLabel,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: ColorManager.textSecondary,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Revoir'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final order = await controller.submit();
    if (!mounted || order == null) {
      return;
    }

    // The list this order now belongs to is stale the moment it is created.
    if (Get.isRegistered<CommercialOrdersController>()) {
      await Get.find<CommercialOrdersController>().refreshOrders();
    }

    if (!mounted) {
      return;
    }

    Navigator.pop(context, order);
  }
}

/// A stock row offered as a line to add. The available quantity rides along,
/// because adding 40 units of something with 3 left is the mistake this screen
/// exists to prevent.
class _SearchResultTile extends StatelessWidget {
  final CommercialStockItem stock;
  final VoidCallback onAdd;

  const _SearchResultTile({required this.stock, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final level = stock.level;
    final color = StockPalette.forLevel(level);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ColorManager.greybg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColorManager.lightGrey2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stock.designationProduit.isEmpty
                      ? stock.referenceProduit
                      : stock.designationProduit,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ColorManager.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      stock.referenceProduit,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: ColorManager.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${stock.quantiteDisponible} dispo.',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${_formatAmount(stock.prixHt)} HT',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: ColorManager.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onAdd,
            icon: const Icon(Icons.add_circle_outline),
            color: ColorManager.primaryColor,
            tooltip: 'Ajouter',
          ),
        ],
      ),
    );
  }
}

class _DraftLineTile extends StatelessWidget {
  final CommercialOrderDraftLine line;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onDiscountTap;
  final VoidCallback onRemove;

  const _DraftLineTile({
    required this.line,
    required this.onQuantityChanged,
    required this.onDiscountTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  line.designationProduit.isEmpty
                      ? line.referenceProduit
                      : line.designationProduit,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ColorManager.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline, size: 18),
                color: ColorManager.errorColor,
                visualDensity: VisualDensity.compact,
                tooltip: 'Retirer',
              ),
            ],
          ),
          Text(
            line.referenceProduit,
            style: const TextStyle(
              fontSize: 11.5,
              color: ColorManager.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _StepperButton(
                icon: Icons.remove,
                onPressed: () => onQuantityChanged(line.quantite - 1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '${line.quantite}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: ColorManager.textPrimary,
                  ),
                ),
              ),
              _StepperButton(
                icon: Icons.add,
                onPressed: () => onQuantityChanged(line.quantite + 1),
              ),
              const Spacer(),
              TextButton(
                onPressed: onDiscountTap,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  line.remisePourcentage == 0
                      ? 'Remise'
                      : '-${_formatNumber(line.remisePourcentage)} %',
                ),
              ),
              Text(
                _formatAmount(line.totalHt),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: ColorManager.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _StepperButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
          side: const BorderSide(color: ColorManager.lightGrey2),
          foregroundColor: ColorManager.primaryColor,
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? ColorManager.primaryColor.withValues(alpha: 0.12)
              : ColorManager.greybg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? ColorManager.primaryColor
                : ColorManager.lightGrey2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? ColorManager.primaryColor
                : ColorManager.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _TotalRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: emphasize ? 13.5 : 12.5,
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
                color: emphasize
                    ? ColorManager.textPrimary
                    : ColorManager.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasize ? 16 : 13,
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
              color: ColorManager.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatAmount(double value) => '${_formatNumber(value)} DT';

String _formatNumber(double value) {
  final fixed = value.toStringAsFixed(2);
  final separator = fixed.indexOf('.');
  final units = fixed.substring(0, separator);
  final cents = fixed.substring(separator + 1);

  final grouped = StringBuffer();
  for (var i = 0; i < units.length; i++) {
    if (i > 0 && (units.length - i) % 3 == 0) {
      grouped.write(' ');
    }
    grouped.write(units[i]);
  }

  return '$grouped,$cents';
}

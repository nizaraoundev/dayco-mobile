import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/commercial_order_models.dart';
import '../controllers/commercial_orders_controller.dart';
import '../widgets/order_palette.dart';
import 'new_order_page.dart';
import '../../../../core/shared/widget/app_bar/dayco_app_bar.dart';

/// Orders, read from `/api/v1/commandes` on the live backend.
///
/// The status tabs this page used to carry were a local filter over sample
/// data; the backend filters on status itself, so they are chips that reload
/// the list and the counts next to them are the backend's own totals.
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  late final CommercialOrdersController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<CommercialOrdersController>()
        ? Get.find<CommercialOrdersController>()
        : Get.put(CommercialOrdersController());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorManager.backgroundColor,
      appBar: DaycoAppBar(
        titleText: 'Commandes',
        actions: [
          IconButton(
            onPressed: controller.refreshOrders,
            icon: const Icon(Icons.refresh),
            tooltip: 'Recharger',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(child: _buildOrderList()),
        ],
      ),
      floatingActionButton: Column(
        // The floating-action slot gives loose constraints, so a Column that
        // sizes itself to the max would claim the height of the screen.
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Obx(() {
            if (!controller.showScrollToTop.value) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FloatingActionButton.small(
                onPressed: controller.scrollToTop,
                backgroundColor: ColorManager.cardColor,
                foregroundColor: ColorManager.primaryColor,
                tooltip: 'Revenir en haut',
                heroTag: 'orders-scroll-top',
                child: const Icon(Icons.arrow_upward),
              ),
            );
          }),
          FloatingActionButton.extended(
            onPressed: _openNewOrder,
            backgroundColor: ColorManager.primaryColor,
            foregroundColor: ColorManager.white,
            heroTag: 'orders-new',
            icon: const Icon(Icons.add),
            label: const Text(
              'Nouvelle commande',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// Opens the write screen. It refreshes this list itself once an order is
  /// accepted, so the new order is in place by the time we are back here.
  Future<void> _openNewOrder() async {
    await Navigator.of(context).push(
      MaterialPageRoute<CommercialOrder>(builder: (_) => const NewOrderPage()),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: const BoxDecoration(
        color: ColorManager.cardColor,
        boxShadow: [
          BoxShadow(
            color: ColorManager.lightShadowColor,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Obx(() {
              final selected = controller.statusFilter.value;

              return Row(
                children: [
                  _buildStatusChip(null, selected),
                  for (final status in OrderPalette.filterable) ...[
                    const SizedBox(width: 8),
                    _buildStatusChip(status, selected),
                  ],
                ],
              );
            }),
          ),
          const SizedBox(height: 8),
          Obx(() {
            final shown = controller.orders.length;
            final total = controller.totalElements.value;

            // In the fallback scope the backend's total counts quotes and
            // other clients' orders too, so quoting it would overstate what
            // is on screen.
            final label = controller.isPersonalScope.value
                ? '$shown commandes'
                : (total > 0
                      ? '$shown sur $total commandes'
                      : '$shown commandes');

            return Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: ColorManager.textSecondary,
                    ),
                  ),
                ),
                if (controller.isPersonalScope.value)
                  const Tooltip(
                    message:
                        'Votre compte ne peut lister que ses propres '
                        'commandes.',
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 13,
                          color: ColorManager.textTertiary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Mes commandes',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: ColorManager.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  /// One status filter. The chip wears the colour of the status it selects, so
  /// the same reading holds in the bar and on the cards.
  Widget _buildStatusChip(
    CommercialOrderStatus? status,
    CommercialOrderStatus? selected,
  ) {
    final isSelected = status == selected;
    final color = status == null
        ? ColorManager.primaryColor
        : OrderPalette.forStatus(status);
    final label = status == null ? 'Toutes' : OrderPalette.labelFor(status);

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => controller.setStatusFilter(status),
      backgroundColor: ColorManager.greybg,
      selectedColor: color.withValues(alpha: 0.14),
      shape: StadiumBorder(
        side: BorderSide(color: isSelected ? color : ColorManager.lightGrey2),
      ),
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? color : ColorManager.textSecondary,
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildOrderList() {
    return Obx(() {
      if (controller.isLoading.value && controller.orders.isEmpty) {
        return _buildSkeletonList();
      }

      if (controller.errorMessage.value != null && controller.orders.isEmpty) {
        return _buildErrorState();
      }

      final orders = controller.orders;

      if (orders.isEmpty) {
        return _buildEmptyState();
      }

      return Column(
        children: [
          if (controller.isLoading.value)
            const LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: controller.refreshOrders,
              child: ListView.builder(
                controller: controller.scrollController,
                padding: const EdgeInsets.all(12),
                itemCount:
                    orders.length + (controller.isLoadingMore.value ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= orders.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final order = orders[index];
                  return _OrderCard(
                    order: order,
                    onTap: () => _showOrderDetail(order),
                  );
                },
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 6,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (_, __) => const _SkeletonCard(),
    );
  }

  Widget _buildErrorState() {
    final isAuthError = controller.isAuthError.value;
    final message = controller.errorMessage.value ?? 'Erreur inconnue';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isAuthError ? Icons.lock_outline : Icons.cloud_off_outlined,
                size: 44,
                color: isAuthError
                    ? OrderPalette.enAttente
                    : ColorManager.errorColor,
              ),
              const SizedBox(height: 12),
              Text(
                isAuthError ? 'Session expirée' : 'Commandes indisponibles',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: ColorManager.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: ColorManager.textSecondary,
                ),
              ),
              if (isAuthError) ...[
                const SizedBox(height: 8),
                const Text(
                  "Reconnectez-vous à l'application pour continuer.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: ColorManager.textPrimary,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: controller.refreshOrders,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Réessayer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorManager.primaryColor,
                    foregroundColor: ColorManager.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final status = controller.statusFilter.value;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 42,
              color: ColorManager.textTertiary,
            ),
            const SizedBox(height: 10),
            Text(
              status == null
                  ? 'Aucune commande.'
                  : 'Aucune commande '
                        '« ${OrderPalette.labelFor(status).toLowerCase()} ».',
              textAlign: TextAlign.center,
              style: const TextStyle(color: ColorManager.textSecondary),
            ),
            if (status != null) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => controller.setStatusFilter(null),
                icon: const Icon(Icons.close),
                label: const Text('Retirer le filtre'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The order in full: what the list card leaves out is the lines, the
  /// delivery details and the HT/TTC split, all of which the list payload
  /// already carries — so opening this costs no request.
  Future<void> _showOrderDetail(CommercialOrder order) async {
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.numeroCommande,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: ColorManager.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              order.clientRaisonSociale,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: ColorManager.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _StatusBadge(order: order),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                    children: [
                      _DetailRow(
                        label: 'Créée le',
                        value: _formatMoment(
                          order.dateCreation,
                          withTime: true,
                        ),
                      ),
                      _DetailRow(
                        label: 'Livraison souhaitée',
                        value: _formatMoment(
                          order.dateLivraisonSouhaitee,
                          withTime: false,
                        ),
                      ),
                      _DetailRow(
                        label: 'Mode de livraison',
                        value: _humanizeEnum(order.modeLivraison),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Lignes (${order.lignes.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: ColorManager.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (order.lignes.isEmpty)
                        const Text(
                          'Aucune ligne sur cette commande.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: ColorManager.textSecondary,
                          ),
                        )
                      else
                        for (final line in order.lignes)
                          _OrderLineTile(line: line),
                      const SizedBox(height: 18),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      _DetailRow(
                        label: 'Total HT',
                        value: _formatAmount(order.montantHt),
                      ),
                      _DetailRow(
                        label: 'Total TTC',
                        value: _formatAmount(order.montantTtc),
                        emphasize: true,
                      ),
                    ],
                  ),
                ),
                _buildSheetActions(order, sheetContext),
              ],
            );
          },
        );
      },
    );
  }

  /// The actions an order will take, under its details.
  ///
  /// Each one writes to the backend and none of them can be undone from this
  /// screen, so each is confirmed first and the sheet closes on success —
  /// the list behind it already holds the order as the backend returned it,
  /// which is the version worth looking at.
  Widget _buildSheetActions(CommercialOrder order, BuildContext sheetContext) {
    final canValidate = controller.canValidate(order);
    final canChangeStatus = controller.canChangeStatus(order);
    final canCancel = controller.canCancel(order);

    if (!canValidate && !canChangeStatus && !canCancel) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: ColorManager.lightGrey2)),
      ),
      child: SafeArea(
        top: false,
        child: Obx(() {
          final isBusy = controller.actingOrderId.value == order.id;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isBusy)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              Row(
                children: [
                  if (canValidate)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isBusy
                            ? null
                            : () => _validate(order, sheetContext),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Valider'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorManager.primaryColor,
                          foregroundColor: ColorManager.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  if (canValidate && canChangeStatus) const SizedBox(width: 10),
                  if (canChangeStatus)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isBusy
                            ? null
                            : () => _changeStatus(order, sheetContext),
                        icon: const Icon(Icons.swap_horiz, size: 18),
                        label: const Text('Statut'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ColorManager.primaryVariant,
                          side: const BorderSide(
                            color: ColorManager.lightGrey2,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                ],
              ),
              if (canCancel) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: isBusy
                        ? null
                        : () => _cancel(order, sheetContext),
                    icon: const Icon(Icons.block, size: 18),
                    label: const Text('Annuler la commande'),
                    style: TextButton.styleFrom(
                      foregroundColor: ColorManager.errorColor,
                    ),
                  ),
                ),
              ],
            ],
          );
        }),
      ),
    );
  }

  Future<void> _validate(
    CommercialOrder order,
    BuildContext sheetContext,
  ) async {
    final confirmed = await _confirm(
      title: 'Valider la commande',
      message: 'Valider la commande ${order.numeroCommande} ?',
      confirmLabel: 'Valider',
    );

    // The sheet can be gone by the time the dialog closes, so it is checked
    // here rather than relied on further in.
    if (confirmed != true || !sheetContext.mounted) {
      return;
    }

    await _apply(
      sheetContext,
      () => controller.validateOrder(order),
      'Commande validée',
    );
  }

  Future<void> _changeStatus(
    CommercialOrder order,
    BuildContext sheetContext,
  ) async {
    final target = await showModalBottomSheet<CommercialOrderStatus>(
      context: context,
      backgroundColor: ColorManager.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (pickerContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 18, 18, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Nouveau statut',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: ColorManager.textPrimary,
                    ),
                  ),
                ),
              ),
              for (final status
                  in CommercialOrdersController.movableStatuses) ...[
                if (status != order.status)
                  ListTile(
                    leading: Icon(
                      Icons.circle,
                      size: 12,
                      color: OrderPalette.forStatus(status),
                    ),
                    title: Text(OrderPalette.labelFor(status)),
                    onTap: () => Navigator.pop(pickerContext, status),
                  ),
              ],
            ],
          ),
        );
      },
    );

    if (target == null) {
      return;
    }

    final confirmed = await _confirm(
      title: 'Modifier le statut',
      message:
          'Passer la commande ${order.numeroCommande} en '
          '« ${OrderPalette.labelFor(target)} » ?',
      confirmLabel: 'Modifier',
    );

    if (confirmed != true || !sheetContext.mounted) {
      return;
    }

    await _apply(
      sheetContext,
      () => controller.changeStatus(order, target),
      'Statut mis à jour',
    );
  }

  /// Cancelling asks for the reason the backend stores against the order, and
  /// will not proceed without one: "Annulation admin" on every cancelled
  /// order tells whoever reads it later nothing at all.
  Future<void> _cancel(CommercialOrder order, BuildContext sheetContext) async {
    final reasonController = TextEditingController();
    final canSubmit = false.obs;

    final motif = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Annuler la commande'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Annuler définitivement la commande '
                '${order.numeroCommande} ?',
                style: const TextStyle(fontSize: 13.5),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                autofocus: true,
                maxLines: 2,
                onChanged: (value) => canSubmit.value = value.trim().isNotEmpty,
                decoration: InputDecoration(
                  labelText: 'Motif',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Revenir'),
            ),
            Obx(() {
              return ElevatedButton(
                onPressed: canSubmit.value
                    ? () => Navigator.pop(
                        dialogContext,
                        reasonController.text.trim(),
                      )
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorManager.errorColor,
                  foregroundColor: ColorManager.white,
                ),
                child: const Text('Annuler la commande'),
              );
            }),
          ],
        );
      },
    );

    reasonController.dispose();

    if (motif == null || motif.isEmpty || !sheetContext.mounted) {
      return;
    }

    await _apply(
      sheetContext,
      () => controller.cancelOrder(order, motif),
      'Commande annulée',
    );
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Revenir'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
  }

  /// Runs an action, then closes the sheet and says what happened — or leaves
  /// the sheet open with the reason it did not.
  Future<void> _apply(
    BuildContext sheetContext,
    Future<bool> Function() action,
    String successMessage,
  ) async {
    final succeeded = await action();

    if (!mounted) {
      return;
    }

    if (!succeeded) {
      final error = controller.actionError.value;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'L\'action a échoué.'),
          backgroundColor: ColorManager.errorColor,
        ),
      );
      return;
    }

    if (sheetContext.mounted) {
      Navigator.pop(sheetContext);
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(successMessage),
        backgroundColor: ColorManager.successColor,
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final CommercialOrder order;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.numeroCommande,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: ColorManager.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.clientRaisonSociale,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: ColorManager.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _StatusBadge(order: order),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 13,
                    color: ColorManager.textTertiary,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      _formatMoment(order.dateCreation, withTime: false),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: ColorManager.textTertiary,
                      ),
                    ),
                  ),
                  Text(
                    '${order.lignes.length} ligne'
                    '${order.lignes.length > 1 ? 's' : ''}'
                    ' · ${order.totalQuantite} u.',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: ColorManager.textTertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text(
                    'TTC',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: ColorManager.textTertiary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatAmount(order.montantTtc),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: ColorManager.textPrimary,
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

class _StatusBadge extends StatelessWidget {
  final CommercialOrder order;

  const _StatusBadge({required this.order});

  @override
  Widget build(BuildContext context) {
    final color = OrderPalette.forStatus(order.status);

    // An unknown status shows what the backend actually said, so a value this
    // app has not been taught is still readable on screen.
    final label = order.status == CommercialOrderStatus.unknown
        ? (order.statutRaw.isEmpty
              ? OrderPalette.labelFor(order.status)
              : order.statutRaw)
        : OrderPalette.labelFor(order.status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10.5,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _OrderLineTile extends StatelessWidget {
  final CommercialOrderLine line;

  const _OrderLineTile({required this.line});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ColorManager.greybg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColorManager.lightGrey2),
      ),
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
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: ColorManager.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '×${line.quantite}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: ColorManager.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${line.referenceProduit} · '
                  '${_formatAmount(line.prixUnitaireHt)} HT'
                  '${line.remise > 0 ? ' · remise ${_formatNumber(line.remise)} %' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: ColorManager.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatAmount(line.totalHt),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _DetailRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label : ',
            style: const TextStyle(
              fontSize: 12.5,
              color: ColorManager.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: emphasize ? 15 : 12.5,
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
                color: ColorManager.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder card drawn while the first page is on its way, matching the
/// stock screen's: a slow pulse rather than a shimmer, which would need a
/// dependency the project does not carry.
class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Widget _block(double? width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE6E9EC),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: ColorManager.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: ColorManager.lightGrey2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: FadeTransition(
          opacity: Tween<double>(
            begin: 0.4,
            end: 1,
          ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _block(130, 13),
                        const SizedBox(height: 7),
                        _block(null, 10),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _block(70, 18),
                ],
              ),
              const SizedBox(height: 14),
              _block(null, 10),
              const SizedBox(height: 12),
              _block(110, 14),
            ],
          ),
        ),
      ),
    );
  }
}

/// `1 234,50 DT`. Matches the stock screen's formatting, minus the HT suffix,
/// which here depends on which total is being shown.
String _formatAmount(double value) {
  return '${_formatNumber(value)} DT';
}

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

/// `12/03/2026 à 14:05`, or just the date. The backend hands back ISO
/// timestamps, which read as machine output when printed raw.
String _formatMoment(String? raw, {required bool withTime}) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) {
    return '—';
  }

  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return value;
  }

  final local = parsed.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final date = '$day/$month/${local.year}';

  if (!withTime) {
    return date;
  }

  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');

  return '$date à $hour:$minute';
}

/// `LIVRAISON_STD_DAYCO` reads as a database value; this makes it a phrase.
String _humanizeEnum(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) {
    return '—';
  }

  final words = value.split('_').where((part) => part.isNotEmpty).toList();
  if (words.isEmpty) {
    return value;
  }

  return words
      .map((word) {
        final lower = word.toLowerCase();
        return lower.length == 1
            ? lower.toUpperCase()
            : '${lower[0].toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');
}

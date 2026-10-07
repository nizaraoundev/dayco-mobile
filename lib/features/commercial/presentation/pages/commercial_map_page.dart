import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../localization/ui_translations.dart';
import '../controllers/commercial_map_controller.dart';
import 'commercial_stock_page.dart';
import '../widgets/brand_selection_widget.dart';
import '../../data/models/models.dart';

class CommercialMapPage extends StatelessWidget {
  const CommercialMapPage({super.key});

  String _tr(String key) => UiTranslations.t(key);

  String _value(dynamic value) {
    if (value == null) return '-';
    if (value is List) {
      if (value.isEmpty) return '-';
      return value.map((item) => item.toString()).join(', ');
    }
    final text = value.toString().trim();
    return text.isEmpty ? '-' : text;
  }

  bool _hasValue(dynamic value) {
    if (value == null) return false;
    if (value is List) return value.isNotEmpty;
    final text = value.toString().trim();
    if (text.isEmpty) return false;
    return text.toLowerCase() != 'null';
  }

  Widget _metaChip({
    required IconData icon,
    required String label,
    required dynamic value,
  }) {
    if (!_hasValue(value)) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.black45),
          const SizedBox(width: 5),
          Text(
            '$label: ${_value(value)}',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '-';
    final s = raw.toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return '-';
    try {
      final dt = DateTime.parse(s);
      final dd = dt.day.toString().padLeft(2, '0');
      final mm = dt.month.toString().padLeft(2, '0');
      final yy = (dt.year % 100).toString().padLeft(2, '0');
      final hh = dt.hour.toString().padLeft(2, '0');
      final mi = dt.minute.toString().padLeft(2, '0');
      return '$dd/$mm/$yy $hh:$mi';
    } catch (_) {
      return s;
    }
  }

  Widget _buildClientDetailsCard(
    CommercialMapController controller,
    Map<String, dynamic> client,
    VoidCallback? onTap,
  ) {
    return _ExpandableClientCard(
      controller: controller,
      client: client,
      onTap: onTap,
      metaChipBuilder: _metaChip,
      formatDate: _formatDate,
      hasValue: _hasValue,
      valueStr: _value,
    );
  }

  Widget _drawerActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.black38),
      ),
    );
  }

  Future<void> _openParentClientsPicker(
    CommercialMapController controller,
  ) async {
    await controller.loadMyClients();

    Get.bottomSheet(
      SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: Obx(() {
            final clients = controller.myClients;
            if (clients.isEmpty) {
              return SizedBox(
                height: 200,
                child: Center(child: Text(_tr('noParentClientsAvailable'))),
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _tr('selectParentClients'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: clients.length,
                    itemBuilder: (_, index) {
                      final client = clients[index];
                      final clientId = _value(client['id']);
                      final displayName = controller.getClientDisplayName(client);

                      return CheckboxListTile(
                        value: controller.isParentClientSelected(clientId),
                        onChanged: (_) =>
                            controller.toggleParentClientSelection(clientId),
                        title: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          controller.getClientSubtitle(client),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: Get.back,
                    child: Text(_tr('done')),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Future<void> _openSubClientsManagementSheet(
    CommercialMapController controller,
  ) async {
    return Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Obx(
          () => Column(
            children: [
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.people_alt, color: Colors.blue),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _tr('subClientsProspects'),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${controller.mySubClients.length} ${_tr('items')}',
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: Get.back,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Get.back();
                          controller.closeClientForm();
                          controller.registrationType.value = 'sub_client';
                          controller.isProspectFormMode.value = false;
                          controller.selectedClientForUpdate.value = null;
                          controller.selectedParentClientIds.clear();
                          controller.openClientForm();
                        },
                        icon: const Icon(Icons.person_add_alt_1),
                        label: Text(_tr('newSubClient')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Get.back();
                          controller.closeClientForm();
                          controller.registrationType.value = 'sub_client';
                          controller.isProspectFormMode.value = true;
                          controller.selectedClientForUpdate.value = null;
                          controller.selectedParentClientIds.clear();
                          controller.openClientForm();
                        },
                        icon: const Icon(Icons.person_search),
                        label: Text(_tr('newProspect')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: controller.mySubClients.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox, size: 44, color: Colors.grey[400]),
                            const SizedBox(height: 10),
                            Text(
                              _tr('noSubClientsProspects'),
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        itemCount: controller.mySubClients.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          final subClient = controller.mySubClients[index];
                          final isProspect = subClient['type'] == 'PROSPECT';
                          final displayName =
                              controller.getClientDisplayName(subClient);
                          final parentIds =
                              (subClient['parentClientIds'] as List?) ?? const [];
                          final marques =
                              (subClient['marques'] as List?) ?? const [];
                          final imageUrl =
                              controller.getClientImageUrl(subClient);

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                              border: Border(
                                left: BorderSide(
                                  color: isProspect ? Colors.blue : Colors.orange,
                                  width: 4,
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (imageUrl.isNotEmpty)
                                        CircleAvatar(
                                          radius: 21,
                                          backgroundColor: Colors.grey.shade200,
                                          child: ClipOval(
                                            child: Image.network(
                                              imageUrl,
                                              width: 42,
                                              height: 42,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Icon(
                                                isProspect
                                                    ? Icons.person_outline
                                                    : Icons.person,
                                                color: Colors.black45,
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        CircleAvatar(
                                          radius: 21,
                                          backgroundColor:
                                              (isProspect
                                                      ? Colors.blue
                                                      : Colors.orange)
                                                  .withOpacity(0.12),
                                          child: Icon(
                                            isProspect
                                                ? Icons.person_search
                                                : Icons.person_pin,
                                            color: isProspect
                                                ? Colors.blue
                                                : Colors.orange,
                                          ),
                                        ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          displayName,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: (isProspect
                                                  ? Colors.blue
                                                  : Colors.orange)
                                              .withOpacity(0.16),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          isProspect
                                              ? _tr('prospect')
                                              : _tr('subClientShort'),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: isProspect
                                                ? Colors.blue.shade700
                                                : Colors.orange.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _metaChip(
                                        icon: Icons.phone,
                                        label: _tr('phoneLabel'),
                                        value: subClient['telephone'],
                                      ),
                                      _metaChip(
                                        icon: Icons.store,
                                        label: _tr('agencyLabel'),
                                        value: subClient['nomAgence'],
                                      ),
                                      _metaChip(
                                        icon: Icons.group_outlined,
                                        label: _tr('parentsLabel'),
                                        value: parentIds.length,
                                      ),
                                      _metaChip(
                                        icon: Icons.directions_car_outlined,
                                        label: _tr('brandsLabel'),
                                        value: marques.isEmpty
                                            ? '-'
                                            : marques.join(', '),
                                      ),
                                      _metaChip(
                                        icon: Icons.note_alt_outlined,
                                        label: _tr('noteLabel'),
                                        value: subClient['note'],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Get.back();
                                        controller.selectSubClientForEdit(
                                            subClient);
                                      },
                                      icon: const Icon(Icons.edit,
                                          color: Colors.white),
                                      label: Text(
                                        _tr('update'),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            ColorManager.primaryColor,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _openClientsListSheet(CommercialMapController controller) {
    controller.loadMyClients();
    controller.setClientsSearchQuery('');
    final searchController = TextEditingController();

    Get.bottomSheet(
      SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Obx(() {
            if (controller.isLoadingMyClients.value &&
                controller.myClients.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (controller.myClients.isEmpty) {
              return Center(
                child: Text(
                  _tr('noClientsFound'),
                  style: const TextStyle(fontSize: 14),
                ),
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _tr('clientsList'),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${controller.myClients.length} client(s)',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: searchController,
                  onChanged: controller.setClientsSearchQuery,
                  decoration: InputDecoration(
                    hintText: 'Rechercher client, code, téléphone...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: Obx(
                      () => controller.clientsSearchQuery.value.isEmpty
                          ? const SizedBox.shrink()
                          : IconButton(
                              onPressed: () {
                                searchController.clear();
                                controller.setClientsSearchQuery('');
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: Obx(() {
                    final clients = controller.filteredMyClients;
                    if (clients.isEmpty) {
                      return const Center(
                        child: Text(
                          'Aucun client ne correspond à la recherche',
                          style:
                              TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: clients.length,
                      itemBuilder: (_, index) {
                        final client = clients[index];
                        return _buildClientDetailsCard(
                          controller,
                          client,
                          () {
                            Get.back();
                            controller.selectClientForLocationUpdate(client);
                          },
                        );
                      },
                    );
                  }),
                ),
              ],
            );
          }),
        ),
      ),
      isScrollControlled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CommercialMapController());
    final scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: scaffoldKey,
      drawer: _buildMenuDrawer(controller),
      body: Stack(
        children: [
          Obx(
            () => GoogleMap(
              mapType: controller.selectedMapType.value,
              initialCameraPosition: CameraPosition(
                target: controller.currentPosition.value != null
                    ? LatLng(
                        controller.currentPosition.value!.latitude,
                        controller.currentPosition.value!.longitude,
                      )
                    : const LatLng(36.8065, 10.1815),
                zoom: 12,
              ),
              onMapCreated: (GoogleMapController mapController) {
                controller.mapController = mapController;
              },
              onTap: controller.onMapTap,
              markers: Set<Marker>.from(controller.markers),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            ),
          ),

          // Top app bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    elevation: 4,
                    child: InkWell(
                      onTap: () => scaffoldKey.currentState?.openDrawer(),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        child: Icon(Icons.menu, color: ColorManager.textPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Text(
                          _tr('addClientTitle'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: ColorManager.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom action buttons
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: controller.fillWithCurrentLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: ColorManager.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.location_on),
                    label: Text(
                      _tr('myPosition'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openClientsListSheet(controller),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorManager.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.group),
                    label: const Text(
                      'Mes Clients',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Client form overlay
          Obx(
            () => controller.showClientForm.value
                ? _buildClientFormOverlay(controller)
                : const SizedBox.shrink(),
          ),

          // Confirm drag position button
          Obx(
            () => controller.hasPendingDragPosition.value &&
                    !controller.showClientForm.value
                ? Positioned(
                    left: 16,
                    right: 16,
                    bottom: 100,
                    child: ElevatedButton.icon(
                      onPressed: controller.confirmDragPosition,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text(
                        'Confirmer cette position',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuDrawer(CommercialMapController controller) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Obx(
          () => ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          ColorManager.primaryColor.withOpacity(0.15),
                      child: Icon(Icons.person,
                          color: ColorManager.primaryColor, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            controller.profileData['name']?.isNotEmpty == true
                                ? controller.profileData['name']!
                                : '${controller.profileData['nom'] ?? ''} ${controller.profileData['prenom'] ?? ''}'
                                    .trim(),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            controller.profileData['email']?.isNotEmpty == true
                                ? controller.profileData['email']!
                                : '-',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _profileRow('Nom', controller.profileData['nom']),
                    _profileRow('Prénom', controller.profileData['prenom']),
                    _profileRow(
                        'Téléphone', controller.profileData['telephone']),
                    _profileRow(
                      _tr('roles'),
                      controller.profileRoles.isEmpty
                          ? _tr('noData')
                          : controller.profileRoles.join(', '),
                    ),
                    _profileRow(
                      _tr('regions'),
                      controller.profileRegions.isEmpty
                          ? _tr('noData')
                          : controller.profileRegions.join(', '),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _drawerActionTile(
                icon: Icons.add_business,
                iconColor: Colors.green,
                title: _tr('newClientB2B'),
                subtitle: _tr('createNewClient'),
                onTap: () {
                  Get.back();
                  controller.openClientForm();
                },
              ),
              const SizedBox(height: 2),
              _drawerActionTile(
                icon: Icons.person_add,
                iconColor: Colors.blue,
                title: _tr('subClientsProspects'),
                subtitle: _tr('manageSubClientsProspects'),
                onTap: () {
                  Get.back();
                  _openSubClientsManagementSheet(controller);
                },
              ),
              const SizedBox(height: 2),
              _drawerActionTile(
                icon: Icons.inventory_2,
                iconColor: Colors.deepPurple,
                title: 'Stocks',
                subtitle: 'Consulter stock et réservations',
                onTap: () {
                  Get.back();
                  Get.to(() => const CommercialStockPage());
                },
              ),
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SwitchListTile(
                  secondary: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: ColorManager.primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.layers_outlined,
                        color: ColorManager.primaryColor, size: 20),
                  ),
                  title: Text(_tr('hybridMap'),
                      style:
                          const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    controller.selectedMapType.value == MapType.hybrid
                        ? _tr('hybridOn')
                        : _tr('hybridOffNormal'),
                  ),
                  value:
                      controller.selectedMapType.value == MapType.hybrid,
                  onChanged: (isHybrid) {
                    controller.setMapType(
                        isHybrid ? MapType.hybrid : MapType.normal);
                  },
                  activeThumbColor: ColorManager.primaryColor,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 4, bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => controller.changeLanguage('fr'),
                        child: const Text('🇫🇷 FR'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => controller.changeLanguage('ar'),
                        child: const Text('🇹🇳 AR'),
                      ),
                    ),
                  ],
                ),
              ),
              _drawerActionTile(
                icon: Icons.logout,
                iconColor: Colors.red,
                title: _tr('logout'),
                onTap: () async {
                  Get.back();
                  await controller.logout();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileRow(String title, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 13),
          children: [
            TextSpan(
              text: '$title: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(
                text: (value == null || value.isEmpty) ? '-' : value),
          ],
        ),
      ),
    );
  }

  Widget _buildClientFormOverlay(CommercialMapController controller) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Form(
              key: controller.clientFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.business,
                          color: ColorManager.primaryColor, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Obx(
                          () => Text(
                            controller.registrationType.value == 'sub_client'
                                ? 'Sub-Client / Prospect'
                                : _tr('newClientB2B'),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: ColorManager.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: controller.closeClientForm,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Obx(
                    () => controller.registrationType.value == 'b2b'
                        ? Column(
                            children: [
                              TextFormField(
                                controller: controller.codeClientController,
                                enabled: controller
                                    .isFieldEditableForCommercialUpdate(
                                        'codeClient'),
                                decoration: InputDecoration(
                                  labelText: _tr('codeClientOptional'),
                                  prefixIcon: Icon(Icons.tag,
                                      color: ColorManager.primaryColor),
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller:
                                    controller.raisonSocialeController,
                                enabled: controller
                                    .isFieldEditableForCommercialUpdate(
                                        'raisonSociale'),
                                decoration: InputDecoration(
                                  labelText: _tr('raisonSocialeOptional'),
                                  prefixIcon: Icon(Icons.business,
                                      color: ColorManager.primaryColor),
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller:
                                    controller.matriculeFiscalController,
                                enabled: controller
                                    .isFieldEditableForCommercialUpdate(
                                        'matriculeFiscal'),
                                decoration: InputDecoration(
                                  labelText:
                                      _tr('matriculeFiscalOptional'),
                                  prefixIcon: Icon(Icons.badge,
                                      color: ColorManager.primaryColor),
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),

                  Obx(
                    () => controller.registrationType.value == 'sub_client'
                        ? Column(
                            children: [
                              TextFormField(
                                controller: controller.nomController,
                                decoration: InputDecoration(
                                  labelText: 'Nom',
                                  prefixIcon: Icon(Icons.person_outline,
                                      color: ColorManager.primaryColor),
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: controller.prenomController,
                                decoration: InputDecoration(
                                  labelText: 'Prénom',
                                  prefixIcon: Icon(Icons.badge_outlined,
                                      color: ColorManager.primaryColor),
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: controller.nomAgenceController,
                                decoration: InputDecoration(
                                  labelText: 'Agence',
                                  prefixIcon: Icon(Icons.store_outlined,
                                      color: ColorManager.primaryColor),
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (!controller.isProspectFormMode.value) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.black12),
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _tr('parentClients'),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Obx(() {
                                        final selectedParents = controller
                                            .getSelectedParentClients();
                                        if (selectedParents.isEmpty) {
                                          return Text(
                                            _tr('noneSelectedProspectHint'),
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black54),
                                          );
                                        }
                                        return Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children:
                                              selectedParents.map((parent) {
                                            final id = _value(parent['id']);
                                            return Chip(
                                              label: Text(
                                                controller
                                                    .getClientDisplayName(
                                                        parent),
                                              ),
                                              onDeleted: () => controller
                                                  .toggleParentClientSelection(
                                                      id),
                                            );
                                          }).toList(),
                                        );
                                      }),
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _openParentClientsPicker(
                                                  controller),
                                          icon: const Icon(
                                              Icons.group_add_outlined),
                                          label: Text(
                                              _tr('selectParentClients')),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),

                  TextFormField(
                    controller: controller.telephoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: _tr('phoneOptional'),
                      prefixIcon: Icon(Icons.phone,
                          color: ColorManager.primaryColor),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Obx(
                    () => controller.registrationType.value == 'b2b'
                        ? Column(
                            children: [
                              TextFormField(
                                controller: controller.emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: _tr('emailOptional'),
                                  prefixIcon: Icon(Icons.email,
                                      color: ColorManager.primaryColor),
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),

                  Obx(
                    () => controller.registrationType.value == 'b2b' ||
                            controller.registrationType.value == 'sub_client'
                        ? Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Marques automobiles',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: ColorManager.textPrimary,
                                          ),
                                        ),
                                        Obx(
                                          () => Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2),
                                            decoration: BoxDecoration(
                                              color: ColorManager.primaryColor
                                                  .withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '${controller.selectedBrands.length}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                    ColorManager.primaryColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Obx(
                                      () => controller
                                              .selectedBrands.isEmpty
                                          ? Text(
                                              'Aucune marque sélectionnée',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                                fontStyle: FontStyle.italic,
                                              ),
                                            )
                                          : Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: controller
                                                  .selectedBrands
                                                  .map((brand) {
                                                return Chip(
                                                  label: Text(
                                                    brand.displayName,
                                                    style: const TextStyle(
                                                        fontSize: 11),
                                                  ),
                                                  backgroundColor:
                                                      ColorManager.primaryColor
                                                          .withOpacity(0.1),
                                                  labelStyle: TextStyle(
                                                    color: ColorManager
                                                        .primaryColor,
                                                    fontWeight:
                                                        FontWeight.w500,
                                                  ),
                                                  onDeleted: () {
                                                    controller
                                                        .toggleBrand(brand);
                                                  },
                                                );
                                              }).toList(),
                                            ),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton(
                                        onPressed: controller
                                                    .registrationType
                                                    .value ==
                                                'sub_client' ||
                                            controller
                                                .canEditBrandsForCurrentClient
                                            ? () {
                                                Get.bottomSheet(
                                                  SafeArea(
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              12),
                                                      child: Container(
                                                        clipBehavior:
                                                            Clip.antiAlias,
                                                        decoration: BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(20),
                                                        ),
                                                        child: Stack(
                                                          children: [
                                                            BrandSelectionWidget(
                                                              initialBrands:
                                                                  CarBrandsModel(
                                                                selectedBrands:
                                                                    controller
                                                                        .selectedBrands,
                                                              ),
                                                              onBrandsChanged:
                                                                  (brands) {
                                                                controller
                                                                    .selectedBrands
                                                                    .clear();
                                                                controller
                                                                    .selectedBrands
                                                                    .addAll(brands
                                                                        .selectedBrands);
                                                              },
                                                              isEditing: true,
                                                            ),
                                                            Positioned(
                                                              top: 8,
                                                              right: 8,
                                                              child: Material(
                                                                color: Colors
                                                                    .black12,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            16),
                                                                child: InkWell(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              16),
                                                                  onTap:
                                                                      Get.back,
                                                                  child:
                                                                      const Padding(
                                                                    padding:
                                                                        EdgeInsets.all(6),
                                                                    child: Icon(
                                                                        Icons
                                                                            .close,
                                                                        size:
                                                                            18),
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
                                                  backgroundColor:
                                                      Colors.transparent,
                                                  shape:
                                                      const RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.vertical(
                                                            top: Radius.circular(
                                                                20)),
                                                  ),
                                                );
                                              }
                                            : null,
                                        child: const Text(
                                            'Sélectionner les marques'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),

                  TextFormField(
                    controller: controller.noteController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Note',
                      prefixIcon: Icon(Icons.note_alt_outlined,
                          color: ColorManager.primaryColor),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Obx(
                    () => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: controller.isPickingImage.value
                                    ? null
                                    : controller.pickImageFromCamera,
                                icon: const Icon(Icons.camera_alt),
                                label: Text(_tr('takePhoto')),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: controller.isPickingImage.value
                                    ? null
                                    : controller.pickImageFromGallery,
                                icon: const Icon(Icons.photo_library),
                                label: Text(_tr('gallery')),
                              ),
                            ),
                          ],
                        ),
                        if (controller.selectedImageBytes.value !=
                            null) ...[
                          const SizedBox(height: 12),
                          Container(
                            height: 120,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    child: Image.memory(
                                      controller
                                          .selectedImageBytes.value!,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 6,
                                  top: 6,
                                  child: Material(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(14),
                                    child: InkWell(
                                      borderRadius:
                                          BorderRadius.circular(14),
                                      onTap:
                                          controller.removeSelectedImage,
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(Icons.close,
                                            color: Colors.white, size: 18),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: controller.pickLocationFromMap,
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Choose location on map'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ColorManager.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Obx(
                      () => Row(
                        children: [
                          Icon(Icons.location_on,
                              color: ColorManager.primaryColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              controller.selectedLocation.value != null
                                  ? 'Lat: ${controller.selectedLocation.value!.latitude.toStringAsFixed(6)}\nLng: ${controller.selectedLocation.value!.longitude.toStringAsFixed(6)}'
                                  : _tr('touchMapBoutique'),
                              style: TextStyle(
                                fontSize: 12,
                                color: ColorManager.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Obx(
                    () => ElevatedButton(
                      onPressed: controller.isCreatingClient.value
                          ? null
                          : controller.submitClientForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorManager.primaryColor,
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: controller.isCreatingClient.value
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Obx(() {
                              final isUpdateMode = controller
                                      .selectedClientForUpdate.value !=
                                  null;
                              return Text(
                                isUpdateMode
                                    ? controller.clientLocationActionLabel
                                    : _tr('createClient'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              );
                            }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Expandable client card widget
// ---------------------------------------------------------------------------
class _ExpandableClientCard extends StatefulWidget {
  final CommercialMapController controller;
  final Map<String, dynamic> client;
  final VoidCallback? onTap;
  final Widget Function({
    required IconData icon,
    required String label,
    required dynamic value,
  }) metaChipBuilder;
  final String Function(dynamic raw) formatDate;
  final bool Function(dynamic value) hasValue;
  final String Function(dynamic value) valueStr;

  const _ExpandableClientCard({
    required this.controller,
    required this.client,
    required this.onTap,
    required this.metaChipBuilder,
    required this.formatDate,
    required this.hasValue,
    required this.valueStr,
  });

  @override
  State<_ExpandableClientCard> createState() => _ExpandableClientCardState();
}

class _ExpandableClientCardState extends State<_ExpandableClientCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _animController;
  late final Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _expandAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _animController.forward() : _animController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    final controller = widget.controller;
    final isActive = client['actif'] == true;
    final imageUrl = controller.getClientImageUrl(client);
    final name = controller.getClientDisplayName(client);

    final rawLat = client['latitude'];
    final rawLng = client['longitude'];
    double? lat;
    double? lng;
    try {
      if (rawLat != null) lat = double.tryParse(rawLat.toString());
      if (rawLng != null) lng = double.tryParse(rawLng.toString());
    } catch (_) {}
    final hasLocation = lat != null && lng != null && lat != 0.0 && lng != 0.0;

    final locationColor = hasLocation ? const Color(0xFF22C55E) : const Color(0xFFF59E0B);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Colored top accent bar
            Container(height: 3, color: locationColor),

            // ── Collapsed header ─────────────────────────────────────────
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      _buildAvatar(controller, client, imageUrl),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A2E),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(
                                  hasLocation
                                      ? Icons.location_on
                                      : Icons.location_off,
                                  size: 12,
                                  color: locationColor,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  hasLocation ? 'Localisé' : 'Sans position',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: locationColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? Colors.green.withOpacity(0.1)
                                        : Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isActive ? 'ACTIF' : 'INACTIF',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: isActive
                                          ? Colors.green.shade700
                                          : Colors.red.shade700,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _toggle,
                        child: AnimatedRotation(
                          turns: _expanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 220),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.keyboard_arrow_down,
                              size: 18,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Expanded details ──────────────────────────────────────────
            SizeTransition(
              sizeFactor: _expandAnim,
              axisAlignment: -1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 1, color: Colors.grey.shade100),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Full banner image
                        if (imageUrl.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: AspectRatio(
                              aspectRatio: 16 / 7,
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey.shade100,
                                  alignment: Alignment.center,
                                  child: const Icon(
                                      Icons.broken_image_outlined,
                                      color: Colors.black38),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // GPS row
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: locationColor.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: locationColor.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                hasLocation
                                    ? Icons.my_location
                                    : Icons.location_searching,
                                size: 14,
                                color: locationColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  hasLocation
                                      ? '${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}'
                                      : 'Aucune position — appuyez sur Modifier',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: locationColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Info chips
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            widget.metaChipBuilder(
                              icon: Icons.badge_outlined,
                              label: 'Code',
                              value: client['codeClient'],
                            ),
                            widget.metaChipBuilder(
                              icon: Icons.phone_outlined,
                              label: 'Tél',
                              value: client['telephone'],
                            ),
                            widget.metaChipBuilder(
                              icon: Icons.email_outlined,
                              label: 'Email',
                              value: client['email'],
                            ),
                            widget.metaChipBuilder(
                              icon: Icons.receipt_long_outlined,
                              label: 'Matricule',
                              value: client['matriculeFiscal'],
                            ),
                            widget.metaChipBuilder(
                              icon: Icons.person_outline,
                              label: 'Commercial',
                              value: client['commercialName'],
                            ),
                          ],
                        ),

                        // Dates
                        if (widget.hasValue(client['dateCreation']) ||
                            widget.hasValue(client['dateModification'])) ...[
                          const SizedBox(height: 10),
                          Container(height: 1, color: Colors.grey.shade100),
                          const SizedBox(height: 8),
                          if (widget.hasValue(client['dateCreation']))
                            _dateRow(
                              'Créé le',
                              widget.formatDate(client['dateCreation']),
                            ),
                          if (widget.hasValue(client['dateModification']))
                            _dateRow(
                              'Modifié le',
                              widget.formatDate(client['dateModification']),
                            ),
                        ],

                        const SizedBox(height: 12),

                        // Edit CTA
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: widget.onTap,
                            icon: const Icon(Icons.edit_location_alt,
                                size: 16),
                            label: const Text(
                              'Modifier ce client',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.grey.shade50,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 12, color: Colors.grey.shade400),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          Text(
            value,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(
    CommercialMapController controller,
    Map<String, dynamic> client,
    String imageUrl,
  ) {
    if (imageUrl.isEmpty) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child:
            const Icon(Icons.business, color: Colors.black38, size: 22),
      );
    }
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade100,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imageUrl,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.business, color: Colors.black38, size: 22),
        ),
      ),
    );
  }
}
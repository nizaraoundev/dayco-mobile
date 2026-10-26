import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/assets/images.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../localization/ui_translations.dart';
import '../controllers/commercial_map_controller.dart';
import 'commercial_stock_page.dart';
import '../widgets/brand_selection_widget.dart';
import '../widgets/map_style.dart';
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
    VoidCallback? onTap, {
    bool? isExpanded,
    ValueChanged<bool>? onExpandedChanged,
    bool compact = false,
  }) {
    return _ExpandableClientCard(
      controller: controller,
      client: client,
      onTap: onTap,
      metaChipBuilder: _metaChip,
      formatDate: _formatDate,
      hasValue: _hasValue,
      isExpanded: isExpanded,
      onExpandedChanged: onExpandedChanged,
      compact: compact,
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

  void _openClientsListSheet(
    BuildContext context,
    CommercialMapController controller,
  ) {
    controller.loadMyClients();
    controller.setClientsSearchQuery('');

    // Deliberately not Get.bottomSheet: it offers no way to lift the Material 3
    // 640px width cap, and its own drag handler fights the
    // DraggableScrollableSheet inside, which is what expands the sheet.
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      builder: (_) => _buildClientsSheet(controller),
    );
  }

  Widget _buildClientsSheet(CommercialMapController controller) {
    return _ClientsListSheet(
      controller: controller,
        cardBuilder:
            (client, onTap, isExpanded, onExpandedChanged, compact) =>
                _buildClientDetailsCard(
          controller,
          client,
          onTap,
          isExpanded: isExpanded,
          onExpandedChanged: onExpandedChanged,
          compact: compact,
        ),
        detailBuilder: (client, onTap) => _ClientDetailsBody(
          controller: controller,
          client: client,
          onTap: onTap,
          metaChipBuilder: _metaChip,
          formatDate: _formatDate,
          hasValue: _hasValue,
          showHeader: true,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CommercialMapController());
    final scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: scaffoldKey,
      drawer: _buildMenuDrawer(context, controller),
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
              // Styling only applies to the normal basemap; imagery ignores it.
              style: controller.selectedMapType.value == MapType.normal
                  ? kDaycoMapStyle
                  : null,
              myLocationEnabled: true,
              // Replaced by our own locate button in the control rail.
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              // Native compass: appears once the map is rotated and snaps
              // back to north when tapped, exactly like Google Maps.
              compassEnabled: true,
              // Free toolbar giving directions to a tapped marker.
              mapToolbarEnabled: true,
              trafficEnabled: controller.isTrafficEnabled.value,
              buildingsEnabled: true,
              indoorViewEnabled: true,
              fortyFiveDegreeImageryEnabled: true,
              rotateGesturesEnabled: true,
              tiltGesturesEnabled: true,
              zoomGesturesEnabled: true,
              scrollGesturesEnabled: true,
              minMaxZoomPreference: const MinMaxZoomPreference(3, 20),
              // Keeps the native compass, toolbar and Google logo clear of
              // our own overlays instead of hidden behind them.
              padding: EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top + 64,
                bottom: 96,
              ),
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

          // Map controls: a right-hand rail of icon buttons over a single
          // bottom pill, so the map itself stays visible.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildMapControlRail(controller),
                    const SizedBox(height: 14),

                    // Confirm a position dragged on the map
                    Obx(
                      () => controller.hasPendingDragPosition.value &&
                              !controller.showClientForm.value
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: controller.confirmDragPosition,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF16A34A),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    elevation: 4,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                  ),
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: const Text(
                                    'Confirmer cette position',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),

                    Align(
                      alignment: Alignment.center,
                      child: _buildClientsPill(context, controller),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Client form overlay
          Obx(
            () => controller.showClientForm.value
                ? _buildClientFormOverlay(context, controller)
                : const SizedBox.shrink(),
          ),

        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Map controls
  // ---------------------------------------------------------------------------

  /// Vertical stack of round icon buttons, the way Google Maps presents its
  /// own map controls.
  Widget _buildMapControlRail(CommercialMapController controller) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Obx(
          () => _mapControlButton(
            icon: Icons.layers_outlined,
            tooltip: _tr('hybridMap'),
            // Highlighted whenever the map is showing something other than
            // the plain basemap, so the layer state is readable at a glance.
            active: controller.selectedMapType.value != MapType.normal ||
                controller.isTrafficEnabled.value,
            onTap: () => _openMapLayersSheet(controller),
          ),
        ),
        const SizedBox(height: 10),
        Obx(
          () => _mapControlButton(
            icon: Icons.my_location,
            tooltip: _tr('myPosition'),
            busy: controller.isLoadingLocation.value,
            onTap: controller.recenterOnCurrentPosition,
          ),
        ),
      ],
    );
  }

  Widget _mapControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool active = false,
    bool busy = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? ColorManager.primaryColor : Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: Colors.black26,
        child: InkWell(
          onTap: busy ? null : onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 48,
            height: 48,
            child: busy
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: ColorManager.primaryColor,
                    ),
                  )
                : Icon(
                    icon,
                    size: 22,
                    color: active ? Colors.white : const Color(0xFF444C55),
                  ),
          ),
        ),
      ),
    );
  }

  /// Single entry point to the clients list, with a live count badge.
  Widget _buildClientsPill(
    BuildContext context,
    CommercialMapController controller,
  ) {
    return Material(
      color: ColorManager.primaryColor,
      borderRadius: BorderRadius.circular(28),
      elevation: 5,
      shadowColor: ColorManager.primaryColor.withOpacity(0.4),
      child: InkWell(
        onTap: () => _openClientsListSheet(context, controller),
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.groups_outlined, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                _tr('clientsList'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              Obx(() {
                if (controller.myClients.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${controller.myClients.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  /// Layer picker: basemap type plus the free traffic overlay.
  void _openMapLayersSheet(CommercialMapController controller) {
    Get.bottomSheet(
      SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: _sheetHandle()),
              const SizedBox(height: 14),
              const Text(
                'Type de carte',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Obx(
                () => Row(
                  children: [
                    _mapTypeTile(
                      controller,
                      type: MapType.normal,
                      icon: Icons.map_outlined,
                      label: 'Plan',
                    ),
                    const SizedBox(width: 10),
                    _mapTypeTile(
                      controller,
                      type: MapType.satellite,
                      icon: Icons.satellite_alt_outlined,
                      label: 'Satellite',
                    ),
                    const SizedBox(width: 10),
                    _mapTypeTile(
                      controller,
                      type: MapType.hybrid,
                      icon: Icons.layers_outlined,
                      label: 'Hybride',
                    ),
                    const SizedBox(width: 10),
                    _mapTypeTile(
                      controller,
                      type: MapType.terrain,
                      icon: Icons.terrain_outlined,
                      label: 'Relief',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Obx(
                () => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: controller.isTrafficEnabled.value,
                  onChanged: (_) => controller.toggleTraffic(),
                  activeThumbColor: ColorManager.primaryColor,
                  secondary: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: ColorManager.primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.traffic_outlined,
                      color: ColorManager.primaryColor,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Trafic en direct',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Affiche la circulation sur les routes',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mapTypeTile(
    CommercialMapController controller, {
    required MapType type,
    required IconData icon,
    required String label,
  }) {
    final selected = controller.selectedMapType.value == type;

    return Expanded(
      child: InkWell(
        onTap: () => controller.setMapType(type),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? ColorManager.primaryColor.withOpacity(0.10)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? ColorManager.primaryColor
                  : Colors.grey.shade200,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? ColorManager.primaryColor : Colors.black54,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? ColorManager.primaryColor
                      : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _sheetHandle() {
    return Container(
      width: 44,
      height: 5,
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Navigation drawer
  // ---------------------------------------------------------------------------

  Widget _buildMenuDrawer(
    BuildContext context,
    CommercialMapController controller,
  ) {
    final size = MediaQuery.sizeOf(context);
    final isTablet = size.shortestSide >= 600;
    final isLandscape = size.width > size.height;

    // Phones get a share of the screen, capped so it never looks stretched;
    // tablets get a fixed, roomier panel.
    final width = isTablet
        ? 380.0
        : (size.width * 0.86).clamp(260.0, 330.0).toDouble();

    // A landscape phone is short, so the header lays itself out sideways.
    final compactHeader = isLandscape && !isTablet;

    return Drawer(
      width: width,
      backgroundColor: const Color(0xFFF5F7FA),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: Obx(
        () => Column(
          children: [
            _buildDrawerHeader(
              context,
              controller,
              compact: compactHeader,
              isTablet: isTablet,
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 14, 16, isTablet ? 20 : 16),
                children: [
                  // Secondary to the header: the rest of the connected
                  // commercial's data, kept to one line each.
                  _buildDrawerUserInfo(controller),
                  const SizedBox(height: 22),

                  // Main part of the drawer: one tall, separate card per
                  // action so they are the obvious thing to tap.
                  _drawerSectionLabel('Actions'),
                  _drawerActionTile(
                    icon: Icons.add_business_outlined,
                    iconColor: const Color(0xFF16A34A),
                    title: _tr('newClientB2B'),
                    subtitle: _tr('createNewClient'),
                    onTap: () {
                      Get.back();
                      controller.openClientForm();
                    },
                  ),
                  const SizedBox(height: 10),
                  _drawerActionTile(
                    icon: Icons.person_add_alt_1_outlined,
                    iconColor: ColorManager.primaryColor,
                    title: _tr('subClientsProspects'),
                    subtitle: _tr('manageSubClientsProspects'),
                    onTap: () {
                      Get.back();
                      _openSubClientsManagementSheet(controller);
                    },
                  ),
                  const SizedBox(height: 10),
                  _drawerActionTile(
                    icon: Icons.inventory_2_outlined,
                    iconColor: const Color(0xFF7C3AED),
                    title: 'Stocks',
                    subtitle: 'Consulter stock et réservations',
                    onTap: () {
                      Get.back();
                      Get.to(() => const CommercialStockPage());
                    },
                  ),
                  const SizedBox(height: 24),

                  _drawerSectionLabel(_tr('language')),
                  _buildDrawerLanguageSwitch(controller),
                ],
              ),
            ),

            // Pinned footer: logout never scrolls away.
            _buildDrawerFooter(controller),
          ],
        ),
      ),
    );
  }

  /// Branded header: the logo on white over the app gradient, with the signed
  /// in commercial underneath.
  Widget _buildDrawerHeader(
    BuildContext context,
    CommercialMapController controller, {
    required bool compact,
    required bool isTablet,
  }) {
    final name = controller.profileData['name']?.isNotEmpty == true
        ? controller.profileData['name']!
        : '${controller.profileData['nom'] ?? ''} ${controller.profileData['prenom'] ?? ''}'
            .trim();
    final email = controller.profileData['email']?.isNotEmpty == true
        ? controller.profileData['email']!
        : '-';

    final identity = Row(
      children: [
        _drawerLogoBadge(compact ? 46 : (isTablet ? 68 : 60)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Connecté en tant que',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                name.isEmpty ? '-' : name,
                style: TextStyle(
                  fontSize: compact ? 16 : (isTablet ? 21 : 19),
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                email,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.white.withOpacity(0.85),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      // The gradient runs under the status bar, but the content starts below
      // it: the safe-area inset is added on top of the real padding instead of
      // being used as it.
      padding: EdgeInsets.fromLTRB(
        18,
        MediaQuery.paddingOf(context).top + (compact ? 18 : 30),
        18,
        compact ? 18 : 30,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ColorManager.primaryColor, ColorManager.primaryVariant],
        ),
        borderRadius: BorderRadius.only(bottomRight: Radius.circular(24)),
      ),
      child: identity,
    );
  }

  /// The logo as a small round badge: white disc, because the mark is blue,
  /// with the artwork cover-cropped to its own ratio so the asset's empty
  /// margins do not shrink it inside the circle.
  Widget _drawerLogoBadge(double size) {
    final artWidth = size * 0.78;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: ColorManager.white,
        shape: BoxShape.circle,
      ),
      child: SizedBox(
        width: artWidth,
        height: artWidth / (280 / 150),
        child: Image.asset(AppImages.logo, fit: BoxFit.cover),
      ),
    );
  }

  /// Compact companion to the header: the fields the header does not already
  /// show, one line each. Anything missing is simply left out.
  Widget _buildDrawerUserInfo(CommercialMapController controller) {
    final rows = <Widget>[];

    void add(IconData icon, String? value) {
      final text = value?.trim() ?? '';
      if (text.isEmpty || text.toLowerCase() == 'null') return;
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 9));
      rows.add(_drawerInfoRow(icon, text));
    }

    add(Icons.phone_outlined, controller.profileData['telephone']);
    add(
      Icons.badge_outlined,
      controller.profileRoles.isEmpty ? null : controller.profileRoles.join(', '),
    );
    add(
      Icons.place_outlined,
      controller.profileRegions.isEmpty
          ? null
          : controller.profileRegions.join(', '),
    );

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: ColorManager.primaryColor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }

  Widget _drawerInfoRow(IconData icon, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: ColorManager.primaryColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF384049),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDrawerLanguageSwitch(CommercialMapController controller) {
    final languageService = Get.find<LanguageService>();

    return Obx(
      () => Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: ColorManager.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0x14000000)),
        ),
        child: Row(
          children: [
            _drawerLanguageOption(
              flag: '\u{1F1EB}\u{1F1F7}',
              label: _tr('french'),
              selected: languageService.currentLanguage.value == 'fr',
              onTap: () => controller.changeLanguage('fr'),
            ),
            const SizedBox(width: 5),
            _drawerLanguageOption(
              flag: '\u{1F1F9}\u{1F1F3}',
              label: _tr('arabic'),
              selected: languageService.currentLanguage.value == 'ar',
              onTap: () => controller.changeLanguage('ar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerLanguageOption({
    required String flag,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(26),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? ColorManager.primaryColor : Colors.transparent,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(flag, style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? ColorManager.textOnPrimary
                          : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerFooter(CommercialMapController controller) {
    return Container(
      decoration: const BoxDecoration(
        color: ColorManager.white,
        border: Border(top: BorderSide(color: Color(0x14000000))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () async {
                Get.back();
                await controller.logout();
              },
              icon: const Icon(Icons.logout, size: 18),
              label: Text(
                _tr('logout'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                backgroundColor: const Color(0x14DC2626),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _drawerSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: ColorManager.textSecondary,
        ),
      ),
    );
  }

  Widget _drawerActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: ColorManager.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x14000000)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black45,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Colors.black26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  // ---------------------------------------------------------------------------
  // Client form
  // ---------------------------------------------------------------------------

  Widget _buildClientFormOverlay(
    BuildContext context,
    CommercialMapController controller,
  ) {
    final size = MediaQuery.sizeOf(context);

    // Deliberate breathing room on every side so the map stays visible around
    // the dialog: a fixed base plus 2.5% of the screen, which keeps the inset
    // proportional from a small phone to a tablet.
    final horizontal = 24 + size.width * 0.025;
    final vertical = 24 + size.height * 0.025;

    return Container(
      color: Colors.black.withOpacity(0.55),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontal,
            vertical: vertical,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Material(
                color: ColorManager.white,
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFormHeader(controller),

                    // Only the fields scroll: the title and the submit button
                    // stay in view the whole time.
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                        child: Form(
                          key: controller.clientFormKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildFormIdentitySection(controller),
                              _buildFormContactSection(controller),
                              _buildFormLocationSection(controller),
                              _buildFormBrandsSection(controller),
                              _buildFormExtrasSection(controller),
                            ],
                          ),
                        ),
                      ),
                    ),

                    _buildFormFooter(controller),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormHeader(CommercialMapController controller) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ColorManager.primaryColor, ColorManager.primaryVariant],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.business, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Obx(
              () => Text(
                controller.registrationType.value == 'sub_client'
                    ? 'Sous-client / Prospect'
                    : _tr('newClientB2B'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          IconButton(
            onPressed: controller.closeClientForm,
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'Fermer',
          ),
        ],
      ),
    );
  }

  /// Who the client is. Short fields are paired two per line.
  Widget _buildFormIdentitySection(CommercialMapController controller) {
    return Obx(() {
      final isSubClient = controller.registrationType.value == 'sub_client';

      if (isSubClient) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _formSectionTitle('Identité'),
            _formFieldPair(
              _formField(
                label: 'Nom',
                controller: controller.nomController,
              ),
              _formField(
                label: 'Prénom',
                controller: controller.prenomController,
              ),
            ),
            const SizedBox(height: 14),
            _formField(
              label: 'Agence',
              controller: controller.nomAgenceController,
            ),
            if (!controller.isProspectFormMode.value) ...[
              const SizedBox(height: 14),
              _buildFormParentClients(controller),
            ],
            const SizedBox(height: 20),
          ],
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _formSectionTitle('Identité'),
          _formFieldPair(
            _formField(
              label: _tr('codeClientOptional'),
              controller: controller.codeClientController,
              enabled: controller.isFieldEditableForCommercialUpdate(
                'codeClient',
              ),
            ),
            _formField(
              label: _tr('matriculeFiscalOptional'),
              controller: controller.matriculeFiscalController,
              enabled: controller.isFieldEditableForCommercialUpdate(
                'matriculeFiscal',
              ),
            ),
          ),
          const SizedBox(height: 14),
          _formField(
            label: _tr('raisonSocialeOptional'),
            controller: controller.raisonSocialeController,
            enabled: controller.isFieldEditableForCommercialUpdate(
              'raisonSociale',
            ),
          ),
          const SizedBox(height: 20),
        ],
      );
    });
  }

  Widget _buildFormContactSection(CommercialMapController controller) {
    return Obx(() {
      final phone = _formField(
        label: _tr('phoneOptional'),
        controller: controller.telephoneController,
        keyboardType: TextInputType.phone,
      );

      // Sub-clients have no e-mail field, so the phone takes the full width.
      if (controller.registrationType.value != 'b2b') {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _formSectionTitle('Contact'),
            phone,
            const SizedBox(height: 20),
          ],
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _formSectionTitle('Contact'),
          _formFieldPair(
            phone,
            _formField(
              label: _tr('emailOptional'),
              controller: controller.emailController,
              keyboardType: TextInputType.emailAddress,
            ),
          ),
          const SizedBox(height: 20),
        ],
      );
    });
  }

  Widget _buildFormLocationSection(CommercialMapController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _formSectionTitle('Position'),
        Row(
          children: [
            Expanded(
              child: _formSecondaryButton(
                icon: Icons.map_outlined,
                label: 'Sur la carte',
                onPressed: controller.pickLocationFromMap,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Obx(
                () => _formSecondaryButton(
                  icon: Icons.my_location,
                  label: _tr('myPosition'),
                  onPressed: controller.isLoadingLocation.value
                      ? null
                      : controller.fillWithCurrentLocation,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Obx(() {
          final location = controller.selectedLocation.value;
          final isSet = location != null;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSet
                  ? const Color(0xFF22C55E).withOpacity(0.08)
                  : ColorManager.primaryColor.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  isSet ? Icons.check_circle_outline : Icons.location_on,
                  size: 17,
                  color: isSet
                      ? const Color(0xFF16A34A)
                      : ColorManager.primaryColor,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    isSet
                        ? '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}'
                        : _tr('touchMapBoutique'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSet ? FontWeight.w600 : FontWeight.w400,
                      color: isSet
                          ? const Color(0xFF15803D)
                          : ColorManager.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildFormBrandsSection(CommercialMapController controller) {
    return Obx(() {
      final type = controller.registrationType.value;
      if (type != 'b2b' && type != 'sub_client') return const SizedBox.shrink();

      final canEdit = type == 'sub_client' ||
          controller.canEditBrandsForCurrentClient;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _formSectionTitle('Marques automobiles'),
          _formPickerTile(
            icon: Icons.directions_car_outlined,
            label: controller.selectedBrands.isEmpty
                ? 'Aucune marque sélectionnée'
                : 'Sélectionner les marques',
            count: controller.selectedBrands.length,
            onTap: canEdit ? () => _openBrandPicker(controller) : null,
          ),
          if (controller.selectedBrands.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: controller.selectedBrands
                  .map(
                    (brand) => _formChip(
                      label: brand.displayName,
                      onDeleted:
                          canEdit ? () => controller.toggleBrand(brand) : null,
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 20),
        ],
      );
    });
  }

  Widget _buildFormParentClients(CommercialMapController controller) {
    return Obx(() {
      final selected = controller.getSelectedParentClients();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _formPickerTile(
            icon: Icons.account_tree_outlined,
            label: selected.isEmpty
                ? _tr('noneSelectedProspectHint')
                : _tr('parentClients'),
            count: selected.length,
            onTap: () => _openParentClientsPicker(controller),
          ),
          if (selected.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: selected.map((parent) {
                final id = _value(parent['id']);
                return _formChip(
                  label: controller.getClientDisplayName(parent),
                  onDeleted: () => controller.toggleParentClientSelection(id),
                );
              }).toList(),
            ),
          ],
        ],
      );
    });
  }

  Widget _buildFormExtrasSection(CommercialMapController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _formSectionTitle('Photo et note'),
        Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _formSecondaryButton(
                      icon: Icons.camera_alt_outlined,
                      label: _tr('takePhoto'),
                      onPressed: controller.isPickingImage.value
                          ? null
                          : controller.pickImageFromCamera,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _formSecondaryButton(
                      icon: Icons.photo_library_outlined,
                      label: _tr('gallery'),
                      onPressed: controller.isPickingImage.value
                          ? null
                          : controller.pickImageFromGallery,
                    ),
                  ),
                ],
              ),
              if (controller.selectedImageBytes.value != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 96,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            controller.selectedImageBytes.value!,
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
                            borderRadius: BorderRadius.circular(14),
                            onTap: controller.removeSelectedImage,
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
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
        const SizedBox(height: 14),
        _formField(
          label: 'Note',
          controller: controller.noteController,
          maxLines: 3,
          hint: 'Remarque libre...',
        ),
      ],
    );
  }

  Widget _buildFormFooter(CommercialMapController controller) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: const BoxDecoration(
        color: ColorManager.white,
        border: Border(top: BorderSide(color: Color(0x14000000))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: OutlinedButton(
              onPressed: controller.closeClientForm,
              style: OutlinedButton.styleFrom(
                foregroundColor: ColorManager.textSecondary,
                padding: const EdgeInsets.symmetric(vertical: 15),
                side: const BorderSide(color: Color(0x22000000)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Annuler',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Obx(
              () => ElevatedButton(
                onPressed: controller.isCreatingClient.value
                    ? null
                    : controller.submitClientForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorManager.primaryColor,
                  disabledBackgroundColor:
                      ColorManager.primaryColor.withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  elevation: 0,
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
                    : Text(
                        controller.selectedClientForUpdate.value != null
                            ? controller.clientLocationActionLabel
                            : _tr('createClient'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openBrandPicker(CommercialMapController controller) {
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
                  initialBrands: CarBrandsModel(
                    selectedBrands: controller.selectedBrands,
                  ),
                  onBrandsChanged: (brands) {
                    controller.selectedBrands.clear();
                    controller.selectedBrands.addAll(brands.selectedBrands);
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

  // --- Form building blocks --------------------------------------------------

  Widget _formSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
          color: ColorManager.primaryColor,
        ),
      ),
    );
  }

  /// Two fields on one line. The labels sit in a fixed-height box so the
  /// inputs stay aligned even when one label wraps.
  Widget _formFieldPair(Widget left, Widget right) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }

  Widget _formField({
    required String label,
    required TextEditingController controller,
    String? hint,
    bool enabled = true,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    OutlineInputBorder border({Color? color}) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: color == null
              ? BorderSide.none
              : BorderSide(color: color, width: 1.5),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 30,
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.25,
              fontWeight: FontWeight.w600,
              color: enabled
                  ? ColorManager.textSecondary
                  : ColorManager.textTertiary,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 13, color: Colors.black26),
            isDense: true,
            filled: true,
            fillColor: enabled
                ? const Color(0xFFF4F6F8)
                : const Color(0xFFEDEFF1),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 13,
            ),
            border: border(),
            enabledBorder: border(),
            disabledBorder: border(),
            focusedBorder: border(color: ColorManager.primaryColor),
            errorBorder: border(color: ColorManager.errorColor),
            focusedErrorBorder: border(color: ColorManager.errorColor),
          ),
        ),
      ],
    );
  }

  Widget _formSecondaryButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: ColorManager.primaryColor,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        side: BorderSide(color: ColorManager.primaryColor.withOpacity(0.35)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// A one-line entry point to a picker, with how many items are chosen.
  Widget _formPickerTile({
    required IconData icon,
    required String label,
    required int count,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;

    return Material(
      color: const Color(0xFFF4F6F8),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: enabled
                    ? ColorManager.primaryColor
                    : ColorManager.textTertiary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: enabled ? Colors.black87 : ColorManager.textTertiary,
                  ),
                ),
              ),
              if (count > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: ColorManager.primaryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Icon(
                Icons.chevron_right,
                size: 18,
                color: enabled ? Colors.black38 : Colors.black12,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formChip({required String label, VoidCallback? onDeleted}) {
    return Container(
      padding: EdgeInsets.fromLTRB(10, 5, onDeleted == null ? 10 : 5, 5),
      decoration: BoxDecoration(
        color: ColorManager.primaryColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: ColorManager.primaryColor,
            ),
          ),
          if (onDeleted != null) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: onDeleted,
              borderRadius: BorderRadius.circular(10),
              child: Icon(
                Icons.close,
                size: 14,
                color: ColorManager.primaryColor,
              ),
            ),
          ],
        ],
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

  /// When both are provided the parent owns the expanded state, which is how
  /// the clients list keeps a single card open at a time. Left null, the card
  /// expands and collapses on its own.
  final bool? isExpanded;
  final ValueChanged<bool>? onExpandedChanged;

  /// Row-only mode used by the landscape master/detail layout: the card never
  /// unfolds, it just marks itself as the selected one.
  final bool compact;

  const _ExpandableClientCard({
    required this.controller,
    required this.client,
    required this.onTap,
    required this.metaChipBuilder,
    required this.formatDate,
    required this.hasValue,
    this.isExpanded,
    this.onExpandedChanged,
    this.compact = false,
  });

  @override
  State<_ExpandableClientCard> createState() => _ExpandableClientCardState();
}

class _ExpandableClientCardState extends State<_ExpandableClientCard>
    with SingleTickerProviderStateMixin {
  bool _localExpanded = false;
  late final AnimationController _animController;
  late final Animation<double> _expandAnim;

  bool get _expanded => widget.isExpanded ?? _localExpanded;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: _expanded ? 1 : 0,
    );
    _expandAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void didUpdateWidget(_ExpandableClientCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The parent may have collapsed this card by opening another one.
    if (widget.isExpanded != null && widget.isExpanded != oldWidget.isExpanded) {
      widget.isExpanded! ? _animController.forward() : _animController.reverse();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggle() {
    final next = !_expanded;
    if (widget.onExpandedChanged != null) {
      widget.onExpandedChanged!(next);
      return;
    }
    setState(() => _localExpanded = next);
    next ? _animController.forward() : _animController.reverse();
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

    final isSelectedRow = widget.compact && _expanded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isSelectedRow
            ? Border.all(color: ColorManager.primaryColor, width: 1.6)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isSelectedRow ? 0.10 : 0.06),
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
            // ── Collapsed header ─────────────────────────────────────────
            // Tapping the row only expands it; every action is an explicit
            // button below, so nothing destructive happens by accident.
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _toggle,
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
                            if (_clientSubtitle(client).isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                _clientSubtitle(client),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.black45,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 5),
                            // Wrap, not Row: in the narrow landscape column
                            // the two tags do not always fit side by side.
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _clientStatusTag(
                                  color: locationColor,
                                  label: hasLocation
                                      ? 'Localisé'
                                      : 'Sans position',
                                ),
                                _clientStatusTag(
                                  color: isActive
                                      ? const Color(0xFF22C55E)
                                      : const Color(0xFFEF4444),
                                  label: isActive ? 'Actif' : 'Inactif',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Compact rows point at the side panel; normal rows
                      // rotate a chevron over the details they unfold.
                      GestureDetector(
                        onTap: _toggle,
                        child: AnimatedRotation(
                          turns: (!widget.compact && _expanded) ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 220),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: widget.compact && _expanded
                                  ? ColorManager.primaryColor
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              widget.compact
                                  ? Icons.chevron_right
                                  : Icons.keyboard_arrow_down,
                              size: 18,
                              color: widget.compact && _expanded
                                  ? Colors.white
                                  : Colors.black54,
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
            // Skipped in compact mode: there the details open in the side
            // panel instead of inside the row.
            if (!widget.compact)
              SizeTransition(
                sizeFactor: _expandAnim,
                axisAlignment: -1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 1, color: Colors.grey.shade100),
                    _ClientDetailsBody(
                      controller: controller,
                      client: client,
                      onTap: widget.onTap,
                      metaChipBuilder: widget.metaChipBuilder,
                      formatDate: widget.formatDate,
                      hasValue: widget.hasValue,
                    ),
                  ],
                ),
              ),
          ],
        ),
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
// ---------------------------------------------------------------------------
// Clients list bottom sheet
// ---------------------------------------------------------------------------

enum _ClientsFilter { all, located, missing }

/// Builds one client row: the card, what its action button does, whether it is
/// currently the open one, and how it asks to become the open one.
typedef _ClientCardBuilder = Widget Function(
  Map<String, dynamic> client,
  VoidCallback? onTap,
  bool isExpanded,
  ValueChanged<bool> onExpandedChanged,
  bool compact,
);

/// Builds the full details of one client for the landscape side panel.
typedef _ClientDetailBuilder = Widget Function(
  Map<String, dynamic> client,
  VoidCallback? onTap,
);

/// Draggable sheet listing the commercial's clients.
///
/// Replaces the old fixed-height sheet: the header (title, search, filters)
/// stays pinned while the list scrolls, and the sheet can be dragged between
/// half screen and almost full screen.
class _ClientsListSheet extends StatefulWidget {
  const _ClientsListSheet({
    required this.controller,
    required this.cardBuilder,
    required this.detailBuilder,
  });

  final CommercialMapController controller;
  final _ClientCardBuilder cardBuilder;
  final _ClientDetailBuilder detailBuilder;

  @override
  State<_ClientsListSheet> createState() => _ClientsListSheetState();
}

class _ClientsListSheetState extends State<_ClientsListSheet> {
  final TextEditingController _searchController = TextEditingController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  _ClientsFilter _filter = _ClientsFilter.all;

  /// Identifier of the one card allowed to be open; opening another closes it.
  String? _expandedClientKey;

  static const double _maxSize = 0.95;

  bool get _isLandscape =>
      MediaQuery.orientationOf(context) == Orientation.landscape;

  /// Landscape screens are short, so the sheet opens taller there.
  double get _initialSize => _isLandscape ? 0.75 : 0.52;

  double get _minSize => _isLandscape ? 0.4 : 0.32;

  /// Drag on the header: the modal route's own drag is off, so the handle has
  /// to resize the sheet itself.
  void _onHeaderDrag(DragUpdateDetails details) {
    if (!_sheetController.isAttached) return;
    final height = MediaQuery.sizeOf(context).height;
    if (height <= 0) return;

    _sheetController.jumpTo(
      (_sheetController.size - details.delta.dy / height)
          .clamp(_minSize, _maxSize),
    );
  }

  void _onHeaderDragEnd(DragEndDetails details) {
    if (!_sheetController.isAttached) return;

    final current = _sheetController.size;
    var nearest = _minSize;
    for (final target in [_minSize, _initialSize, _maxSize]) {
      if ((target - current).abs() < (nearest - current).abs()) {
        nearest = target;
      }
    }

    _sheetController.animateTo(
      nearest,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  static String _keyOf(Map<String, dynamic> client, int index) {
    for (final field in ['id', 'codeClient']) {
      final raw = client[field]?.toString().trim() ?? '';
      if (raw.isNotEmpty && raw.toLowerCase() != 'null') return '$field:$raw';
    }
    return 'index:$index';
  }

  @override
  void dispose() {
    _searchController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  static bool _hasLocation(Map<String, dynamic> client) {
    final lat = double.tryParse(client['latitude']?.toString() ?? '');
    final lng = double.tryParse(client['longitude']?.toString() ?? '');
    return lat != null && lng != null && lat != 0.0 && lng != 0.0;
  }

  List<Map<String, dynamic>> get _visibleClients {
    final clients = widget.controller.filteredMyClients;
    switch (_filter) {
      case _ClientsFilter.all:
        return clients;
      case _ClientsFilter.located:
        return clients.where(_hasLocation).toList();
      case _ClientsFilter.missing:
        return clients.where((c) => !_hasLocation(c)).toList();
    }
  }

  /// What tapping the row's action does: close the sheet and hand the client
  /// to the map for a location update.
  VoidCallback _editAction(
    CommercialMapController controller,
    Map<String, dynamic> client,
  ) {
    return () {
      Get.back();
      controller.selectClientForLocationUpdate(client);
    };
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final isLandscape = _isLandscape;

    return DraggableScrollableSheet(
      // Opens partially so the map stays visible, and snaps to near full
      // screen when dragged up.
      controller: _sheetController,
      initialChildSize: _initialSize,
      minChildSize: _minSize,
      maxChildSize: _maxSize,
      snap: true,
      snapSizes: [_initialSize, _maxSize],
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF7F8FA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: _onHeaderDrag,
                onVerticalDragEnd: _onHeaderDragEnd,
                child: _buildHeader(controller, isLandscape: isLandscape),
              ),
              Expanded(
                child: Obx(() {
                  if (controller.isLoadingMyClients.value &&
                      controller.myClients.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final clients = _visibleClients;
                  if (clients.isEmpty) {
                    return _buildEmptyState(controller);
                  }

                  if (!isLandscape) {
                    return _buildList(controller, clients, scrollController);
                  }

                  // Landscape: rows on the left, the selected client's
                  // details on the right.
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 4,
                        child: _buildList(
                          controller,
                          clients,
                          scrollController,
                          compact: true,
                        ),
                      ),
                      const VerticalDivider(width: 1, thickness: 1),
                      Expanded(
                        flex: 5,
                        child: _buildDetailPane(controller, clients),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList(
    CommercialMapController controller,
    List<Map<String, dynamic>> clients,
    ScrollController scrollController, {
    bool compact = false,
  }) {
    return RefreshIndicator(
      onRefresh: controller.loadMyClients,
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: clients.length,
        itemBuilder: (_, index) {
          final client = clients[index];
          final key = _keyOf(client, index);

          return widget.cardBuilder(
            client,
            _editAction(controller, client),
            key == _expandedClientKey,
            (open) => setState(
              () => _expandedClientKey = open ? key : null,
            ),
            compact,
          );
        },
      ),
    );
  }

  /// Right-hand panel in landscape: the selected client, or a hint to pick one.
  Widget _buildDetailPane(
    CommercialMapController controller,
    List<Map<String, dynamic>> clients,
  ) {
    Map<String, dynamic>? selected;
    for (var i = 0; i < clients.length; i++) {
      if (_keyOf(clients[i], i) == _expandedClientKey) {
        selected = clients[i];
        break;
      }
    }

    if (selected == null) {
      return Container(
        color: Colors.white,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.touch_app_outlined,
              size: 40,
              color: Colors.black26,
            ),
            const SizedBox(height: 12),
            Text(
              'Sélectionnez un client pour voir ses détails',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        key: ValueKey(_expandedClientKey),
        padding: const EdgeInsets.only(bottom: 16),
        child: widget.detailBuilder(
          selected,
          _editAction(controller, selected),
        ),
      ),
    );
  }

  Widget _buildHeader(
    CommercialMapController controller, {
    required bool isLandscape,
  }) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          UiTranslations.t('clientsList'),
          style: TextStyle(
            fontSize: isLandscape ? 16 : 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Obx(
          () => Text(
            '${controller.myClients.length} client(s)',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
      ],
    );

    final closeButton = IconButton(
      onPressed: () => Get.back(),
      icon: const Icon(Icons.close),
      color: Colors.black45,
      tooltip: 'Fermer',
    );

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.fromLTRB(16, 10, 16, isLandscape ? 10 : 14),
      child: Column(
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
          SizedBox(height: isLandscape ? 10 : 14),

          // Landscape screens are short: the title and the search field share
          // a line instead of stacking.
          if (isLandscape)
            Row(
              children: [
                Flexible(child: titleBlock),
                const SizedBox(width: 16),
                Expanded(flex: 3, child: _buildSearchField(controller)),
                closeButton,
              ],
            )
          else ...[
            Row(children: [Expanded(child: titleBlock), closeButton]),
            const SizedBox(height: 10),
            _buildSearchField(controller),
          ],
          const SizedBox(height: 12),
          Obx(() {
            final all = controller.filteredMyClients;
            final located = all.where(_hasLocation).length;
            return Row(
              children: [
                _filterChip(_ClientsFilter.all, 'Tous', all.length),
                const SizedBox(width: 8),
                _filterChip(_ClientsFilter.located, 'Localisés', located),
                const SizedBox(width: 8),
                _filterChip(
                  _ClientsFilter.missing,
                  'Sans position',
                  all.length - located,
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSearchField(CommercialMapController controller) {
    return TextField(
      controller: _searchController,
      onChanged: controller.setClientsSearchQuery,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Rechercher client, code, téléphone...',
        hintStyle: const TextStyle(fontSize: 13),
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: Obx(
          () => controller.clientsSearchQuery.value.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    controller.setClientsSearchQuery('');
                  },
                  icon: const Icon(Icons.close, size: 18),
                ),
        ),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF1F3F6),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _filterChip(_ClientsFilter filter, String label, int count) {
    final selected = _filter == filter;

    return InkWell(
      onTap: () => setState(() => _filter = filter),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color:
              selected ? ColorManager.primaryColor : const Color(0xFFF1F3F6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : Colors.black54,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white70 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(CommercialMapController controller) {
    final searching = controller.clientsSearchQuery.value.isNotEmpty ||
        _filter != _ClientsFilter.all;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searching ? Icons.search_off : Icons.groups_outlined,
              size: 44,
              color: Colors.black26,
            ),
            const SizedBox(height: 12),
            Text(
              searching
                  ? 'Aucun client ne correspond à la recherche'
                  : UiTranslations.t('noClientsFound'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared client presentation helpers
// ---------------------------------------------------------------------------

/// Secondary identity line: the two fields a commercial actually scans for.
String _clientSubtitle(Map<String, dynamic> client) {
  final parts = <String>[];
  for (final key in ['codeClient', 'telephone']) {
    final raw = client[key]?.toString().trim() ?? '';
    if (raw.isNotEmpty && raw.toLowerCase() != 'null') parts.add(raw);
  }
  return parts.join('  •  ');
}

Widget _clientStatusTag({required Color color, required String label}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );
}

/// Parsed coordinates, or `(null, null)` when the client has no usable point.
({double? lat, double? lng}) _clientLatLng(Map<String, dynamic> client) {
  final lat = double.tryParse(client['latitude']?.toString() ?? '');
  final lng = double.tryParse(client['longitude']?.toString() ?? '');
  if (lat == null || lng == null || lat == 0.0 || lng == 0.0) {
    return (lat: null, lng: null);
  }
  return (lat: lat, lng: lng);
}

// ---------------------------------------------------------------------------
// Client details
// ---------------------------------------------------------------------------

/// Everything known about one client: photo, coordinates, fields, dates and
/// the two actions.
///
/// Shown inline under the row in portrait, and in the side panel in landscape.
class _ClientDetailsBody extends StatelessWidget {
  const _ClientDetailsBody({
    required this.controller,
    required this.client,
    required this.onTap,
    required this.metaChipBuilder,
    required this.formatDate,
    required this.hasValue,
    this.showHeader = false,
  });

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

  /// The side panel has no row above it, so it repeats the client identity.
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final coords = _clientLatLng(client);
    final hasLocation = coords.lat != null;
    final locationColor =
        hasLocation ? const Color(0xFF22C55E) : const Color(0xFFF59E0B);
    final imageUrl = controller.getClientImageUrl(client);
    final isActive = client['actif'] == true;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            Text(
              controller.getClientDisplayName(client),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
            if (_clientSubtitle(client).isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                _clientSubtitle(client),
                style: const TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _clientStatusTag(
                  color: locationColor,
                  label: hasLocation ? 'Localisé' : 'Sans position',
                ),
                _clientStatusTag(
                  color: isActive
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFEF4444),
                  label: isActive ? 'Actif' : 'Inactif',
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],

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
                      color: Colors.black38,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // GPS row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: locationColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: locationColor.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  hasLocation ? Icons.my_location : Icons.location_searching,
                  size: 14,
                  color: locationColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasLocation
                        ? '${coords.lat!.toStringAsFixed(5)}, ${coords.lng!.toStringAsFixed(5)}'
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
              metaChipBuilder(
                icon: Icons.badge_outlined,
                label: 'Code',
                value: client['codeClient'],
              ),
              metaChipBuilder(
                icon: Icons.phone_outlined,
                label: 'Tél',
                value: client['telephone'],
              ),
              metaChipBuilder(
                icon: Icons.email_outlined,
                label: 'Email',
                value: client['email'],
              ),
              metaChipBuilder(
                icon: Icons.receipt_long_outlined,
                label: 'Matricule',
                value: client['matriculeFiscal'],
              ),
              metaChipBuilder(
                icon: Icons.person_outline,
                label: 'Commercial',
                value: client['commercialName'],
              ),
            ],
          ),

          // Dates
          if (hasValue(client['dateCreation']) ||
              hasValue(client['dateModification'])) ...[
            const SizedBox(height: 10),
            Container(height: 1, color: Colors.grey.shade100),
            const SizedBox(height: 8),
            if (hasValue(client['dateCreation']))
              _dateRow('Créé le', formatDate(client['dateCreation'])),
            if (hasValue(client['dateModification']))
              _dateRow('Modifié le', formatDate(client['dateModification'])),
          ],

          const SizedBox(height: 12),

          // Actions
          Row(
            children: [
              if (hasLocation) ...[
                Expanded(
                  child: _action(
                    icon: Icons.map_outlined,
                    label: 'Voir sur la carte',
                    onPressed: () {
                      Get.back();
                      controller.focusOnLocation(
                        LatLng(coords.lat!, coords.lng!),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: _action(
                  icon: Icons.edit_location_alt,
                  label: 'Modifier',
                  primary: true,
                  onPressed: onTap,
                ),
              ),
            ],
          ),
        ],
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
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _action({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool primary = false,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
      ),
      style: TextButton.styleFrom(
        backgroundColor:
            primary ? ColorManager.primaryColor : Colors.grey.shade100,
        foregroundColor: primary ? Colors.white : const Color(0xFF444C55),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../../../core/services/language_service.dart';
import '../../../../localization/ui_translations.dart';
import '../../../../routes/app_routes.dart';
import 'commercial_stock_controller.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../data/models/brands_model.dart';
import '../../data/models/sync_model.dart';
import '../../data/services/client_annotations_service.dart';
import '../../data/services/database_service.dart';
import '../../data/services/reminder_notification_service.dart';
import '../../data/services/sync_service.dart';
import '../widgets/client_palette.dart';
import '../../../../core/theme/app_theme.dart';

class CommercialMapController extends GetxController {
  static const String _draftStorageKey = 'commercial_client_draft';
  static const String _registeredPinsStorageKey = 'commercial_registered_pins';
  static const String _submittedRecordsStorageKey =
      'commercial_submitted_records';

  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();
  final DatabaseService _db = DatabaseService.instance;

  /// The offline queue.
  ///
  /// Found rather than injected, and registered here if nobody has: the map is
  /// where a commercial lands after signing in and it carries no binding of
  /// its own, so this is the first screen that needs the queue to exist.
  SyncService get _sync => Get.isRegistered<SyncService>()
      ? Get.find<SyncService>()
      : Get.put<SyncService>(SyncService(), permanent: true);

  /// Whether what is on screen came off the device rather than the backend.
  final RxBool isShowingCachedClients = false.obs;

  // Map controller
  GoogleMapController? mapController;
  final Rx<MapType> selectedMapType = Rx<MapType>(MapType.normal);

  /// Live traffic overlay. Free with the Maps SDK, so it is offered as a layer.
  final RxBool isTrafficEnabled = false.obs;

  // User's current location
  final Rx<Position?> currentPosition = Rx<Position?>(null);

  // Selected location for new client
  final Rx<LatLng?> selectedLocation = Rx<LatLng?>(null);

  // Markers
  final RxSet<Marker> markers = <Marker>{}.obs;
  final RxList<_RegisteredClientPin> registeredPins =
      <_RegisteredClientPin>[].obs;
  final RxList<Map<String, dynamic>> submittedRecords =
      <Map<String, dynamic>>[].obs;

  // Loading states
  final RxBool isLoadingLocation = false.obs;
  final RxBool isCreatingClient = false.obs;
  final RxBool isPickingImage = false.obs;

  // Form controllers
  final TextEditingController codeClientController = TextEditingController();
  final TextEditingController raisonSocialeController = TextEditingController();
  final TextEditingController matriculeFiscalController =
      TextEditingController();
  final TextEditingController telephoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController parentClientIdController =
      TextEditingController();
  final TextEditingController nomController = TextEditingController();
  final TextEditingController prenomController = TextEditingController();
  final TextEditingController nomAgenceController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  // Form key
  final GlobalKey<FormState> clientFormKey = GlobalKey<FormState>();

  // Show form
  final RxBool showClientForm = false.obs;
  final RxBool isPickingLocationFromMap = false.obs;
  final RxBool hasPendingDragPosition = false.obs;

  // Type + media
  final RxString registrationType = 'b2b'.obs;
  final RxBool isProspectFormMode = false.obs;

  /// Whether the "add" speed dial on the map is expanded.
  final RxBool isAddMenuOpen = false.obs;

  // ---------------------------------------------------------------------------
  // Marker selection
  // ---------------------------------------------------------------------------

  /// Marker currently tapped. Its pin is drawn larger and its details open
  /// beside it.
  final RxString selectedMarkerId = ''.obs;

  /// The record behind the selected marker, shown in the side panel.
  final Rx<Map<String, dynamic>?> markerPopupClient = Rx<Map<String, dynamic>?>(
    null,
  );

  /// Which side of the screen the details panel sits on. The marker is moved
  /// to the opposite side, whichever is nearer.
  final RxBool markerPopupOnRight = true.obs;

  /// Viewport geometry, published by the page because the controller has no
  /// BuildContext of its own. Needed to work out which half of the screen a
  /// marker is in and how far to scroll it.
  Size? viewportSize;
  double viewportPixelRatio = 1;

  /// Opens the details panel for a marker and slides it clear of the panel.
  Future<void> selectMarker({
    required String id,
    required LatLng position,
    Map<String, dynamic>? client,
  }) async {
    selectedMarkerId.value = id;
    markerPopupClient.value = client;
    popupView.value = 'details';
    editingNote.value = null;

    await _refreshMarkers();
    await _positionMarkerForPopup(position);
  }

  /// Hands the client's position to Google Maps for turn-by-turn directions.
  ///
  /// Uses the universal https link rather than a `google.navigation:` intent,
  /// so it opens the Maps app when installed and falls back to the browser
  /// when it is not.
  Future<void> openDirectionsTo(LatLng target) => _launchMaps(
    'https://www.google.com/maps/dir/?api=1'
    '&destination=${target.latitude},${target.longitude}'
    '&travelmode=driving',
  );

  /// Shows the client's position in Google Maps, without starting navigation.
  Future<void> openInGoogleMaps(LatLng target) => _launchMaps(
    'https://www.google.com/maps/search/?api=1'
    '&query=${target.latitude},${target.longitude}',
  );

  Future<void> _launchMaps(String url) async {
    try {
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
    } catch (_) {
      // Falls through to the message below.
    }

    Get.snackbar(
      _tr('error'),
      "Impossible d'ouvrir Google Maps",
      backgroundColor: ColorManager.errorColor,
      colorText: Colors.white,
    );
  }

  // ---------------------------------------------------------------------------
  // Notes and reminders
  //
  // Both are stored on the device: there is no server endpoint for either.
  // ---------------------------------------------------------------------------

  final ClientAnnotationsService _annotations =
      ClientAnnotationsService.instance;
  final ReminderNotificationService _notifications =
      ReminderNotificationService.instance;

  final RxList<ClientNote> clientNotes = <ClientNote>[].obs;
  final RxList<ClientReminder> clientReminders = <ClientReminder>[].obs;

  /// Which view the marker fiche is showing. The popup acts as its own little
  /// navigator so notes can open in place, with a back arrow.
  final RxString popupView = 'details'.obs;

  /// The note being written or edited, when [popupView] is `noteEditor`.
  final Rx<ClientNote?> editingNote = Rx<ClientNote?>(null);

  Future<void> loadAnnotations() async {
    clientNotes.assignAll(await _annotations.loadNotes());
    clientReminders.assignAll(await _annotations.loadReminders());

    // Android drops pending alarms on reboot or force-stop, so everything
    // still due is re-armed at launch.
    unawaited(_notifications.rescheduleAll(clientReminders));
  }

  List<ClientNote> notesForClient(String clientId) {
    final notes = clientNotes
        .where((note) => note.clientId == clientId)
        .toList();
    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return notes;
  }

  List<ClientReminder> remindersForClient(String clientId) {
    final reminders = clientReminders
        .where((reminder) => reminder.clientId == clientId)
        .toList();
    reminders.sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return reminders;
  }

  Future<void> saveNote({
    required String clientId,
    required String title,
    required String body,
    ClientNote? existing,
  }) async {
    final now = DateTime.now();

    if (existing == null) {
      clientNotes.add(
        ClientNote(
          id: now.microsecondsSinceEpoch.toString(),
          clientId: clientId,
          title: title.trim(),
          body: body.trim(),
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else {
      final index = clientNotes.indexWhere((note) => note.id == existing.id);
      if (index == -1) return;
      clientNotes[index] = existing.copyWith(
        title: title.trim(),
        body: body.trim(),
        updatedAt: now,
      );
    }

    clientNotes.refresh();
    await _annotations.saveNotes(clientNotes);
  }

  Future<void> deleteNote(String noteId) async {
    clientNotes.removeWhere((note) => note.id == noteId);
    await _annotations.saveNotes(clientNotes);
  }

  Future<void> saveReminder({
    required Map<String, dynamic> client,
    required String title,
    required String context,
    required DateTime dueAt,
    ClientReminder? existing,
  }) async {
    final ClientReminder saved;

    if (existing != null) {
      final index = clientReminders.indexWhere(
        (reminder) => reminder.id == existing.id,
      );
      if (index == -1) return;
      saved = existing.copyWith(
        title: title.trim(),
        context: context.trim(),
        dueAt: dueAt,
      );
      clientReminders[index] = saved;
    } else {
      saved = ClientReminder(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        clientId: _safeString(client['id']),
        clientName: getClientDisplayName(client),
        region: clientRegion(client),
        title: title.trim(),
        context: context.trim(),
        dueAt: dueAt,
        done: false,
      );
      clientReminders.add(saved);
    }

    clientReminders.refresh();
    await _annotations.saveReminders(clientReminders);
    await _notifications.schedule(saved);
  }

  Future<void> deleteReminder(String reminderId) async {
    clientReminders.removeWhere((reminder) => reminder.id == reminderId);
    await _annotations.saveReminders(clientReminders);
    await _notifications.cancel(reminderId);
  }

  Future<void> toggleReminderDone(ClientReminder reminder) async {
    final index = clientReminders.indexWhere((item) => item.id == reminder.id);
    if (index == -1) return;

    final updated = reminder.copyWith(done: !reminder.done);
    clientReminders[index] = updated;
    clientReminders.refresh();
    await _annotations.saveReminders(clientReminders);

    // Completing a reminder should stop it ringing later.
    await _notifications.schedule(updated);
  }

  /// Best available region for a client record.
  ///
  /// The API carries `region` and `regions` but they are often null, so
  /// anything without one is grouped rather than dropped.
  String clientRegion(Map<String, dynamic> client) {
    final single = _safeString(client['region']);
    if (single.isNotEmpty) return single;

    final many = client['regions'];
    if (many is List && many.isNotEmpty) return _safeString(many.first);

    return 'Sans région';
  }

  /// Every region that currently has at least one reminder.
  List<String> get reminderRegions {
    final regions = clientReminders
        .map(
          (reminder) =>
              reminder.region.isEmpty ? 'Sans région' : reminder.region,
        )
        .toSet()
        .toList();
    regions.sort();
    return regions;
  }

  /// Only the clients that actually have reminders, for the list's filter.
  List<MapEntry<String, String>> get reminderClients {
    final byId = <String, String>{};
    for (final reminder in clientReminders) {
      byId[reminder.clientId] = reminder.clientName;
    }

    final entries = byId.entries.toList();
    entries.sort(
      (a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()),
    );
    return entries;
  }

  void closeMarkerPopup() {
    if (selectedMarkerId.value.isEmpty) return;
    selectedMarkerId.value = '';
    markerPopupClient.value = null;
    popupView.value = 'details';
    editingNote.value = null;
    unawaited(_refreshMarkers());
  }

  /// Scrolls the camera so the tapped marker ends up on the emptier side,
  /// leaving room for the panel.
  Future<void> _positionMarkerForPopup(LatLng target) async {
    final controller = mapController;
    final size = viewportSize;
    if (controller == null || size == null) return;

    try {
      // Both getScreenCoordinate and scrollBy work in device pixels, so the
      // comparison is done there and MediaQuery's logical size is converted.
      final screen = await controller.getScreenCoordinate(target);
      final widthPx = size.width * viewportPixelRatio;
      final heightPx = size.height * viewportPixelRatio;

      // A marker on the left half has more room on its right, so the panel
      // goes right and the marker slides left.
      final panelOnRight = screen.x < widthPx / 2;
      markerPopupOnRight.value = panelOnRight;

      final targetX = panelOnRight ? widthPx * 0.26 : widthPx * 0.74;
      final targetY = heightPx * 0.42;

      await controller.animateCamera(
        CameraUpdate.scrollBy(screen.x - targetX, screen.y - targetY),
      );
    } catch (_) {
      // Positioning is a nicety; the panel still opens without it.
    }
  }

  final RxBool accessB2B = false.obs;
  final RxString selectedImageBase64 = ''.obs;
  final Rx<Uint8List?> selectedImageBytes = Rx<Uint8List?>(null);
  final RxList<CarBrand> selectedBrands = <CarBrand>[].obs;

  final RxMap<String, String> profileData = <String, String>{}.obs;
  final RxList<String> profileRoles = <String>[].obs;
  final RxList<String> profileRegions = <String>[].obs;
  final RxList<Map<String, dynamic>> myClients = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingMyClients = false.obs;
  final RxString selectedParentClientId = ''.obs; // Keep for compatibility
  final RxList<String> selectedParentClientIds =
      <String>[].obs; // Multiple parents
  final RxList<Map<String, dynamic>> mySubClients =
      <Map<String, dynamic>>[].obs;
  final RxString clientsSearchQuery = ''.obs;
  final Rx<Map<String, dynamic>?> selectedClientForUpdate =
      Rx<Map<String, dynamic>?>(null);
  final Map<String, String> _imageBase64Cache = <String, String>{};

  static const double _positionChangeThresholdMeters = 2.0;

  bool get _hasCommercialRole =>
      profileRoles.any((role) => role.toUpperCase().contains('COMMERCIAL'));
  bool get isUpdateMode => selectedClientForUpdate.value != null;

  bool isFieldEditableForCommercialUpdate(String key) {
    if (!isUpdateMode || !_hasCommercialRole) {
      return true;
    }

    final value = _safeString(selectedClientForUpdate.value?[key]).trim();
    return value.isEmpty;
  }

  bool get canEditBrandsForCurrentClient {
    // Allow brand editing for B2B and sub-client forms in both create and update modes
    return (registrationType.value == 'b2b' ||
            registrationType.value == 'sub_client') &&
        _hasCommercialRole;
  }

  bool get selectedClientHasLocation {
    final client = selectedClientForUpdate.value;
    if (client == null) return false;
    final latitude = _toDouble(client['latitude']);
    final longitude = _toDouble(client['longitude']);
    return latitude != null &&
        longitude != null &&
        latitude != 0.0 &&
        longitude != 0.0;
  }

  String get clientLocationActionLabel {
    return selectedClientHasLocation
        ? 'Mettre à jour la position'
        : 'Ajouter la position';
  }

  List<Map<String, dynamic>> get filteredMyClients {
    final query = clientsSearchQuery.value.trim().toLowerCase();
    if (query.isEmpty) {
      return myClients;
    }

    final ranked =
        myClients
            .map((client) {
              final name = getClientDisplayName(client).toLowerCase();
              final code = _safeString(client['codeClient']).toLowerCase();
              final phone = _safeString(client['telephone']).toLowerCase();
              final email = _safeString(client['email']).toLowerCase();

              final fields = [name, code, phone, email];
              final startsWithScore = fields.any((f) => f.startsWith(query));
              final containsScore = fields.any((f) => f.contains(query));

              final rank = startsWithScore ? 0 : (containsScore ? 1 : 99);
              return (client: client, rank: rank, name: name);
            })
            .where((item) => item.rank < 99)
            .toList()
          ..sort((a, b) {
            final byRank = a.rank.compareTo(b.rank);
            if (byRank != 0) return byRank;
            return a.name.compareTo(b.name);
          });

    return ranked.map((item) => item.client).toList();
  }

  String _tr(String key) => UiTranslations.t(key);

  @override
  void onInit() {
    super.onInit();
    _attachDraftListeners();
    _restoreDraft();
    unawaited(_loadRegisteredPins().then((_) => _dropGhostLocalPins()));
    _loadSubmittedRecords();
    _loadConnectedProfile();
    _getCurrentLocation();
    unawaited(loadMyClients());
    unawaited(loadAllSubClientsAndProspectsForCommercial());
    unawaited(loadAnnotations());
    // This screen is where a commercial lands after signing in, and the stock
    // page is one tap from it. Starting stock here means it is already loaded
    // by the time they ask for it, instead of them watching it load.
    CommercialStockController.warmUp();

    // Touching the queue is what registers it, which is what starts it
    // listening for the network coming back.
    ever<SyncResolution?>(_sync.lastResolution, (resolution) {
      if (resolution != null) unawaited(_onRecordSynced(resolution));
    });

    // Giving up on a record that never reached the backend takes its marker
    // with it, rather than leaving a shop on the map that exists nowhere.
    ever<String?>(_sync.lastDiscardedEntityId, (entityId) {
      if (entityId == null) return;
      registeredPins.removeWhere((pin) => pin.id == entityId);
      unawaited(_saveRegisteredPins());
      unawaited(_refreshMarkers());
    });
  }

  Future<void> _loadConnectedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    profileData.assignAll({
      'id': prefs.getString('connected_user_id') ?? '',
      'email': prefs.getString('connected_user_email') ?? '',
      'name': prefs.getString('connected_user_name') ?? '',
      'nom': prefs.getString('connected_user_nom') ?? '',
      'prenom': prefs.getString('connected_user_prenom') ?? '',
      'telephone': prefs.getString('connected_user_telephone') ?? '',
    });

    profileRoles.assignAll(prefs.getStringList('connected_user_roles') ?? []);
    profileRegions.assignAll(
      prefs.getStringList('connected_user_regions') ?? [],
    );
  }

  Future<void> logout() async {
    // Clear all cached data before logout
    _clearAllCache();
    await _authService.logout();
    Get.offAllNamed(AppRoutes.login);
  }

  void _clearAllCache() {
    // Clear observables
    myClients.clear();
    mySubClients.clear();
    selectedClientForUpdate.value = null;
    registeredPins.clear();
    submittedRecords.clear();
    selectedLocation.value = null;
    currentPosition.value = null;
    selectedBrands.clear();
    selectedImageBase64.value = '';
    selectedImageBytes.value = null;

    // Clear form controllers
    codeClientController.clear();
    raisonSocialeController.clear();
    matriculeFiscalController.clear();
    telephoneController.clear();
    emailController.clear();
    parentClientIdController.clear();
    nomController.clear();
    prenomController.clear();
    nomAgenceController.clear();

    // Clear selected parent client
    selectedParentClientId.value = '';

    // The stock controller is kept alive across pages so that returning to
    // the stock screen is instant, which means signing out has to empty it
    // explicitly — otherwise the next representative on this device would be
    // shown the previous one's stock as a freshly loaded list.
    if (Get.isRegistered<CommercialStockController>()) {
      Get.find<CommercialStockController>().clearCache();
    }

    // The cached clients belong to the representative signing out. The sync
    // queue deliberately does not go with them: it holds work they did that
    // has not reached the backend, and emptying it here would silently throw
    // away a client they registered minutes ago.
    myClients.clear();
    mySubClients.clear();
    isShowingCachedClients.value = false;
    unawaited(_db.clearCachedDocuments());

    // Clear SharedPreferences related to commercial map
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_draftStorageKey);
      prefs.remove(_registeredPinsStorageKey);
      prefs.remove(_submittedRecordsStorageKey);
    });
  }

  void goToClientsList() {
    Get.toNamed(AppRoutes.clients);
  }

  void setClientsSearchQuery(String query) {
    clientsSearchQuery.value = query;
  }

  Future<void> changeLanguage(String languageCode) async {
    final languageService = Get.find<LanguageService>();
    await languageService.setLanguage(languageCode);
  }

  void setMapType(MapType mapType) {
    selectedMapType.value = mapType;
  }

  void toggleTraffic() {
    isTrafficEnabled.value = !isTrafficEnabled.value;
  }

  /// Recenters the camera on the device, resetting bearing and tilt the way
  /// the Google Maps locate button does.
  ///
  /// Unlike [fillWithCurrentLocation] this never touches the client form
  /// selection, so it is safe to call at any time.
  Future<void> recenterOnCurrentPosition() async {
    final position = await refreshCurrentPosition();
    if (position == null || mapController == null) return;

    await mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 16,
          bearing: 0,
          tilt: 0,
        ),
      ),
    );
  }

  /// Centers the map on an arbitrary point, used to jump to a client.
  Future<void> focusOnLocation(LatLng target, {double zoom = 17}) async {
    await mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(target, zoom),
    );
  }

  Future<void> loadMyClients() async {
    isLoadingMyClients.value = true;
    try {
      final commercialId = profileData['id']?.trim() ?? '';
      final clients = commercialId.isNotEmpty
          ? await _authService.getClientsByCommercialId(commercialId)
          : await _authService.getMyClients();
      myClients.assignAll(clients);
      isShowingCachedClients.value = false;
      // Kept so the next launch without a signal opens on the same map rather
      // than an empty one. Only after a success: a failed load must never
      // replace good data with nothing.
      unawaited(
        _db.cacheDocuments(DatabaseService.collectionMyClients, clients),
      );

      // Validate selected parent IDs still exist
      selectedParentClientIds.removeWhere(
        (id) => !clients.any((client) => _safeString(client['id']) == id),
      );

      final selectedId = selectedParentClientId.value.trim();
      final hasSelected = clients.any(
        (client) => _safeString(client['id']) == selectedId,
      );
      if (!hasSelected) {
        selectedParentClientId.value = '';
        parentClientIdController.clear();
      }

      _syncApiClientsToPins(clients);
    } catch (e) {
      debugPrint('Failed to load my clients: $e');
      await _fallBackToCachedClients();
    } finally {
      isLoadingMyClients.value = false;
    }
  }

  /// Shows the last clients that did load, when this one did not.
  ///
  /// Only when there is nothing on screen: a list already in memory is at
  /// least as current as the cache, and replacing it would make a failed
  /// refresh look like a change.
  Future<void> _fallBackToCachedClients() async {
    if (myClients.isNotEmpty) return;

    final cached = await _db.readCachedDocuments(
      DatabaseService.collectionMyClients,
    );
    if (cached.isEmpty) return;

    myClients.assignAll(cached);
    isShowingCachedClients.value = true;
    _syncApiClientsToPins(cached);
    debugPrint('Showing ${cached.length} clients from the device cache.');
  }

  Future<Position?> refreshCurrentPosition({
    bool updateSelectionIfEmpty = false,
  }) async {
    try {
      isLoadingLocation.value = true;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Get.snackbar(
            _tr('permissionDenied'),
            _tr('allowLocation'),
            backgroundColor: ColorManager.errorColor,
            colorText: Colors.white,
          );
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        Get.snackbar(
          _tr('permissionDenied'),
          _tr('allowLocation'),
          backgroundColor: ColorManager.errorColor,
          colorText: Colors.white,
        );
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      currentPosition.value = position;

      if (updateSelectionIfEmpty && selectedLocation.value == null) {
        selectedLocation.value = LatLng(position.latitude, position.longitude);
        await _refreshMarkers();
        await _saveDraft();
      }

      return position;
    } catch (e) {
      Get.snackbar(
        _tr('error'),
        '${_tr('unableGetPosition')}: $e',
        backgroundColor: ColorManager.errorColor,
        colorText: Colors.white,
      );
      return null;
    } finally {
      isLoadingLocation.value = false;
    }
  }

  Future<void> loadClientsByCommercialId(String commercialId) async {
    try {
      final clients = await _authService.getClientsByCommercialId(commercialId);
      myClients.assignAll(clients);
      _syncApiClientsToPins(clients);
    } catch (e) {
      debugPrint('Failed to load clients by commercial id: $e');
    }
  }

  Future<Map<String, dynamic>> getClientDetails(String clientId) {
    return _authService.getClientById(clientId);
  }

  Future<List<Map<String, dynamic>>> loadSubClients(
    String parentClientId,
  ) async {
    final subClients = await _authService.getSubClientsByParent(parentClientId);
    mySubClients.assignAll(subClients);
    return subClients;
  }

  Future<void> loadAllSubClientsForSelectedParents() async {
    try {
      if (selectedParentClientIds.isEmpty) {
        mySubClients.clear();
        return;
      }

      final allSubClients = <Map<String, dynamic>>[];
      for (final parentId in selectedParentClientIds) {
        final subClients = await _authService.getSubClientsByParent(parentId);
        allSubClients.addAll(subClients);
      }

      // Remove duplicates by ID
      final uniqueSubClients = <String, Map<String, dynamic>>{};
      for (final subClient in allSubClients) {
        final id = _safeString(subClient['id']);
        if (id.isNotEmpty) {
          uniqueSubClients[id] = subClient;
        }
      }

      mySubClients.assignAll(uniqueSubClients.values.toList());
      // Refresh map markers to show sub-clients
      await _refreshMarkers();
    } catch (e) {
      debugPrint('Failed to load sub-clients: $e');
    }
  }

  // Load all sub-clients and prospects for the current commercial
  Future<void> loadAllSubClientsAndProspectsForCommercial() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final commercialId = prefs.getString('connected_user_id');

      if (commercialId == null || commercialId.isEmpty) {
        debugPrint('No commercial ID found');
        return;
      }

      final allClients = await _authService.getSubClientsByCommercial(
        commercialId,
      );
      mySubClients.assignAll(allClients);
      unawaited(
        _db.cacheDocuments(DatabaseService.collectionSubClients, allClients),
      );
      // Refresh map markers to show all sub-clients and prospects
      await _refreshMarkers();
    } catch (e) {
      debugPrint('Failed to load sub-clients/prospects: $e');

      if (mySubClients.isEmpty) {
        final cached = await _db.readCachedDocuments(
          DatabaseService.collectionSubClients,
        );
        if (cached.isNotEmpty) {
          mySubClients.assignAll(cached);
          isShowingCachedClients.value = true;
          await _refreshMarkers();
          debugPrint(
            'Showing ${cached.length} sub-clients from the device cache.',
          );
        }
      }
    }
  }

  Future<Map<String, dynamic>> getSubClientDetails(String subClientId) {
    return _authService.getSubClientById(subClientId);
  }

  Future<Map<String, dynamic>> updateSubClient({
    required String subClientId,
    required Map<String, dynamic> payload,
  }) {
    return _authService.updateSubClient(
      subClientId: subClientId,
      payload: payload,
    );
  }

  Future<void> deleteSubClient(String subClientId) {
    return _authService.deleteSubClient(subClientId);
  }

  // Select a sub-client/prospect for editing
  void selectSubClientForEdit(Map<String, dynamic> subClient) {
    selectedClientForUpdate.value = Map<String, dynamic>.from(subClient);
    registrationType.value = 'sub_client';
    isProspectFormMode.value = _safeString(subClient['type']) == 'PROSPECT';
    selectedImageBase64.value = '';
    selectedImageBytes.value = null;

    nomController.text = _safeString(subClient['nom']);
    prenomController.text = _safeString(subClient['prenom']);
    nomAgenceController.text = _safeString(subClient['nomAgence']);
    telephoneController.text = _safeString(subClient['telephone']);
    noteController.text = _safeString(subClient['note']);

    // Restore selected brands
    _restoreSelectedBrands(subClient);

    // Restore parent client IDs
    selectedParentClientIds.clear();
    final parentIds = subClient['parentClientIds'];
    if (parentIds is List) {
      selectedParentClientIds.addAll(
        parentIds.map((id) => _safeString(id)).where((id) => id.isNotEmpty),
      );
    }

    final latitude = _toDouble(subClient['latitude']);
    final longitude = _toDouble(subClient['longitude']);

    if (latitude != null && longitude != null) {
      final existingLocation = LatLng(latitude, longitude);
      selectedLocation.value = existingLocation;
      if (mapController != null) {
        mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(existingLocation, 15),
        );
      }
    } else {
      selectedLocation.value = null;
    }

    showClientForm.value = true;
  }

  // Update sub-client/prospect from form and handle type conversion
  Future<void> updateSubClientFromForm() async {
    try {
      final selectedSubClient = selectedClientForUpdate.value;
      if (selectedSubClient == null) {
        throw Exception(_tr('noData'));
      }

      final subClientId = _safeString(selectedSubClient['id']);
      if (subClientId.isEmpty) {
        throw Exception(_tr('noData'));
      }

      isCreatingClient.value = true;

      final payload = <String, dynamic>{
        'nom': nomController.text.trim(),
        'prenom': prenomController.text.trim(),
        'telephone': telephoneController.text.trim(),
        'nomAgence': nomAgenceController.text.trim(),
      };

      // Add location if selected
      final location = selectedLocation.value;
      if (location != null) {
        payload['latitude'] = location.latitude;
        payload['longitude'] = location.longitude;
      }

      // Add parent IDs (always include - empty array converts to PROSPECT)
      payload['parentClientIds'] = selectedParentClientIds.toList();

      // Add note if not empty
      if (noteController.text.trim().isNotEmpty) {
        payload['note'] = noteController.text.trim();
      }

      // Add marques if selected
      if (selectedBrands.isNotEmpty) {
        payload['marques'] = selectedBrands
            .map((brand) => brand.displayName)
            .toList();
      }

      debugPrint('Updating sub-client with payload: ${jsonEncode(payload)}');

      final response = await _queueWrite(
        localId: subClientId,
        payload: payload,
        action: SyncAction.update,
        isSubClient: true,
        );

      // The local copy takes the change either way: the user made it, and it
      // is going to the backend whether that happens now or when the signal
      // comes back. Showing them the old values in the meantime would be a lie
      // about what the app is holding.
      final index = mySubClients.indexWhere(
        (client) => _safeString(client['id']) == subClientId,
      );
      if (index >= 0) {
        mySubClients[index] = {
          ...mySubClients[index],
          ...payload,
          ...?response,
        };
        mySubClients.refresh();
      }

      final selectedImage = selectedImageBytes.value;
      if (selectedImage != null) {
        await _queuePhoto(
          entityType: AuthService.entitySubClient,
          entityId: subClientId,
          imageBytes: selectedImage,
          fileName: 'sub_client_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }

      _reportSaved(message: 'Sous-client/Prospect mis à jour avec succès');

      _clearDraftAndFormAfterSave();
      closeClientForm();
    } catch (e) {
      Get.snackbar(
        _tr('error'),
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: ColorManager.errorColor,
        colorText: Colors.white,
      );
    } finally {
      isCreatingClient.value = false;
    }
  }

  // Delete sub-client/prospect with confirmation
  Future<void> deleteSubClientWithConfirmation(String subClientId) async {
    Get.defaultDialog(
      title: 'Confirmation',
      content: const Text(
        'Êtes-vous sûr de vouloir supprimer ce sous-client/prospect?',
      ),
      textConfirm: 'Supprimer',
      textCancel: 'Annuler',
      confirmTextColor: Colors.white,
      onConfirm: () async {
        Get.back();
        try {
          await deleteSubClient(subClientId);
          mySubClients.removeWhere(
            (client) => _safeString(client['id']) == subClientId,
          );
          mySubClients.refresh();

          Get.snackbar(
            _tr('success'),
            'Sous-client/Prospect supprimé avec succès',
            backgroundColor: ColorManager.successColor,
            colorText: Colors.white,
          );

          await _refreshMarkers();
        } catch (e) {
          Get.snackbar(
            _tr('error'),
            e.toString().replaceAll('Exception: ', ''),
            backgroundColor: ColorManager.errorColor,
            colorText: Colors.white,
          );
        }
      },
    );
  }

  @override
  void onClose() {
    _saveDraft();
    codeClientController.dispose();
    raisonSocialeController.dispose();
    matriculeFiscalController.dispose();
    telephoneController.dispose();
    emailController.dispose();
    parentClientIdController.dispose();
    nomController.dispose();
    prenomController.dispose();
    nomAgenceController.dispose();
    mapController?.dispose();
    super.onClose();
  }

  void _attachDraftListeners() {
    final controllers = [
      codeClientController,
      raisonSocialeController,
      matriculeFiscalController,
      telephoneController,
      emailController,
      parentClientIdController,
      nomController,
      prenomController,
      nomAgenceController,
    ];

    for (final controller in controllers) {
      controller.addListener(_saveDraft);
    }
  }

  // Get current location
  Future<void> _getCurrentLocation() async {
    final position = await refreshCurrentPosition(updateSelectionIfEmpty: true);
    if (position != null && mapController != null) {
      mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          15,
        ),
      );
    }
  }

  /// The full record behind a pin, so the details panel has something to show.
  Map<String, dynamic>? _findClientById(String id) {
    for (final client in myClients) {
      if (_safeString(client['id']) == id) return client;
    }
    for (final subClient in mySubClients) {
      if (_safeString(subClient['id']) == id) return subClient;
    }
    return null;
  }

  // Handle map tap
  void onMapTap(LatLng location) {
    // A tap on the map while a pin is open just dismisses it.
    if (selectedMarkerId.value.isNotEmpty) {
      closeMarkerPopup();
      return;
    }

    // While picking, the centre pin is what counts: a tap just moves the map
    // under it instead of committing a position behind the user's back.
    if (isPickingLocationFromMap.value) {
      mapController?.animateCamera(CameraUpdate.newLatLng(location));
      return;
    }

    if (hasPendingDragPosition.value) return;
    if (showClientForm.value) return;

    // A tap on open map is an intent to register something here. It drops a
    // provisional pin and offers to create a client at that point, instead of
    // the old behaviour of quietly setting a location nothing could use.
    tappedLocation.value = location;
    unawaited(_refreshMarkers());
  }

  /// Point the commercial tapped on an otherwise idle map.
  final Rx<LatLng?> tappedLocation = Rx<LatLng?>(null);

  void dismissTappedLocation() {
    if (tappedLocation.value == null) return;
    tappedLocation.value = null;
    unawaited(_refreshMarkers());
  }

  /// Opens the chosen form with the tapped point already filled in, so the
  /// commercial only has to complete the details.
  void createClientAtTappedLocation(ClientKind kind) {
    final location = tappedLocation.value;
    if (location == null) return;

    // Clears the form, so the location is applied afterwards.
    openClientFormForKind(kind);
    selectedLocation.value = location;
    tappedLocation.value = null;

    unawaited(_refreshMarkers());
    _saveDraft();
  }

  // ---------------------------------------------------------------------------
  // Picking a client's position
  //
  // Entering picking mode hands the whole map over to the user: a fixed pin
  // sits at the centre of the screen, they move the map under it, and nothing
  // is written to the client until they confirm.
  // ---------------------------------------------------------------------------

  /// Where the centre pin currently sits. Kept in step with the camera.
  final Rx<LatLng?> pickTarget = Rx<LatLng?>(null);

  /// The position the client had when picking started, so cancelling restores
  /// it exactly.
  LatLng? _locationBeforePicking;

  Future<void> startLocationPicking() async {
    _locationBeforePicking = selectedLocation.value;

    hasPendingDragPosition.value = false;
    showClientForm.value = false;
    isPickingLocationFromMap.value = true;

    // Start on the client's known position; otherwise on the commercial, who
    // is often standing in front of the shop they are registering.
    var target = selectedLocation.value;
    if (target == null) {
      final position = currentPosition.value ?? await refreshCurrentPosition();
      if (position != null) {
        target = LatLng(position.latitude, position.longitude);
      }
    }

    // No client position and no GPS fix: fall back to whatever the map is
    // already showing, so the pin always stands for a real point and the
    // confirm button is never dead.
    if (target == null && mapController != null) {
      final bounds = await mapController!.getVisibleRegion();
      target = LatLng(
        (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
        (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
      );
    }

    pickTarget.value = target;
    await _refreshMarkers();

    if (target != null) {
      await mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(target, 17),
      );
    }
  }

  /// Called as the camera moves so the readout matches what will be saved.
  void updatePickTarget(LatLng target) {
    if (!isPickingLocationFromMap.value) return;
    pickTarget.value = target;
  }

  void confirmPickedLocation() {
    final target = pickTarget.value;
    if (target == null) return;

    selectedLocation.value = target;
    isPickingLocationFromMap.value = false;
    hasPendingDragPosition.value = false;
    showClientForm.value = true;
    _locationBeforePicking = null;

    unawaited(_refreshMarkers());
    _saveDraft();
  }

  void cancelLocationPicking() {
    selectedLocation.value = _locationBeforePicking;
    isPickingLocationFromMap.value = false;
    hasPendingDragPosition.value = false;
    showClientForm.value = true;
    _locationBeforePicking = null;

    unawaited(_refreshMarkers());
  }

  Future<void> pickLocationFromMap() => startLocationPicking();

  // Open client form
  void openClientForm() {
    showClientForm.value = true;
    unawaited(loadMyClients());
  }

  /// Opens a blank form for one of the three kinds of record.
  ///
  /// The kind is chosen up front, on the speed dial, rather than buried in a
  /// selector inside the form: it decides the colour, the fields and what the
  /// map pin will look like.
  void openClientFormForKind(ClientKind kind) {
    _clearForm();
    selectedClientForUpdate.value = null;
    selectedLocation.value = null;
    selectedImageBase64.value = '';
    selectedImageBytes.value = null;
    selectedBrands.clear();
    selectedParentClientIds.clear();

    registrationType.value = kind == ClientKind.b2b ? 'b2b' : 'sub_client';
    isProspectFormMode.value = kind == ClientKind.prospect;

    showClientForm.value = true;
    unawaited(loadMyClients());
  }

  /// What the form is currently editing, for colouring and labelling.
  ClientKind get activeClientKind {
    if (registrationType.value != 'sub_client') return ClientKind.b2b;
    return isProspectFormMode.value
        ? ClientKind.prospect
        : ClientKind.subClient;
  }

  /// Colour of the record being edited, following the parent group for a
  /// sub-client once a parent has been chosen.
  Color get activeClientColor => ClientPalette.forKind(
    activeClientKind,
    parentId: selectedParentClientIds.isNotEmpty
        ? selectedParentClientIds.first
        : null,
  );

  // Close client form
  void closeClientForm() {
    showClientForm.value = false;
    _clearForm();
    selectedClientForUpdate.value = null;
    selectedLocation.value = null;
    registrationType.value = 'b2b';
    isProspectFormMode.value = false;
    selectedImageBase64.value = '';
    selectedImageBytes.value = null;
    selectedBrands.clear();
    selectedParentClientId.value = '';
    selectedParentClientIds.clear();
    // Don't save draft on close - form should be empty next time
  }

  // Clear form
  void _clearForm() {
    codeClientController.clear();
    raisonSocialeController.clear();
    matriculeFiscalController.clear();
    telephoneController.clear();
    emailController.clear();
    parentClientIdController.clear();
    nomController.clear();
    prenomController.clear();
    nomAgenceController.clear();
    noteController.clear();
    selectedParentClientId.value = '';
    accessB2B.value = false;
    registrationType.value = 'b2b';
    isProspectFormMode.value = false;
    selectedImageBase64.value = '';
    selectedImageBytes.value = null;
    selectedBrands.clear();
    selectedClientForUpdate.value = null;
    isPickingLocationFromMap.value = false;
    hasPendingDragPosition.value = false;
  }

  // Fill form with current location
  Future<void> fillWithCurrentLocation() async {
    final previousLocation = selectedLocation.value;
    final position = await refreshCurrentPosition();
    if (position == null) {
      return;
    }

    final nextLocation = LatLng(position.latitude, position.longitude);
    selectedLocation.value = nextLocation;
    await _refreshMarkers();
    await _saveDraft();

    if (mapController != null) {
      await mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(nextLocation, 15),
      );
    }

    final hasChanged = previousLocation == null
        ? true
        : Geolocator.distanceBetween(
                previousLocation.latitude,
                previousLocation.longitude,
                nextLocation.latitude,
                nextLocation.longitude,
              ) >
              _positionChangeThresholdMeters;

    if (hasChanged) {
      Get.snackbar(
        _tr('locationUsed'),
        _tr('currentPositionUsed'),
        backgroundColor: ColorManager.successColor,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    }
  }

  void setRegistrationType(String value) {
    registrationType.value = value;
    if (value != 'sub_client') {
      isProspectFormMode.value = false;
    }

    if (value == 'sub_client') {
      codeClientController.clear();
      raisonSocialeController.clear();
      matriculeFiscalController.clear();
      emailController.clear();
      selectedBrands.clear();
      accessB2B.value = false;
    }

    if (value == 'sub_client' && myClients.isEmpty) {
      unawaited(loadMyClients());
    }
    _saveDraft();
  }

  void selectParentClient(String? parentClientId) {
    final selected = parentClientId?.trim() ?? '';
    selectedParentClientId.value = selected;
    parentClientIdController.text = selected;
    _saveDraft();
  }

  void toggleParentClientSelection(String parentClientId) {
    final id = parentClientId.toString().trim();
    if (id.isEmpty) return;
    debugPrint('Toggling parent client selection for id: $id');
    debugPrint('Before: ${selectedParentClientIds.toList()}');
    if (selectedParentClientIds.contains(id)) {
      selectedParentClientIds.remove(id);
    } else {
      selectedParentClientIds.add(id);
    }
    selectedParentClientIds.refresh();
    debugPrint('After: ${selectedParentClientIds.toList()}');
    _saveDraft();
  }

  void addParentClient(String parentClientId) {
    final id = parentClientId.trim();
    if (id.isNotEmpty && !selectedParentClientIds.contains(id)) {
      selectedParentClientIds.add(id);
      // Load sub-clients for all selected parents
      unawaited(loadAllSubClientsForSelectedParents());
      _saveDraft();
    }
  }

  void removeParentClient(String parentClientId) {
    final id = parentClientId.trim();
    selectedParentClientIds.remove(id);
    // Reload sub-clients for remaining parents
    unawaited(loadAllSubClientsForSelectedParents());
    _saveDraft();
  }

  bool isParentClientSelected(String parentClientId) {
    final id = parentClientId.toString().trim();
    final result = selectedParentClientIds.contains(id);
    debugPrint(
      'isParentClientSelected($id) => $result | Current: ${selectedParentClientIds.toList()}',
    );
    return result;
  }

  List<Map<String, dynamic>> getSelectedParentClients() {
    return myClients
        .where(
          (client) =>
              selectedParentClientIds.contains(_safeString(client['id'])),
        )
        .toList();
  }

  void setAccessB2B(bool enabled) {
    accessB2B.value = enabled;
    _saveDraft();
  }

  void toggleBrand(CarBrand brand) {
    if (selectedBrands.contains(brand)) {
      selectedBrands.remove(brand);
    } else {
      selectedBrands.add(brand);
    }
    _saveDraft();
  }

  Future<void> pickImageFromCamera() async {
    await _pickImage(ImageSource.camera);
  }

  Future<void> pickImageFromGallery() async {
    await _pickImage(ImageSource.gallery);
  }

  void removeSelectedImage() {
    selectedImageBase64.value = '';
    selectedImageBytes.value = null;
    unawaited(_refreshMarkers());
    _saveDraft();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      isPickingImage.value = true;
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1280,
      );

      if (picked == null) {
        return;
      }

      final bytes = await picked.readAsBytes();
      selectedImageBytes.value = bytes;
      selectedImageBase64.value = base64Encode(bytes);
      unawaited(_refreshMarkers());
      _saveDraft();
    } catch (e) {
      Get.snackbar(
        _tr('imageError'),
        '${_tr('unableSelectImage')}: $e',
        backgroundColor: ColorManager.errorColor,
        colorText: Colors.white,
      );
    } finally {
      isPickingImage.value = false;
    }
  }

  // Create client
  Future<void> createClient() async {
    try {
      isCreatingClient.value = true;

      final location = selectedLocation.value;
      if (location == null) {
        throw Exception(_tr('selectBoutiqueBeforeCreate'));
      }

      final prefs = await SharedPreferences.getInstance();
      final connectedCommercialId = prefs.getString('connected_user_id');

      if (registrationType.value == 'sub_client') {
        // Parent client IDs are now optional - empty list will create a PROSPECT type

        // Checked here rather than left to the backend.
        //
        // Writes no longer wait for the network, so the form closes and says
        // "saved" before anything has been sent — which means a payload the
        // backend was always going to refuse would be discovered minutes
        // later, in the queue, with the form long gone and the commercial
        // somewhere else. The three fields `/sub-clients` insists on are
        // checked while the form is still open and can still be fixed.
        final missing = <String>[
          if (nomController.text.trim().isEmpty) 'le nom',
          if (prenomController.text.trim().isEmpty) 'le prénom',
          if (telephoneController.text.trim().isEmpty) 'le téléphone',
        ];
        if (missing.isNotEmpty) {
          throw Exception(
            'Le serveur exige ${missing.join(', ')} pour un sous-client ou '
            'un prospect.',
          );
        }

        final payload = _buildSubClientPayload(location);
        if (connectedCommercialId != null && connectedCommercialId.isNotEmpty) {
          payload['commercialId'] = connectedCommercialId;
        }

        debugPrint('SUB-CLIENT payload sent: ${jsonEncode(payload)}');

        // The id the record answers to until the backend gives it one. With a
        // connection it is replaced a second later by the real one; without,
        // it is what the marker, the photo and any edit all hang off until the
        // queue drains.
        final localId = SyncService.newLocalId();

        final response = await _queueWrite(
          localId: localId,
          payload: payload,
          action: SyncAction.create,
          isSubClient: true,
          );

        final queued = response == null;
        final entityId = queued
            ? localId
            : (_safeString(response['id']).isNotEmpty
                  ? _safeString(response['id'])
                  : _safeString(response['userId']));

        final snapshotImageBytes = selectedImageBytes.value;
        if (snapshotImageBytes != null && entityId.isNotEmpty) {
          await _queuePhoto(
            entityType: AuthService.entitySubClient,
            entityId: entityId,
            imageBytes: snapshotImageBytes,
            fileName: 'sub_client_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
        }

        await _saveSubmittedRecord(
          type: 'sub_client',
          sentPayload: payload,
          responsePayload: response ?? {'id': localId, 'pendingSync': true},
        );

        final markerLabel = _safeString(response?['nomAgence']).isNotEmpty
            ? _safeString(response?['nomAgence'])
            : _safeString(response?['codeClient']).isNotEmpty
            ? _safeString(response?['codeClient'])
            : '${nomController.text.trim()} ${prenomController.text.trim()}'
                  .trim();

        await _addRegisteredPin(
          id: entityId.isNotEmpty ? entityId : localId,
          label: markerLabel.isEmpty ? _tr('subClientLabel') : markerLabel,
          location: location,
          imageBase64: selectedImageBase64.value,
          type: 'sub_client',
        );

      } else {
        // Build B2B client payload
        var sentPayload = <String, dynamic>{
          'latitude': location.latitude.toString(),
          'longitude': location.longitude.toString(),
        };

        if (codeClientController.text.trim().isNotEmpty) {
          sentPayload['codeClient'] = codeClientController.text.trim();
        }

        if (raisonSocialeController.text.trim().isNotEmpty) {
          sentPayload['raisonSociale'] = raisonSocialeController.text.trim();
        }

        if (matriculeFiscalController.text.trim().isNotEmpty) {
          sentPayload['matriculeFiscal'] = matriculeFiscalController.text
              .trim();
        }

        if (telephoneController.text.trim().isNotEmpty) {
          sentPayload['telephone'] = telephoneController.text.trim();
        }

        if (emailController.text.trim().isNotEmpty) {
          sentPayload['email'] = emailController.text.trim();
        }

        debugPrint('B2B payload sent: ${jsonEncode(sentPayload)}');

        final localId = SyncService.newLocalId();

        final response = await _queueWrite(
          localId: localId,
          payload: sentPayload,
          action: SyncAction.create,
          isSubClient: false,
          );

        final queued = response == null;
        final entityId = queued
            ? localId
            : (_safeString(response['id']).isNotEmpty
                  ? _safeString(response['id'])
                  : (_safeString(response['userId']).isNotEmpty
                        ? _safeString(response['userId'])
                        : _safeString(response['codeClient'])));

        // Marques are a second call against the new client. Queued behind the
        // create when there is nothing to send it over; the queue's ordering
        // is what guarantees it arrives after the client exists.
        if (selectedBrands.isNotEmpty && entityId.isNotEmpty) {
          final marques = {
            'marques': selectedBrands.map((brand) => brand.displayName).toList(),
          };

          try {
            await _queueWrite(
              localId: entityId,
              payload: marques,
              action: SyncAction.update,
              isSubClient: false,
              );
          } catch (e) {
            // Never worth failing the creation over: the client is registered,
            // and the marques can be set again from the fiche.
            debugPrint('Failed to save marques: $e');
          }
        }

        final snapshotImageBytes = selectedImageBytes.value;
        if (snapshotImageBytes != null && entityId.isNotEmpty) {
          await _queuePhoto(
            entityType: AuthService.entityClient,
            entityId: entityId,
            imageBytes: snapshotImageBytes,
            fileName: 'client_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
        }

        await _saveSubmittedRecord(
          type: 'b2b',
          sentPayload: sentPayload,
          responsePayload: response ?? {'id': localId, 'pendingSync': true},
        );

        await _addRegisteredPin(
          id: entityId.isNotEmpty ? entityId : localId,
          label: _safeString(response?['raisonSociale']).isNotEmpty
              ? _safeString(response?['raisonSociale'])
              : (raisonSocialeController.text.trim().isEmpty
                    ? _tr('b2bClientLabel')
                    : raisonSocialeController.text.trim()),
          location: location,
          imageBase64: selectedImageBase64.value,
          type: 'b2b',
        );

      }

      _reportSaved(message: _tr('clientCreated'));

      _clearDraftAndFormAfterSave();
      closeClientForm();
    } catch (e) {
      Get.snackbar(
        _tr('error'),
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: ColorManager.errorColor,
        colorText: Colors.white,
      );
    } finally {
      isCreatingClient.value = false;
    }
  }

  Future<void> submitClientForm() async {
    if (selectedClientForUpdate.value != null) {
      // If it's a sub-client/prospect in update mode
      if (registrationType.value == 'sub_client') {
        await updateSubClientFromForm();
      } else {
        // B2B client update
        await updateSelectedClient();
      }
      return;
    }
    await createClient();
  }

  /// Whether a record is a sub-client or prospect rather than a direct client.
  ///
  /// Checked against the loaded sub-clients first, because the `type` field is
  /// not always present on records that came from a marker.
  bool isSubClientRecord(Map<String, dynamic> client) {
    final id = _safeString(client['id']);
    if (id.isNotEmpty) {
      for (final subClient in mySubClients) {
        if (_safeString(subClient['id']) == id) return true;
      }
    }

    final type = _safeString(client['type']).toUpperCase();
    return type == 'PROSPECT' || type == 'SOUS_CLIENT';
  }

  /// Names of the clients a sub-client hangs off, for display on its fiche.
  List<String> parentNamesFor(Map<String, dynamic> client) {
    final ids = client['parentClientIds'];
    if (ids is! List) return [];

    final names = <String>[];
    for (final raw in ids) {
      final id = _safeString(raw);
      if (id.isEmpty) continue;

      var name = id;
      for (final candidate in myClients) {
        if (_safeString(candidate['id']) == id) {
          name = getClientDisplayName(candidate);
          break;
        }
      }
      names.add(name);
    }
    return names;
  }

  /// Opens the form that matches the record: a sub-client keeps its own form
  /// rather than being edited as if it were a B2B client.
  void selectRecordForEdit(Map<String, dynamic> client) {
    if (isSubClientRecord(client)) {
      selectSubClientForEdit(client);
    } else {
      unawaited(selectClientForLocationUpdate(client));
    }
  }

  /// Starts a *new* B2B client prefilled from a sub-client or prospect.
  ///
  /// Nothing is deleted and nothing is updated: the source record stays as it
  /// is until the commercial saves the new client, and whatever is not known
  /// is simply left blank for them to fill in.
  void convertToB2BClient(Map<String, dynamic> source) {
    _clearForm();
    selectedClientForUpdate.value = null;
    selectedParentClientIds.clear();
    selectedBrands.clear();

    registrationType.value = 'b2b';
    isProspectFormMode.value = false;

    raisonSocialeController.text = getClientDisplayName(source);
    telephoneController.text = _safeString(source['telephone']);
    emailController.text = _safeString(source['email']);
    noteController.text = _safeString(source['note']);
    _restoreSelectedBrands(source);

    final latitude = _toDouble(source['latitude']);
    final longitude = _toDouble(source['longitude']);
    selectedLocation.value = (latitude != null && longitude != null)
        ? LatLng(latitude, longitude)
        : null;

    closeMarkerPopup();
    showClientForm.value = true;
    unawaited(_refreshMarkers());
  }

  /// A record that reached the backend without the fields that identify a
  /// real B2B client. Flagged rather than rejected, so a commercial can
  /// register what they saw and complete it later.
  bool isIncompleteRecord(Map<String, dynamic> client) {
    if (isSubClientRecord(client)) return false;

    for (final field in ['codeClient', 'raisonSociale', 'matriculeFiscal']) {
      if (_safeString(client[field]).isEmpty) return true;
    }
    return false;
  }

  Future<void> selectClientForLocationUpdate(
    Map<String, dynamic> client,
  ) async {
    selectedClientForUpdate.value = Map<String, dynamic>.from(client);
    registrationType.value = 'b2b';
    selectedImageBase64.value = '';
    selectedImageBytes.value = null;

    codeClientController.text = _safeString(client['codeClient']);
    raisonSocialeController.text = _safeString(client['raisonSociale']);
    matriculeFiscalController.text = _safeString(client['matriculeFiscal']);
    telephoneController.text = _safeString(client['telephone']);
    emailController.text = _safeString(client['email']);
    nomController.text = _safeString(client['nom']);
    prenomController.text = _safeString(client['prenom']);
    nomAgenceController.text = _safeString(client['nomAgence']);
    noteController.text = _safeString(client['note']);
    _restoreSelectedBrands(client);

    final latitude = _toDouble(client['latitude']);
    final longitude = _toDouble(client['longitude']);

    if (latitude != null && longitude != null) {
      final existingLocation = LatLng(latitude, longitude);
      selectedLocation.value = existingLocation;
      if (mapController != null) {
        await mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(existingLocation, 15),
        );
      }
    } else {
      // No snackbar: the form's position section states this plainly and
      // offers the button that fixes it.
      selectedLocation.value = null;
    }

    showClientForm.value = true;
    await _refreshMarkers();
  }

  Future<void> updateSelectedClient() async {
    print(
      'Updating client with data: ${jsonEncode(selectedClientForUpdate.value)}',
    );
    try {
      final selectedClient = selectedClientForUpdate.value;
      if (selectedClient == null) {
        throw Exception(_tr('noData'));
      }

      final clientId = _safeString(selectedClient['id']);
      if (clientId.isEmpty) {
        throw Exception(_tr('noData'));
      }

      isCreatingClient.value = true;

      final payload = <String, dynamic>{};

      void putIfNotEmpty(String key, String value) {
        final normalized = value.trim();
        if (normalized.isNotEmpty && isFieldEditableForCommercialUpdate(key)) {
          payload[key] = normalized;
        }
      }

      putIfNotEmpty('codeClient', codeClientController.text);
      putIfNotEmpty('raisonSociale', raisonSocialeController.text);
      putIfNotEmpty('nom', nomController.text);
      putIfNotEmpty('matriculeFiscal', matriculeFiscalController.text);
      putIfNotEmpty('telephone', telephoneController.text);
      putIfNotEmpty('email', emailController.text);

      // Add note if not empty (always editable)
      if (noteController.text.trim().isNotEmpty) {
        payload['note'] = noteController.text.trim();
      }

      final location = selectedLocation.value;
      if (location != null) {
        payload['latitude'] = location.latitude.toString();
        payload['longitude'] = location.longitude.toString();
      }

      if (canEditBrandsForCurrentClient && selectedBrands.isNotEmpty) {
        payload['marques'] = selectedBrands
            .map((brand) => brand.displayName)
            .toList();
      }

      if (payload.isEmpty) {
        throw Exception(_tr('noData'));
      }

      final response = await _queueWrite(
        localId: clientId,
        payload: payload,
        action: SyncAction.update,
        isSubClient: false,
        );

      final queued = response == null;

      final index = myClients.indexWhere(
        (client) => _safeString(client['id']) == clientId,
      );
      if (index >= 0) {
        myClients[index] = {...myClients[index], ...payload, ...?response};
        myClients.refresh();
      }

      final selectedImage = selectedImageBytes.value;
      if (selectedImage != null) {
        await _queuePhoto(
          entityType: AuthService.entityClient,
          entityId: clientId,
          imageBytes: selectedImage,
          fileName: 'client_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }

      // Only worth asking the backend for the list when the backend has the
      // change. Queued, it would answer with the values the user just edited
      // away and undo them on screen.
      if (!queued) {
        await loadMyClients();
      }

      _reportSaved(message: _tr('clientCreated'));

      _clearDraftAndFormAfterSave();
    } catch (e) {
      print('Error updating client: $e');
      Get.snackbar(
        _tr('error'),
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: ColorManager.errorColor,
        colorText: Colors.white,
      );
    } finally {
      isCreatingClient.value = false;
    }
  }

  Map<String, dynamic> _buildSubClientPayload(LatLng location) {
    final payload = <String, dynamic>{
      'latitude': location.latitude,
      'longitude': location.longitude,
    };

    // Empty fields are left out of the payload, not sent as "".
    //
    // The backend validates what it is given rather than what is missing, so
    // an empty string is a *bad* value where an absent field is simply an
    // unknown one: sending `nom: ""` is refused with "un ou plusieurs champs
    // sont invalides", which is exactly how a prospect registered from the
    // street — a shop front, a position and nothing else yet — used to fail.
    void putIfNotEmpty(String key, String value) {
      final normalized = value.trim();
      if (normalized.isNotEmpty) {
        payload[key] = normalized;
      }
    }

    putIfNotEmpty('nom', nomController.text);
    putIfNotEmpty('prenom', prenomController.text);
    putIfNotEmpty('telephone', telephoneController.text);
    putIfNotEmpty('nomAgence', nomAgenceController.text);

    // Add parent client IDs (multiple parents supported)
    // If empty, backend will create type PROSPECT; if filled, creates type SOUS_CLIENT
    final parentIds = selectedParentClientIds.isNotEmpty
        ? selectedParentClientIds.toList()
        : (selectedParentClientId.value.trim().isNotEmpty
              ? [selectedParentClientId.value.trim()]
              : []);

    // Always include parentClientIds (empty array results in PROSPECT type)
    payload['parentClientIds'] = parentIds;

    // Add brands/marques
    if (selectedBrands.isNotEmpty) {
      payload['marques'] = selectedBrands.map((brand) => brand.name).toList();
    }

    // Add note if not empty
    if (noteController.text.trim().isNotEmpty) {
      payload['note'] = noteController.text.trim();
    }

    return payload;
  }

  String getClientDisplayName(Map<String, dynamic> client) {
    final raisonSociale = _safeString(client['raisonSociale']);
    if (raisonSociale.isNotEmpty) {
      return raisonSociale;
    }

    final nomAgence = _safeString(client['nomAgence']);
    if (nomAgence.isNotEmpty) {
      return nomAgence;
    }

    final nom = _safeString(client['nom']);
    final prenom = _safeString(client['prenom']);
    final fullName = '$nom $prenom'.trim();
    if (fullName.isNotEmpty) {
      return fullName;
    }

    final codeClient = _safeString(client['codeClient']);
    if (codeClient.isNotEmpty) {
      return codeClient;
    }

    return _tr('noData');
  }

  String getClientSubtitle(Map<String, dynamic> client) {
    final phone = _safeString(client['telephone']);
    if (phone.isNotEmpty) {
      return phone;
    }

    final codeClient = _safeString(client['codeClient']);
    if (codeClient.isNotEmpty) {
      return codeClient;
    }

    return _safeString(client['id']);
  }

  String getClientImageUrl(Map<String, dynamic> client) {
    final clientId = _safeString(client['id']);
    if (clientId.isEmpty) {
      return '';
    }

    final imagePath = _safeString(client['imagePath']).isNotEmpty
        ? _safeString(client['imagePath'])
        : (_safeString(client['boutiqueImagePath']).isNotEmpty
              ? _safeString(client['boutiqueImagePath'])
              : (_safeString(client['imageUrl']).isNotEmpty
                    ? _safeString(client['imageUrl'])
                    : _safeString(client['boutiqueImageUrl'])));

    if (imagePath.isEmpty) {
      return '';
    }

    return _authService.buildClientImageUrl(
      clientId: clientId,
      imagePathOrUrl: imagePath,
    );
  }

  /// Records a write and hands it to the queue. Never waits for the network.
  ///
  /// Saving is a local operation: the record is written down, the form closes,
  /// and the backend hears about it a moment later from the queue — or in ten
  /// minutes, if that is when the signal comes back. The commercial's
  /// experience is the same either way, which is the point: the only thing
  /// they should ever wait for is the phone.
  ///
  /// Going through the backend first would mean waiting on it, and the worst
  /// case is not a dead network — it is a weak one, where the request sits
  /// until the timeout gives up thirty seconds later with the form still open.
  /// The queue is written first, so there is nothing to wait for and nothing
  /// to lose.
  ///
  /// Always returns null, so callers carry on with [localId] as the record's
  /// id; [_onRecordSynced] swaps in the real one behind them when it arrives.
  Future<Map<String, dynamic>?> _queueWrite({
    required String localId,
    required Map<String, dynamic> payload,
    required SyncAction action,
    required bool isSubClient,
  }) async {
    await _sync.queueClientWrite(
      clientId: localId,
      payload: payload,
      action: action,
      isSubClient: isSubClient,
    );
    return null;
  }

  /// Queues a photo behind the record it belongs to.
  Future<void> _queuePhoto({
    required String entityType,
    required String entityId,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    await _sync.queuePhotoUpload(
      entityId: entityId,
      ownerType: entityType,
      imageBytes: imageBytes,
      fileName: fileName,
    );
  }

  /// Confirms the save, in the same words whatever the network is doing.
  ///
  /// The record is saved — that is true the moment it is written down, and
  /// which second it reaches the backend is not something a commercial should
  /// have to think about. The badge on the map is there for anyone who wants
  /// to know; nothing else mentions it.
  void _reportSaved({required String message}) {
    Get.snackbar(
      _tr('success'),
      message,
      backgroundColor: ColorManager.successColor,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  /// Takes off the map any record that can never become real.
  ///
  /// A pin under a `local_…` id is a record the backend has not seen yet, and
  /// the queue is what is going to tell it. If there is no longer anything
  /// queued for that id — the user gave up on it, or it was dropped with the
  /// create it belonged to — then nothing will ever create it, and leaving the
  /// marker there shows a shop that exists on no system at all.
  Future<void> _dropGhostLocalPins() async {
    final locals = registeredPins
        .where((pin) => SyncService.isLocalId(pin.id))
        .toList();
    if (locals.isEmpty) return;

    final queued = await _db.getAllSyncItems();
    final stillComing = queued.map((item) => item.entityId).toSet();

    final ghosts = locals
        .where((pin) => !stillComing.contains(pin.id))
        .map((pin) => pin.id)
        .toSet();
    if (ghosts.isEmpty) return;

    registeredPins.removeWhere((pin) => ghosts.contains(pin.id));
    await _saveRegisteredPins();
    await _refreshMarkers();
    debugPrint('Removed ${ghosts.length} local pin(s) with nothing queued.');
  }

  /// A queued create has landed and the backend has named the record.
  ///
  /// The marker and the stored pin are still filed under the local id, so they
  /// are moved across — otherwise the next load would bring the same shop back
  /// from the backend and the map would show it twice.
  Future<void> _onRecordSynced(SyncResolution resolution) async {
    final index = registeredPins.indexWhere(
      (pin) => pin.id == resolution.localId,
    );

    if (index >= 0) {
      final pin = registeredPins[index];
      registeredPins[index] = _RegisteredClientPin(
        id: resolution.serverId,
        label: pin.label,
        latitude: pin.latitude,
        longitude: pin.longitude,
        imageBase64: pin.imageBase64,
        imageUrl: pin.imageUrl,
        type: pin.type,
      );
      await _saveRegisteredPins();
    }

    if (selectedMarkerId.value == resolution.localId) {
      selectedMarkerId.value = resolution.serverId;
    }

    await _refreshMarkers();

    // The record now exists on the backend, so the lists it belongs to are out
    // of date by exactly one entry.
    unawaited(loadMyClients());
    unawaited(loadAllSubClientsAndProspectsForCommercial());
  }

  // Photos used to be uploaded straight from here, in the background but
  // outside anything that remembered them: an upload that failed was simply
  // gone, and nobody was told. They go through the queue now, like every
  // other write, which is what makes them survive a dropped connection.

  void _syncApiClientsToPins(List<Map<String, dynamic>> clients) {
    for (final client in clients) {
      final id = _safeString(client['id']);
      if (id.isEmpty) continue;

      final latitude = _toDouble(client['latitude']);
      final longitude = _toDouble(client['longitude']);
      if (latitude == null || longitude == null) continue;

      final existingIndex = registeredPins.indexWhere((pin) => pin.id == id);
      final label = _safeString(client['raisonSociale']).isNotEmpty
          ? _safeString(client['raisonSociale'])
          : (_safeString(client['codeClient']).isNotEmpty
                ? _safeString(client['codeClient'])
                : _tr('b2bClientLabel'));

      final pin = _RegisteredClientPin(
        id: id,
        label: label,
        latitude: latitude,
        longitude: longitude,
        imageBase64: existingIndex >= 0
            ? registeredPins[existingIndex].imageBase64
            : '',
        imageUrl: getClientImageUrl(client),
        type: 'b2b',
      );

      if (existingIndex >= 0) {
        registeredPins[existingIndex] = pin;
      } else {
        registeredPins.add(pin);
      }
    }

    unawaited(_saveRegisteredPins());
    unawaited(_refreshMarkers());
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  Future<void> _addRegisteredPin({
    required String id,
    required String label,
    required LatLng location,
    required String imageBase64,
    String imageUrl = '',
    required String type,
  }) async {
    registeredPins.add(
      _RegisteredClientPin(
        id: id,
        label: label,
        latitude: location.latitude,
        longitude: location.longitude,
        imageBase64: imageBase64,
        imageUrl: imageUrl,
        type: type,
      ),
    );

    await _saveRegisteredPins();
    await _refreshMarkers();
  }

  Future<void> _refreshMarkers() async {
    final nextMarkers = <Marker>{};

    // Add registered pins
    for (final pin in registeredPins) {
      final resolvedImageBase64 = await _resolveImageBase64(pin);
      final icon = await _buildClientMarkerIcon(
        imageBase64: resolvedImageBase64,
        markerType: pin.type,
        selected: selectedMarkerId.value == pin.id,
      );
      final position = LatLng(pin.latitude, pin.longitude);

      nextMarkers.add(
        Marker(
          markerId: MarkerId('registered_${pin.id}'),
          position: position,
          icon: icon,
          // No InfoWindow: the details open in our own side panel instead.
          onTap: () => selectMarker(
            id: pin.id,
            position: position,
            client: _findClientById(pin.id),
          ),
        ),
      );
    }

    // Add sub-clients markers
    for (final subClient in mySubClients) {
      final lat = _toDouble(subClient['latitude']);
      final lng = _toDouble(subClient['longitude']);
      if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
        final subClientType = _safeString(subClient['type']).isEmpty
            ? 'SOUS_CLIENT'
            : _safeString(subClient['type']);

        // Sub-clients are coloured by the parent they belong to, so one
        // parent's network reads as one group on the map.
        final parentIds = subClient['parentClientIds'];
        final parentId = parentIds is List && parentIds.isNotEmpty
            ? _safeString(parentIds.first)
            : '';

        final subClientId = _safeString(subClient['id']);
        final subClientIcon = await _buildClientMarkerIcon(
          imageBase64: '',
          markerType: subClientType,
          parentId: parentId,
          selected: selectedMarkerId.value == subClientId,
        );
        final position = LatLng(lat, lng);

        nextMarkers.add(
          Marker(
            markerId: MarkerId('subclient_$subClientId'),
            position: position,
            icon: subClientIcon,
            onTap: () => selectMarker(
              id: subClientId,
              position: position,
              client: subClient,
            ),
          ),
        );
      }
    }

    // Provisional pin for a point the commercial just tapped. Neutral grey,
    // because no kind has been chosen yet.
    if (tappedLocation.value != null && !isPickingLocationFromMap.value) {
      nextMarkers.add(
        Marker(
          markerId: const MarkerId('tapped_location'),
          position: tappedLocation.value!,
          icon: await _buildClientMarkerIcon(
            imageBase64: '',
            markerType: 'pending',
          ),
          onTap: () {},
        ),
      );
    }

    // Add selected location for editing. Hidden while picking, where the
    // floating centre pin stands in for it.
    if (selectedLocation.value != null && !isPickingLocationFromMap.value) {
      // The pin being placed already wears the colour the record will have.
      final selectedPickerIcon = await _buildClientMarkerIcon(
        imageBase64: selectedImageBase64.value,
        markerType: isProspectFormMode.value
            ? 'PROSPECT'
            : registrationType.value,
        parentId: selectedParentClientIds.isNotEmpty
            ? selectedParentClientIds.first
            : null,
      );
      nextMarkers.add(
        Marker(
          markerId: const MarkerId('selected_location'),
          position: selectedLocation.value!,
          icon: selectedPickerIcon,
          // Not draggable on purpose: picking mode is the single, explicit
          // way to move a client's position.
          infoWindow: InfoWindow(
            title: _tr('newLocation'),
            snippet: _tr('activeSelection'),
          ),
        ),
      );
    }

    markers.assignAll(nextMarkers);
  }

  Future<String> _resolveImageBase64(_RegisteredClientPin pin) async {
    if (pin.imageBase64.isNotEmpty) {
      return pin.imageBase64;
    }

    final imageUrl = pin.imageUrl.trim();
    if (imageUrl.isEmpty) {
      return '';
    }

    final cached = _imageBase64Cache[imageUrl];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    final bytes = await _authService.getProtectedImageBytes(imageUrl);
    if (bytes == null || bytes.isEmpty) {
      return '';
    }

    final encoded = base64Encode(bytes);
    _imageBase64Cache[imageUrl] = encoded;
    return encoded;
  }

  /// Rendered marker bitmaps, keyed by what actually changes their pixels.
  ///
  /// Every `_refreshMarkers()` used to redraw each pin from scratch — load the
  /// asset, decode it, paint a canvas, re-encode a PNG — for every marker, and
  /// that method runs on almost every state change. Caching turns a map with
  /// N pins from N renders per refresh into N renders in total.
  final Map<String, BitmapDescriptor> _markerIconCache = {};

  /// Draws a pin with depth: a blurred ground shadow, a teardrop body shaded
  /// from light to dark, a glossy highlight, and a white disc carrying either
  /// the client's photo or the glyph for its kind.
  /// Displayed pin size in logical pixels. The artwork is always drawn at
  /// [_markerCanvasWidth] x [_markerCanvasHeight] and scaled down on display,
  /// so the gradient and glyph stay crisp at any size.
  static const double _markerDisplayWidth = 54;
  static const double _markerDisplayHeight = 68;

  /// How much a tapped pin grows, so the selection is obvious.
  static const double _markerSelectedScale = 1.5;

  static const double _markerCanvasWidth = 150;
  static const double _markerCanvasHeight = 190;

  Future<BitmapDescriptor> _buildClientMarkerIcon({
    String? imageBase64,
    required String markerType,
    String? parentId,
    bool selected = false,
  }) async {
    final color = ClientPalette.forType(markerType, parentId: parentId);
    final photo = imageBase64 ?? '';
    final cacheKey = '${color.toARGB32()}|${photo.hashCode}|$selected';

    final cached = _markerIconCache[cacheKey];
    if (cached != null) return cached;

    try {
      const width = _markerCanvasWidth;
      const height = _markerCanvasHeight;
      const cx = width / 2;
      const headRadius = 56.0;
      const headCenterY = headRadius + 10;
      const tipY = height - 14;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Ground shadow, so the pin reads as standing on the map.
      canvas.drawOval(
        Rect.fromCenter(
          center: const Offset(cx, tipY - 2),
          width: headRadius * 1.15,
          height: headRadius * 0.4,
        ),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );

      // Teardrop: tip at the bottom, round head on top.
      final body = Path()
        ..moveTo(cx, tipY)
        ..quadraticBezierTo(
          cx - headRadius * 0.92,
          headCenterY + headRadius * 0.78,
          cx - headRadius,
          headCenterY,
        )
        ..arcToPoint(
          const Offset(cx + headRadius, headCenterY),
          radius: const Radius.circular(headRadius),
        )
        ..quadraticBezierTo(
          cx + headRadius * 0.92,
          headCenterY + headRadius * 0.78,
          cx,
          tipY,
        )
        ..close();

      final hsl = HSLColor.fromColor(color);
      final light = hsl
          .withLightness((hsl.lightness + 0.14).clamp(0.0, 1.0))
          .toColor();
      final dark = hsl
          .withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0))
          .toColor();

      canvas.drawPath(
        body,
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(cx, headCenterY - headRadius),
            const Offset(cx, tipY),
            [light, dark],
          ),
      );

      // Rim, so the pin keeps its shape against a busy basemap.
      canvas.drawPath(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: 0.85),
      );

      // Glossy highlight on the upper left.
      canvas.save();
      canvas.clipPath(body);
      canvas.drawOval(
        Rect.fromCenter(
          center: const Offset(
            cx - headRadius * 0.3,
            headCenterY - headRadius * 0.42,
          ),
          width: headRadius * 0.95,
          height: headRadius * 0.55,
        ),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.26)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.restore();

      // White disc holding the photo or the kind's glyph.
      const discRadius = headRadius * 0.66;
      const discCenter = Offset(cx, headCenterY);
      canvas.drawCircle(discCenter, discRadius, Paint()..color = Colors.white);

      if (photo.isNotEmpty) {
        final avatarImage = await _decodeImage(
          base64Decode(photo),
          targetWidth: (discRadius * 2).round(),
        );
        final avatarRect = Rect.fromCircle(
          center: discCenter,
          radius: discRadius - 2,
        );
        canvas.save();
        canvas.clipPath(Path()..addOval(avatarRect));
        paintImage(
          canvas: canvas,
          rect: avatarRect,
          image: avatarImage,
          fit: BoxFit.cover,
        );
        canvas.restore();
      } else {
        _paintMarkerGlyph(canvas, markerType, color, discCenter, discRadius);
      }

      final picture = recorder.endRecording();
      final markerImage = await picture.toImage(width.toInt(), height.toInt());
      final pngBytes = await markerImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      markerImage.dispose();
      picture.dispose();

      if (pngBytes == null) {
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      }

      final scale = selected ? _markerSelectedScale : 1.0;
      final descriptor = BitmapDescriptor.bytes(
        pngBytes.buffer.asUint8List(),
        width: _markerDisplayWidth * scale,
        height: _markerDisplayHeight * scale,
      );
      _markerIconCache[cacheKey] = descriptor;
      return descriptor;
    } catch (_) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }
  }

  /// Material glyph for the kind, painted through the icon font.
  void _paintMarkerGlyph(
    Canvas canvas,
    String markerType,
    Color color,
    Offset center,
    double radius,
  ) {
    final icon = switch (markerType.toLowerCase()) {
      // Nothing has been chosen yet, so the pin shows an invitation.
      'pending' => Icons.add,
      'prospect' => ClientPalette.icon(ClientKind.prospect),
      'sous_client' || 'sub_client' => ClientPalette.icon(ClientKind.subClient),
      _ => ClientPalette.icon(ClientKind.b2b),
    };

    final painter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: radius * 1.15,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      )
      ..layout();

    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  Future<ui.Image> _decodeImage(Uint8List bytes, {int? targetWidth}) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: targetWidth,
    );
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draft = <String, dynamic>{
      'registrationType': registrationType.value,
      'accessB2B': accessB2B.value,
      'codeClient': codeClientController.text,
      'raisonSociale': raisonSocialeController.text,
      'matriculeFiscal': matriculeFiscalController.text,
      'telephone': telephoneController.text,
      'email': emailController.text,
      'parentClientId': parentClientIdController.text,
      'parentClientIds': selectedParentClientIds.toList(), // Multiple parents
      'nom': nomController.text,
      'prenom': prenomController.text,
      'nomAgence': nomAgenceController.text,
      'imageBase64': selectedImageBase64.value,
      'showClientForm': showClientForm.value,
      'latitude': selectedLocation.value?.latitude,
      'longitude': selectedLocation.value?.longitude,
      'selectedBrands': selectedBrands.map((b) => b.index).toList(),
    };

    await prefs.setString(_draftStorageKey, jsonEncode(draft));
  }

  Future<void> _restoreDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftStorageKey);
    if (raw == null || raw.isEmpty) {
      return;
    }

    try {
      final draft = jsonDecode(raw) as Map<String, dynamic>;
      registrationType.value = _safeString(draft['registrationType']).isEmpty
          ? 'b2b'
          : _safeString(draft['registrationType']);
      accessB2B.value = draft['accessB2B'] == true;

      codeClientController.text = _safeString(draft['codeClient']);
      raisonSocialeController.text = _safeString(draft['raisonSociale']);
      matriculeFiscalController.text = _safeString(draft['matriculeFiscal']);
      telephoneController.text = _safeString(draft['telephone']);
      emailController.text = _safeString(draft['email']);
      parentClientIdController.text = _safeString(draft['parentClientId']);
      nomController.text = _safeString(draft['nom']);
      prenomController.text = _safeString(draft['prenom']);
      nomAgenceController.text = _safeString(draft['nomAgence']);

      selectedImageBase64.value = _safeString(draft['imageBase64']);
      if (selectedImageBase64.value.isNotEmpty) {
        selectedImageBytes.value = base64Decode(selectedImageBase64.value);
      }

      final lat = draft['latitude'];
      final lng = draft['longitude'];
      if (lat is num && lng is num) {
        selectedLocation.value = LatLng(lat.toDouble(), lng.toDouble());
      }

      // Restore selected brands
      if (draft['selectedBrands'] is List) {
        final brandIndices = List<int>.from(draft['selectedBrands']);
        selectedBrands.assignAll(
          brandIndices
              .where((i) => i >= 0 && i < CarBrand.values.length)
              .map((i) => CarBrand.values[i]),
        );
      }

      showClientForm.value = draft['showClientForm'] == true;

      // Restore multiple parent client IDs
      if (draft['parentClientIds'] is List) {
        selectedParentClientIds.assignAll(
          List<String>.from(draft['parentClientIds']),
        );
      } else {
        final restoredParentClientId = _safeString(draft['parentClientId']);
        if (restoredParentClientId.isNotEmpty) {
          selectedParentClientIds.add(restoredParentClientId);
        }
      }

      selectedParentClientId.value = selectedParentClientIds.firstOrNull ?? '';
      parentClientIdController.text = selectedParentClientId.value;
      _refreshMarkers();
    } catch (_) {
      // Ignore malformed draft
    }
  }

  Future<void> _loadRegisteredPins() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_registeredPinsStorageKey);
    if (raw == null || raw.isEmpty) {
      return;
    }

    try {
      final parsed = jsonDecode(raw) as List<dynamic>;
      registeredPins.assignAll(
        parsed
            .whereType<Map>()
            .map(
              (item) => _RegisteredClientPin.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(),
      );
      _refreshMarkers();
    } catch (_) {
      // Ignore malformed local markers
    }
  }

  Future<void> _saveRegisteredPins() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(registeredPins.map((e) => e.toJson()).toList());
    await prefs.setString(_registeredPinsStorageKey, encoded);
  }

  Future<void> _loadSubmittedRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_submittedRecordsStorageKey);
    if (raw == null || raw.isEmpty) {
      return;
    }

    try {
      final parsed = jsonDecode(raw) as List<dynamic>;
      submittedRecords.assignAll(
        parsed
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(),
      );
    } catch (_) {
      // Ignore malformed records
    }
  }

  Future<void> _saveSubmittedRecord({
    required String type,
    required Map<String, dynamic> sentPayload,
    required Map<String, dynamic> responsePayload,
  }) async {
    final record = <String, dynamic>{
      'type': type,
      'createdAt': DateTime.now().toIso8601String(),
      'sentPayload': sentPayload,
      'responsePayload': responsePayload,
    };

    submittedRecords.insert(0, record);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _submittedRecordsStorageKey,
      jsonEncode(submittedRecords),
    );
  }

  Future<void> _clearDraftAndFormAfterSave() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftStorageKey);

    _clearForm();
    selectedLocation.value = null;
    showClientForm.value = false;
    await _refreshMarkers();
  }

  String _safeString(dynamic value) => value?.toString() ?? '';

  void _restoreSelectedBrands(Map<String, dynamic> client) {
    selectedBrands.clear();

    final marques = client['marques'];
    if (marques is List) {
      selectedBrands.assignAll(_mapBrandValues(marques));
      return;
    }

    final availableBrands = client['availableBrands'];
    if (availableBrands is Map) {
      try {
        final brandsModel = CarBrandsModel.fromJson(
          Map<String, dynamic>.from(availableBrands),
        );
        selectedBrands.assignAll(brandsModel.selectedBrands);
      } catch (_) {
        // Ignore malformed brand payload.
      }
    }
  }

  List<CarBrand> _mapBrandValues(List<dynamic> values) {
    final normalizedValues = values
        .map((value) => _normalizeBrandName(value.toString()))
        .where((value) => value.isNotEmpty)
        .toSet();

    return CarBrand.values.where((brand) {
      final display = _normalizeBrandName(brand.displayName);
      final enumName = _normalizeBrandName(brand.name);
      return normalizedValues.contains(display) ||
          normalizedValues.contains(enumName);
    }).toList();
  }

  String _normalizeBrandName(String value) {
    return value
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  // Recenter on current location
  void recenterMap() {
    if (currentPosition.value != null && mapController != null) {
      mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(
            currentPosition.value!.latitude,
            currentPosition.value!.longitude,
          ),
          15,
        ),
      );
    }
  }
}

class _RegisteredClientPin {
  final String id;
  final String label;
  final double latitude;
  final double longitude;
  final String imageBase64;
  final String imageUrl;
  final String type;

  _RegisteredClientPin({
    required this.id,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.imageBase64,
    required this.imageUrl,
    required this.type,
  });

  factory _RegisteredClientPin.fromJson(Map<String, dynamic> json) {
    return _RegisteredClientPin(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      imageBase64: (json['imageBase64'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? '').toString(),
      type: (json['type'] ?? 'b2b').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'latitude': latitude,
      'longitude': longitude,
      'imageBase64': imageBase64,
      'imageUrl': imageUrl,
      'type': type,
    };
  }
}

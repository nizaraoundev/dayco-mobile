import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/single_flight.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../cartography/presentation/marker_icon_cache.dart';
import '../../../clients/domain/entities/client.dart';
import '../../../clients/domain/entities/geo_position.dart';
import '../../../clients/domain/repositories/clients_repository.dart';
import '../../../../localization/ui_translations.dart';
import '../../../../routes/app_routes.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/catalog/car_brand.dart';

class CommercialMapController extends GetxController {
  static const String _draftStorageKey = 'commercial_client_draft';
  static const String _registeredPinsStorageKey = 'commercial_registered_pins';
  static const String _submittedRecordsStorageKey =
      'commercial_submitted_records';

  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();

  /// The shared portfolio source of truth. Resolved from the service locator
  /// so this controller reads the same cache the initialization screen filled.
  final ClientsRepository _clients = locator<ClientsRepository>();
  final AuthRepository _auth = locator<AuthRepository>();

  /// Shared marker-icon cache — the same instance the initialization screen
  /// pre-warmed, so the first marker paint is a cache hit.
  final MarkerIconCache _icons = locator<MarkerIconCache>();

  /// Serialises marker rebuilds so a stale run cannot overwrite a newer one.
  final LatestWins _markerRefresh = LatestWins();

  /// Coalesces draft writes while the representative is typing.
  Timer? _draftSaveTimer;
  static const Duration _draftSaveDebounce = Duration(milliseconds: 600);

  /// User feedback, in one place.
  ///
  /// The colours and durations were repeated at every `Get.snackbar` call site,
  /// which is why success was sometimes green-for-2s and sometimes green with
  /// no duration at all.
  void _showSuccess(String message) {
    Get.snackbar(
      _tr('success'),
      message,
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  void _showError(String message) {
    Get.snackbar(
      _tr('error'),
      message,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }

  // Map controller
  GoogleMapController? mapController;
  final Rx<MapType> selectedMapType = Rx<MapType>(MapType.normal);

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
    _loadRegisteredPins();
    _loadSubmittedRecords();
    unawaited(_bootstrap());
  }

  /// Startup work, ordered by its real dependencies.
  ///
  /// The profile is awaited before the portfolio because the portfolio
  /// endpoints are keyed by the representative's id; the previous version
  /// fired them off together, so the id was still empty when the fetch ran.
  ///
  /// By the time this runs the post-login initialization screen has normally
  /// already loaded the portfolio, so [_loadPortfolio] is answered from cache
  /// and the map paints immediately.
  Future<void> _bootstrap() async {
    await _loadConnectedProfile();

    // Independent of each other: the portfolio is network-bound, the position
    // is sensor-bound.
    await Future.wait([
      _loadPortfolio(),
      _getCurrentLocation(),
    ]);
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

  /// The active UI language code.
  ///
  /// Reads the observable directly so a widget inside an `Obx` rebuilds when
  /// the language changes. The drawer's language selector needs this to show
  /// which option is active — previously nothing in the UI did, so both
  /// language buttons looked identical whichever one was in effect.
  String get currentLanguageCode =>
      Get.find<LanguageService>().currentLanguage.value;

  void setMapType(MapType mapType) {
    selectedMapType.value = mapType;
  }

  /// The signed-in representative's id.
  ///
  /// Read from [AuthRepository] first. The previous code read
  /// `profileData['id']`, which `onInit` populated asynchronously *without
  /// awaiting it* — so this was reliably empty on the first call and the B2B
  /// fetch silently fell back to `/my-clients` instead of the
  /// commercial-scoped endpoint.
  String get _commercialId {
    final fromSession = _auth.currentUser?.id.trim() ?? '';
    if (fromSession.isNotEmpty) return fromSession;
    return profileData['id']?.trim() ?? '';
  }

  /// Loads the portfolio and splits it into the two lists the UI binds to.
  ///
  /// Both [loadMyClients] and [loadAllSubClientsAndProspectsForCommercial]
  /// funnel through here, and here goes through [ClientsRepository] — which
  /// collapses concurrent calls and serves a fresh cache without touching the
  /// network. That is what stops `onInit` (which calls both) and the
  /// post-login initialization screen from each fetching the same data.
  Future<void> _loadPortfolio({bool forceRefresh = false}) async {
    isLoadingMyClients.value = true;
    try {
      final result = await _clients.loadPortfolio(
        commercialId: _commercialId,
        forceRefresh: forceRefresh,
      );

      if (result case FailureResult<List<Client>>(:final failure)) {
        AppLogger.warn('Portfolio unavailable', error: failure);
        return;
      }

      final clients = result.valueOrNull ?? const <Client>[];

      // `toUiMap` keeps the original backend payload and overlays the
      // normalised fields, so the existing map-based screens see everything
      // they did before plus correctly parsed coordinates and type.
      final b2b = clients
          .where((client) => client.kind.isB2b)
          .map((client) => client.toUiMap())
          .toList();
      final subs = clients
          .where((client) => client.kind.usesSubClientApi)
          .map((client) => client.toUiMap())
          .toList();

      myClients.assignAll(b2b);
      mySubClients.assignAll(subs);

      // Drop any selected parent that no longer exists in the portfolio.
      selectedParentClientIds.removeWhere(
        (id) => !b2b.any((client) => _safeString(client['id']) == id),
      );

      final selectedId = selectedParentClientId.value.trim();
      final hasSelected = b2b.any(
        (client) => _safeString(client['id']) == selectedId,
      );
      if (!hasSelected) {
        selectedParentClientId.value = '';
        parentClientIdController.clear();
      }

      _syncApiClientsToPins(b2b);
      await _refreshMarkers();
    } finally {
      isLoadingMyClients.value = false;
    }
  }

  Future<void> loadMyClients() => _loadPortfolio();

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
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        Get.snackbar(
          _tr('permissionDenied'),
          _tr('allowLocation'),
          backgroundColor: Colors.red,
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
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return null;
    } finally {
      isLoadingLocation.value = false;
    }
  }

  Future<void> loadAllSubClientsForSelectedParents() async {
    try {
      if (selectedParentClientIds.isEmpty) {
        mySubClients.clear();
        return;
      }

      // One request per parent, issued concurrently rather than in sequence —
      // the previous loop awaited each in turn, so selecting four parents cost
      // four round-trips end to end.
      final responses = await Future.wait(
        selectedParentClientIds.map(_clients.fetchSubClientsOfParent),
      );

      final uniqueSubClients = <String, Client>{};
      for (final response in responses) {
        if (response case FailureResult<List<Client>>(:final failure)) {
          AppLogger.warn('Sub-clients of a parent unavailable', error: failure);
          continue;
        }
        for (final subClient in response.valueOrNull ?? const <Client>[]) {
          if (subClient.id.isNotEmpty) uniqueSubClients[subClient.id] = subClient;
        }
      }

      mySubClients.assignAll(
        uniqueSubClients.values.map((client) => client.toUiMap()).toList(),
      );
      await _refreshMarkers();
    } finally {
      // Nothing to unwind; the guard above returns early on an empty selection.
    }
  }

  // Load all sub-clients and prospects for the current commercial
  /// Sub-clients and prospects come from the same portfolio load as the B2B
  /// clients, so this shares [_loadPortfolio] rather than issuing its own
  /// request. Calling it alongside [loadMyClients] now costs one fetch, not two.
  Future<void> loadAllSubClientsAndProspectsForCommercial() => _loadPortfolio();

  /// Deletes a sub-client or prospect.
  ///
  /// Through [ClientsRepository], so the cached portfolio drops it immediately
  /// and every screen reading that cache stays in agreement.
  Future<Result<void>> deleteSubClient(String subClientId) =>
      _clients.deleteSubClient(subClientId);

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
  /// Applies the open form to the selected sub-client or prospect.
  ///
  /// Through [ClientsRepository], which also handles the type conversion the
  /// backend derives from parentage: clearing every parent turns a sub-client
  /// into a `PROSPECT`, and adding one converts it back.
  Future<void> updateSubClientFromForm() async {
    final selected = selectedClientForUpdate.value;
    final subClientId = _safeString(selected?['id']);

    if (selected == null || subClientId.isEmpty) {
      _showError(_tr('noData'));
      return;
    }

    isCreatingClient.value = true;
    try {
      final location = selectedLocation.value;
      final parents = selectedParentClientIds.toList();

      final draft = ClientDraft(
        kind: parents.isEmpty ? ClientKind.prospect : ClientKind.subClient,
        id: subClientId,
        nom: nomController.text,
        prenom: prenomController.text,
        nomAgence: nomAgenceController.text,
        telephone: telephoneController.text,
        note: noteController.text,
        position: location == null
            ? null
            : GeoPosition(
                latitude: location.latitude,
                longitude: location.longitude,
              ),
        parentClientIds: parents,
        brands: CarBrandCodec.encodeAll(selectedBrands),
        imageBytes: selectedImageBytes.value,
      );

      final result = await _clients.updateClient(draft);

      if (result case FailureResult<Client>(:final failure)) {
        if (failure is! CancelledFailure) _showError(failure.message);
        return;
      }

      await _refreshMarkers();

      _showSuccess('Sous-client/Prospect mis à jour avec succès');
      _clearDraftAndFormAfterSave();
      closeClientForm();
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

        final result = await deleteSubClient(subClientId);

        if (result case FailureResult<void>(:final failure)) {
          _showError(failure.message);
          return;
        }

        // The repository removed it from the shared cache; this keeps the
        // controller's own list in step until the map reads the cache directly.
        mySubClients.removeWhere(
          (client) => _safeString(client['id']) == subClientId,
        );
        mySubClients.refresh();

        _showSuccess('Sous-client/Prospect supprimé avec succès');
        await _refreshMarkers();
      },
    );
  }

  @override
  void onClose() {
    // Flush before tearing anything down, so the last keystrokes are not lost
    // to the debounce.
    unawaited(_flushDraftSave());

    // Listeners are removed before disposal. The previous version never removed
    // them, so each controller held a reference to this controller's
    // `_saveDraft` for as long as it lived.
    for (final controller in _draftControllers) {
      controller.removeListener(_scheduleDraftSave);
      controller.dispose();
    }

    mapController?.dispose();
    mapController = null;
    super.onClose();
  }

  /// Every text field whose content belongs to the saved draft.
  List<TextEditingController> get _draftControllers => [
    codeClientController,
    raisonSocialeController,
    matriculeFiscalController,
    telephoneController,
    emailController,
    parentClientIdController,
    nomController,
    prenomController,
    nomAgenceController,
    // Was missing from both the listener list and `onClose`, so notes were
    // never captured in the draft and this controller was never disposed.
    noteController,
  ];

  void _attachDraftListeners() {
    for (final controller in _draftControllers) {
      controller.addListener(_scheduleDraftSave);
    }
  }

  /// Queues a draft save shortly after typing stops.
  ///
  /// `_saveDraft` was previously registered directly as the listener, so every
  /// keystroke ran `SharedPreferences.getInstance()`, built a map, JSON-encoded
  /// it and wrote it to disk. Typing a twenty-character company name meant
  /// twenty full serialisations and twenty disk writes — the form-typing lag.
  /// Coalescing them means one write per pause instead.
  void _scheduleDraftSave() {
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(_draftSaveDebounce, () {
      unawaited(_saveDraft());
    });
  }

  /// Writes any pending draft immediately, cancelling the queued save.
  ///
  /// Used when leaving the screen, where waiting for the debounce would lose
  /// the last few characters typed.
  Future<void> _flushDraftSave() async {
    _draftSaveTimer?.cancel();
    _draftSaveTimer = null;
    await _saveDraft();
  }

  // Get current location
  /// Receives the platform map once it exists.
  ///
  /// Startup is a race: the GPS fix can arrive before or after the map is
  /// created. Previously `_getCurrentLocation` simply skipped the camera move
  /// when `mapController` was still null, so a fast fix left the map sitting on
  /// its default position. Centring is now driven from whichever of the two
  /// completes last.
  void attachMapController(GoogleMapController controller) {
    mapController = controller;

    final position = currentPosition.value;
    if (position != null) _moveCameraTo(position);
  }

  Future<void> _getCurrentLocation() async {
    final position = await refreshCurrentPosition(updateSelectionIfEmpty: true);
    if (position != null) _moveCameraTo(position);
  }

  /// Moves the camera imperatively.
  ///
  /// This is why the `GoogleMap` widget no longer needs to depend on the
  /// position: the camera is a command, not a rebuild.
  void _moveCameraTo(Position position) {
    mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(position.latitude, position.longitude),
        15,
      ),
    );
  }

  // Handle map tap
  void onMapTap(LatLng location) {
    if (hasPendingDragPosition.value) return;
    selectedLocation.value = location;
    if (isPickingLocationFromMap.value) {
      isPickingLocationFromMap.value = false;
      showClientForm.value = true;
      Get.snackbar(
        _tr('locationUsed'),
        _tr('currentPositionUsed'),
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    }
    unawaited(_refreshMarkers());
    _saveDraft();
  }

  void confirmDragPosition() {
    hasPendingDragPosition.value = false;
    showClientForm.value = true;
    unawaited(_refreshMarkers());
    _saveDraft();
  }

  Future<void> pickLocationFromMap() async {
    hasPendingDragPosition.value = false;
    isPickingLocationFromMap.value = true;
    showClientForm.value = false;
    Get.snackbar(
      _tr('locationUsed'),
      _tr('touchMapBoutique'),
      backgroundColor: Colors.orange,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  // Open client form
  void openClientForm() {
    showClientForm.value = true;
    unawaited(loadMyClients());
  }

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
        backgroundColor: Colors.green,
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
    debugPrint('isParentClientSelected($id) => $result | Current: ${selectedParentClientIds.toList()}');
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
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isPickingImage.value = false;
    }
  }

  // Create client
  /// Creates the client described by the open form.
  ///
  /// Goes through [ClientsRepository], which brings three things the previous
  /// direct `AuthService` call did not have: a typed failure instead of a
  /// stringly-typed exception, de-duplication of a double tap so the
  /// representative cannot create the same client twice, and an automatic
  /// cache update so the new client appears on the map and in the clients list
  /// without a reload.
  Future<void> createClient() async {
    final location = selectedLocation.value;
    if (location == null) {
      _showError(_tr('selectBoutiqueBeforeCreate'));
      return;
    }

    isCreatingClient.value = true;
    try {
      final draft = _buildDraft(location);
      final result = await _clients.createClient(draft);

      if (result case FailureResult<Client>(:final failure)) {
        // A dropped duplicate submission is the guard working, not an error
        // worth interrupting the user for.
        if (failure is! CancelledFailure) _showError(failure.message);
        return;
      }

      final created = (result as Success<Client>).value;
      final isSubClient = draft.kind.usesSubClientApi;
      final recordType = isSubClient ? 'sub_client' : 'b2b';

      await _saveSubmittedRecord(
        type: recordType,
        sentPayload: draft.position == null
            ? const <String, dynamic>{}
            : _draftAuditPayload(draft),
        responsePayload: created.raw,
      );

      await _addRegisteredPin(
        id: created.id.isNotEmpty
            ? created.id
            : DateTime.now().millisecondsSinceEpoch.toString(),
        label: _pinLabelFor(created, isSubClient: isSubClient),
        location: location,
        imageBase64: selectedImageBase64.value,
        type: recordType,
      );

      _showSuccess(_tr('clientCreated'));
      _clearDraftAndFormAfterSave();
      closeClientForm();
    } finally {
      isCreatingClient.value = false;
    }
  }

  /// Builds a [ClientDraft] from the open form.
  ///
  /// The kind is derived from parentage exactly as the backend does: a
  /// sub-client form with no parent selected creates a `PROSPECT`.
  ClientDraft _buildDraft(LatLng location, {String id = ''}) {
    final isSubClientForm = registrationType.value == 'sub_client';
    final parents = selectedParentClientIds.toList();

    return ClientDraft(
      kind: isSubClientForm
          ? (parents.isEmpty ? ClientKind.prospect : ClientKind.subClient)
          : ClientKind.b2b,
      id: id,
      codeClient: codeClientController.text,
      raisonSociale: raisonSocialeController.text,
      matriculeFiscal: matriculeFiscalController.text,
      nom: nomController.text,
      prenom: prenomController.text,
      nomAgence: nomAgenceController.text,
      telephone: telephoneController.text,
      email: emailController.text,
      note: noteController.text,
      position: GeoPosition(
        latitude: location.latitude,
        longitude: location.longitude,
      ),
      parentClientIds: parents,
      // Always the backend display name. Creation used to send `brand.name`
      // while updates sent `brand.displayName`, so editing a client rewrote its
      // brands into a different vocabulary (audit H-10).
      brands: CarBrandCodec.encodeAll(selectedBrands),
      imageBytes: selectedImageBytes.value,
    );
  }

  /// A record of what was submitted, kept for the local audit trail.
  Map<String, dynamic> _draftAuditPayload(ClientDraft draft) => {
    'kind': draft.kind.name,
    if (draft.codeClient.isNotEmpty) 'codeClient': draft.codeClient,
    if (draft.raisonSociale.isNotEmpty) 'raisonSociale': draft.raisonSociale,
    if (draft.matriculeFiscal.isNotEmpty)
      'matriculeFiscal': draft.matriculeFiscal,
    if (draft.nom.isNotEmpty) 'nom': draft.nom,
    if (draft.prenom.isNotEmpty) 'prenom': draft.prenom,
    if (draft.nomAgence.isNotEmpty) 'nomAgence': draft.nomAgence,
    if (draft.telephone.isNotEmpty) 'telephone': draft.telephone,
    if (draft.email.isNotEmpty) 'email': draft.email,
    if (draft.note.isNotEmpty) 'note': draft.note,
    'parentClientIds': draft.parentClientIds,
    if (draft.brands.isNotEmpty) 'marques': draft.brands,
    if (draft.position != null) 'latitude': draft.position!.latitude,
    if (draft.position != null) 'longitude': draft.position!.longitude,
  };

  /// Label for the map pin, falling back through what the backend returned and
  /// then what was typed, so a pin is never left unlabelled.
  String _pinLabelFor(Client created, {required bool isSubClient}) {
    final fromServer = created.displayName;
    if (fromServer.isNotEmpty) return fromServer;

    if (isSubClient) {
      final typed = '${nomController.text.trim()} ${prenomController.text.trim()}'
          .trim();
      final agency = nomAgenceController.text.trim();
      if (agency.isNotEmpty) return agency;
      if (typed.isNotEmpty) return typed;
      return _tr('subClientLabel');
    }

    final raisonSociale = raisonSocialeController.text.trim();
    return raisonSociale.isEmpty ? _tr('b2bClientLabel') : raisonSociale;
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
      selectedLocation.value = null;
      Get.snackbar(
        _tr('locationUsed'),
        _tr('touchMapBoutique'),
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    }

    showClientForm.value = true;
    await _refreshMarkers();
  }

  /// Applies the open form to the selected B2B client.
  ///
  /// Routed through [ClientsRepository], so the update is de-duplicated, the
  /// cached portfolio is refreshed in place (no full reload), and a failure
  /// arrives as a typed [Failure] rather than a string-matched exception.
  Future<void> updateSelectedClient() async {
    final selectedClient = selectedClientForUpdate.value;
    final clientId = _safeString(selectedClient?['id']);

    if (selectedClient == null || clientId.isEmpty) {
      _showError(_tr('noData'));
      return;
    }

    isCreatingClient.value = true;
    try {
      final draft = _buildB2bUpdateDraft(clientId);
      final result = await _clients.updateClient(draft);

      if (result case FailureResult<Client>(:final failure)) {
        if (failure is! CancelledFailure) _showError(failure.message);
        return;
      }

      // The repository already refreshed its cache and notified listeners, so
      // the previous `await loadMyClients()` round-trip is no longer needed.
      await _refreshMarkers();

      _showSuccess(_tr('clientCreated'));
      _clearDraftAndFormAfterSave();
    } finally {
      isCreatingClient.value = false;
    }
  }

  /// Builds the update draft for a B2B client, honouring the commercial
  /// field-edit rule.
  ///
  /// A representative may fill a field that is still blank on the client but
  /// may not overwrite one that already holds a value. A field they are not
  /// allowed to change is left empty here, and the mapper omits empty fields,
  /// so it is never sent.
  ClientDraft _buildB2bUpdateDraft(String clientId) {
    String editable(String key, String value) =>
        isFieldEditableForCommercialUpdate(key) ? value.trim() : '';

    final location = selectedLocation.value;

    return ClientDraft(
      kind: ClientKind.b2b,
      id: clientId,
      codeClient: editable('codeClient', codeClientController.text),
      raisonSociale: editable('raisonSociale', raisonSocialeController.text),
      matriculeFiscal: editable('matriculeFiscal', matriculeFiscalController.text),
      nom: editable('nom', nomController.text),
      telephone: editable('telephone', telephoneController.text),
      email: editable('email', emailController.text),
      // The note is always the representative's to change.
      note: noteController.text.trim(),
      position: location == null
          ? null
          : GeoPosition(
              latitude: location.latitude,
              longitude: location.longitude,
            ),
      brands: canEditBrandsForCurrentClient
          ? CarBrandCodec.encodeAll(selectedBrands)
          : const [],
      imageBytes: selectedImageBytes.value,
    );
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

  /// Rebuilds the marker set.
  ///
  /// Sequenced through [LatestWins]: this is `async` and is invoked from ~15
  /// places, including the draggable pin's `onDragEnd`. Previously concurrent
  /// runs interleaved and a slower, older run could finish last and overwrite
  /// the newer marker set with stale content — the map showing state the app
  /// had already moved past. Now only the newest run is allowed to commit.
  Future<void> _refreshMarkers() => _markerRefresh.run<Set<Marker>>(
    _buildMarkers,
    commit: markers.assignAll,
  );

  Future<Set<Marker>> _buildMarkers() async {
    final nextMarkers = <Marker>{};
    final pixelRatio = _devicePixelRatio;

    // Add registered pins
    for (final pin in registeredPins) {
      final resolvedImageBase64 = await _resolveImageBase64(pin);
      // Served from cache after the first build of each distinct icon. The
      // previous implementation reloaded the pin asset, decoded it, rasterised
      // a canvas and PNG-encoded the result *per marker, per refresh*.
      final icon = await _icons.iconFor(
        kind: _kindOfMarkerType(pin.type),
        avatarBytes: _bytesOfBase64(resolvedImageBase64),
        pixelRatio: pixelRatio,
      );
      nextMarkers.add(
        Marker(
          markerId: MarkerId('registered_${pin.id}'),
          position: LatLng(pin.latitude, pin.longitude),
          icon: icon,
          infoWindow: InfoWindow(
            title: pin.label,
            snippet: pin.type == 'sub_client'
                ? _tr('subClientLabel')
                : _tr('b2bClientLabel'),
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
        final subClientIcon = await _icons.iconFor(
          kind: _kindOfMarkerType(subClientType),
          pixelRatio: pixelRatio,
        );
        final displayName = getClientDisplayName(subClient);
        nextMarkers.add(
          Marker(
            markerId: MarkerId('subclient_${subClient["id"]}'),
            position: LatLng(lat, lng),
            icon: subClientIcon,
            infoWindow: InfoWindow(
              title: displayName,
              snippet: _tr('subClientLabel'),
            ),
          ),
        );
      }
    }

    // Add selected location for editing
    if (selectedLocation.value != null) {
      final selectedPickerIcon = await _icons.iconFor(
        kind: _kindOfMarkerType(registrationType.value),
        avatarBytes: _bytesOfBase64(selectedImageBase64.value),
        pixelRatio: pixelRatio,
      );
      nextMarkers.add(
        Marker(
          markerId: const MarkerId('selected_location'),
          position: selectedLocation.value!,
          icon: selectedPickerIcon,
          draggable: true,
          onDragEnd: (newPosition) {
            selectedLocation.value = newPosition;
            hasPendingDragPosition.value = true;
            unawaited(_refreshMarkers());
            _saveDraft();
          },
          infoWindow: InfoWindow(
            title: _tr('newLocation'),
            snippet: _tr('activeSelection'),
          ),
        ),
      );
    }

    return nextMarkers;
  }

  /// The display density the marker bitmaps are rendered for, so pins are
  /// crisp rather than upscaled.
  double get _devicePixelRatio {
    final views = ui.PlatformDispatcher.instance.views;
    return views.isEmpty ? 1.0 : views.first.devicePixelRatio;
  }

  /// Maps the marker-type strings this controller uses internally
  /// (`b2b`, `sub_client`) and the backend's (`PROSPECT`, `SOUS_CLIENT`) onto
  /// the domain's [ClientKind], which is what the icon cache is keyed by.
  ClientKind _kindOfMarkerType(String type) =>
      ClientKind.fromBackend(type, fromSubClientEndpoint: true);

  Uint8List? _bytesOfBase64(String? encoded) {
    if (encoded == null || encoded.isEmpty) return null;
    try {
      return base64Decode(encoded);
    } on FormatException {
      // A corrupt stored image must not stop the marker from being drawn.
      return null;
    }
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

    // The repository memoises the download, so a shopfront photo is fetched
    // once per session no matter how often the markers are rebuilt.
    final result = await _clients.fetchImageBytes(imageUrl);
    final bytes = result.valueOrNull;
    if (bytes == null || bytes.isEmpty) {
      return '';
    }

    final encoded = base64Encode(bytes);
    _imageBase64Cache[imageUrl] = encoded;
    return encoded;
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

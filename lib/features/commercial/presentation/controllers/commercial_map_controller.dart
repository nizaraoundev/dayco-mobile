import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../auth/data/models/client_model.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../../../core/services/language_service.dart';
import '../../../../localization/ui_translations.dart';
import '../../../../routes/app_routes.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../data/models/brands_model.dart';

class CommercialMapController extends GetxController {
  static const String _draftStorageKey = 'commercial_client_draft';
  static const String _registeredPinsStorageKey = 'commercial_registered_pins';
  static const String _submittedRecordsStorageKey =
      'commercial_submitted_records';

  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();

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
    _loadConnectedProfile();
    _getCurrentLocation();
    unawaited(loadMyClients());
    unawaited(loadAllSubClientsAndProspectsForCommercial());
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

  void setMapType(MapType mapType) {
    selectedMapType.value = mapType;
  }

  Future<void> loadMyClients() async {
    isLoadingMyClients.value = true;
    try {
      final commercialId = profileData['id']?.trim() ?? '';
      final clients = commercialId.isNotEmpty
          ? await _authService.getClientsByCommercialId(commercialId)
          : await _authService.getMyClients();
      myClients.assignAll(clients);

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
    } finally {
      isLoadingMyClients.value = false;
    }
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
      // Refresh map markers to show all sub-clients and prospects
      await _refreshMarkers();
    } catch (e) {
      debugPrint('Failed to load sub-clients/prospects: $e');
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

      final response = await _authService.updateSubClient(
        subClientId: subClientId,
        payload: payload,
      );

      // Update local list
      final index = mySubClients.indexWhere(
        (client) => _safeString(client['id']) == subClientId,
      );
      if (index >= 0) {
        mySubClients[index] = {...mySubClients[index], ...payload, ...response};
        mySubClients.refresh();
      }

      final selectedImage = selectedImageBytes.value;
      if (selectedImage != null) {
        unawaited(
          _uploadImageInBackground(
            entityType: AuthService.entitySubClient,
            entityId: subClientId,
            imageBytes: selectedImage,
            fileName: 'sub_client_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
        );
      }

      Get.snackbar(
        _tr('success'),
        'Sous-client/Prospect mis à jour avec succès',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );

      _clearDraftAndFormAfterSave();
      closeClientForm();
    } catch (e) {
      Get.snackbar(
        _tr('error'),
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: Colors.red,
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
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );

          await _refreshMarkers();
        } catch (e) {
          Get.snackbar(
            _tr('error'),
            e.toString().replaceAll('Exception: ', ''),
            backgroundColor: Colors.red,
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
  Future<void> createClient() async {
    try {
      isCreatingClient.value = true;

      final location = selectedLocation.value;
      if (location == null) {
        throw Exception(_tr('selectBoutiqueBeforeCreate'));
      }

      final prefs = await SharedPreferences.getInstance();
      final connectedCommercialId = prefs.getString('connected_user_id');
      final connectedCommercialName = prefs.getString('connected_user_name');

      if (registrationType.value == 'sub_client') {
        // Parent client IDs are now optional - empty list will create a PROSPECT type

        final payload = _buildSubClientPayload(location);
        if (connectedCommercialId != null && connectedCommercialId.isNotEmpty) {
          payload['commercialId'] = connectedCommercialId;
        }

        debugPrint('SUB-CLIENT payload sent: ${jsonEncode(payload)}');

        // If no parent IDs selected, use empty array (will be prospect type on backend)
        // Otherwise use first parent ID for the API call
        final firstParentId = selectedParentClientIds.isNotEmpty
            ? selectedParentClientIds.first
            : null;

        final response = await _authService.createSubClient(
          parentClientId: firstParentId,
          payload: payload,
        );

        final entityId = _safeString(response['id']).isNotEmpty
            ? _safeString(response['id'])
            : _safeString(response['userId']);

        final snapshotImageBytes = selectedImageBytes.value;
        if (snapshotImageBytes != null && entityId.isNotEmpty) {
          unawaited(
            _uploadImageInBackground(
              entityType: AuthService.entitySubClient,
              entityId: entityId,
              imageBytes: snapshotImageBytes,
              fileName:
                  'sub_client_${DateTime.now().millisecondsSinceEpoch}.jpg',
            ),
          );
        }

        await _saveSubmittedRecord(
          type: 'sub_client',
          sentPayload: payload,
          responsePayload: response,
        );

        final markerLabel = _safeString(response['nomAgence']).isNotEmpty
            ? _safeString(response['nomAgence'])
            : _safeString(response['codeClient']).isNotEmpty
            ? _safeString(response['codeClient'])
            : '${nomController.text.trim()} ${prenomController.text.trim()}'
                  .trim();

        await _addRegisteredPin(
          id: _safeString(response['id']).isNotEmpty
              ? _safeString(response['id'])
              : DateTime.now().millisecondsSinceEpoch.toString(),
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

        final response = await _authService.createClientWithPayload(
          payload: sentPayload,
        );

        final entityId = _safeString(response['id']).isNotEmpty
            ? _safeString(response['id'])
            : (_safeString(response['userId']).isNotEmpty
                  ? _safeString(response['userId'])
                  : _safeString(response['codeClient']));

        // Save marques/brands separately after client creation
        if (selectedBrands.isNotEmpty && entityId.isNotEmpty) {
          try {
            await _authService.updateClient(
              clientId: entityId,
              payload: {
                'marques': selectedBrands
                    .map((brand) => brand.displayName)
                    .toList(),
              },
            );
            debugPrint('Marques saved successfully for client: $entityId');
          } catch (e) {
            debugPrint('Failed to save marques: $e');
          }
        }

        final snapshotImageBytes = selectedImageBytes.value;
        if (snapshotImageBytes != null && entityId.isNotEmpty) {
          unawaited(
            _uploadImageInBackground(
              entityType: AuthService.entityClient,
              entityId: entityId,
              imageBytes: snapshotImageBytes,
              fileName: 'client_${DateTime.now().millisecondsSinceEpoch}.jpg',
            ),
          );
        }

        await _saveSubmittedRecord(
          type: 'b2b',
          sentPayload: sentPayload,
          responsePayload: response,
        );

        await _addRegisteredPin(
          id: _safeString(response['userId']).isNotEmpty
              ? _safeString(response['userId'])
              : DateTime.now().millisecondsSinceEpoch.toString(),
          label: _safeString(response['raisonSociale']).isNotEmpty
              ? _safeString(response['raisonSociale'])
              : (raisonSocialeController.text.trim().isEmpty
                    ? _tr('b2bClientLabel')
                    : raisonSocialeController.text.trim()),
          location: location,
          imageBase64: selectedImageBase64.value,
          type: 'b2b',
        );
      }

      Get.snackbar(
        _tr('success'),
        _tr('clientCreated'),
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );

      _clearDraftAndFormAfterSave();
      closeClientForm();
    } catch (e) {
      Get.snackbar(
        _tr('error'),
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: Colors.red,
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

      final response = await _authService.updateClient(
        clientId: clientId,
        payload: payload,
      );

      final index = myClients.indexWhere(
        (client) => _safeString(client['id']) == clientId,
      );
      if (index >= 0) {
        myClients[index] = {...myClients[index], ...payload, ...response};
        myClients.refresh();
      }

      final selectedImage = selectedImageBytes.value;
      if (selectedImage != null) {
        unawaited(
          _uploadImageInBackground(
            entityType: AuthService.entityClient,
            entityId: clientId,
            imageBytes: selectedImage,
            fileName: 'client_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
        );
      }

      await loadMyClients();

      Get.snackbar(
        _tr('success'),
        _tr('clientCreated'),
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      _clearDraftAndFormAfterSave();
    } catch (e) {
      print('Error updating client: $e');
      Get.snackbar(
        _tr('error'),
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isCreatingClient.value = false;
    }
  }

  LatLng _resolveClientLocation() {
    if (selectedLocation.value != null) {
      return selectedLocation.value!;
    }

    if (currentPosition.value != null) {
      return LatLng(
        currentPosition.value!.latitude,
        currentPosition.value!.longitude,
      );
    }

    return const LatLng(36.8065, 10.1815);
  }

  Map<String, dynamic> _buildSubClientPayload(LatLng location) {
    final payload = <String, dynamic>{
      'nom': nomController.text.trim(),
      'prenom': prenomController.text.trim(),
      'telephone': telephoneController.text.trim(),
      'nomAgence': nomAgenceController.text.trim(),
      'latitude': location.latitude,
      'longitude': location.longitude,
    };

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

  Future<void> _uploadImageInBackground({
    required String entityType,
    required String entityId,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    try {
      final response = await _authService.uploadEntityImage(
        entityType: entityType,
        entityId: entityId,
        imageBytes: imageBytes,
        fileName: fileName,
      );
      debugPrint(
        'Image upload completed for $entityType/$entityId: ${jsonEncode(response)}',
      );
    } catch (e) {
      debugPrint('Image upload failed for $entityType/$entityId: $e');
    }
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

  Future<void> _refreshMarkers() async {
    final nextMarkers = <Marker>{};

    // Add registered pins
    for (final pin in registeredPins) {
      final resolvedImageBase64 = await _resolveImageBase64(pin);
      final icon = await _buildClientMarkerIcon(
        imageBase64: resolvedImageBase64,
        markerType: pin.type,
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
        final subClientIcon = await _buildClientMarkerIcon(
          imageBase64: '',
          markerType: subClientType,
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
      final selectedPickerIcon = await _buildClientMarkerIcon(
        imageBase64: selectedImageBase64.value,
        markerType: registrationType.value,
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

  Future<BitmapDescriptor> _buildClientMarkerIcon({
    String? imageBase64,
    required String markerType,
  }) async {
    try {
      final pinAsset = await rootBundle.load('assets/images/picker.png');
      final pinBytes = pinAsset.buffer.asUint8List();
      final pinImage = await _decodeImage(pinBytes, targetWidth: 120);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(140, 180);

      final pinX = (size.width - pinImage.width) / 2;
      final pinPaint = Paint();
      if (markerType == 'b2b') {
        pinPaint.colorFilter = const ColorFilter.mode(
          Colors.green,
          BlendMode.modulate,
        );
      } else if (markerType == 'PROSPECT') {
        pinPaint.colorFilter = const ColorFilter.mode(
          Colors.blue,
          BlendMode.modulate,
        );
      } else if (markerType == 'SOUS_CLIENT') {
        pinPaint.colorFilter = const ColorFilter.mode(
          Colors.orange,
          BlendMode.modulate,
        );
      }
      canvas.drawImage(pinImage, Offset(pinX, 44), pinPaint);

      if (imageBase64 != null && imageBase64.isNotEmpty) {
        final avatarBytes = base64Decode(imageBase64);
        final avatarImage = await _decodeImage(avatarBytes, targetWidth: 56);
        const avatarCenter = Offset(70, 36);
        const avatarRadius = 28.0;

        canvas.drawCircle(
          avatarCenter,
          avatarRadius + 3,
          Paint()..color = Colors.white,
        );

        final avatarRect = Rect.fromCircle(
          center: avatarCenter,
          radius: avatarRadius,
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
      }

      final picture = recorder.endRecording();
      final markerImage = await picture.toImage(
        size.width.toInt(),
        size.height.toInt(),
      );
      final pngBytes = await markerImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (pngBytes == null) {
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      }

      return BitmapDescriptor.fromBytes(pngBytes.buffer.asUint8List());
    } catch (_) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }
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

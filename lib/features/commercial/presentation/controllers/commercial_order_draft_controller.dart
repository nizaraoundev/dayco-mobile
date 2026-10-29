import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../features/auth/data/services/auth_service.dart';
import '../../data/models/commercial_order_models.dart';
import '../../data/models/commercial_stock_models.dart';
import '../../data/services/commercial_order_service.dart';
import '../../data/services/commercial_stock_service.dart';

/// The order being written on the Nouvelle commande screen.
///
/// Everything it offers comes from the live backend: the clients are the
/// commercial's own, and the products are stock rows — which is also what
/// makes the screen useful, since the quantity available is visible at the
/// moment a line is added rather than discovered after the order is placed.
class CommercialOrderDraftController extends GetxController {
  final CommercialOrderService _orderService = CommercialOrderService();
  final CommercialStockService _stockService = CommercialStockService();
  final AuthService _authService = AuthService();

  /// How many stock rows a product search asks for. A commercial is picking
  /// one reference, not browsing, so the first page is enough.
  static const int searchPageSize = 20;

  // --- Clients -------------------------------------------------------------

  final RxList<Map<String, dynamic>> clients = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingClients = false.obs;
  final RxnString clientsError = RxnString();
  final Rxn<Map<String, dynamic>> selectedClient = Rxn<Map<String, dynamic>>();

  // --- Product search ------------------------------------------------------

  final RxString productQuery = ''.obs;
  final RxList<CommercialStockItem> searchResults = <CommercialStockItem>[].obs;
  final RxBool isSearching = false.obs;
  final RxnString searchError = RxnString();

  // --- The order itself ----------------------------------------------------

  final RxList<CommercialOrderDraftLine> lines =
      <CommercialOrderDraftLine>[].obs;

  final Rx<CommercialDeliveryMode> deliveryMode =
      CommercialDeliveryMode.livraisonStdDayco.obs;

  final RxString adresseLivraison = ''.obs;
  final RxString villeLivraison = ''.obs;
  final RxString codePostalLivraison = ''.obs;
  final RxString commentaire = ''.obs;
  final RxString referenceClient = ''.obs;

  /// Desired delivery date, kept as the `yyyy-MM-dd` the backend is sent.
  final Rxn<DateTime> dateLivraisonSouhaitee = Rxn<DateTime>();

  // --- Submission ----------------------------------------------------------

  final RxBool isSubmitting = false.obs;
  final RxnString submitError = RxnString();

  Worker? _searchWorker;

  @override
  void onInit() {
    super.onInit();
    _searchWorker = debounce<String>(
      productQuery,
      (_) => searchProducts(),
      time: 450.milliseconds,
    );
    loadClients();
  }

  @override
  void onClose() {
    _searchWorker?.dispose();
    super.onClose();
  }

  // --- Totals --------------------------------------------------------------

  /// Sum of the lines, each already net of its own discount.
  double get totalHt =>
      lines.fold<double>(0, (sum, line) => sum + line.totalHt);

  /// Computed the way the web client computes it, so the figure a commercial
  /// quotes matches the one the back office will see.
  double get totalTva => totalHt * CommercialOrderDraftLine.tauxTva / 100;

  double get totalTtc => totalHt + totalTva;

  int get totalQuantite =>
      lines.fold<int>(0, (sum, line) => sum + line.quantite);

  /// Whether the order holds everything the backend needs.
  bool get canSubmit =>
      !isSubmitting.value &&
      lines.isNotEmpty &&
      (selectedClient.value?['id']?.toString().trim().isNotEmpty ?? false);

  // --- Clients -------------------------------------------------------------

  /// The commercial's own clients, by the same rule the map screen uses: the
  /// profile's id picks the commercial's list, and without one the account's
  /// own clients are all there is to offer.
  Future<void> loadClients() async {
    isLoadingClients.value = true;
    clientsError.value = null;

    try {
      final commercialId = await _currentUserId();
      final loaded = commercialId.isEmpty
          ? await _authService.getMyClients()
          : await _authService.getClientsByCommercialId(commercialId);

      clients.assignAll(loaded);
    } catch (e) {
      clientsError.value = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoadingClients.value = false;
    }
  }

  void selectClient(Map<String, dynamic>? client) {
    selectedClient.value = client;
  }

  /// A client's name, by the same precedence the rest of the app reads it
  /// with: raison sociale, then agency, then person.
  String clientDisplayName(Map<String, dynamic> client) {
    final raisonSociale = _text(client['raisonSociale']);
    if (raisonSociale.isNotEmpty) {
      return raisonSociale;
    }

    final nomAgence = _text(client['nomAgence']);
    if (nomAgence.isNotEmpty) {
      return nomAgence;
    }

    final fullName = '${_text(client['nom'])} ${_text(client['prenom'])}'
        .trim();
    if (fullName.isNotEmpty) {
      return fullName;
    }

    final code = _text(client['codeClient']);
    return code.isEmpty ? 'Client sans nom' : code;
  }

  // --- Product search ------------------------------------------------------

  void setProductQuery(String value) {
    productQuery.value = value;
  }

  Future<void> searchProducts() async {
    final query = productQuery.value.trim();

    if (query.isEmpty) {
      searchResults.clear();
      searchError.value = null;
      return;
    }

    isSearching.value = true;
    searchError.value = null;

    try {
      final page = await _stockService.getStocksAdminAll(
        page: 0,
        size: searchPageSize,
        search: query,
      );
      searchResults.assignAll(page.content);
    } catch (e) {
      searchResults.clear();
      searchError.value = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isSearching.value = false;
    }
  }

  // --- Lines ---------------------------------------------------------------

  /// Adds a stock row as a line, or bumps the quantity if it is already on
  /// the order. The reference is the identity: the same product reached from
  /// two different searches is one line, not two.
  void addLine(CommercialStockItem stock, {int quantite = 1}) {
    final reference = stock.referenceProduit.trim();
    final existing = lines.indexWhere(
      (line) => line.referenceProduit == reference,
    );

    if (existing >= 0) {
      final line = lines[existing];
      lines[existing] = line.copyWith(quantite: line.quantite + quantite);
      return;
    }

    lines.add(
      CommercialOrderDraftLine(
        produitId: stock.produitId?.trim() ?? '',
        referenceProduit: reference,
        designationProduit: stock.designationProduit,
        quantite: quantite,
        prixUnitaireHt: stock.prixHt,
      ),
    );
  }

  void setLineQuantity(int index, int quantite) {
    if (index < 0 || index >= lines.length) {
      return;
    }

    if (quantite <= 0) {
      lines.removeAt(index);
      return;
    }

    lines[index] = lines[index].copyWith(quantite: quantite);
  }

  void setLineDiscount(int index, double percentage) {
    if (index < 0 || index >= lines.length) {
      return;
    }

    final clamped = percentage.clamp(0, 100).toDouble();
    lines[index] = lines[index].copyWith(remisePourcentage: clamped);
  }

  void removeLine(int index) {
    if (index >= 0 && index < lines.length) {
      lines.removeAt(index);
    }
  }

  // --- Delivery ------------------------------------------------------------

  void setDeliveryMode(CommercialDeliveryMode mode) {
    deliveryMode.value = mode;
  }

  void setDeliveryDate(DateTime? date) {
    dateLivraisonSouhaitee.value = date;
  }

  // --- Submission ----------------------------------------------------------

  /// Places the order. Returns it on success, or null with [submitError] set.
  ///
  /// The caller is expected to have confirmed with the user first: this writes
  /// a real order to the backend and there is no undo from this screen.
  Future<CommercialOrder?> submit() async {
    final client = selectedClient.value;
    final clientId = _text(client?['id']);

    if (clientId.isEmpty) {
      submitError.value = 'Sélectionnez un client.';
      return null;
    }

    if (lines.isEmpty) {
      submitError.value = 'Ajoutez au moins un produit.';
      return null;
    }

    isSubmitting.value = true;
    submitError.value = null;

    try {
      final order = await _orderService.createOrder(
        clientId: clientId,
        clientRaisonSociale: client == null ? null : clientDisplayName(client),
        lignes: List<CommercialOrderDraftLine>.from(lines),
        modeLivraison: deliveryMode.value,
        adresseLivraison: adresseLivraison.value,
        villeLivraison: villeLivraison.value,
        codePostalLivraison: codePostalLivraison.value,
        commentaire: commentaire.value,
        referenceClient: referenceClient.value,
        dateLivraisonSouhaitee: _formatDateForBackend(
          dateLivraisonSouhaitee.value,
        ),
      );

      return order;
    } catch (e) {
      submitError.value = e.toString().replaceFirst('Exception: ', '');
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  /// The signed-in account's id.
  ///
  /// `connected_user_id` is what the map screen picks its client list with,
  /// so it is read first to keep the two screens showing the same clients;
  /// `user_id`, written by the login itself, covers the case where the
  /// connected profile has not been fetched yet.
  Future<String> _currentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final connected = (prefs.getString('connected_user_id') ?? '').trim();
    if (connected.isNotEmpty) {
      return connected;
    }
    return (prefs.getString('user_id') ?? '').trim();
  }

  /// `yyyy-MM-dd`, the form the backend is sent for a wanted-by date.
  static String? _formatDateForBackend(DateTime? date) {
    if (date == null) {
      return null;
    }

    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static String _text(dynamic value) => value?.toString().trim() ?? '';
}

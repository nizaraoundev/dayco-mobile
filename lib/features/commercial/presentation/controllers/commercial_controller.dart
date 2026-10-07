import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/models/models.dart';
import '../../data/services/services.dart';
import '../../data/services/fake_data_service.dart';

/// Main controller for commercial app
class CommercialController extends GetxController {
  final DatabaseService _db = DatabaseService.instance;
  final MapService _mapService = Get.find<MapService>();
  final SyncService _syncService = Get.find<SyncService>();

  // Observable state
  final RxList<ClientModel> clients = <ClientModel>[].obs;
  final RxList<ProductModel> products = <ProductModel>[].obs;
  final RxList<VisitModel> todayVisits = <VisitModel>[].obs;
  final RxList<OrderModel> orders = <OrderModel>[].obs;
  final Rx<RouteModel?> activeRoute = Rx<RouteModel?>(null);

  final RxBool isLoading = false.obs;
  final RxString searchQuery = ''.obs;

  // Current location
  final Rx<LatLng?> currentLocation = Rx<LatLng?>(null);

  // Selected items
  final Rx<ClientModel?> selectedClient = Rx<ClientModel?>(null);
  final Rx<VisitModel?> activeVisit = Rx<VisitModel?>(null);

  // Product filtering
  final Rx<ProductCategory?> selectedProductCategory = Rx<ProductCategory?>(
    null,
  );
  final RxString productSearchQuery = ''.obs;

  // Shopping cart
  final RxList<CartItemModel> cartItems = <CartItemModel>[].obs;

  // Stats
  final RxInt completedVisitsToday = 0.obs;
  final RxInt pendingVisitsToday = 0.obs;
  final RxDouble todaySales = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    _initData();
    _getCurrentLocation();
  }

  Future<void> _initData() async {
    isLoading.value = true;
    try {
      // Load fake data for demo
      await _loadFakeData();

      // Calculate stats
      _calculateStats();
    } catch (e) {
      print('Error initializing data: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadFakeData() async {
    // Load clients
    clients.value = FakeDataService.getTunisianClients();

    // Load products
    products.value = FakeDataService.getTunisianProducts();

    // Load today's visits
    todayVisits.value = FakeDataService.getTodayVisits();

    // Load orders
    orders.value = FakeDataService.getSampleOrders();

    // Find active visit
    activeVisit.value = todayVisits.firstWhereOrNull(
      (v) => v.status == VisitStatus.inProgress,
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        currentLocation.value = LatLng(position.latitude, position.longitude);
      } else {
        // Default to Tunis warehouse
        final warehouse = FakeDataService.getWarehouseLocation();
        currentLocation.value = LatLng(
          warehouse['latitude'],
          warehouse['longitude'],
        );
      }
    } catch (e) {
      // Default to Tunis warehouse
      final warehouse = FakeDataService.getWarehouseLocation();
      currentLocation.value = LatLng(
        warehouse['latitude'],
        warehouse['longitude'],
      );
    }
  }

  void _calculateStats() {
    completedVisitsToday.value = todayVisits
        .where((v) => v.status == VisitStatus.completed)
        .length;

    pendingVisitsToday.value = todayVisits
        .where(
          (v) =>
              v.status == VisitStatus.planned ||
              v.status == VisitStatus.inProgress,
        )
        .length;

    // Calculate today's sales
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    todaySales.value = orders
        .where((o) => o.createdAt.isAfter(startOfDay))
        .fold(0.0, (sum, o) => sum + o.totalAmount);
  }

  // ========== Client Operations ==========

  List<ClientModel> get filteredClients {
    if (searchQuery.value.isEmpty) return clients;
    final query = searchQuery.value.toLowerCase();
    return clients
        .where(
          (c) =>
              c.businessName.toLowerCase().contains(query) ||
              c.contactPerson.toLowerCase().contains(query) ||
              c.address.toLowerCase().contains(query),
        )
        .toList();
  }

  List<ClientModel> get clientsNeedingVisit {
    return clients.where((c) => c.needsVisit).toList();
  }

  List<ClientModel> get vipClients {
    return clients.where((c) => c.category == ClientCategory.vip).toList();
  }

  void selectClient(ClientModel client) {
    selectedClient.value = client;
  }

  Future<void> updateClient(ClientModel client) async {
    final index = clients.indexWhere((c) => c.id == client.id);
    if (index != -1) {
      clients[index] = client;
      await _db.updateClient(client);
      await _syncService.queueClientSync(client, SyncAction.update);
    }
  }

  // ========== Visit Operations ==========

  Future<void> startVisit(VisitModel visit) async {
    final now = DateTime.now();
    final updatedVisit = visit.copyWith(
      status: VisitStatus.inProgress,
      startTime: now,
      updatedAt: now,
      syncStatus: 'pending',
    );

    final index = todayVisits.indexWhere((v) => v.id == visit.id);
    if (index != -1) {
      todayVisits[index] = updatedVisit;
    }
    activeVisit.value = updatedVisit;

    await _db.updateVisit(updatedVisit);
    await _syncService.queueVisitSync(updatedVisit, SyncAction.update);
  }

  Future<void> completeVisit(VisitModel visit, {String? outcome}) async {
    final now = DateTime.now();
    final duration = visit.startTime != null
        ? now.difference(visit.startTime!).inMinutes
        : 0;

    final updatedVisit = visit.copyWith(
      status: VisitStatus.completed,
      endTime: now,
      durationMinutes: duration,
      outcome: outcome,
      updatedAt: now,
      syncStatus: 'pending',
    );

    final index = todayVisits.indexWhere((v) => v.id == visit.id);
    if (index != -1) {
      todayVisits[index] = updatedVisit;
    }

    if (activeVisit.value?.id == visit.id) {
      activeVisit.value = null;
    }

    // Update client's last visit date
    final clientIndex = clients.indexWhere((c) => c.id == visit.clientId);
    if (clientIndex != -1) {
      final updatedClient = clients[clientIndex].copyWith(
        lastVisitDate: now,
        updatedAt: now,
      );
      clients[clientIndex] = updatedClient;
      await _db.updateClient(updatedClient);
    }

    await _db.updateVisit(updatedVisit);
    await _syncService.queueVisitSync(updatedVisit, SyncAction.update);

    _calculateStats();
  }

  Future<void> skipVisit(VisitModel visit, {String? reason}) async {
    final now = DateTime.now();
    final updatedVisit = visit.copyWith(
      status: VisitStatus.skipped,
      outcome: reason ?? 'Reportée',
      updatedAt: now,
      syncStatus: 'pending',
    );

    final index = todayVisits.indexWhere((v) => v.id == visit.id);
    if (index != -1) {
      todayVisits[index] = updatedVisit;
    }

    if (activeVisit.value?.id == visit.id) {
      activeVisit.value = null;
    }

    await _db.updateVisit(updatedVisit);
    await _syncService.queueVisitSync(updatedVisit, SyncAction.update);

    _calculateStats();
  }

  Future<void> addNoteToVisit(VisitModel visit, VisitNoteModel note) async {
    final updatedNotes = [...visit.notes, note];
    final updatedVisit = visit.copyWith(
      notes: updatedNotes,
      updatedAt: DateTime.now(),
    );

    final index = todayVisits.indexWhere((v) => v.id == visit.id);
    if (index != -1) {
      todayVisits[index] = updatedVisit;
    }

    if (activeVisit.value?.id == visit.id) {
      activeVisit.value = updatedVisit;
    }

    await _db.updateVisit(updatedVisit);
  }

  // ========== Route Operations ==========

  Future<void> generateOptimizedRoute() async {
    if (currentLocation.value == null) return;

    isLoading.value = true;
    try {
      // Get pending visits for today
      final pendingVisitClients = todayVisits
          .where((v) => v.status == VisitStatus.planned)
          .map((v) => clients.firstWhere((c) => c.id == v.clientId))
          .toList();

      if (pendingVisitClients.isEmpty) return;

      final warehouse = FakeDataService.getWarehouseLocation();

      final route = await _mapService.optimizeRoute(
        startPoint: currentLocation.value!,
        startAddress: 'Position actuelle',
        clients: pendingVisitClients,
        endPoint: LatLng(warehouse['latitude'], warehouse['longitude']),
        endAddress: warehouse['address'],
      );

      if (route != null) {
        activeRoute.value = route.copyWith(status: RouteStatus.active);
        await _db.insertRoute(activeRoute.value!);
      }
    } catch (e) {
      print('Error generating route: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // ========== Product Operations ==========

  List<ProductModel> get filteredProducts {
    var result = products.toList();

    // Filter by category
    if (selectedProductCategory.value != null) {
      result = result
          .where((p) => p.category == selectedProductCategory.value)
          .toList();
    }

    // Filter by search query
    if (productSearchQuery.value.isNotEmpty) {
      final q = productSearchQuery.value.toLowerCase();
      result = result
          .where(
            (p) =>
                p.reference.toLowerCase().contains(q) ||
                p.name.toLowerCase().contains(q) ||
                p.brand.toLowerCase().contains(q),
          )
          .toList();
    }

    return result;
  }

  void filterProductsByCategory(ProductCategory? category) {
    selectedProductCategory.value = category;
  }

  List<ProductModel> searchProducts(String query) {
    productSearchQuery.value = query;
    if (query.isEmpty) return products;
    final q = query.toLowerCase();
    return products
        .where(
          (p) =>
              p.reference.toLowerCase().contains(q) ||
              p.name.toLowerCase().contains(q) ||
              p.brand.toLowerCase().contains(q),
        )
        .toList();
  }

  List<ProductModel> getProductsByCategory(ProductCategory category) {
    return products.where((p) => p.category == category).toList();
  }

  List<ProductModel> get lowStockProducts {
    return products
        .where((p) => p.stockStatus == StockStatus.lowStock)
        .toList();
  }

  List<ProductModel> get outOfStockProducts {
    return products
        .where((p) => p.stockStatus == StockStatus.outOfStock)
        .toList();
  }

  // ========== Cart Operations ==========

  double get cartTotal {
    return cartItems.fold(0.0, (sum, item) => sum + item.total);
  }

  void addToCart(ProductModel product, {int quantity = 1}) {
    final existingIndex = cartItems.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (existingIndex != -1) {
      final existing = cartItems[existingIndex];
      cartItems[existingIndex] = CartItemModel(
        product: product,
        quantity: existing.quantity + quantity,
      );
    } else {
      cartItems.add(CartItemModel(product: product, quantity: quantity));
    }
  }

  void removeFromCart(ProductModel product) {
    cartItems.removeWhere((item) => item.product.id == product.id);
  }

  void updateCartItemQuantity(ProductModel product, int quantity) {
    if (quantity <= 0) {
      removeFromCart(product);
      return;
    }

    final index = cartItems.indexWhere((item) => item.product.id == product.id);
    if (index != -1) {
      cartItems[index] = CartItemModel(product: product, quantity: quantity);
    }
  }

  void clearCart() {
    cartItems.clear();
  }

  // ========== Order Operations ==========

  Future<OrderModel> createOrder({
    required ClientModel client,
    required List<OrderItemModel> items,
    double discount = 0,
    String? notes,
  }) async {
    final subtotal = items.fold(0.0, (sum, item) => sum + item.totalPrice);
    final totalDiscount = subtotal * (discount / 100);
    final totalAmount = subtotal - totalDiscount;

    final order = OrderModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      orderNumber:
          'CMD-${DateTime.now().year}-${(orders.length + 1).toString().padLeft(4, '0')}',
      clientId: client.id,
      clientName: client.businessName,
      items: items,
      subtotal: subtotal,
      totalDiscount: totalDiscount,
      totalAmount: totalAmount,
      status: OrderStatus.draft,
      notes: notes,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdByUserId: 'user_001',
      visitId: activeVisit.value?.id,
    );

    orders.add(order);
    await _db.insertOrder(order);
    await _syncService.queueOrderSync(order, SyncAction.create);

    // If created during a visit, link it
    if (activeVisit.value != null) {
      final updatedVisit = activeVisit.value!.copyWith(
        orderIds: [...activeVisit.value!.orderIds, order.id],
      );
      final index = todayVisits.indexWhere((v) => v.id == updatedVisit.id);
      if (index != -1) {
        todayVisits[index] = updatedVisit;
      }
      activeVisit.value = updatedVisit;
    }

    _calculateStats();
    return order;
  }

  Future<void> confirmOrder(OrderModel order) async {
    final updatedOrder = order.copyWith(
      status: OrderStatus.confirmed,
      updatedAt: DateTime.now(),
    );

    final index = orders.indexWhere((o) => o.id == order.id);
    if (index != -1) {
      orders[index] = updatedOrder;
    }

    await _syncService.queueOrderSync(updatedOrder, SyncAction.update);
    _calculateStats();
  }

  // ========== Utility ==========

  void refreshData() {
    _initData();
  }

  double getDistanceToClient(ClientModel client) {
    if (currentLocation.value == null) return 0;
    return _mapService.calculateDistance(
      currentLocation.value!.latitude,
      currentLocation.value!.longitude,
      client.latitude,
      client.longitude,
    );
  }

  List<ClientModel> getClientsSortedByDistance() {
    if (currentLocation.value == null) return clients;
    return _mapService.sortClientsByDistance(clients, currentLocation.value!);
  }
}

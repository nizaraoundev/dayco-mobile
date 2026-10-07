import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/commercial_stock_models.dart';
import '../../data/services/commercial_stock_service.dart';

class CommercialStockController extends GetxController {
  final CommercialStockService _stockService = CommercialStockService();

  static const int pageSize = 20;

  final RxList<CommercialStockItem> stocks = <CommercialStockItem>[].obs;
  final RxList<CommercialPendingReservation> reservations =
      <CommercialPendingReservation>[].obs;

  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool isLoadingReservations = false.obs;
  final RxBool hasMore = true.obs;

  final RxString searchQuery = ''.obs;
  final RxString warehouseFilter = ''.obs;
  final RxnString errorMessage = RxnString();
  final RxnString reservationError = RxnString();

  final Rxn<CommercialStockItem> selectedStock = Rxn<CommercialStockItem>();

  final ScrollController scrollController = ScrollController();

  int _currentPage = 0;
  int _totalPages = 1;
  Worker? _searchWorker;
  Worker? _warehouseWorker;

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_onScroll);
    _searchWorker = debounce<String>(
      searchQuery,
      (_) => refreshStocks(),
      time: 450.milliseconds,
    );
    _warehouseWorker = debounce<String>(
      warehouseFilter,
      (_) => refreshStocks(),
      time: 450.milliseconds,
    );
    refreshStocks();
  }

  @override
  void onClose() {
    _searchWorker?.dispose();
    _warehouseWorker?.dispose();
    scrollController.dispose();
    super.onClose();
  }

  void setSearchQuery(String value) {
    searchQuery.value = value;
  }

  void setWarehouseFilter(String value) {
    warehouseFilter.value = value;
  }

  Future<void> refreshStocks() async {
    _currentPage = 0;
    _totalPages = 1;
    hasMore.value = true;
    errorMessage.value = null;

    await _loadPage(reset: true);
  }

  Future<void> loadReservationsForStock(CommercialStockItem stock) async {
    selectedStock.value = stock;
    reservations.clear();
    reservationError.value = null;
    isLoadingReservations.value = true;

    try {
      String productId = stock.produitId ?? '';

      if (productId.isEmpty) {
        final details = await _stockService.getStockByReferenceOrId(
          stock.referenceProduit,
        );
        productId = (details.produitId ?? '').trim();
      }

      if (productId.isEmpty) {
        throw Exception(
          'Produit introuvable pour ${stock.referenceProduit}.',
        );
      }

      final pending = await _stockService.getPendingReservations(
        produitId: productId,
      );
      reservations.assignAll(pending);
    } catch (e) {
      reservationError.value = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoadingReservations.value = false;
    }
  }

  Future<CommercialStockAvailability?> checkAvailability({
    required CommercialStockItem stock,
    required int quantite,
  }) async {
    try {
      return await _stockService.checkAvailability(
        referenceOrId: stock.referenceProduit,
        quantite: quantite,
      );
    } catch (e) {
      Get.snackbar(
        'Disponibilité',
        e.toString().replaceFirst('Exception: ', ''),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return null;
    }
  }

  Future<void> loginForStocks({
    required String codeClient,
    required String password,
  }) async {
    try {
      await _stockService.loginAndGetToken(
        codeClient: codeClient,
        password: password,
      );
      await refreshStocks();
      Get.snackbar(
        'Connexion réussie',
        'Token stock mis à jour.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Connexion échouée',
        e.toString().replaceFirst('Exception: ', ''),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _loadPage({required bool reset}) async {
    if (isLoading.value || isLoadingMore.value) {
      return;
    }

    if (!hasMore.value && !reset) {
      return;
    }

    if (reset) {
      isLoading.value = true;
      stocks.clear();
    } else {
      isLoadingMore.value = true;
    }

    try {
      final response = await _stockService.getStocksAdminAll(
        page: _currentPage,
        size: pageSize,
        search: searchQuery.value,
        entrepot: warehouseFilter.value,
      );

      _totalPages = response.totalPages;

      if (reset) {
        stocks.assignAll(response.content);
      } else {
        stocks.addAll(response.content);
      }

      hasMore.value = (_currentPage + 1) < _totalPages;
      if (_totalPages == 0) {
        hasMore.value = false;
      }

      errorMessage.value = null;
    } catch (e) {
      errorMessage.value = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  Future<void> loadNextPage() async {
    if (!hasMore.value || isLoading.value || isLoadingMore.value) {
      return;
    }

    _currentPage += 1;
    await _loadPage(reset: false);
  }

  void _onScroll() {
    if (!scrollController.hasClients) {
      return;
    }

    final max = scrollController.position.maxScrollExtent;
    final current = scrollController.position.pixels;

    if (current >= (max - 250)) {
      loadNextPage();
    }
  }
}

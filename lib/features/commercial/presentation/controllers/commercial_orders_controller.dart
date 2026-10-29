import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/commercial_order_models.dart';
import '../../data/services/commercial_order_service.dart';

class CommercialOrdersController extends GetxController {
  final CommercialOrderService _orderService = CommercialOrderService();

  static const int pageSize = 20;

  /// Pages [_fillFilteredPage] will pull on its own before giving up.
  static const int maxAutoPages = 10;

  final RxList<CommercialOrder> orders = <CommercialOrder>[].obs;

  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = true.obs;

  /// Status the list is narrowed to, or null for every status. Unlike the
  /// stock screen's level filter this one is applied by the backend, so
  /// switching it reloads from page zero rather than sifting what is in hand.
  final Rx<CommercialOrderStatus?> statusFilter = Rx<CommercialOrderStatus?>(
    null,
  );

  /// Total the backend reports for the current filter, across all pages.
  final RxInt totalElements = 0.obs;

  final RxnString errorMessage = RxnString();

  /// Set when the backend refused the call rather than failing to answer, so
  /// the screen can say so instead of offering a pointless retry.
  final RxBool isAuthError = false.obs;

  /// Set once the admin listing has been refused for this session: the token
  /// is valid but carries no admin role, so the screen is showing only the
  /// signed-in account's own orders and has to say so rather than presenting a
  /// partial list as though it were everything.
  final RxBool isPersonalScope = false.obs;

  final RxBool showScrollToTop = false.obs;

  /// The order an action is running on, so the row that is changing is the
  /// only one that looks busy.
  final RxnString actingOrderId = RxnString();

  /// Why the last action failed, cleared when another is started. Separate
  /// from [errorMessage], which is about loading the list: a refused
  /// cancellation must not blank the orders already on screen.
  final RxnString actionError = RxnString();

  final ScrollController scrollController = ScrollController();

  int _currentPage = 0;
  int _totalPages = 1;

  /// Bumped when a fresh request supersedes what is in flight, so a page that
  /// arrives late cannot append itself to a filter it does not belong to.
  int _generation = 0;

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_onScroll);
    refreshOrders();
  }

  @override
  void onClose() {
    scrollController.dispose();
    super.onClose();
  }

  void setStatusFilter(CommercialOrderStatus? status) {
    if (statusFilter.value == status) {
      return;
    }

    statusFilter.value = status;
    refreshOrders();
  }

  Future<void> refreshOrders() async {
    _currentPage = 0;
    _totalPages = 1;
    hasMore.value = true;
    errorMessage.value = null;
    isAuthError.value = false;

    await _loadPage(reset: true);
    await _fillFilteredPage();
  }

  /// Pulls further pages when the status filter had to be applied here.
  ///
  /// Only the fallback scope needs this: `mes-commandes` takes no status, so a
  /// page of orders can hold no match at all, and an empty list cannot be
  /// scrolled to ask for the next one. Bounded, because a status the account
  /// has never used would otherwise walk its whole order history on one tap.
  Future<void> _fillFilteredPage() async {
    if (!isPersonalScope.value || statusFilter.value == null) {
      return;
    }

    var fetched = 0;
    while (orders.isEmpty && hasMore.value && fetched < maxAutoPages) {
      if (!await loadNextPage()) {
        break;
      }
      fetched += 1;
    }
  }

  Future<bool> loadNextPage() async {
    if (!hasMore.value || isLoading.value || isLoadingMore.value) {
      return false;
    }

    _currentPage += 1;
    final loaded = await _loadPage(reset: false);

    if (!loaded) {
      // Give the page number back, so a retry does not skip a page of orders.
      _currentPage -= 1;
    }

    return loaded;
  }

  Future<bool> _loadPage({required bool reset}) async {
    if (reset) {
      _generation += 1;
    } else if (isLoading.value || isLoadingMore.value || !hasMore.value) {
      return false;
    }

    final generation = _generation;

    if (reset) {
      isLoading.value = true;
      isLoadingMore.value = false;
    } else {
      isLoadingMore.value = true;
    }

    try {
      final response = await _fetchPage(_currentPage);

      if (generation != _generation) {
        return false;
      }

      _totalPages = response.totalPages;
      totalElements.value = response.totalElements;

      if (reset) {
        orders.assignAll(response.content);
      } else {
        orders.addAll(response.content);
      }

      hasMore.value = _totalPages > 0 && (_currentPage + 1) < _totalPages;

      errorMessage.value = null;
      isAuthError.value = false;
      return true;
    } catch (e) {
      if (generation != _generation) {
        return false;
      }

      isAuthError.value = e is CommercialOrderAuthException;
      errorMessage.value = e.toString().replaceFirst('Exception: ', '');

      if (reset) {
        orders.clear();
      }
      return false;
    } finally {
      if (generation == _generation) {
        isLoading.value = false;
        isLoadingMore.value = false;
      }
    }
  }

  /// Asks for every client's orders, and falls back to the signed-in
  /// account's own once the backend has said that role is not available.
  ///
  /// Which listing a commercial's token may read is a question only the
  /// backend can answer, so it is asked rather than assumed — once per
  /// session, since a refusal will not change until someone signs in again.
  Future<CommercialOrderPageResponse> _fetchPage(int page) async {
    final statut = statusFilter.value == null
        ? null
        : CommercialOrder.rawForStatus(statusFilter.value!);

    if (!isPersonalScope.value) {
      try {
        return await _orderService.getOrders(
          page: page,
          size: pageSize,
          statut: statut,
        );
      } on CommercialOrderForbiddenException {
        isPersonalScope.value = true;
      }
    }

    final personal = await _orderService.getMyOrders(
      page: page,
      size: pageSize,
    );

    if (statusFilter.value == null) {
      return personal;
    }

    // The personal listing takes no status, so that filter is the one thing
    // this fallback has to apply itself. The backend's totals then count more
    // than the list shows, which is why the screen stops reporting them once
    // it is in this scope.
    return CommercialOrderPageResponse(
      content: personal.content
          .where((order) => order.status == statusFilter.value)
          .toList(),
      totalElements: personal.totalElements,
      totalPages: personal.totalPages,
      number: personal.number,
      size: personal.size,
    );
  }

  // --- Actions -------------------------------------------------------------

  /// Which actions an order will accept.
  ///
  /// Validation is the step out of "en attente", so it is offered only there.
  /// A delivered or cancelled order is finished: nothing is offered on it,
  /// because the backend accepting such a change does not make it something a
  /// commercial should be able to do by mistake from a phone.
  bool canValidate(CommercialOrder order) =>
      order.status == CommercialOrderStatus.enAttente;

  bool canCancel(CommercialOrder order) =>
      order.status != CommercialOrderStatus.annulee &&
      order.status != CommercialOrderStatus.livree;

  bool canChangeStatus(CommercialOrder order) =>
      order.status != CommercialOrderStatus.annulee &&
      order.status != CommercialOrderStatus.livree;

  /// The statuses offered for a move, in lifecycle order.
  ///
  /// Validation and cancellation have endpoints of their own, so they are not
  /// repeated here — this is for walking an accepted order forward.
  static const List<CommercialOrderStatus> movableStatuses = [
    CommercialOrderStatus.enPreparation,
    CommercialOrderStatus.expediee,
    CommercialOrderStatus.livree,
  ];

  Future<bool> validateOrder(CommercialOrder order) {
    return _runAction(order, () => _orderService.validateOrder(order.id));
  }

  Future<bool> cancelOrder(CommercialOrder order, String motif) {
    return _runAction(order, () => _orderService.cancelOrder(order.id, motif));
  }

  Future<bool> changeStatus(
    CommercialOrder order,
    CommercialOrderStatus status,
  ) {
    return _runAction(
      order,
      () => _orderService.updateStatus(order.id, status),
    );
  }

  /// Runs one action and puts the order the backend returned back in the list.
  ///
  /// The returned order is used rather than the status that was asked for: if
  /// the backend applied something else, the list shows what is actually
  /// stored. An order that no longer matches the active filter leaves the
  /// list, since it is no longer one of the rows that were asked for.
  Future<bool> _runAction(
    CommercialOrder order,
    Future<CommercialOrder> Function() action,
  ) async {
    if (actingOrderId.value != null) {
      return false;
    }

    actingOrderId.value = order.id;
    actionError.value = null;

    try {
      final updated = await action();
      final index = orders.indexWhere((item) => item.id == order.id);

      if (index >= 0) {
        final filter = statusFilter.value;
        if (filter != null && updated.status != filter) {
          orders.removeAt(index);
          if (totalElements.value > 0) {
            totalElements.value -= 1;
          }
        } else {
          orders[index] = updated;
        }
      }

      return true;
    } catch (e) {
      actionError.value = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      actingOrderId.value = null;
    }
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

    final shouldShow = current > 600;
    if (showScrollToTop.value != shouldShow) {
      showScrollToTop.value = shouldShow;
    }
  }

  Future<void> scrollToTop() async {
    if (!scrollController.hasClients) {
      return;
    }

    await scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }
}

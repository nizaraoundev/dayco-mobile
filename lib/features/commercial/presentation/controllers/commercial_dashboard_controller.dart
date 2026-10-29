import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../features/auth/data/services/auth_service.dart';
import '../../data/models/commercial_order_models.dart';
import '../../data/models/commercial_stock_models.dart';
import '../../data/services/commercial_order_service.dart';
import '../../data/services/commercial_stock_service.dart';

/// The dashboard's figures, all of them read from the backend.
///
/// Every number here is a count the backend did itself, asked for as a page of
/// one, plus one call for the stock totals and one for the latest orders. The
/// calls go out together and **each one falls back on its own**: a dashboard
/// is a page of unrelated figures, so one refused endpoint should cost its own
/// tile and nothing else. That is also how the B2B web client loads its
/// dashboard.
class CommercialDashboardController extends GetxController {
  final CommercialOrderService _orderService = CommercialOrderService();
  final CommercialStockService _stockService = CommercialStockService();
  final AuthService _authService = AuthService();

  /// How many recent orders the dashboard lists.
  static const int recentOrdersCount = 5;

  final RxBool isLoading = false.obs;

  final Rx<CommercialStockStats> stockStats = CommercialStockStats.empty.obs;

  final RxInt totalOrders = 0.obs;
  final RxInt ordersEnAttente = 0.obs;
  final RxInt ordersEnPreparation = 0.obs;
  final RxInt ordersExpediees = 0.obs;
  final RxInt ordersLivrees = 0.obs;

  final RxInt clientCount = 0.obs;
  final RxInt stockAlertCount = 0.obs;

  final RxList<CommercialOrder> recentOrders = <CommercialOrder>[].obs;

  /// Which parts of the dashboard could not be read, so each tile can say so
  /// rather than showing a zero that looks like a real figure.
  final RxBool hasOrderError = false.obs;
  final RxBool hasStockError = false.obs;
  final RxBool hasClientError = false.obs;

  /// Set when every call was refused for want of a usable token, which is one
  /// problem with one way out rather than four broken tiles.
  final RxBool isAuthError = false.obs;

  @override
  void onInit() {
    super.onInit();
    refreshDashboard();
  }

  Future<void> refreshDashboard() async {
    isLoading.value = true;
    hasOrderError.value = false;
    hasStockError.value = false;
    hasClientError.value = false;
    isAuthError.value = false;

    final authRefusals = <bool>[];

    // Sent together: the figures are independent, so waiting for them one
    // after another would only make the dashboard slower to read.
    await Future.wait([
      _loadOrderCounts(authRefusals),
      _loadRecentOrders(authRefusals),
      _loadStock(authRefusals),
      _loadClientCount(),
    ]);

    // Only worth offering a sign-in when nothing that can report a refusal
    // reported anything else; a single refused endpoint is that tile's
    // problem, not the session's. The client count is not in this tally —
    // see [_loadClientCount] for why it cannot vote.
    isAuthError.value =
        authRefusals.isNotEmpty && authRefusals.every((refused) => refused);

    isLoading.value = false;
  }

  Future<void> _loadOrderCounts(List<bool> authRefusals) async {
    try {
      final counts = await Future.wait([
        _orderService.countOrders(),
        _orderService.countOrders(status: CommercialOrderStatus.enAttente),
        _orderService.countOrders(status: CommercialOrderStatus.enPreparation),
        _orderService.countOrders(status: CommercialOrderStatus.expediee),
        _orderService.countOrders(status: CommercialOrderStatus.livree),
      ]);

      totalOrders.value = counts[0];
      ordersEnAttente.value = counts[1];
      ordersEnPreparation.value = counts[2];
      ordersExpediees.value = counts[3];
      ordersLivrees.value = counts[4];
    } catch (e) {
      hasOrderError.value = true;
      authRefusals.add(e is CommercialOrderAuthException);
      return;
    }

    authRefusals.add(false);
  }

  Future<void> _loadRecentOrders(List<bool> authRefusals) async {
    try {
      final page = await _orderService.getOrders(
        page: 0,
        size: recentOrdersCount,
      );
      recentOrders.assignAll(page.content);
    } catch (e) {
      recentOrders.clear();
      hasOrderError.value = true;
      authRefusals.add(e is CommercialOrderAuthException);
      return;
    }

    authRefusals.add(false);
  }

  Future<void> _loadStock(List<bool> authRefusals) async {
    var refused = false;

    try {
      stockStats.value = await _stockService.getStockStats();
    } catch (e) {
      stockStats.value = CommercialStockStats.empty;
      hasStockError.value = true;
      refused = e is CommercialStockAuthException;
    }

    try {
      stockAlertCount.value = await _stockService.countStockAlerts();
    } catch (e) {
      stockAlertCount.value = 0;
      hasStockError.value = true;
      refused = refused || e is CommercialStockAuthException;
    }

    authRefusals.add(hasStockError.value && refused);
  }

  /// The one loader that casts no vote on [isAuthError].
  ///
  /// AuthService reports every failure as a bare Exception, so a refused
  /// token cannot be told from a dead network here. Voting either way would
  /// be a guess: "refused" would offer a sign-in on a network blip, and "not
  /// refused" would stop a genuinely expired session from ever being
  /// reported. So this tile fails on its own and leaves the verdict to the
  /// calls that can actually tell.
  Future<void> _loadClientCount() async {
    try {
      final commercialId = await _currentUserId();
      final clients = commercialId.isEmpty
          ? await _authService.getMyClients()
          : await _authService.getClientsByCommercialId(commercialId);

      clientCount.value = clients.length;
    } catch (_) {
      clientCount.value = 0;
      hasClientError.value = true;
    }
  }

  /// Orders that are through the door but not yet delivered — the figure a
  /// commercial is actually answerable for.
  int get ordersInFlight =>
      ordersEnAttente.value + ordersEnPreparation.value + ordersExpediees.value;

  Future<String> _currentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final connected = (prefs.getString('connected_user_id') ?? '').trim();
    if (connected.isNotEmpty) {
      return connected;
    }
    return (prefs.getString('user_id') ?? '').trim();
  }
}

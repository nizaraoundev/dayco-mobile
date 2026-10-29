import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/commercial_stock_models.dart';
import '../../data/services/commercial_stock_service.dart';
import '../../data/services/stock_marque_index.dart';

class CommercialStockController extends GetxController
    with WidgetsBindingObserver {
  final CommercialStockService _stockService = CommercialStockService();
  final StockMarqueIndexStore _marqueStore = const StockMarqueIndexStore();

  /// Starts the stock loading before anybody asks for it.
  ///
  /// Called from the home screen, once a session exists: the stock page is one
  /// tap away and its first load is a round trip, so it is paid for here,
  /// behind the map, instead of in front of a commercial who has just opened
  /// the screen. The controller is permanent, so the rows pulled now are the
  /// rows that page shows — there is no second request.
  ///
  /// Safe to call repeatedly: an already-loaded controller is only asked
  /// whether what it holds has gone stale, which usually costs nothing.
  static void warmUp() {
    if (Get.isRegistered<CommercialStockController>()) {
      unawaited(Get.find<CommercialStockController>().ensureLoaded());
      return;
    }

    // Registering it is what starts the load: onInit does the rest.
    Get.put(CommercialStockController(), permanent: true);
  }

  static const int pageSize = 20;

  /// Rows a screen holds, until the page has measured itself and said so.
  static const int defaultDisplayCapacity = 8;

  /// Pages one filtered search may walk before it stops of its own accord.
  ///
  /// This is a runaway guard, not a decision point: at [pageSize] rows a
  /// page that is 6 000 references, comfortably past any filter worth waiting
  /// for, and it exists so that a backend reporting a page count it cannot
  /// honour — or a filter that matches nothing in a catalogue that has grown
  /// far beyond this — cannot spend a commercial's connection without end.
  /// Reaching it is reported like any other interrupted search, and asking to
  /// carry on grants a fresh budget, so it can delay a search but never block
  /// one. Raise it if the catalogue outgrows it.
  static const int maxPagesPerFilterSearch = 300;

  final RxList<CommercialStockItem> stocks = <CommercialStockItem>[].obs;
  final RxList<CommercialPendingReservation> reservations =
      <CommercialPendingReservation>[].obs;

  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool isLoadingReservations = false.obs;
  final RxBool hasMore = true.obs;

  /// Whether pages are being pulled in on their own to fill a filtered page,
  /// as opposed to a page the user asked for by scrolling. The list says so
  /// instead of looking empty or finished while the search is still running.
  final RxBool isFillingFilter = false.obs;

  /// Set when the search stopped short of filling the screen while pages
  /// were still unread — which now only happens when a load failed, since
  /// nothing else ends it early. The list then offers to pick it back up.
  final RxBool isFilterSearchPaused = false.obs;

  final RxString searchQuery = ''.obs;
  final RxString warehouseFilter = ''.obs;

  /// Level the list is narrowed to, or null for every level. The backend has
  /// no status parameter, so this one is applied to the pages already loaded.
  final Rx<StockLevel?> levelFilter = Rx<StockLevel?>(null);

  /// Marque the list is narrowed to — "DAYCO", "REMSA" — or null for all.
  ///
  /// Client-side for the same reason as [levelFilter]: `/stocks/admin/all`
  /// takes only `page`, `size`, `search` and `entrepot`, so there is no brand
  /// parameter to ask the backend for. The text search stays server-side, so
  /// typing with a marque picked searches *within* that marque: the backend
  /// narrows by the words, this narrows by the manufacturer, and
  /// [_ensureVisibleTarget] pulls as many pages as a screenful of matches
  /// takes.
  final RxnString brandFilter = RxnString();

  /// Warehouses seen in the loaded pages, offered as shortcuts in the picker.
  final RxList<String> knownWarehouses = <String>[].obs;

  /// Every marque the catalogue carries, as far as it is known.
  ///
  /// Two things fill this list. The rows of any page that lands contribute
  /// their own marque, as they always did; and a background sweep
  /// ([ensureMarqueIndex]) reads the catalogue end to end once a day and
  /// writes what it found to [StockMarqueIndex], which is read back into this
  /// list on launch. So the filter offers the whole list from the first time
  /// it is opened rather than only the marques of the twenty rows on screen —
  /// this backend has no marque endpoint to ask, and a sweep that is kept is
  /// the nearest honest thing to one.
  final RxList<String> knownBrands = <String>[].obs;

  /// Whether the catalogue-wide marque sweep is running right now.
  final RxBool isBuildingMarqueIndex = false.obs;

  /// Whether the marque list in hand reached the end of the catalogue. False
  /// means it is a partial list — still worth offering, not worth presenting
  /// as everything STDP carries.
  final RxBool isMarqueIndexComplete = false.obs;

  /// Sweep progress, for the one line in the picker that explains the wait.
  final RxInt marqueScanPagesRead = 0.obs;
  final RxInt marqueScanTotalPages = 0.obs;

  /// Total the backend reports for the current search, across all pages.
  final RxInt totalElements = 0.obs;
  final RxnString errorMessage = RxnString();
  final RxnString reservationError = RxnString();

  /// Set when the backend refused the call rather than failing to answer, so
  /// the screen can offer a sign-in instead of a pointless retry.
  final RxBool isAuthError = false.obs;

  /// When the rows in hand were last pulled from the backend.
  ///
  /// Null until the first page lands. Only a full reload sets it — paging
  /// deeper into the same result set does not make the first page any newer.
  final Rxn<DateTime> lastLoadedAt = Rxn<DateTime>();

  /// A reload running underneath rows that are already on screen.
  ///
  /// Distinct from [isLoading], which blanks the list for a skeleton: coming
  /// back to this page must show the last stock immediately, so the refresh
  /// that follows has to be visible without being in the way.
  final RxBool isBackgroundRefreshing = false.obs;

  /// Set when a background reload failed. The rows stay — they are the last
  /// good answer — but the screen says they are older than they should be
  /// rather than passing them off as current.
  final RxBool isBackgroundRefreshStale = false.obs;

  /// How long a load stays good enough to show without going back to the
  /// backend. Returning to the page inside this window costs nothing.
  static const Duration freshnessWindow = Duration(minutes: 10);

  /// How often the controller looks, by itself, at whether the stock it holds
  /// has aged out — so that a commercial who left the page an hour ago and
  /// comes back finds today's figures instead of a reload.
  static const Duration autoRefreshInterval = Duration(minutes: 10);

  /// Rows the marque sweep asks for at a time.
  ///
  /// Deliberately larger than [pageSize]: the sweep is read once in the
  /// background and only the manufacturer names are kept, so a few big
  /// requests cost the commercial's connection far less than many small ones.
  static const int marqueScanPageSize = 100;

  /// Pages one sweep may read before it stops and calls the list partial.
  /// A runaway guard on the same footing as [maxPagesPerFilterSearch]: it
  /// bounds what a background task can spend if the backend ignores
  /// [marqueScanPageSize] or the catalogue has grown past all expectation.
  static const int maxMarqueScanPages = 200;

  /// How long a complete marque list is trusted before it is swept for again.
  /// Marques appear and disappear from a catalogue over months, not minutes,
  /// and a sweep is the most expensive thing this controller does.
  static const Duration marqueIndexFreshness = Duration(days: 7);

  /// Whether the list has been scrolled far enough to be worth a way back up.
  final RxBool showScrollToTop = false.obs;

  final Rxn<CommercialStockItem> selectedStock = Rxn<CommercialStockItem>();

  final ScrollController scrollController = ScrollController();

  int _currentPage = 0;
  int _totalPages = 1;

  /// Rows the screen can show at once, as the page measures it.
  int _displayCapacity = defaultDisplayCapacity;

  /// How many matching rows the list is currently trying to hold.
  ///
  /// The backend has no level parameter, so a filter is applied to the pages
  /// already loaded — and a screen worth of matches can easily sit behind
  /// pages nobody has asked for yet. A filter therefore asks for a full
  /// screen of matches and [_ensureVisibleTarget] keeps pulling pages until
  /// it has them or the backend runs out: a half-filled screen with pages
  /// left unread is not an answer to show anybody. Each scroll to the bottom
  /// then asks for one page more.
  int _visibleTarget = defaultDisplayCapacity;
  bool _isFillingFilter = false;
  bool _fillRequested = false;

  /// Pages this search has walked, against [maxPagesPerFilterSearch]. Reset
  /// whenever the search itself changes, and whenever the user asks for more.
  int _pagesWalked = 0;

  /// Set when there is no longer anybody to fill a screen for — the page was
  /// left. The loop checks it between pages and gives up quietly.
  bool _fillCancelled = false;

  /// Set once the controller is disposed of, so a loop waiting on a page
  /// cannot come back to life afterwards.
  bool _isClosed = false;

  /// Bumped whenever a fresh search supersedes what is in flight, so a page
  /// that arrives late cannot append itself to results it does not belong to.
  int _generation = 0;

  Worker? _searchWorker;
  Worker? _warehouseWorker;

  Timer? _autoRefreshTimer;

  /// Whether the stock list is on screen, as the page itself reports it.
  ///
  /// What it guards is the unasked-for reload: [refreshInBackground] rewinds
  /// to the first page, and pulling the rows out from under somebody who has
  /// scrolled into page five would be far worse than showing them stock that
  /// is ten minutes old.
  bool _pageIsOpen = false;

  bool _marqueSweepRunning = false;

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

    // Watched so that coming back to the app after a while reloads stock that
    // has gone stale, rather than showing yesterday's figures until somebody
    // thinks to pull the list down.
    WidgetsBinding.instance.addObserver(this);

    // The marque list from the last sweep, so the filter is complete from the
    // first time it is opened. Not awaited: the first page of stock matters
    // more than the picker, and neither waits on the other.
    unawaited(_restoreMarqueIndex());
    unawaited(_loadThenSweep());

    _autoRefreshTimer = Timer.periodic(
      autoRefreshInterval,
      (_) => unawaited(_autoRefresh()),
    );
  }

  @override
  void onClose() {
    _isClosed = true;
    cancelFilling();
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _searchWorker?.dispose();
    _warehouseWorker?.dispose();
    scrollController.dispose();
    super.onClose();
  }

  /// The first load, and then the sweep behind it.
  ///
  /// In that order on purpose: the sweep reads the whole catalogue and the
  /// commercial is waiting for the first twenty rows of it.
  Future<void> _loadThenSweep() async {
    await refreshStocks();
    await ensureMarqueIndex();
  }

  /// Told by the page that it is on screen.
  void attachPage() {
    _pageIsOpen = true;
    // A sweep that was abandoned on the way out is picked up again; one that
    // finished costs nothing to ask about.
    unawaited(ensureMarqueIndex());
  }

  /// Told by the page that it has gone. What is loaded stays, for the next
  /// visit; the searches that were filling the screen stop, because there is
  /// no longer a screen to fill.
  void detachPage() {
    _pageIsOpen = false;
    cancelFilling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      unawaited(_autoRefresh());
    }
  }

  /// A reload nobody asked for, which is why it is so hedged about: only when
  /// the rows have genuinely aged out, only when nothing else is loading, only
  /// when there is a connection to spend, and never underneath a list somebody
  /// has scrolled through.
  Future<void> _autoRefresh() async {
    if (_isClosed || !isStale) {
      return;
    }
    if (isLoading.value || isLoadingMore.value || isBackgroundRefreshing.value) {
      return;
    }
    if (_pageIsOpen && stocks.length > pageSize) {
      return;
    }
    if (!await _hasConnection()) {
      return;
    }

    await refreshInBackground();
  }

  /// Whether the device thinks it has a connection.
  ///
  /// Asked of the platform rather than of the backend, so it costs nothing.
  /// A plugin that will not answer is no reason to skip the work: we try, and
  /// a failed request is handled like any other.
  Future<bool> _hasConnection() async {
    final results = await _connectionTypes();
    return results.any((result) => result != ConnectivityResult.none);
  }

  /// What the device is connected by, or a single "assume mobile" answer when
  /// the plugin will not say. Assuming the expensive case is the safe way
  /// round: it never spends data the user did not expect, and the work that
  /// matters — loading stock — does not depend on this.
  Future<List<ConnectivityResult>> _connectionTypes() async {
    try {
      return await Connectivity().checkConnectivity();
    } catch (error) {
      debugPrint('Connectivity unavailable, assuming mobile: $error');
      return const [ConnectivityResult.mobile];
    }
  }

  void setSearchQuery(String value) {
    searchQuery.value = value;
  }

  void setWarehouseFilter(String value) {
    warehouseFilter.value = value;
  }

  void setLevelFilter(StockLevel? level) {
    if (levelFilter.value == level) {
      return;
    }

    levelFilter.value = level;
    _restartRowFilterSearch();
  }

  /// Narrows the list to one marque, or to all of them with null.
  void setBrandFilter(String? brand) {
    final cleaned = brand?.trim();
    final next = (cleaned == null || cleaned.isEmpty) ? null : cleaned;

    if (brandFilter.value == next) {
      return;
    }

    brandFilter.value = next;
    _restartRowFilterSearch();
  }

  /// A new filter starts its own count: a screen of matches, pulled from as
  /// many backend pages as that takes. The loop re-reads the filters as it
  /// goes, so this redirects a search already running rather than racing it
  /// — and clearing a filter satisfies any target at once, which stops it.
  void _restartRowFilterSearch() {
    _visibleTarget = _displayCapacity;
    _pagesWalked = 0;
    _fillCancelled = false;
    _ensureVisibleTarget();
  }

  /// The rows the list shows: [stocks] narrowed by [levelFilter] and
  /// [brandFilter]. Reading it inside an Obx tracks all three, so the list
  /// rebuilds on any of them changing.
  List<CommercialStockItem> get visibleStocks {
    final level = levelFilter.value;
    final brand = brandFilter.value;

    if (level == null && brand == null) {
      return stocks;
    }

    return stocks.where((stock) {
      if (level != null && stock.level != level) {
        return false;
      }
      if (brand != null && !_matchesBrand(stock, brand)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Whether anything is narrowing the loaded rows.
  ///
  /// What matters to the fill loop is that matches are being *searched for*
  /// across pages, which is true of either filter — the backend applies
  /// neither.
  bool get hasRowFilter => levelFilter.value != null || brandFilter.value != null;

  /// Case- and whitespace-insensitive: the backend has returned the same
  /// manufacturer as "DAYCO", "Dayco" and " dayco ", and a commercial
  /// picking a marque off a chip means all three.
  static bool _matchesBrand(CommercialStockItem stock, String brand) {
    return stock.fabricant.trim().toUpperCase() == brand.trim().toUpperCase();
  }

  /// How many rows have been pulled from the backend to produce the matches on
  /// screen. Worth showing while a filter is active: "12 matches out of 180
  /// scanned" is the honest reading of a filtered list.
  int get scannedCount => stocks.length;

  Future<void> refreshStocks() async {
    _currentPage = 0;
    _totalPages = 1;
    _visibleTarget = _displayCapacity;
    _pagesWalked = 0;
    _fillCancelled = false;
    hasMore.value = true;
    isFilterSearchPaused.value = false;
    errorMessage.value = null;
    isAuthError.value = false;

    await _loadPage(reset: true);
    await _ensureVisibleTarget();
  }

  /// Drops everything held for the signed-in representative.
  ///
  /// The controller outlives the page so that coming back is instant; it must
  /// not outlive the *session*, or the next person to sign in on this device
  /// would be shown the previous one's stock and marques as though they were
  /// freshly loaded.
  void clearCache() {
    cancelFilling();
    _generation += 1;
    stocks.clear();
    reservations.clear();
    knownWarehouses.clear();
    knownBrands.clear();
    // The marques go back to the stored index rather than to nothing: the
    // catalogue's manufacturer list is not the departing user's data, and the
    // next person to sign in should find the filter working immediately.
    unawaited(_restoreMarqueIndex());
    selectedStock.value = null;
    lastLoadedAt.value = null;
    isBackgroundRefreshStale.value = false;
    isBackgroundRefreshing.value = false;
    searchQuery.value = '';
    warehouseFilter.value = '';
    levelFilter.value = null;
    brandFilter.value = null;
    totalElements.value = 0;
    errorMessage.value = null;
    reservationError.value = null;
    isAuthError.value = false;
    _currentPage = 0;
    _totalPages = 1;
    hasMore.value = true;
  }

  /// Whether the rows in hand have aged past [freshnessWindow].
  bool get isStale {
    final loadedAt = lastLoadedAt.value;
    if (loadedAt == null) {
      return true;
    }
    return DateTime.now().difference(loadedAt) >= freshnessWindow;
  }

  /// What the page calls every time it is opened.
  ///
  /// The point is that coming back is never a wait: whatever was loaded last
  /// is already on screen, and this only decides what to do behind it.
  ///   * nothing loaded yet — load, with the skeleton, because there is
  ///     genuinely nothing to show;
  ///   * loaded within [freshnessWindow] — do nothing at all, no request;
  ///   * older than that — reload underneath the rows, which stay readable
  ///     and get replaced when the answer lands.
  /// The manual refresh is untouched and always forces a reload.
  Future<void> ensureLoaded() async {
    if (_isClosed) {
      return;
    }

    // A load is already answering this question.
    if (isLoading.value || isBackgroundRefreshing.value) {
      return;
    }

    // The search was stopped on the way out; the screen is back for it.
    resumeFilling();

    if (stocks.isEmpty) {
      await refreshStocks();
      return;
    }

    if (isStale) {
      await refreshInBackground();
    }
  }

  /// Reloads the first page without disturbing what is on screen.
  ///
  /// Deliberately not written as `refreshStocks()` with a flag: that one
  /// resets the paging cursor *before* it fetches, so a failure would leave
  /// the old rows sitting under a cursor that had been rewound — and the next
  /// scroll would append page 1 to rows that already contained it. Here
  /// nothing is committed until the response is in hand, so a failed refresh
  /// leaves the list exactly as it was, merely marked stale.
  Future<void> refreshInBackground() async {
    if (_isClosed ||
        isLoading.value ||
        isLoadingMore.value ||
        isBackgroundRefreshing.value) {
      return;
    }

    isBackgroundRefreshing.value = true;
    // Supersedes anything in flight: those pages belong to the result set
    // this call is about to replace.
    final generation = ++_generation;

    var committed = false;

    try {
      final response = await _stockService.getStocksAdminAll(
        page: 0,
        size: pageSize,
        search: searchQuery.value,
        entrepot: warehouseFilter.value,
      );

      if (generation != _generation || _isClosed) {
        return;
      }

      _currentPage = 0;
      _totalPages = response.totalPages;
      totalElements.value = response.totalElements;
      _collectWarehouses(response.content);
      _collectBrands(response.content);
      stocks.assignAll(response.content);

      hasMore.value = response.totalPages > 1;
      lastLoadedAt.value = DateTime.now();
      isBackgroundRefreshStale.value = false;
      errorMessage.value = null;
      isAuthError.value = false;

      _visibleTarget = _displayCapacity;
      _pagesWalked = 0;
      _fillCancelled = false;
      isFilterSearchPaused.value = false;
      committed = true;
    } catch (e) {
      if (generation != _generation || _isClosed) {
        return;
      }

      // The rows stay: they are the last good answer, and emptying the screen
      // over a refresh the user never asked for would be worse than showing
      // stock that is ten minutes old. The page says it is stale instead.
      isBackgroundRefreshStale.value = true;
      isAuthError.value = e is CommercialStockAuthException;
    } finally {
      isBackgroundRefreshing.value = false;
    }

    if (committed) {
      await _ensureVisibleTarget();
    }
  }

  /// Told by the page how many rows it has to fill. A taller screen — a
  /// tablet, or a phone turned on its side — needs more matches before a
  /// filtered list is worth looking at, and a search already running is sent
  /// back for them.
  void setDisplayCapacity(int rows) {
    final capacity = rows < 1 ? 1 : rows;
    if (capacity == _displayCapacity) {
      return;
    }

    _displayCapacity = capacity;

    if (_visibleTarget < capacity) {
      _visibleTarget = capacity;
      _ensureVisibleTarget();
    }
  }

  /// Stops the search without touching what is already loaded: the page has
  /// been left, so there is no screen left to fill.
  ///
  /// A request already in flight is left to land. It belongs to this same
  /// search, costs nothing more, and is already paid for — it will be waiting
  /// if the user comes back.
  void cancelFilling() {
    _fillCancelled = true;
    _fillRequested = false;
    isFillingFilter.value = false;
  }

  /// Picks the search up again when the page is shown once more, for a filter
  /// that never managed to fill it.
  void resumeFilling() {
    _fillCancelled = false;
    _ensureVisibleTarget();
  }

  /// Pulls pages until the list holds [_visibleTarget] matching rows, the
  /// backend runs out of pages, the page is left, or a load fails.
  ///
  /// Conditions are re-read on every turn of the loop, so changing the filter
  /// mid-flight redirects it and clearing the filter — which satisfies any
  /// target at once — stops it, instead of spending a user's data on pages
  /// nobody is waiting for any more.
  Future<void> _ensureVisibleTarget() async {
    if (_isClosed) {
      return;
    }

    // A loop already running reads the target as it goes, so it picks up a new
    // one rather than letting a second loop race it for pages. The flag is
    // what lets it know the state changed under it while it was waiting on a
    // page — a refresh, typically — and that it has to look again before it
    // gives up.
    _fillRequested = true;
    isFilterSearchPaused.value = false;

    if (_isFillingFilter) {
      return;
    }

    _isFillingFilter = true;

    try {
      while (_fillRequested && !_fillCancelled && !_isClosed) {
        _fillRequested = false;

        // Every condition is re-read on each turn: the target, the filter
        // behind it, whether the backend has pages left, and whether anybody
        // is still watching. One page is in flight at a time, awaited, so the
        // loop never blocks the app — it just keeps asking.
        while (hasMore.value &&
            visibleStocks.length < _visibleTarget &&
            _pagesWalked < maxPagesPerFilterSearch &&
            !_fillCancelled &&
            !_isClosed) {
          // Only a filtered list is being *searched* through; without one the
          // footer spinner already says everything there is to say.
          isFillingFilter.value = hasRowFilter;

          final loaded = await loadNextPage();
          if (!loaded) {
            // Out of pages, a load already in flight, or a refused call:
            // either way, looping again would only hammer the backend.
            break;
          }

          _pagesWalked += 1;
        }
      }
    } finally {
      _isFillingFilter = false;
      isFillingFilter.value = false;
      // Short of a full screen with pages still unread, and not because
      // anybody asked it to stop: a load failed or the budget above ran out.
      // Either way the list says so rather than passing off what it has as
      // the whole answer.
      isFilterSearchPaused.value =
          !_fillCancelled &&
          !_isClosed &&
          hasMore.value &&
          visibleStocks.length < _visibleTarget;
    }
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
        throw Exception('Produit introuvable pour ${stock.referenceProduit}.');
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

  /// Loads one page. Returns whether rows for the current search landed, which
  /// is what tells the fill loop above whether it is worth asking again.
  Future<bool> _loadPage({required bool reset}) async {
    if (reset) {
      // A fresh search supersedes whatever is in flight rather than being
      // dropped by it: waiting out an auto-fill would leave the user typing
      // into a list that never answered.
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
      final response = await _stockService.getStocksAdminAll(
        page: _currentPage,
        size: pageSize,
        search: searchQuery.value,
        entrepot: warehouseFilter.value,
      );

      if (generation != _generation) {
        return false;
      }

      _totalPages = response.totalPages;
      totalElements.value = response.totalElements;
      _collectWarehouses(response.content);
      _collectBrands(response.content);

      if (reset) {
        stocks.assignAll(response.content);
        // Only a full reload makes the rows new; paging deeper does not.
        lastLoadedAt.value = DateTime.now();
        isBackgroundRefreshStale.value = false;
      } else {
        stocks.addAll(response.content);
      }

      hasMore.value = (_currentPage + 1) < _totalPages;
      if (_totalPages == 0) {
        hasMore.value = false;
      }

      errorMessage.value = null;
      isAuthError.value = false;
      return true;
    } catch (e) {
      if (generation != _generation) {
        return false;
      }

      isAuthError.value = e is CommercialStockAuthException;
      errorMessage.value = e.toString().replaceFirst('Exception: ', '');

      if (reset) {
        // The rows on screen answered the request that just failed; leaving
        // them would show stale prices under a new search.
        stocks.clear();
      }
      return false;
    } finally {
      if (generation == _generation) {
        isLoading.value = false;
        isLoadingMore.value = false;
      }
    }
  }

  /// Builds up the warehouse shortcut list as pages arrive. The list
  /// endpoint returns no warehouse inventory, so the only names we can offer
  /// are the ones the rows themselves carry.
  void _collectWarehouses(List<CommercialStockItem> items) {
    var added = false;
    for (final item in items) {
      final warehouse = item.entrepot?.trim() ?? '';
      if (warehouse.isNotEmpty && !knownWarehouses.contains(warehouse)) {
        knownWarehouses.add(warehouse);
        added = true;
      }
    }
    if (added) {
      knownWarehouses.sort();
    }
  }

  /// Adds the marques carried by these rows to [knownBrands].
  ///
  /// Every page that lands feeds this, whichever request fetched it — a
  /// search, a scroll, or the sweep below. Kept in the spelling the backend
  /// sent, deduplicated case-insensitively so "Dayco" and "DAYCO" do not both
  /// end up on the picker.
  void _collectBrands(List<CommercialStockItem> items) {
    var added = false;
    for (final item in items) {
      final brand = item.fabricant.trim();
      if (brand.isEmpty || brand == '-') {
        continue;
      }
      final alreadyKnown = knownBrands.any(
        (known) => known.toUpperCase() == brand.toUpperCase(),
      );
      if (!alreadyKnown) {
        knownBrands.add(brand);
        added = true;
      }
    }
    if (added) {
      knownBrands.sort((a, b) => a.toUpperCase().compareTo(b.toUpperCase()));
    }
  }

  /// Seeds [knownBrands] from the last sweep.
  ///
  /// Additive, never destructive: whatever the loaded rows have already
  /// contributed stays, because it is at least as current as what was written
  /// down. A marque that has since left the catalogue is the cost of the
  /// cache, and the next sweep is what settles it.
  Future<void> _restoreMarqueIndex() async {
    final index = await _marqueStore.read();
    if (_isClosed || index.isEmpty) {
      return;
    }

    _mergeMarques(index.marques);
    isMarqueIndexComplete.value = index.isComplete;
    marqueScanPagesRead.value = index.pagesRead;
    marqueScanTotalPages.value = index.totalPages;
  }

  void _mergeMarques(List<String> marques) {
    var added = false;
    for (final marque in marques) {
      final cleaned = marque.trim();
      if (cleaned.isEmpty) {
        continue;
      }
      final alreadyKnown = knownBrands.any(
        (known) => known.toUpperCase() == cleaned.toUpperCase(),
      );
      if (!alreadyKnown) {
        knownBrands.add(cleaned);
        added = true;
      }
    }
    if (added) {
      knownBrands.sort((a, b) => a.toUpperCase().compareTo(b.toUpperCase()));
    }
  }

  /// Builds the catalogue-wide marque list, if the one in hand will not do.
  ///
  /// What it costs is what decides when it runs. With no list at all the
  /// filter does not work, so the sweep goes ahead on whatever connection
  /// there is. With a list already in hand it is only a refresh of something
  /// that still works, so it waits for Wi-Fi rather than spending a
  /// commercial's mobile data re-reading a catalogue that rarely changes.
  ///
  /// [force] is the picker's own retry: the user asked, so neither the
  /// freshness window nor the Wi-Fi condition applies.
  Future<void> ensureMarqueIndex({bool force = false}) async {
    if (_isClosed || _marqueSweepRunning) {
      return;
    }

    var needsWifi = false;

    if (!force) {
      final index = await _marqueStore.read();
      if (!index.isEmpty) {
        if (!index.isStale(marqueIndexFreshness)) {
          return;
        }
        needsWifi = true;
      }
    }

    final connection = await _connectionTypes();
    final isOnline = connection.any((type) => type != ConnectivityResult.none);
    if (!isOnline) {
      return;
    }

    final isUnmetered = connection.any(
      (type) =>
          type == ConnectivityResult.wifi || type == ConnectivityResult.ethernet,
    );
    if (needsWifi && !isUnmetered) {
      return;
    }

    await _sweepMarques();
  }

  /// Reads the catalogue end to end, keeping only the marques.
  ///
  /// Unfiltered on purpose — the point is every marque from the first page to
  /// the last, not the marques of whatever the user is currently searching
  /// for. It yields between pages and steps aside whenever a request the user
  /// is actually waiting for is in flight, so a background sweep cannot make
  /// the list in front of them feel slow. Progress is written down as it goes,
  /// so a sweep cut short by the app closing still leaves its marques behind.
  Future<void> _sweepMarques() async {
    _marqueSweepRunning = true;
    isBuildingMarqueIndex.value = true;
    marqueScanPagesRead.value = 0;

    var page = 0;
    var totalPages = 1;
    var reachedEnd = false;
    // Turns spent waiting for a user-driven load to finish, so a page that
    // never lands cannot leave this loop spinning for ever.
    var waits = 0;

    try {
      while (page < totalPages && page < maxMarqueScanPages && !_isClosed) {
        // The commercial's own request comes first.
        if (isLoading.value || isLoadingMore.value) {
          if (waits >= 50) {
            break;
          }
          waits += 1;
          await Future<void>.delayed(const Duration(milliseconds: 400));
          continue;
        }

        final response = await _stockService.getStocksAdminAll(
          page: page,
          size: marqueScanPageSize,
        );

        if (_isClosed) {
          return;
        }

        totalPages = response.totalPages;
        page += 1;
        reachedEnd = page >= totalPages;

        _collectBrands(response.content);
        marqueScanPagesRead.value = page;
        marqueScanTotalPages.value = totalPages;

        await _marqueStore.write(
          StockMarqueIndex(
            marques: List<String>.from(knownBrands),
            isComplete: reachedEnd,
            pagesRead: page,
            totalPages: totalPages,
            builtAt: DateTime.now(),
          ),
        );

        if (reachedEnd) {
          break;
        }

        // A breath between pages: this is a background sweep, and the
        // connection belongs to whatever the user is doing with it.
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }

      if (!_isClosed) {
        isMarqueIndexComplete.value = reachedEnd;
      }

      debugPrint(
        'Marque sweep: ${knownBrands.length} marques, '
        '$page/$totalPages pages of $marqueScanPageSize, '
        'complete=$reachedEnd',
      );
    } catch (error) {
      // The marques collected so far are already saved, and the filter works
      // with a partial list. Nothing is shown to the user over this: they did
      // not ask for the sweep, and the picker says the list is partial.
      debugPrint('Marque sweep stopped at page $page: $error');
      if (!_isClosed) {
        isMarqueIndexComplete.value = false;
      }
    } finally {
      _marqueSweepRunning = false;
      isBuildingMarqueIndex.value = false;
    }
  }

  /// Loads the page after the last one in hand. Returns whether it landed, and
  /// gives the page number back on failure so a retry does not skip a page.
  Future<bool> loadNextPage() async {
    if (!hasMore.value || isLoading.value || isLoadingMore.value) {
      return false;
    }

    _currentPage += 1;
    final loaded = await _loadPage(reset: false);

    if (!loaded) {
      _currentPage -= 1;
    }

    return loaded;
  }

  /// Asks for one more page worth of rows than the list holds now, filter
  /// included: with a filter on, that may take several backend pages, which
  /// [_ensureVisibleTarget] pulls in one after another.
  void loadMore() {
    if (_isFillingFilter || isLoading.value || isLoadingMore.value) {
      return;
    }

    _pagesWalked = 0;
    _fillCancelled = false;
    _visibleTarget = visibleStocks.length + pageSize;
    _ensureVisibleTarget();
  }

  void _onScroll() {
    if (!scrollController.hasClients) {
      return;
    }

    final max = scrollController.position.maxScrollExtent;
    final current = scrollController.position.pixels;

    if (current >= (max - 250)) {
      loadMore();
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

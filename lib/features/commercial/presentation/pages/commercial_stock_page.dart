import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/commercial_stock_models.dart';
import '../controllers/commercial_stock_controller.dart';
import '../widgets/stock_palette.dart';
import '../../../../core/shared/widget/app_bar/dayco_app_bar.dart';

class CommercialStockPage extends StatefulWidget {
  const CommercialStockPage({super.key});

  @override
  State<CommercialStockPage> createState() => _CommercialStockPageState();
}

class _CommercialStockPageState extends State<CommercialStockPage> {
  /// Height one row takes, near enough to count how many fit. A row is about
  /// 122dp, a little more with an arrivage note; rounding up and adding one
  /// errs towards filling the screen rather than leaving a gap under the last
  /// match.
  static const double _estimatedRowExtent = 130;

  late final CommercialStockController controller;
  late final TextEditingController searchController;
  late final TextEditingController warehouseController;

  /// Last capacity handed to the controller, so an unchanged measurement is
  /// not reported again on every rebuild.
  int? _reportedCapacity;

  @override
  void initState() {
    super.initState();
    final isReturning = Get.isRegistered<CommercialStockController>();
    controller = isReturning
        ? Get.find<CommercialStockController>()
        // Permanent so the rows survive leaving this page; see the binding.
        // Reaching this branch means the warm-up from the home screen never
        // ran, so this is the first load rather than the usual case.
        : Get.put(CommercialStockController(), permanent: true);

    controller.attachPage();

    // Whether arriving for the first time or coming back, the controller
    // decides: show what it already has, and reload behind it only if that
    // has gone stale. Deferred to after the first frame because it writes
    // observables that the list below is about to start reading.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        controller.ensureLoaded();
      }
    });

    searchController = TextEditingController(
      text: controller.searchQuery.value,
    );
    warehouseController = TextEditingController(
      text: controller.warehouseFilter.value,
    );
  }

  @override
  void dispose() {
    // Leaving the page ends its search: nothing is left to fill a screen for,
    // and the user's connection is not ours to spend on pages nobody will
    // see. What is already loaded stays, for when they come back.
    controller.detachPage();
    searchController.dispose();
    warehouseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorManager.backgroundColor,
      appBar: DaycoAppBar(
        titleText: 'Stock Commercial',
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _reportDisplayCapacity(constraints.maxHeight);
                return _buildStockList();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Obx(() {
        if (!controller.showScrollToTop.value) {
          return const SizedBox.shrink();
        }

        return FloatingActionButton.small(
          onPressed: controller.scrollToTop,
          backgroundColor: ColorManager.primaryColor,
          foregroundColor: ColorManager.white,
          tooltip: 'Revenir en haut',
          child: const Icon(Icons.arrow_upward),
        );
      }),
    );
  }

  /// Tells the controller how many rows fit, after the frame rather than
  /// during it: [CommercialStockController.setDisplayCapacity] can start a
  /// search, and starting one mid-layout would write to observables the list
  /// around us is in the middle of reading.
  void _reportDisplayCapacity(double availableHeight) {
    if (!availableHeight.isFinite || availableHeight <= 0) {
      return;
    }

    final capacity = (availableHeight / _estimatedRowExtent).ceil() + 1;
    if (capacity == _reportedCapacity) {
      return;
    }

    _reportedCapacity = capacity;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        controller.setDisplayCapacity(capacity);
      }
    });
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: const BoxDecoration(
        color: ColorManager.cardColor,
        boxShadow: [
          BoxShadow(
            color: ColorManager.lightShadowColor,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: searchController,
            builder: (context, value, _) {
              return TextField(
                controller: searchController,
                onChanged: controller.setSearchQuery,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Rechercher référence / produit / fabricant',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: value.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            searchController.clear();
                            controller.setSearchQuery('');
                          },
                          icon: const Icon(Icons.close),
                          tooltip: 'Effacer la recherche',
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Obx(() {
              final selected = controller.levelFilter.value;
              return Row(
                children: [
                  _buildLevelChip('Tous', null, selected),
                  const SizedBox(width: 8),
                  _buildLevelChip('En stock', StockLevel.inStock, selected),
                  const SizedBox(width: 8),
                  _buildLevelChip('Stock faible', StockLevel.low, selected),
                  const SizedBox(width: 8),
                  _buildLevelChip('En arrivage', StockLevel.incoming, selected),
                  const SizedBox(width: 8),
                  _buildLevelChip('Hors stock', StockLevel.out, selected),
                  const SizedBox(width: 8),
                  _buildBrandChip(),
                  const SizedBox(width: 8),
                  _buildWarehouseChip(),
                ],
              );
            }),
          ),
          const SizedBox(height: 8),
          // With a filter on, the honest reading is "matches found, out of the
          // catalogue walked so far" — the old "x sur y chargés" said nothing
          // about whether more was still coming.
          Obx(() {
            final shown = controller.visibleStocks.length;
            final scanned = controller.scannedCount;
            final total = controller.totalElements.value;
            final level = controller.levelFilter.value;
            final brand = controller.brandFilter.value;

            final String label;
            if (level != null || brand != null) {
              final progress = total > 0
                  ? '$scanned/$total analysés'
                  : '$scanned analysés';
              // Name what is actually narrowing the list, so "14 trouvés" is
              // never ambiguous between a level and a marque.
              final what = [
                if (brand != null) brand,
                if (level != null) StockPalette.labelFor(level).toLowerCase(),
              ].join(' · ');
              label = controller.isFillingFilter.value
                  ? '$shown trouvés · recherche en cours ($progress)'
                  : '$shown $what · $progress';
            } else if (total > 0) {
              label = '$shown sur $total produits';
            } else {
              label = '$shown produits';
            }

            return Row(
              children: [
                if (controller.isFillingFilter.value) ...[
                  const SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(strokeWidth: 1.6),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: ColorManager.textSecondary,
                    ),
                  ),
                ),
              ],
            );
          }),
          _buildFreshnessLine(),
        ],
      ),
    );
  }

  /// Says how old the rows are, and what is being done about it.
  ///
  /// Returning to this page shows the last stock immediately, so the one
  /// thing the user cannot otherwise tell is *how old* that stock is. Without
  /// this line a cached list and a freshly loaded one look identical, which
  /// is exactly the ambiguity a commercial quoting a quantity cannot afford.
  Widget _buildFreshnessLine() {
    return Obx(() {
      final loadedAt = controller.lastLoadedAt.value;
      if (loadedAt == null) {
        return const SizedBox.shrink();
      }

      final refreshing = controller.isBackgroundRefreshing.value;
      final failedQuietly = controller.isBackgroundRefreshStale.value;

      final String text;
      final Color color;
      if (refreshing) {
        text = 'Mise à jour en arrière-plan…';
        color = ColorManager.textSecondary;
      } else if (failedQuietly) {
        text =
            'Hors ligne · données de ${_relativeTime(loadedAt)}, '
            'non actualisées';
        color = StockPalette.low;
      } else {
        text = 'Mis à jour ${_relativeTime(loadedAt)}';
        color = ColorManager.textSecondary;
      }

      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            if (refreshing) ...[
              const SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(strokeWidth: 1.6),
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: color),
              ),
            ),
            if (!refreshing)
              GestureDetector(
                onTap: controller.refreshStocks,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'Actualiser',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: ColorManager.primaryColor,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  /// Deliberately coarse. A commercial needs "is this current or not", and a
  /// to-the-second count would redraw this line every second to say nothing.
  static String _relativeTime(DateTime moment) {
    final elapsed = DateTime.now().difference(moment);

    if (elapsed.inSeconds < 60) {
      return "à l'instant";
    }
    if (elapsed.inMinutes < 60) {
      return 'il y a ${elapsed.inMinutes} min';
    }
    if (elapsed.inHours < 24) {
      return 'il y a ${elapsed.inHours} h';
    }
    return 'il y a ${elapsed.inDays} j';
  }

  /// One level filter. The chip wears the colour of the level it selects, so
  /// the same green / amber / red reading holds in the bar and on the cards.
  Widget _buildLevelChip(
    String label,
    StockLevel? level,
    StockLevel? selected,
  ) {
    final isSelected = level == selected;
    final color = level == null
        ? ColorManager.primaryColor
        : StockPalette.forLevel(level);

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => controller.setLevelFilter(level),
      backgroundColor: ColorManager.greybg,
      selectedColor: color.withValues(alpha: 0.14),
      shape: StadiumBorder(
        side: BorderSide(color: isSelected ? color : ColorManager.lightGrey2),
      ),
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? color : ColorManager.textSecondary,
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildBrandChip() {
    return Obx(() {
      final brand = controller.brandFilter.value;
      final isActive = brand != null;
      final color = isActive
          ? ColorManager.primaryColor
          : ColorManager.textSecondary;

      return ActionChip(
        onPressed: _showBrandPicker,
        avatar: Icon(Icons.sell_outlined, size: 16, color: color),
        label: Text(isActive ? brand : 'Marque'),
        backgroundColor: isActive
            ? ColorManager.primaryColor.withValues(alpha: 0.12)
            : ColorManager.greybg,
        shape: StadiumBorder(
          side: BorderSide(
            color: isActive
                ? ColorManager.primaryColor
                : ColorManager.lightGrey2,
          ),
        ),
        labelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          color: color,
        ),
        visualDensity: VisualDensity.compact,
      );
    });
  }

  Widget _buildWarehouseChip() {
    return Obx(() {
      final warehouse = controller.warehouseFilter.value.trim();
      final isActive = warehouse.isNotEmpty;
      final color = isActive
          ? ColorManager.primaryColor
          : ColorManager.textSecondary;

      return ActionChip(
        onPressed: _showWarehousePicker,
        avatar: Icon(Icons.warehouse_outlined, size: 16, color: color),
        label: Text(isActive ? warehouse : 'Entrepôt'),
        backgroundColor: isActive
            ? ColorManager.primaryColor.withValues(alpha: 0.12)
            : ColorManager.greybg,
        shape: StadiumBorder(
          side: BorderSide(
            color: isActive
                ? ColorManager.primaryColor
                : ColorManager.lightGrey2,
          ),
        ),
        labelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          color: color,
        ),
        visualDensity: VisualDensity.compact,
      );
    });
  }

  Widget _buildStockList() {
    return Obx(() {
      if (controller.isLoading.value && controller.stocks.isEmpty) {
        return _buildSkeletonList();
      }

      if (controller.errorMessage.value != null && controller.stocks.isEmpty) {
        return _buildErrorState();
      }

      final visible = controller.visibleStocks;
      // A page still being assembled from several backend pages keeps its
      // footer, so the list never looks like it has reached the end.
      final isFetchingMore =
          controller.isLoadingMore.value || controller.isFillingFilter.value;
      // Stopped short with pages left — a failed load — so the footer turns
      // into the way to pick the search back up.
      final isPaused =
          controller.isFilterSearchPaused.value && controller.hasMore.value;

      if (visible.isEmpty) {
        return _buildEmptyState();
      }

      return Column(
        children: [
          // A refresh keeps what is already on screen and says so with a
          // hairline, rather than blanking the list on every keystroke.
          if (controller.isLoading.value)
            const LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: controller.refreshStocks,
              child: ListView.builder(
                controller: controller.scrollController,
                padding: const EdgeInsets.all(12),
                itemCount:
                    visible.length + (isFetchingMore || isPaused ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= visible.length) {
                    return _buildListFooter();
                  }

                  final stock = visible[index];
                  return _StockCard(
                    stock: stock,
                    controller: controller,
                    onReservationsTap: () => _showReservationsSheet(stock),
                  );
                },
              ),
            ),
          ),
        ],
      );
    });
  }

  /// The footer under the last row. While a filter is being filled it also
  /// says what is happening, because a filter that matches two rows per page
  /// would otherwise look like a list that had simply stopped.
  Widget _buildListFooter() {
    final level = controller.levelFilter.value;
    final isSearching = controller.isFillingFilter.value && level != null;
    final isBusy =
        controller.isLoadingMore.value || controller.isFillingFilter.value;

    if (!isBusy) {
      // The search stopped before filling the screen, which it only does when
      // a page failed to load.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: OutlinedButton.icon(
            onPressed: controller.loadMore,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Reprendre la recherche'),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          if (isSearching) ...[
            const SizedBox(height: 10),
            Text(
              'Recherche des produits '
              '« ${StockPalette.labelFor(level).toLowerCase()} »…',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: ColorManager.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// First load shows the shape of what is coming rather than a spinner in
  /// the middle of nothing, so the screen does not lurch when rows arrive.
  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 6,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (_, __) => const _SkeletonCard(),
    );
  }

  /// Centres a state view, and lets it scroll the moment it does not fit.
  ///
  /// Nothing locks this app to portrait, so each of these has to survive a
  /// landscape phone — roughly 320dp of height, less the filter bar — and a
  /// large font setting on top of that. A plain centred Column overflows
  /// there; this one scrolls instead.
  Widget _scrollableCentre({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        );
      },
    );
  }

  /// A refused session and an unreachable backend no longer share one red
  /// screen: the cause picks the icon, the wording and what is worth trying
  /// next — and neither of them is a sign-in, of which this app has only one.
  Widget _buildErrorState() {
    final isAuthError = controller.isAuthError.value;
    final message = controller.errorMessage.value ?? 'Erreur inconnue';

    return _scrollableCentre(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isAuthError ? Icons.lock_outline : Icons.cloud_off_outlined,
                size: 44,
                color: isAuthError ? StockPalette.low : ColorManager.errorColor,
              ),
              const SizedBox(height: 12),
              Text(
                isAuthError ? 'Session expirée' : 'Stock indisponible',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: ColorManager.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: ColorManager.textSecondary,
                ),
              ),
              // There is only one session to renew, and it is not renewed from
              // here: the commercial signs in once, in the app itself.
              if (isAuthError) ...[
                const SizedBox(height: 8),
                const Text(
                  "Reconnectez-vous à l'application pour continuer.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: ColorManager.textPrimary,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: controller.refreshStocks,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Réessayer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorManager.primaryColor,
                    foregroundColor: ColorManager.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Why the list is empty decides what we offer. A level filter matching
  /// nothing is not an empty stock: later pages may still hold matches, and
  /// those are already being fetched, so the screen reports progress instead
  /// of announcing a verdict it has not reached yet.
  Widget _buildEmptyState() {
    final level = controller.levelFilter.value;
    final query = controller.searchQuery.value.trim();

    if (level != null &&
        (controller.isFillingFilter.value || controller.isLoadingMore.value)) {
      final total = controller.totalElements.value;
      final scanned = controller.scannedCount;

      return _scrollableCentre(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              const SizedBox(height: 14),
              Text(
                'Recherche des produits '
                '« ${StockPalette.labelFor(level).toLowerCase()} »…',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: ColorManager.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                total > 0
                    ? '$scanned produits analysés sur $total'
                    : '$scanned produits analysés',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: ColorManager.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (level != null && controller.stocks.isNotEmpty) {
      return _scrollableCentre(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.filter_alt_off_outlined,
                size: 42,
                color: ColorManager.textTertiary,
              ),
              const SizedBox(height: 10),
              Text(
                controller.hasMore.value
                    ? 'Recherche interrompue après '
                          '${controller.scannedCount} produits analysés, sans '
                          'résultat '
                          '« ${StockPalette.labelFor(level).toLowerCase()} ».'
                    : 'Aucun produit '
                          '« ${StockPalette.labelFor(level).toLowerCase()} » '
                          'dans le stock.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: ColorManager.textSecondary),
              ),
              const SizedBox(height: 14),
              if (controller.hasMore.value)
                ElevatedButton.icon(
                  onPressed: controller.loadMore,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reprendre la recherche'),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => controller.setLevelFilter(null),
                  icon: const Icon(Icons.close),
                  label: const Text('Retirer le filtre'),
                ),
            ],
          ),
        ),
      );
    }

    return _scrollableCentre(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 42,
              color: ColorManager.textTertiary,
            ),
            const SizedBox(height: 10),
            Text(
              query.isEmpty
                  ? 'Aucun produit dans le stock.'
                  : 'Aucun résultat pour « $query ».',
              textAlign: TextAlign.center,
              style: const TextStyle(color: ColorManager.textSecondary),
            ),
            if (query.isNotEmpty) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () {
                  searchController.clear();
                  controller.setSearchQuery('');
                },
                icon: const Icon(Icons.close),
                label: const Text('Effacer la recherche'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The warehouse filter is a backend parameter, so applying it reloads from
  /// page zero. Names already seen are offered as shortcuts; typing stays
  /// possible because the API exposes no warehouse inventory.
  Future<void> _showBrandPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ColorManager.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        void apply(String? brand) {
          controller.setBrandFilter(brand);
          Navigator.pop(sheetContext);
        }

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filtrer par marque',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'La recherche ne portera que sur la marque choisie.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: ColorManager.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Obx(() {
                    final brands = controller.knownBrands;
                    final selected = controller.brandFilter.value;

                    if (brands.isEmpty) {
                      // Either the sweep is still on its first pages or it
                      // has never managed to run — this backend has no marque
                      // endpoint, so the list is read from the catalogue.
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          controller.isBuildingMarqueIndex.value
                              ? 'Inventaire des marques du catalogue en cours…'
                              : 'Aucune marque disponible pour le moment.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: ColorManager.textSecondary,
                          ),
                        ),
                      );
                    }

                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Toutes'),
                          selected: selected == null,
                          onSelected: (_) => apply(null),
                          visualDensity: VisualDensity.compact,
                        ),
                        for (final brand in brands)
                          ChoiceChip(
                            label: Text(brand),
                            selected:
                                selected != null &&
                                selected.toUpperCase() == brand.toUpperCase(),
                            onSelected: (_) => apply(brand),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    );
                  }),
                  const SizedBox(height: 10),
                  // Where the list came from, so that a marque not on it is
                  // never left ambiguous between "not carried" and "not read
                  // yet". The sweep runs in the background; this only reports
                  // it.
                  Obx(() {
                    const style = TextStyle(
                      fontSize: 11.5,
                      color: ColorManager.textSecondary,
                    );

                    if (controller.isBuildingMarqueIndex.value) {
                      final read = controller.marqueScanPagesRead.value;
                      final total = controller.marqueScanTotalPages.value;
                      final progress = total > 0 ? ' ($read/$total pages)' : '';
                      return Row(
                        children: [
                          const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(strokeWidth: 1.6),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Lecture du catalogue en cours$progress — la '
                              'liste se complète.',
                              style: style,
                            ),
                          ),
                        ],
                      );
                    }

                    if (controller.isMarqueIndexComplete.value) {
                      return const Text(
                        'Toutes les marques du catalogue sont listées.',
                        style: style,
                      );
                    }

                    return Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Liste partielle: le catalogue n\'a pas pu être '
                            'lu en entier.',
                            style: style,
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              controller.ensureMarqueIndex(force: true),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text(
                            'Réessayer',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showWarehousePicker() async {
    warehouseController.text = controller.warehouseFilter.value;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ColorManager.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        void apply(String value) {
          controller.setWarehouseFilter(value.trim());
          Navigator.pop(sheetContext);
        }

        return SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 18,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filtrer par entrepôt',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: warehouseController,
                autofocus: controller.knownWarehouses.isEmpty,
                textInputAction: TextInputAction.search,
                onSubmitted: apply,
                decoration: InputDecoration(
                  hintText: "Code ou nom d'entrepôt",
                  prefixIcon: const Icon(Icons.warehouse_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
              ),
              Obx(() {
                final warehouses = controller.knownWarehouses;
                if (warehouses.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: warehouses
                        .map(
                          (warehouse) => ActionChip(
                            label: Text(warehouse),
                            onPressed: () => apply(warehouse),
                            backgroundColor: ColorManager.greybg,
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(),
                  ),
                );
              }),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => apply(''),
                      child: const Text('Effacer'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => apply(warehouseController.text),
                      child: const Text('Appliquer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showReservationsSheet(CommercialStockItem stock) async {
    controller.loadReservationsForStock(stock);

    await Get.bottomSheet(
      SafeArea(
        child: Container(
          height: Get.height * 0.70,
          decoration: const BoxDecoration(
            color: ColorManager.cardColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ColorManager.lightGrey2,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.pending_actions),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Réservations en attente - ${stock.referenceProduit}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Obx(() {
                  if (controller.isLoadingReservations.value) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (controller.reservationError.value != null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Text(
                          controller.reservationError.value!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: ColorManager.errorColor,
                          ),
                        ),
                      ),
                    );
                  }

                  if (controller.reservations.isEmpty) {
                    return const Center(
                      child: Text(
                        'Aucune réservation en attente pour ce produit.',
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                    itemBuilder: (_, index) {
                      final reservation = controller.reservations[index];
                      return _ReservationTile(reservation: reservation);
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemCount: controller.reservations.length,
                  );
                }),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }
}

class _StockCard extends StatelessWidget {
  final CommercialStockItem stock;
  final CommercialStockController controller;
  final VoidCallback onReservationsTap;

  const _StockCard({
    required this.stock,
    required this.controller,
    required this.onReservationsTap,
  });

  @override
  Widget build(BuildContext context) {
    final level = stock.level;
    final color = StockPalette.forLevel(level);

    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      // A reference nobody can sell today is tinted, so a run of them reads as
      // a block while scrolling instead of as rows to be examined one by one.
      color: level == StockLevel.out
          ? ColorManager.errorColor.withValues(alpha: 0.035)
          : ColorManager.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: ColorManager.lightGrey2),
      ),
      child: InkWell(
        // The row's one action, on the whole row. The chip further down says
        // what the tap does; this is what makes it comfortable to hit.
        onTap: onReservationsTap,
        child: Container(
          // Full-height rail: the level is readable straight down the left
          // edge of the list, before a single number has been read.
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 11, 11, 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      stock.designationProduit.isEmpty
                          ? stock.referenceProduit
                          : stock.designationProduit,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        height: 1.3,
                        color: ColorManager.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _buildFigure(level, color),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${stock.referenceProduit} · ${stock.fabricant}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: ColorManager.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildPrice(),
                ],
              ),
              _buildArrivageNote(),
              const SizedBox(height: 9),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLevelBar(color),
                        const SizedBox(height: 5),
                        Text(
                          _buildStockCaption(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: ColorManager.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _buildReservationsChip(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The two quantities the big figure does not already give. Kept short
  /// because it shares its line with the bar and the reservations chip.
  String _buildStockCaption() {
    if (stock.quantiteReservee > 0) {
      return '${stock.quantiteReservee} réservés'
          ' · ${stock.quantite} au total';
    }

    return '${stock.quantite} au total';
  }

  /// What is on the way: the quantity on route, the restocking delay and the
  /// forecast date, whichever of them the row carries. This is the answer the
  /// availability sheet used to be opened for, and it was in the list payload
  /// all along.
  ///
  /// Nothing is drawn for a reference the backend announces no resupply for.
  Widget _buildArrivageNote() {
    if (!stock.isEnArrivage) {
      return const SizedBox.shrink();
    }

    final parts = <String>[];

    if (stock.quantiteArrivage > 0) {
      parts.add(
        '${stock.quantiteArrivage} unité'
        '${stock.quantiteArrivage > 1 ? 's' : ''}',
      );
    }

    final delay = stock.delaiReapprovisionnementJours;
    if (delay != null && delay > 0) {
      parts.add('sous $delay j');
    }

    final forecast = stock.datePrevisionDisponibilite?.trim() ?? '';
    if (forecast.isNotEmpty) {
      parts.add('prévu le ${_formatMoment(forecast, withTime: false)}');
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Icon(
            Icons.local_shipping_outlined,
            size: 14,
            color: StockPalette.incoming,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              parts.isEmpty
                  ? 'En arrivage'
                  : 'En arrivage · ${parts.join(' · ')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: StockPalette.incoming,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The available quantity and the level it puts the reference in, as one
  /// block: the number is what gets decided on, and the label under it keeps
  /// that meaning readable where the colour cannot be relied on.
  Widget _buildFigure(StockLevel level, Color color) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            stock.quantiteDisponible.toString(),
            maxLines: 1,
            style: TextStyle(
              fontSize: 22,
              height: 1,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            StockPalette.labelFor(level),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              height: 1,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// The amount carries the weight and the unit stays quiet, so a price is
  /// never read as one of the quantities around it.
  Widget _buildPrice() {
    return Text.rich(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      TextSpan(
        children: [
          TextSpan(
            text: _formatAmount(stock.prixHt),
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: ColorManager.textPrimary,
            ),
          ),
          const TextSpan(
            text: ' DT',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: ColorManager.textSecondary,
            ),
          ),
          const TextSpan(
            text: ' HT',
            style: TextStyle(fontSize: 9.5, color: ColorManager.textTertiary),
          ),
        ],
      ),
    );
  }

  /// The reservations drill-down, as a chip on the meta line rather than a
  /// full-width button on a line of its own: the whole row already carries
  /// the same tap, so this only has to name it.
  Widget _buildReservationsChip() {
    return TextButton.icon(
      onPressed: onReservationsTap,
      icon: const Icon(Icons.pending_actions_outlined, size: 15),
      label: const Text(
        'Réservations',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: TextButton.styleFrom(
        foregroundColor: ColorManager.primaryVariant,
        backgroundColor: ColorManager.primaryVariant.withValues(alpha: 0.08),
        // No fixed height: at a large font setting a 32dp box clipped its own
        // label. The padding keeps it compact and lets it grow when it must.
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
    );
  }

  /// Available / reserved / unaccounted-for as one bar. The split between what
  /// can be sold today and what is already promised is what gets read before
  /// quoting a client, and four equal grey chips never showed it.
  Widget _buildLevelBar(Color color) {
    final available = stock.quantiteDisponible < 0
        ? 0
        : stock.quantiteDisponible;
    final reserved = stock.quantiteReservee < 0 ? 0 : stock.quantiteReservee;
    final remainder = stock.quantite - available - reserved;

    final segments = <Widget>[];

    void addSegment(int weight, Color segmentColor) {
      if (weight <= 0) {
        return;
      }
      segments.add(
        Expanded(
          flex: weight,
          child: ColoredBox(color: segmentColor),
        ),
      );
    }

    addSegment(available, color);
    addSegment(reserved, StockPalette.reserved);
    addSegment(remainder, StockPalette.track);

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 5,
        child: segments.isEmpty
            ? const ColoredBox(color: StockPalette.track)
            : Row(children: segments),
      ),
    );
  }
}

class _ReservationTile extends StatelessWidget {
  final CommercialPendingReservation reservation;

  const _ReservationTile({required this.reservation});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ColorManager.greybg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColorManager.lightGrey2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  reservation.clientRaisonSociale,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: ColorManager.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: StockPalette.reserved.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Reste ${reservation.quantiteRestante}'
                  ' / ${reservation.quantiteInitiale}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ColorManager.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildDetailRow(
            Icons.receipt_long_outlined,
            reservation.numeroCommande,
          ),
          _buildDetailRow(Icons.person_outline, reservation.utilisateur),
          _buildDetailRow(
            Icons.schedule,
            _formatMoment(reservation.dateCreation, withTime: true),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String value) {
    final text = value.trim();
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(icon, size: 13, color: ColorManager.textTertiary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: ColorManager.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder card drawn while the first page is on its way. It breathes
/// rather than shimmers: a gradient sweep would need a dependency the project
/// does not carry, and a slow pulse reads as "loading" just as well.
class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Widget _block(double? width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: StockPalette.track,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: ColorManager.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: ColorManager.lightGrey2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: FadeTransition(
          opacity: Tween<double>(
            begin: 0.4,
            end: 1,
          ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _block(null, 13),
                        const SizedBox(height: 7),
                        _block(140, 10),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _block(44, 28),
                ],
              ),
              const SizedBox(height: 14),
              _block(null, 6),
              const SizedBox(height: 10),
              _block(120, 10),
              const SizedBox(height: 14),
              _block(null, 36),
            ],
          ),
        ),
      ),
    );
  }
}

/// `1 234,50`, grouped the French way. The unit is drawn separately by the
/// row, so the amount can carry more weight than the currency it is in.
String _formatAmount(double value) {
  final fixed = value.toStringAsFixed(2);
  final separator = fixed.indexOf('.');
  final units = fixed.substring(0, separator);
  final cents = fixed.substring(separator + 1);

  final grouped = StringBuffer();
  for (var i = 0; i < units.length; i++) {
    if (i > 0 && (units.length - i) % 3 == 0) {
      grouped.write('\u202f');
    }
    grouped.write(units[i]);
  }

  return '$grouped,$cents';
}

/// `12/03/2026 à 14:05`, or just the date when the time is not wanted. The
/// API hands back an ISO timestamp, which was being printed raw — seconds,
/// microseconds and timezone included — in the reservations list.
String _formatMoment(String raw, {required bool withTime}) {
  final value = raw.trim();
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return value;
  }

  final local = parsed.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final date = '$day/$month/${local.year}';

  if (!withTime) {
    return date;
  }

  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');

  return '$date à $hour:$minute';
}

import 'package:dayco_mobile/features/commercial/data/models/commercial_stock_models.dart';
import 'package:dayco_mobile/features/commercial/presentation/controllers/commercial_stock_controller.dart';
import 'package:flutter_test/flutter_test.dart';
// Brings GetX's RxList extensions (assignAll) into scope, as lib/ has them.
import 'package:get/get.dart';

/// Covers the two things the stock screen now promises: narrowing the list to
/// one marque, and showing the last load instantly when the page is reopened.
///
/// Both are client-side by necessity — `/api/v1/stocks/admin/all` accepts only
/// `page`, `size`, `search` and `entrepot`, so there is no marque parameter to
/// delegate to and no freshness the backend could report. That makes the rules
/// below the real contract, with nothing on the server to fall back on.
void main() {
  CommercialStockItem item({
    required String reference,
    required String fabricant,
    int quantiteDisponible = 50,
    int seuilAlerte = 5,
    String statut = 'EN_STOCK',
  }) {
    return CommercialStockItem(
      produitId: reference,
      referenceProduit: reference,
      designationProduit: 'Courroie $reference',
      fabricant: fabricant,
      prixHt: 42,
      quantite: quantiteDisponible,
      quantiteReservee: 0,
      quantiteDisponible: quantiteDisponible,
      seuilAlerte: seuilAlerte,
      enArrivage: false,
      quantiteArrivage: 0,
      delaiReapprovisionnementJours: null,
      datePrevisionDisponibilite: null,
      statut: statut,
      entrepot: 'TUNIS',
    );
  }

  late CommercialStockController controller;

  setUp(() {
    controller = CommercialStockController();
    // The fill loop pulls backend pages until the screen is full. Nothing in
    // these tests is about paging, and a live HTTP call would make them slow
    // and flaky, so the controller is told the catalogue is exhausted.
    controller.hasMore.value = false;
  });

  group('marque filter', () {
    setUp(() {
      controller.stocks.assignAll([
        item(reference: 'D-1', fabricant: 'DAYCO'),
        item(reference: 'R-1', fabricant: 'REMSA'),
        item(reference: 'D-2', fabricant: 'dayco'),
        item(reference: 'V-1', fabricant: 'VALEO'),
      ]);
    });

    test('shows every row when no marque is picked', () {
      expect(controller.visibleStocks, hasLength(4));
    });

    test('narrows the list to the picked marque', () {
      controller.setBrandFilter('REMSA');

      expect(
        controller.visibleStocks.map((s) => s.referenceProduit),
        ['R-1'],
      );
    });

    test('matches the marque regardless of case or padding', () {
      // The backend has returned the same manufacturer spelled both ways, and
      // a commercial picking "DAYCO" off a chip means both rows.
      controller.setBrandFilter('  dayco  ');

      expect(
        controller.visibleStocks.map((s) => s.referenceProduit),
        ['D-1', 'D-2'],
      );
    });

    test('an empty marque means all marques, not a marque named ""', () {
      controller.setBrandFilter('DAYCO');
      controller.setBrandFilter('   ');

      expect(controller.brandFilter.value, isNull);
      expect(controller.visibleStocks, hasLength(4));
    });

    test('clearing the marque restores the full list', () {
      controller.setBrandFilter('VALEO');
      expect(controller.visibleStocks, hasLength(1));

      controller.setBrandFilter(null);
      expect(controller.visibleStocks, hasLength(4));
    });
  });

  test('marque and level narrow the list together', () {
    // The point of the feature: searching *within* one family. A level filter
    // already existed, so the two have to compose rather than override.
    controller.stocks.assignAll([
      item(reference: 'D-OK', fabricant: 'DAYCO'),
      item(
        reference: 'D-LOW',
        fabricant: 'DAYCO',
        quantiteDisponible: 2,
        seuilAlerte: 5,
      ),
      item(
        reference: 'R-LOW',
        fabricant: 'REMSA',
        quantiteDisponible: 2,
        seuilAlerte: 5,
      ),
    ]);

    controller.setBrandFilter('DAYCO');
    controller.setLevelFilter(StockLevel.low);

    expect(controller.visibleStocks.map((s) => s.referenceProduit), ['D-LOW']);
    expect(controller.hasRowFilter, isTrue);
  });

  group('freshness', () {
    test('is stale before anything has been loaded', () {
      expect(controller.lastLoadedAt.value, isNull);
      expect(controller.isStale, isTrue);
    });

    test('is fresh immediately after a load', () {
      controller.lastLoadedAt.value = DateTime.now();

      expect(controller.isStale, isFalse);
    });

    test('is still fresh just inside the window', () {
      controller.lastLoadedAt.value = DateTime.now().subtract(
        CommercialStockController.freshnessWindow -
            const Duration(seconds: 30),
      );

      expect(controller.isStale, isFalse);
    });

    test('is stale once the window has elapsed', () {
      controller.lastLoadedAt.value = DateTime.now().subtract(
        CommercialStockController.freshnessWindow,
      );

      expect(controller.isStale, isTrue);
    });

    test('the window is the ten minutes the screen promises', () {
      expect(
        CommercialStockController.freshnessWindow,
        const Duration(minutes: 10),
      );
    });
  });

  group('clearCache', () {
    test('empties everything a signed-in representative left behind', () {
      // The controller is permanent so that reopening the page is instant;
      // that makes sign-out the only thing bounding its lifetime. Anything
      // missed here would be shown to the next person on the device.
      controller.stocks.assignAll([item(reference: 'D-1', fabricant: 'DAYCO')]);
      controller.knownBrands.assignAll(['DAYCO']);
      controller.knownWarehouses.assignAll(['TUNIS']);
      controller.lastLoadedAt.value = DateTime.now();
      controller.setBrandFilter('DAYCO');
      controller.setLevelFilter(StockLevel.low);
      controller.searchQuery.value = 'courroie';
      controller.warehouseFilter.value = 'TUNIS';
      controller.totalElements.value = 900;

      controller.clearCache();

      expect(controller.stocks, isEmpty);
      expect(controller.knownBrands, isEmpty);
      expect(controller.knownWarehouses, isEmpty);
      expect(controller.brandFilter.value, isNull);
      expect(controller.levelFilter.value, isNull);
      expect(controller.searchQuery.value, isEmpty);
      expect(controller.warehouseFilter.value, isEmpty);
      expect(controller.totalElements.value, 0);
      expect(controller.lastLoadedAt.value, isNull);
    });

    test('a cleared cache reads as stale, so the next visit reloads', () {
      controller.lastLoadedAt.value = DateTime.now();
      expect(controller.isStale, isFalse);

      controller.clearCache();

      expect(controller.isStale, isTrue);
    });
  });
}

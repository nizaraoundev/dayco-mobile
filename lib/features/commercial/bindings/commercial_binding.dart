import 'package:get/get.dart';
import '../data/services/sync_service.dart';
import '../data/services/map_service.dart';
import '../data/services/fake_data_service.dart';
import '../presentation/controllers/commercial_controller.dart';
import '../presentation/controllers/map_controller.dart';
import '../presentation/controllers/commercial_stock_controller.dart';

/// Binding for commercial feature - initializes all dependencies
class CommercialBinding extends Bindings {
  @override
  void dependencies() {
    // Services (lazy singletons)
    Get.lazyPut<SyncService>(() => SyncService(), fenix: true);
    Get.lazyPut<MapService>(() => MapService(), fenix: true);
    Get.lazyPut<FakeDataService>(() => FakeDataService(), fenix: true);

    // Controllers
    Get.lazyPut<CommercialController>(
      () => CommercialController(),
      fenix: true,
    );
    Get.lazyPut<MapController>(() => MapController(), fenix: true);
    Get.lazyPut<CommercialStockController>(
      () => CommercialStockController(),
      fenix: true,
    );
  }
}

/// Initial binding to be used when app starts with commercial feature
class InitialCommercialBinding extends Bindings {
  @override
  void dependencies() {
    // Core services that should be initialized once
    Get.put<SyncService>(SyncService(), permanent: true);
    Get.put<MapService>(MapService(), permanent: true);
    Get.put<FakeDataService>(FakeDataService(), permanent: true);

    // Main controllers
    Get.put<CommercialController>(CommercialController(), permanent: true);
    Get.put<MapController>(MapController(), permanent: true);
    Get.put<CommercialStockController>(CommercialStockController());
  }
}

/// Binding for map page
class MapBinding extends Bindings {
  @override
  void dependencies() {
    // Ensure MapController is available
    if (!Get.isRegistered<MapController>()) {
      Get.lazyPut<MapController>(() => MapController());
    }
  }
}

/// Binding for client detail page
class ClientDetailBinding extends Bindings {
  @override
  void dependencies() {
    // CommercialController should already be registered
    // This is just a placeholder if additional dependencies are needed
  }
}

/// Binding for products page
class ProductsBinding extends Bindings {
  @override
  void dependencies() {
    // CommercialController should already be registered
  }
}

/// Binding for orders page
class OrdersBinding extends Bindings {
  @override
  void dependencies() {
    // CommercialController should already be registered
  }
}

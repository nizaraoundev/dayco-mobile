import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'database_service.dart';

/// Sync service for offline-first functionality
class SyncService extends GetxService {
  final DatabaseService _db = DatabaseService.instance;
  final String _baseUrl = 'https://api.dayco.tn/v1'; // Replace with actual API

  final RxBool isOnline = false.obs;
  final RxBool isSyncing = false.obs;
  final Rx<SyncSummary> syncSummary = SyncSummary().obs;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _autoSyncTimer;

  @override
  void onInit() {
    super.onInit();
    _initConnectivity();
    _startAutoSync();
  }

  @override
  void onClose() {
    _connectivitySubscription?.cancel();
    _autoSyncTimer?.cancel();
    super.onClose();
  }

  void _initConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      isOnline.value = hasConnection;
      if (hasConnection) {
        // Auto sync when back online
        syncAll();
      }
    });

    // Check initial connectivity
    Connectivity().checkConnectivity().then((results) {
      isOnline.value = results.any((r) => r != ConnectivityResult.none);
    });
  }

  void _startAutoSync() {
    // Auto sync every 5 minutes when online
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (isOnline.value && !isSyncing.value) {
        syncAll();
      }
    });
  }

  /// Refresh sync summary from database
  Future<void> refreshSyncSummary() async {
    syncSummary.value = await _db.getSyncSummary();
  }

  /// Sync all pending items
  Future<void> syncAll() async {
    if (isSyncing.value || !isOnline.value) return;

    isSyncing.value = true;
    syncSummary.value = syncSummary.value.copyWith(isSyncing: true);

    try {
      final pendingItems = await _db.getPendingSyncItems();

      for (final item in pendingItems) {
        await _syncItem(item);
      }

      await refreshSyncSummary();
    } catch (e) {
      print('Sync error: $e');
    } finally {
      isSyncing.value = false;
      syncSummary.value = syncSummary.value.copyWith(isSyncing: false);
    }
  }

  /// Sync a single item
  Future<bool> _syncItem(SyncQueueItem item) async {
    try {
      switch (item.entityType) {
        case 'client':
          return await _syncClient(item);
        case 'order':
          return await _syncOrder(item);
        case 'visit':
          return await _syncVisit(item);
        default:
          return false;
      }
    } catch (e) {
      // Update item with error
      await _db.updateSyncItem(
        item.copyWith(
          status: SyncStatus.failed,
          errorMessage: e.toString(),
          retryCount: item.retryCount + 1,
        ),
      );
      return false;
    }
  }

  Future<bool> _syncClient(SyncQueueItem item) async {
    final endpoint = '$_baseUrl/clients';

    try {
      http.Response response;

      switch (item.action) {
        case SyncAction.create:
          response = await http.post(
            Uri.parse(endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(item.data),
          );
          break;
        case SyncAction.update:
          response = await http.put(
            Uri.parse('$endpoint/${item.entityId}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(item.data),
          );
          break;
        case SyncAction.delete:
          response = await http.delete(Uri.parse('$endpoint/${item.entityId}'));
          break;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await _db.deleteSyncItem(item.id);
        return true;
      } else if (response.statusCode == 409) {
        // Conflict
        await _db.updateSyncItem(item.copyWith(status: SyncStatus.conflict));
        return false;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> _syncOrder(SyncQueueItem item) async {
    final endpoint = '$_baseUrl/orders';

    try {
      http.Response response;

      switch (item.action) {
        case SyncAction.create:
          response = await http.post(
            Uri.parse(endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(item.data),
          );
          break;
        case SyncAction.update:
          response = await http.put(
            Uri.parse('$endpoint/${item.entityId}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(item.data),
          );
          break;
        case SyncAction.delete:
          response = await http.delete(Uri.parse('$endpoint/${item.entityId}'));
          break;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await _db.deleteSyncItem(item.id);
        return true;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> _syncVisit(SyncQueueItem item) async {
    final endpoint = '$_baseUrl/visits';

    try {
      http.Response response;

      switch (item.action) {
        case SyncAction.create:
          response = await http.post(
            Uri.parse(endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(item.data),
          );
          break;
        case SyncAction.update:
          response = await http.put(
            Uri.parse('$endpoint/${item.entityId}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(item.data),
          );
          break;
        case SyncAction.delete:
          response = await http.delete(Uri.parse('$endpoint/${item.entityId}'));
          break;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await _db.deleteSyncItem(item.id);
        return true;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Add client to sync queue
  Future<void> queueClientSync(ClientModel client, SyncAction action) async {
    final item = SyncQueueItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      entityType: 'client',
      entityId: client.id,
      action: action,
      data: client.toJson(),
      createdAt: DateTime.now(),
    );
    await _db.addToSyncQueue(item);
    await refreshSyncSummary();

    // Try immediate sync if online
    if (isOnline.value) {
      syncAll();
    }
  }

  /// Add order to sync queue
  Future<void> queueOrderSync(OrderModel order, SyncAction action) async {
    final item = SyncQueueItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      entityType: 'order',
      entityId: order.id,
      action: action,
      data: order.toJson(),
      createdAt: DateTime.now(),
    );
    await _db.addToSyncQueue(item);
    await refreshSyncSummary();

    if (isOnline.value) {
      syncAll();
    }
  }

  /// Add visit to sync queue
  Future<void> queueVisitSync(VisitModel visit, SyncAction action) async {
    final item = SyncQueueItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      entityType: 'visit',
      entityId: visit.id,
      action: action,
      data: visit.toJson(),
      createdAt: DateTime.now(),
    );
    await _db.addToSyncQueue(item);
    await refreshSyncSummary();

    if (isOnline.value) {
      syncAll();
    }
  }

  /// Download all data from server (initial sync or refresh)
  Future<void> downloadAllData() async {
    if (!isOnline.value) return;

    try {
      // Download clients
      final clientsResponse = await http.get(Uri.parse('$_baseUrl/clients'));
      if (clientsResponse.statusCode == 200) {
        final clients = jsonDecode(clientsResponse.body) as List;
        for (final json in clients) {
          final client = ClientModel.fromJson(json);
          await _db.insertClient(client.copyWith(syncStatus: 'synced'));
        }
      }

      // Download products
      final productsResponse = await http.get(Uri.parse('$_baseUrl/products'));
      if (productsResponse.statusCode == 200) {
        final products = jsonDecode(productsResponse.body) as List;
        for (final json in products) {
          await _db.insertProduct(ProductModel.fromJson(json));
        }
      }
    } catch (e) {
      print('Download error: $e');
    }
  }
}

extension SyncSummaryExtension on SyncSummary {
  SyncSummary copyWith({
    int? totalPending,
    int? totalSynced,
    int? totalFailed,
    int? totalConflicts,
    DateTime? lastSyncTime,
    bool? isSyncing,
  }) {
    return SyncSummary(
      totalPending: totalPending ?? this.totalPending,
      totalSynced: totalSynced ?? this.totalSynced,
      totalFailed: totalFailed ?? this.totalFailed,
      totalConflicts: totalConflicts ?? this.totalConflicts,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }
}

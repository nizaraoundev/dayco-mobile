import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../../../../core/utils/app_logger.dart';
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

  /// Whether a real sync endpoint has been configured.
  ///
  /// [_baseUrl] is still the template placeholder `api.dayco.tn`, which does
  /// not resolve. Every upload attempt therefore fails, and the failures were
  /// swallowed into `print('Sync error: ...')` — so the app burned battery and
  /// radio on a timer, every five minutes, forever, achieving nothing.
  ///
  /// Until a real endpoint exists, uploads are skipped rather than attempted.
  /// The local queue still works: visits and orders are persisted to sqflite
  /// and will be uploaded once this is pointed at a live host.
  static bool get isSyncEndpointConfigured => false;

  @override
  void onInit() {
    super.onInit();
    // Connectivity is still observed, because the dashboard shows an
    // online/offline indicator. What is gone is the automatic `syncAll()` it
    // used to trigger on every connectivity change.
    _initConnectivity();

    // `_startAutoSync()` is deliberately not called. See
    // [isSyncEndpointConfigured].
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
      // Only the indicator is updated. Triggering `syncAll()` here meant every
      // connectivity flap — common in the field, moving between cells — fired
      // a burst of requests at a host that does not exist.
      isOnline.value = results.any((r) => r != ConnectivityResult.none);
    });

    // Check initial connectivity
    Connectivity().checkConnectivity().then((results) {
      isOnline.value = results.any((r) => r != ConnectivityResult.none);
    });
  }

  /// Starts the periodic upload.
  ///
  /// Not called while [isSyncEndpointConfigured] is false. Kept so that
  /// enabling sync, once a real endpoint exists, is a one-line change rather
  /// than a rewrite.
  // ignore: unused_element
  void _startAutoSync() {
    _autoSyncTimer?.cancel();
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
    if (!isSyncEndpointConfigured) {
      // Refresh the counts so the dashboard still shows what is queued, then
      // stop. Attempting an upload against the placeholder host would only
      // mark every item failed and inflate its retry count.
      AppLogger.info('Sync skipped: no sync endpoint is configured');
      await refreshSyncSummary();
      return;
    }

    if (isSyncing.value || !isOnline.value) return;

    isSyncing.value = true;
    syncSummary.value = syncSummary.value.copyWith(isSyncing: true);

    try {
      final pendingItems = await _db.getPendingSyncItems();

      for (final item in pendingItems) {
        await _syncItem(item);
      }

      await refreshSyncSummary();
    } on Object catch (error, stackTrace) {
      AppLogger.error('Sync failed', error: error, stackTrace: stackTrace);
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
    if (isOnline.value && isSyncEndpointConfigured) {
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

    if (isOnline.value && isSyncEndpointConfigured) {
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

    if (isOnline.value && isSyncEndpointConfigured) {
      syncAll();
    }
  }

  /// Download all data from server (initial sync or refresh)
  Future<void> downloadAllData() async {
    if (!isOnline.value || !isSyncEndpointConfigured) return;

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
    } on Object catch (error, stackTrace) {
      AppLogger.error('Download failed', error: error, stackTrace: stackTrace);
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

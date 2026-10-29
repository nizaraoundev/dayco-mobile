import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../../core/network/api_exception.dart';
import '../../../auth/data/services/auth_service.dart';
import '../models/models.dart';
import 'database_service.dart';

/// What happened to one item on one attempt.
enum _Outcome {
  /// The backend has it. The item leaves the queue.
  sent,

  /// Nothing reached the backend, or it was having a bad minute. The item
  /// stays, with a longer wait before the next try.
  retry,

  /// The backend answered and refused. Sending it again would be refused the
  /// same way, so it stops being retried and starts being shown to the user.
  rejected,
}

/// A queued create that landed: what it was called locally, and the id the
/// backend gave it.
@immutable
class SyncResolution {
  const SyncResolution({
    required this.entityType,
    required this.localId,
    required this.serverId,
    required this.response,
  });

  final String entityType;
  final String localId;
  final String serverId;
  final Map<String, dynamic> response;
}

/// The offline queue.
///
/// Everything a commercial writes goes in here first and is sent from here,
/// so the app behaves the same whether or not there is a signal: the record
/// exists locally the moment they save it, and reaching the backend is this
/// service's problem rather than theirs.
///
/// Three rules it keeps:
///
///   * **Nothing leaves the queue until the backend has confirmed it.** Only a
///     2xx deletes a row. A failure keeps the item, with the reason attached.
///   * **The drain order is the user's order, not the clock's** — creates,
///     then edits, then photos. See [SyncPriority].
///   * **A failure that cannot succeed is not retried for ever.** A refused
///     payload is parked and shown; only a connection failure or a backend
///     having trouble is retried, with a widening gap between attempts.
///
/// Work is pushed through [AuthService] rather than raw HTTP so that a queued
/// write and a live one are the same request, built the same way, and cannot
/// drift apart.
class SyncService extends GetxService {
  final DatabaseService _db = DatabaseService.instance;
  final AuthService _auth = AuthService();

  /// Entity types the queue knows how to send.
  static const String entityClient = 'client';
  static const String entitySubClient = 'subclient';
  static const String entityPhoto = 'photo';

  /// Keys the queue adds to a payload for its own use. Stripped before the
  /// payload is sent, so the backend never sees them.
  static const String _keyParentIds = 'parentClientIds';
  static const String _keyOwnerType = '__ownerType';
  static const String _keyImage = '__imageBase64';
  static const String _keyFileName = '__fileName';

  /// Attempts before an item is parked for good.
  static const int maxRetries = 5;

  /// Prefix for the id a record is known by before the backend has given it
  /// one. Recognisable on sight in a log, a row or a marker.
  static const String localIdPrefix = 'local_';

  static bool isLocalId(String id) => id.startsWith(localIdPrefix);

  static String newLocalId() =>
      '$localIdPrefix${DateTime.now().microsecondsSinceEpoch}';

  final RxBool isOnline = false.obs;
  final RxBool isSyncing = false.obs;
  final Rx<SyncSummary> syncSummary = SyncSummary().obs;

  /// Everything still in the queue, newest state first in drain order, for the
  /// screen that lists what has not left the device.
  final RxList<SyncQueueItem> pendingItems = <SyncQueueItem>[].obs;

  /// Set each time a queued create lands, so whoever is holding the local
  /// record can point it at the real one. Listen with `ever(...)`.
  final Rxn<SyncResolution> lastResolution = Rxn<SyncResolution>();

  /// Set when the user gives up on a queued item, so the local copy of a
  /// record that will now never exist can be taken off the map with it.
  final Rxn<String> lastDiscardedEntityId = Rxn<String>();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _autoSyncTimer;

  @override
  void onInit() {
    super.onInit();
    _initConnectivity();
    _startAutoSync();
    unawaited(refreshSyncSummary());
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
      final cameBackOnline = hasConnection && !isOnline.value;
      isOnline.value = hasConnection;

      // Only on the transition, so a Wi-Fi/mobile handover does not restart a
      // sync that is already running.
      if (cameBackOnline) unawaited(syncAll());
    });

    Connectivity().checkConnectivity().then((results) {
      isOnline.value = results.any((r) => r != ConnectivityResult.none);
      if (isOnline.value) unawaited(syncAll());
    });
  }

  void _startAutoSync() {
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (isOnline.value && !isSyncing.value) unawaited(syncAll());
    });
  }

  Future<void> refreshSyncSummary() async {
    syncSummary.value = await _db.getSyncSummary();
    pendingItems.assignAll(await _db.getAllSyncItems());
  }

  /// How many pieces of work have not reached the backend. What the badge
  /// counts, and what a user means by "has my client been sent yet".
  int get outstandingCount => pendingItems.length;

  /// Pushes everything outstanding, in drain order.
  Future<void> syncAll() async {
    if (isSyncing.value || !isOnline.value) return;

    isSyncing.value = true;
    syncSummary.value = syncSummary.value.copyWith(isSyncing: true);

    try {
      final items = await _db.getSyncableItems(maxRetries: maxRetries);

      for (final item in items) {
        if (!isOnline.value) break;
        if (!_isDueForRetry(item)) continue;

        // Re-read it: an earlier item in this same pass may have been its
        // create, which moved it onto the real entity id.
        final current = await _currentVersionOf(item);
        if (current == null) continue;

        await _syncItem(current);
      }

      await refreshSyncSummary();
    } catch (error) {
      debugPrint('Sync pass failed: $error');
    } finally {
      isSyncing.value = false;
      syncSummary.value = syncSummary.value.copyWith(isSyncing: false);
    }
  }

  Future<SyncQueueItem?> _currentVersionOf(SyncQueueItem item) async {
    final all = await _db.getAllSyncItems();
    for (final candidate in all) {
      if (candidate.id == item.id) return candidate;
    }
    // Already gone: sent, or dropped with the create it belonged to.
    return null;
  }

  /// Exponential backoff from the last attempt: 1, 2, 4, 8, 16 minutes.
  bool _isDueForRetry(SyncQueueItem item) {
    if (item.retryCount == 0) return true;

    final lastAttempt = item.lastAttemptAt;
    if (lastAttempt == null) return true;

    final delay = Duration(minutes: 1 << (item.retryCount - 1));
    return DateTime.now().difference(lastAttempt) >= delay;
  }

  Future<void> _syncItem(SyncQueueItem item) async {
    _Outcome outcome;
    String? reason;

    try {
      outcome = switch (item.entityType) {
        entityClient => await _syncClient(item),
        entitySubClient => await _syncSubClient(item),
        entityPhoto => await _syncPhoto(item),
        _ => _Outcome.rejected,
      };

      if (outcome == _Outcome.rejected && item.entityType != entityPhoto) {
        reason ??= 'No endpoint wired for "${item.entityType}"';
      }
    } on ApiException catch (error) {
      outcome = error.isRetryable ? _Outcome.retry : _Outcome.rejected;
      reason = error.message;
    } catch (error) {
      // An unrecognised failure is treated as worth retrying: the cost of one
      // more attempt is small, and dropping a commercial's work on an error we
      // have not classified would not be.
      outcome = _Outcome.retry;
      reason = error.toString();
    }

    switch (outcome) {
      case _Outcome.sent:
        await _db.deleteSyncItem(item.id);
        return;

      case _Outcome.retry:
        debugPrint('Queue: ${item.label} retrying — $reason');
        await _db.updateSyncItem(
          item.copyWith(
            status: SyncStatus.failed,
            errorMessage: reason,
            retryCount: item.retryCount + 1,
            lastAttemptAt: DateTime.now(),
          ),
        );
        return;

      case _Outcome.rejected:
        // Kept, not deleted: the user's work is still in there, and a refused
        // payload is something somebody has to see rather than something to
        // throw away quietly. maxRetries stops it being attempted again.
        debugPrint('Queue: ${item.label} refused — $reason');
        await _db.updateSyncItem(
          item.copyWith(
            status: SyncStatus.conflict,
            errorMessage: reason,
            retryCount: maxRetries,
            lastAttemptAt: DateTime.now(),
          ),
        );
        return;
    }
  }

  Future<_Outcome> _syncClient(SyncQueueItem item) async {
    switch (item.action) {
      case SyncAction.create:
        final response = await _auth.createClientWithPayload(
          payload: _sendablePayload(item),
        );
        await _resolveCreate(item, response, const [
          'id',
          'userId',
          'codeClient',
        ]);
        return _Outcome.sent;

      case SyncAction.update:
        if (isLocalId(item.entityId)) {
          // Its create has not landed yet. Leaving it queued is right: the
          // next pass runs after the create and finds the real id.
          return _Outcome.retry;
        }
        await _auth.updateClient(
          clientId: item.entityId,
          payload: _sendablePayload(item),
        );
        return _Outcome.sent;

      case SyncAction.delete:
        // The clients API exposes no delete; a client is deactivated instead.
        return _Outcome.rejected;
    }
  }

  Future<_Outcome> _syncSubClient(SyncQueueItem item) async {
    switch (item.action) {
      case SyncAction.create:
        final payload = _sendablePayload(item);
        final parents = payload[_keyParentIds];
        final firstParent = parents is List && parents.isNotEmpty
            ? '${parents.first}'
            : null;

        final response = await _auth.createSubClient(
          parentClientId: firstParent,
          payload: payload,
        );
        await _resolveCreate(item, response, const ['id', 'userId']);
        return _Outcome.sent;

      case SyncAction.update:
        if (isLocalId(item.entityId)) return _Outcome.retry;
        await _auth.updateSubClient(
          subClientId: item.entityId,
          payload: _sendablePayload(item),
        );
        return _Outcome.sent;

      case SyncAction.delete:
        if (isLocalId(item.entityId)) {
          // Created and deleted while offline: it never reached the backend,
          // so there is nothing to delete and nothing to keep.
          await _dropQueuedWorkFor(item.entityId);
          return _Outcome.sent;
        }
        await _auth.deleteSubClient(item.entityId);
        return _Outcome.sent;
    }
  }

  Future<_Outcome> _syncPhoto(SyncQueueItem item) async {
    if (isLocalId(item.entityId)) return _Outcome.retry;

    final encoded = item.data[_keyImage]?.toString() ?? '';
    if (encoded.isEmpty) return _Outcome.rejected;

    final ownerType =
        item.data[_keyOwnerType]?.toString() ?? AuthService.entityClient;
    final fileName = item.data[_keyFileName]?.toString() ?? 'photo.jpg';

    await _auth.uploadEntityImage(
      entityType: ownerType,
      entityId: item.entityId,
      imageBytes: base64Decode(encoded),
      fileName: fileName,
    );

    return _Outcome.sent;
  }

  /// The payload as the backend should see it, without the queue's own keys.
  Map<String, dynamic> _sendablePayload(SyncQueueItem item) {
    final payload = Map<String, dynamic>.from(item.data);
    payload.remove(_keyOwnerType);
    payload.remove(_keyImage);
    payload.remove(_keyFileName);
    return payload;
  }

  /// Points everything queued behind a create at the id the backend assigned,
  /// and tells whoever holds the local copy about it.
  Future<void> _resolveCreate(
    SyncQueueItem item,
    Map<String, dynamic> response,
    List<String> idFields,
  ) async {
    var serverId = '';
    for (final field in idFields) {
      final value = response[field]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        serverId = value;
        break;
      }
    }

    if (serverId.isEmpty || serverId == item.entityId) return;

    await _db.remapQueueEntity(
      fromEntityId: item.entityId,
      toEntityId: serverId,
    );

    lastResolution.value = SyncResolution(
      entityType: item.entityType,
      localId: item.entityId,
      serverId: serverId,
      response: response,
    );
  }

  /// Removes everything queued for a record that will never exist.
  Future<void> _dropQueuedWorkFor(String entityId) async {
    for (final queued in await _db.getAllSyncItems()) {
      if (queued.entityId == entityId) {
        await _db.deleteSyncItem(queued.id);
      }
    }
  }

  /// Queues a client or sub-client write.
  ///
  /// [payload] must be the API's shape, not the local model's: pass the same
  /// map the online path sends, so the queued copy and the live call cannot
  /// drift apart.
  Future<void> queueClientWrite({
    required String clientId,
    required Map<String, dynamic> payload,
    required SyncAction action,
    bool isSubClient = false,
  }) async {
    await _enqueue(
      entityType: isSubClient ? entitySubClient : entityClient,
      entityId: clientId,
      action: action,
      data: payload,
      priority: action == SyncAction.create
          ? SyncPriority.creation
          : SyncPriority.change,
    );
  }

  /// Queues a shop-front photo for a record, which may not exist on the
  /// backend yet — [_syncPhoto] waits for its create to land.
  Future<void> queuePhotoUpload({
    required String entityId,
    required String ownerType,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    await _enqueue(
      entityType: entityPhoto,
      entityId: entityId,
      action: SyncAction.create,
      data: {
        _keyOwnerType: ownerType,
        _keyImage: base64Encode(imageBytes),
        _keyFileName: fileName,
      },
      priority: SyncPriority.attachment,
    );
  }

  Future<void> queueClientSync(ClientModel client, SyncAction action) =>
      queueClientWrite(
        clientId: client.id,
        payload: client.toJson(),
        action: action,
      );

  /// Orders are not queued.
  ///
  /// The live order flow posts straight through `CommercialOrderService`,
  /// whose create API is strongly typed; [OrderModel] is the local
  /// demo-data shape and the backend would reject it. Queuing it would only
  /// fill the badge with items that can never clear. Making orders work
  /// offline means mapping the draft model onto that API first.
  Future<void> queueOrderSync(OrderModel order, SyncAction action) async {
    debugPrint(
      'Order ${order.id} not queued: offline orders are not wired up yet.',
    );
  }

  /// Visits are not queued: the backend exposes no visits endpoint at all, so
  /// there is nothing for the queue to send.
  Future<void> queueVisitSync(VisitModel visit, SyncAction action) async {
    debugPrint('Visit ${visit.id} not queued: no visits endpoint exists.');
  }

  Future<void> _enqueue({
    required String entityType,
    required String entityId,
    required SyncAction action,
    required Map<String, dynamic> data,
    required SyncPriority priority,
  }) async {
    await _db.addToSyncQueue(
      SyncQueueItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        entityType: entityType,
        entityId: entityId,
        action: action,
        data: data,
        createdAt: DateTime.now(),
        priority: priority,
      ),
    );
    await refreshSyncSummary();

    if (isOnline.value) unawaited(syncAll());
  }

  /// Sends one item again now, whatever its backoff says — the button next to
  /// a failed row.
  Future<void> retryNow(SyncQueueItem item) async {
    await _db.updateSyncItem(
      item.copyWith(
        status: SyncStatus.pending,
        retryCount: 0,
        errorMessage: null,
      ),
    );
    await refreshSyncSummary();
    await syncAll();
  }

  /// Gives up on one item, at the user's request. The only way anything leaves
  /// the queue unsent.
  ///
  /// Giving up on a *create* takes everything queued behind it too — its photo,
  /// its edits — because they were all aimed at a record that is now never
  /// going to exist.
  Future<void> discard(SyncQueueItem item) async {
    final abandonsRecord =
        item.action == SyncAction.create && isLocalId(item.entityId);

    if (abandonsRecord) {
      await _dropQueuedWorkFor(item.entityId);
    } else {
      await _db.deleteSyncItem(item.id);
    }

    await refreshSyncSummary();

    if (abandonsRecord) {
      lastDiscardedEntityId.value = item.entityId;
    }
  }

  /// Refreshes the local copy of the clients this commercial owns.
  Future<void> downloadAllData() async {
    if (!isOnline.value) return;

    try {
      final clients = await _auth.getMyClients();
      for (final json in clients) {
        await _db.insertClient(
          ClientModel.fromJson(json).copyWith(syncStatus: 'synced'),
        );
      }
    } catch (error) {
      debugPrint('Client download failed: $error');
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

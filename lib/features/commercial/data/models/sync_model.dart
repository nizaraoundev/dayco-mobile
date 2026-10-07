/// Sync status for offline data
enum SyncStatus { synced, pending, inProgress, failed, conflict }

/// Sync action type
enum SyncAction { create, update, delete }

/// Sync queue item - represents a pending sync operation
class SyncQueueItem {
  final String id;
  final String entityType; // 'client', 'order', 'visit', etc.
  final String entityId;
  final SyncAction action;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int retryCount;
  final String? errorMessage;
  final SyncStatus status;

  SyncQueueItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
    this.errorMessage,
    this.status = SyncStatus.pending,
  });

  String get actionLabel {
    switch (action) {
      case SyncAction.create:
        return 'Création';
      case SyncAction.update:
        return 'Modification';
      case SyncAction.delete:
        return 'Suppression';
    }
  }

  String get entityTypeLabel {
    switch (entityType) {
      case 'client':
        return 'Client';
      case 'order':
        return 'Commande';
      case 'visit':
        return 'Visite';
      case 'product':
        return 'Produit';
      case 'route':
        return 'Itinéraire';
      case 'note':
        return 'Note';
      default:
        return entityType;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entityType': entityType,
      'entityId': entityId,
      'action': action.index,
      'data': data,
      'createdAt': createdAt.toIso8601String(),
      'retryCount': retryCount,
      'errorMessage': errorMessage,
      'status': status.index,
    };
  }

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) {
    return SyncQueueItem(
      id: json['id'],
      entityType: json['entityType'],
      entityId: json['entityId'],
      action: SyncAction.values[json['action'] ?? 0],
      data: json['data'] ?? {},
      createdAt: DateTime.parse(json['createdAt']),
      retryCount: json['retryCount'] ?? 0,
      errorMessage: json['errorMessage'],
      status: SyncStatus.values[json['status'] ?? 1],
    );
  }

  SyncQueueItem copyWith({
    String? id,
    String? entityType,
    String? entityId,
    SyncAction? action,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    int? retryCount,
    String? errorMessage,
    SyncStatus? status,
  }) {
    return SyncQueueItem(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      action: action ?? this.action,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      errorMessage: errorMessage ?? this.errorMessage,
      status: status ?? this.status,
    );
  }
}

/// Sync summary for UI display
class SyncSummary {
  final int totalPending;
  final int totalSynced;
  final int totalFailed;
  final int totalConflicts;
  final DateTime? lastSyncTime;
  final bool isSyncing;

  SyncSummary({
    this.totalPending = 0,
    this.totalSynced = 0,
    this.totalFailed = 0,
    this.totalConflicts = 0,
    this.lastSyncTime,
    this.isSyncing = false,
  });

  bool get hasUnsyncedData => totalPending > 0 || totalFailed > 0;
  bool get hasConflicts => totalConflicts > 0;
  bool get isFullySynced =>
      totalPending == 0 && totalFailed == 0 && totalConflicts == 0;

  String get statusMessage {
    if (isSyncing) return 'Synchronisation en cours...';
    if (hasConflicts) return '$totalConflicts conflits à résoudre';
    if (totalFailed > 0) return '$totalFailed échecs de synchronisation';
    if (totalPending > 0) return '$totalPending en attente de sync';
    return 'Tout est synchronisé';
  }
}

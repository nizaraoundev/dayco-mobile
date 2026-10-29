/// Sync status for offline data
enum SyncStatus { synced, pending, inProgress, failed, conflict }

/// Sync action type
enum SyncAction { create, update, delete }

/// The order the queue is drained in — which is the order the user would
/// drain it in, not the order the requests happened to be made.
///
/// A commercial standing in front of a shop has just created a client; that
/// record existing is the whole point of the visit, and everything else they
/// do refers to it. A correction to a record that already exists can wait a
/// few seconds behind that. A shop-front photo is the heaviest thing in the
/// queue and the one nobody is blocked on, so it goes last, and on a thin
/// connection it is the thing still uploading while the rest has long landed.
///
/// Lower sorts first. Items of equal priority keep their own order, so a
/// record's create always precedes its own update.
enum SyncPriority {
  /// A record that does not exist on the backend yet.
  creation(10),

  /// A change to a record that does.
  change(50),

  /// Images: large, slow, and nothing depends on them.
  attachment(90);

  const SyncPriority(this.weight);

  final int weight;

  static SyncPriority fromWeight(int weight) {
    return SyncPriority.values.firstWhere(
      (priority) => priority.weight == weight,
      orElse: () => SyncPriority.change,
    );
  }
}

/// Sync queue item - represents a pending sync operation
class SyncQueueItem {
  final String id;
  final String entityType; // 'client', 'subclient', 'photo'
  final String entityId;
  final SyncAction action;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int retryCount;
  final String? errorMessage;
  final SyncStatus status;

  /// Where this sits in the drain order. See [SyncPriority].
  final SyncPriority priority;

  /// When it was last sent, which is what the backoff is measured from.
  ///
  /// Not [createdAt]: measuring the wait from when the user did the thing
  /// means an item created an hour ago is "due" on every pass for ever, and
  /// a backend that is down gets hammered instead of backed off from.
  final DateTime? lastAttemptAt;

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
    this.priority = SyncPriority.change,
    this.lastAttemptAt,
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
      case 'subclient':
        return 'Sous-client';
      case 'photo':
        return 'Photo';
      default:
        return entityType;
    }
  }

  /// What this item is, in the words the user would use for it. Shown in the
  /// pending list, where "Création · Sous-client" has to mean something to a
  /// commercial looking at why something has not left their phone.
  String get label => '$actionLabel · $entityTypeLabel';

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
      'priority': priority.weight,
      'lastAttemptAt': lastAttemptAt?.toIso8601String(),
    };
  }

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final lastAttempt = json['lastAttemptAt']?.toString();

    return SyncQueueItem(
      id: json['id'],
      entityType: json['entityType'],
      entityId: json['entityId'],
      action: SyncAction.values[json['action'] ?? 0],
      data: rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : <String, dynamic>{},
      createdAt: DateTime.parse(json['createdAt']),
      retryCount: json['retryCount'] ?? 0,
      errorMessage: json['errorMessage'],
      status: SyncStatus.values[json['status'] ?? 1],
      priority: SyncPriority.fromWeight(json['priority'] ?? 50),
      lastAttemptAt: lastAttempt == null || lastAttempt.isEmpty
          ? null
          : DateTime.tryParse(lastAttempt),
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
    SyncPriority? priority,
    DateTime? lastAttemptAt,
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
      priority: priority ?? this.priority,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
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

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

/// Local SQLite database service for offline-first functionality
class DatabaseService {
  static DatabaseService? _instance;
  static Database? _database;

  DatabaseService._();

  static DatabaseService get instance {
    _instance ??= DatabaseService._();
    return _instance!;
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'dayco_commercial.db');

    return await openDatabase(
      path,
      version: _schemaVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// 2 added the queue's drain order and the document cache that lets the map
  /// open without a connection.
  static const int _schemaVersion = 2;

  Future<void> _onCreate(Database db, int version) async {
    // Clients table
    await db.execute('''
      CREATE TABLE clients (
        id TEXT PRIMARY KEY,
        businessName TEXT NOT NULL,
        contactPerson TEXT NOT NULL,
        phone TEXT NOT NULL,
        whatsapp TEXT,
        address TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        category INTEGER DEFAULT 1,
        paymentTerms INTEGER DEFAULT 0,
        creditLimit REAL DEFAULT 0,
        currentCredit REAL DEFAULT 0,
        lastVisitDate TEXT,
        visitFrequencyDays INTEGER DEFAULT 7,
        notes TEXT,
        profileImageUrl TEXT,
        isActive INTEGER DEFAULT 1,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        syncStatus TEXT DEFAULT 'pending'
      )
    ''');

    // Products table
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        reference TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        brand TEXT NOT NULL,
        category INTEGER DEFAULT 9,
        vehicleCompatibility TEXT,
        wholesalePrice REAL NOT NULL,
        retailPrice REAL NOT NULL,
        quantityInStock INTEGER DEFAULT 0,
        minStockAlert INTEGER DEFAULT 5,
        imageUrl TEXT,
        barcode TEXT,
        weight REAL,
        dimensions TEXT,
        isActive INTEGER DEFAULT 1,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    // Orders table
    await db.execute('''
      CREATE TABLE orders (
        id TEXT PRIMARY KEY,
        orderNumber TEXT NOT NULL,
        clientId TEXT NOT NULL,
        clientName TEXT NOT NULL,
        items TEXT NOT NULL,
        subtotal REAL NOT NULL,
        totalDiscount REAL DEFAULT 0,
        totalAmount REAL NOT NULL,
        status INTEGER DEFAULT 0,
        notes TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        syncStatus TEXT DEFAULT 'pending',
        createdByUserId TEXT NOT NULL,
        visitId TEXT,
        FOREIGN KEY (clientId) REFERENCES clients (id)
      )
    ''');

    // Visits table
    await db.execute('''
      CREATE TABLE visits (
        id TEXT PRIMARY KEY,
        clientId TEXT NOT NULL,
        clientName TEXT NOT NULL,
        clientAddress TEXT NOT NULL,
        clientLatitude REAL NOT NULL,
        clientLongitude REAL NOT NULL,
        status INTEGER DEFAULT 0,
        plannedDate TEXT NOT NULL,
        startTime TEXT,
        endTime TEXT,
        durationMinutes INTEGER,
        notes TEXT,
        orderIds TEXT,
        outcome TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        syncStatus TEXT DEFAULT 'pending',
        sortOrder INTEGER DEFAULT 0,
        FOREIGN KEY (clientId) REFERENCES clients (id)
      )
    ''');

    // Routes table
    await db.execute('''
      CREATE TABLE routes (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        date TEXT NOT NULL,
        status INTEGER DEFAULT 0,
        startLatitude REAL NOT NULL,
        startLongitude REAL NOT NULL,
        startAddress TEXT NOT NULL,
        endLatitude REAL,
        endLongitude REAL,
        endAddress TEXT,
        waypoints TEXT,
        totalDistance REAL DEFAULT 0,
        totalDuration INTEGER DEFAULT 0,
        polylinePoints TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        syncStatus TEXT DEFAULT 'pending'
      )
    ''');

    // Sync queue table
    await db.execute('''
      CREATE TABLE sync_queue (
        id TEXT PRIMARY KEY,
        entityType TEXT NOT NULL,
        entityId TEXT NOT NULL,
        action INTEGER NOT NULL,
        data TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        retryCount INTEGER DEFAULT 0,
        errorMessage TEXT,
        status INTEGER DEFAULT 1,
        priority INTEGER DEFAULT 50,
        lastAttemptAt TEXT
      )
    ''');

    await _createDocumentCache(db);

    // Visit notes table
    await db.execute('''
      CREATE TABLE visit_notes (
        id TEXT PRIMARY KEY,
        visitId TEXT NOT NULL,
        content TEXT NOT NULL,
        tag INTEGER DEFAULT 4,
        photoUrls TEXT,
        voiceNoteUrl TEXT,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (visitId) REFERENCES visits (id)
      )
    ''');

    // Create indexes for faster queries
    await db.execute('CREATE INDEX idx_clients_category ON clients (category)');
    await db.execute(
      'CREATE INDEX idx_clients_lastVisit ON clients (lastVisitDate)',
    );
    await db.execute(
      'CREATE INDEX idx_products_reference ON products (reference)',
    );
    await db.execute('CREATE INDEX idx_products_brand ON products (brand)');
    await db.execute('CREATE INDEX idx_orders_clientId ON orders (clientId)');
    await db.execute('CREATE INDEX idx_orders_status ON orders (status)');
    await db.execute('CREATE INDEX idx_visits_clientId ON visits (clientId)');
    await db.execute(
      'CREATE INDEX idx_visits_plannedDate ON visits (plannedDate)',
    );
    await db.execute(
      'CREATE INDEX idx_sync_queue_status ON sync_queue (status)',
    );
    await db.execute(
      'CREATE INDEX idx_sync_queue_order ON sync_queue (priority, createdAt)',
    );
  }

  /// Whole backend responses, kept as they came.
  ///
  /// Deliberately not a typed table per entity: what the map shows is the raw
  /// JSON the API returned, with fields that no local model has, and a commercial
  /// opening the app in a basement should see the same clients they saw an hour
  /// ago rather than a thinner copy of them. One row per collection, replaced
  /// whole on every successful load.
  Future<void> _createDocumentCache(Database db) async {
    await db.execute('''
      CREATE TABLE cached_documents (
        collection TEXT PRIMARY KEY,
        documents TEXT NOT NULL,
        fetchedAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // The queue was FIFO and measured its backoff from when the user did the
      // thing rather than from the last attempt; both are columns now.
      await db.execute(
        'ALTER TABLE sync_queue ADD COLUMN priority INTEGER DEFAULT 50',
      );
      await db.execute(
        'ALTER TABLE sync_queue ADD COLUMN lastAttemptAt TEXT',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sync_queue_order '
        'ON sync_queue (priority, createdAt)',
      );
      await _createDocumentCache(db);

      // Anything already queued was written with `Map.toString()` instead of
      // JSON (see [addToSyncQueue]) and cannot be parsed back into a payload,
      // so it could never have been sent. Dropping it is the only honest
      // option: there is nothing recoverable in `{a: 1, b: null}`.
      final dropped = await db.delete('sync_queue');
      if (dropped > 0) {
        debugPrint('Dropped $dropped queue items written in the old format.');
      }
    }
  }

  // ========== Client Operations ==========

  Future<int> insertClient(ClientModel client) async {
    final db = await database;
    return await db.insert(
      'clients',
      client.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ClientModel>> getAllClients() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'clients',
      where: 'isActive = ?',
      whereArgs: [1],
      orderBy: 'businessName ASC',
    );
    return List.generate(maps.length, (i) => ClientModel.fromJson(maps[i]));
  }

  Future<ClientModel?> getClientById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'clients',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return ClientModel.fromJson(maps.first);
    }
    return null;
  }

  Future<List<ClientModel>> getClientsByCategory(
    ClientCategory category,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'clients',
      where: 'category = ? AND isActive = ?',
      whereArgs: [category.index, 1],
      orderBy: 'businessName ASC',
    );
    return List.generate(maps.length, (i) => ClientModel.fromJson(maps[i]));
  }

  Future<List<ClientModel>> getClientsNeedingVisit() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'clients',
      where: 'isActive = ?',
      whereArgs: [1],
      orderBy: 'lastVisitDate ASC',
    );
    return List.generate(
      maps.length,
      (i) => ClientModel.fromJson(maps[i]),
    ).where((c) => c.needsVisit).toList();
  }

  Future<int> updateClient(ClientModel client) async {
    final db = await database;
    return await db.update(
      'clients',
      client.toJson(),
      where: 'id = ?',
      whereArgs: [client.id],
    );
  }

  Future<int> deleteClient(String id) async {
    final db = await database;
    return await db.update(
      'clients',
      {'isActive': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ========== Product Operations ==========

  Future<int> insertProduct(ProductModel product) async {
    final db = await database;
    final json = product.toJson();
    json['vehicleCompatibility'] = product.vehicleCompatibility.join(',');
    return await db.insert(
      'products',
      json,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ProductModel>> getAllProducts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'isActive = ?',
      whereArgs: [1],
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) {
      final json = Map<String, dynamic>.from(maps[i]);
      if (json['vehicleCompatibility'] != null) {
        json['vehicleCompatibility'] = (json['vehicleCompatibility'] as String)
            .split(',');
      }
      return ProductModel.fromJson(json);
    });
  }

  Future<List<ProductModel>> searchProducts(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where:
          'isActive = ? AND (reference LIKE ? OR name LIKE ? OR brand LIKE ?)',
      whereArgs: [1, '%$query%', '%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) {
      final json = Map<String, dynamic>.from(maps[i]);
      if (json['vehicleCompatibility'] != null) {
        json['vehicleCompatibility'] = (json['vehicleCompatibility'] as String)
            .split(',');
      }
      return ProductModel.fromJson(json);
    });
  }

  Future<List<ProductModel>> getProductsByCategory(
    ProductCategory category,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'category = ? AND isActive = ?',
      whereArgs: [category.index, 1],
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) {
      final json = Map<String, dynamic>.from(maps[i]);
      if (json['vehicleCompatibility'] != null) {
        json['vehicleCompatibility'] = (json['vehicleCompatibility'] as String)
            .split(',');
      }
      return ProductModel.fromJson(json);
    });
  }

  // ========== Order Operations ==========

  Future<int> insertOrder(OrderModel order) async {
    final db = await database;
    final json = order.toJson();
    json['items'] = order.items.map((e) => e.toJson()).toString();
    return await db.insert(
      'orders',
      json,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<OrderModel>> getOrdersByClient(String clientId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'orders',
      where: 'clientId = ?',
      whereArgs: [clientId],
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => OrderModel.fromJson(maps[i]));
  }

  Future<List<OrderModel>> getTodayOrders() async {
    final db = await database;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final List<Map<String, dynamic>> maps = await db.query(
      'orders',
      where: 'createdAt >= ? AND createdAt < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => OrderModel.fromJson(maps[i]));
  }

  // ========== Visit Operations ==========

  Future<int> insertVisit(VisitModel visit) async {
    final db = await database;
    final json = visit.toJson();
    json['notes'] = visit.notes.map((e) => e.toJson()).toString();
    json['orderIds'] = visit.orderIds.join(',');
    return await db.insert(
      'visits',
      json,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<VisitModel>> getTodayVisits() async {
    final db = await database;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final List<Map<String, dynamic>> maps = await db.query(
      'visits',
      where: 'plannedDate >= ? AND plannedDate < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'sortOrder ASC',
    );
    return List.generate(maps.length, (i) => VisitModel.fromJson(maps[i]));
  }

  Future<List<VisitModel>> getVisitsByClient(String clientId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'visits',
      where: 'clientId = ?',
      whereArgs: [clientId],
      orderBy: 'plannedDate DESC',
    );
    return List.generate(maps.length, (i) => VisitModel.fromJson(maps[i]));
  }

  Future<int> updateVisit(VisitModel visit) async {
    final db = await database;
    final json = visit.toJson();
    json['notes'] = visit.notes.map((e) => e.toJson()).toString();
    json['orderIds'] = visit.orderIds.join(',');
    return await db.update(
      'visits',
      json,
      where: 'id = ?',
      whereArgs: [visit.id],
    );
  }

  // ========== Route Operations ==========

  Future<int> insertRoute(RouteModel route) async {
    final db = await database;
    final json = route.toJson();
    json['waypoints'] = route.waypoints.map((e) => e.toJson()).toString();
    json['polylinePoints'] = route.polylinePoints
        .map((e) => '${e.latitude},${e.longitude}')
        .join(';');
    return await db.insert(
      'routes',
      json,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<RouteModel?> getActiveRoute() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'routes',
      where: 'status = ?',
      whereArgs: [RouteStatus.active.index],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return RouteModel.fromJson(maps.first);
    }
    return null;
  }

  // ========== Sync Queue Operations ==========

  /// The payload as a row: JSON, not `Map.toString()`.
  ///
  /// It used to be written with `toString()`, which produces `{a: 1, b: null}`
  /// — not parseable, not quoted, ambiguous about types, and impossible to read
  /// back into a payload. Nothing queued could ever have been sent.
  Map<String, dynamic> _toRow(SyncQueueItem item) {
    final row = item.toJson();
    row['data'] = jsonEncode(item.data);
    return row;
  }

  SyncQueueItem _fromRow(Map<String, dynamic> row) {
    final decoded = Map<String, dynamic>.from(row);
    final raw = row['data'];

    if (raw is String) {
      try {
        final parsed = jsonDecode(raw);
        decoded['data'] = parsed is Map
            ? Map<String, dynamic>.from(parsed)
            : <String, dynamic>{};
      } catch (error) {
        // A row from before the format was fixed, or a truncated write.
        debugPrint('Unreadable queue payload for ${row['id']}: $error');
        decoded['data'] = <String, dynamic>{};
      }
    }

    return SyncQueueItem.fromJson(decoded);
  }

  /// The order the queue is drained in: priority first, then the order the
  /// user did things. That second part is what keeps a record's create ahead
  /// of its own update.
  static const String _queueOrder = 'priority ASC, createdAt ASC';

  Future<int> addToSyncQueue(SyncQueueItem item) async {
    final db = await database;
    return await db.insert(
      'sync_queue',
      _toRow(item),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SyncQueueItem>> getPendingSyncItems() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sync_queue',
      where: 'status = ?',
      whereArgs: [SyncStatus.pending.index],
      orderBy: _queueOrder,
    );
    return List.generate(maps.length, (i) => _fromRow(maps[i]));
  }

  /// Everything still waiting, in drain order, whatever its status — what the
  /// pending sheet lists, including the items that have given up retrying.
  Future<List<SyncQueueItem>> getAllSyncItems() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sync_queue',
      orderBy: _queueOrder,
    );
    return List.generate(maps.length, (i) => _fromRow(maps[i]));
  }

  /// Points queued work at the id the backend gave a record.
  ///
  /// A record created offline is known locally as `local_…`; once its create
  /// lands, the edits and the photo queued behind it have to be aimed at the
  /// real id, or they would be sent against an id the backend has never seen.
  Future<int> remapQueueEntity({
    required String fromEntityId,
    required String toEntityId,
  }) async {
    if (fromEntityId == toEntityId || fromEntityId.isEmpty) {
      return 0;
    }

    final db = await database;
    return await db.update(
      'sync_queue',
      {'entityId': toEntityId},
      where: 'entityId = ?',
      whereArgs: [fromEntityId],
    );
  }

  /// Everything the sync service should attempt on this pass.
  ///
  /// This includes items that failed earlier but have retries left. Selecting
  /// only `pending` — as [getPendingSyncItems] does — strands an item forever
  /// the first time the network blips, because a failure moves it out of that
  /// status and nothing ever moves it back.
  Future<List<SyncQueueItem>> getSyncableItems({int maxRetries = 5}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sync_queue',
      where: 'status = ? OR (status = ? AND retryCount < ?)',
      whereArgs: [
        SyncStatus.pending.index,
        SyncStatus.failed.index,
        maxRetries,
      ],
      orderBy: _queueOrder,
    );
    return List.generate(maps.length, (i) => _fromRow(maps[i]));
  }

  Future<int> updateSyncItem(SyncQueueItem item) async {
    final db = await database;
    return await db.update(
      'sync_queue',
      _toRow(item),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteSyncItem(String id) async {
    final db = await database;
    return await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<SyncSummary> getSyncSummary() async {
    final db = await database;
    final pending =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM sync_queue WHERE status = ?',
            [SyncStatus.pending.index],
          ),
        ) ??
        0;
    final synced =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM sync_queue WHERE status = ?',
            [SyncStatus.synced.index],
          ),
        ) ??
        0;
    final failed =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM sync_queue WHERE status = ?',
            [SyncStatus.failed.index],
          ),
        ) ??
        0;
    final conflicts =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM sync_queue WHERE status = ?',
            [SyncStatus.conflict.index],
          ),
        ) ??
        0;

    return SyncSummary(
      totalPending: pending,
      totalSynced: synced,
      totalFailed: failed,
      totalConflicts: conflicts,
    );
  }

  // ========== Document Cache ==========

  /// Collections the map and its lists read.
  static const String collectionMyClients = 'my_clients';
  static const String collectionSubClients = 'sub_clients';

  /// Keeps the last good answer for a collection.
  ///
  /// Called only after a load succeeds, so a failed request can never replace
  /// good data with nothing.
  Future<void> cacheDocuments(
    String collection,
    List<Map<String, dynamic>> documents,
  ) async {
    try {
      final db = await database;
      await db.insert('cached_documents', {
        'collection': collection,
        'documents': jsonEncode(documents),
        'fetchedAt': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (error) {
      // A cache that cannot be written is a missed optimisation, not a reason
      // to fail the load that just succeeded.
      debugPrint('Could not cache $collection: $error');
    }
  }

  Future<List<Map<String, dynamic>>> readCachedDocuments(
    String collection,
  ) async {
    try {
      final db = await database;
      final rows = await db.query(
        'cached_documents',
        where: 'collection = ?',
        whereArgs: [collection],
        limit: 1,
      );

      if (rows.isEmpty) {
        return const [];
      }

      final decoded = jsonDecode(rows.first['documents'].toString());
      if (decoded is! List) {
        return const [];
      }

      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (error) {
      debugPrint('Could not read cached $collection: $error');
      return const [];
    }
  }

  /// When the collection was last pulled from the backend, so a screen can say
  /// how old what it is showing is instead of implying it is current.
  Future<DateTime?> cachedAt(String collection) async {
    try {
      final db = await database;
      final rows = await db.query(
        'cached_documents',
        columns: ['fetchedAt'],
        where: 'collection = ?',
        whereArgs: [collection],
        limit: 1,
      );

      if (rows.isEmpty) {
        return null;
      }

      return DateTime.tryParse(rows.first['fetchedAt'].toString());
    } catch (error) {
      return null;
    }
  }

  /// Empties the cache on sign-out. The queue is deliberately left alone: it
  /// holds work the user did that has not reached the backend yet, and
  /// dropping it would silently throw away a client they registered.
  Future<void> clearCachedDocuments() async {
    try {
      final db = await database;
      await db.delete('cached_documents');
    } catch (error) {
      debugPrint('Could not clear the document cache: $error');
    }
  }

  // ========== Utility Methods ==========

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('clients');
    await db.delete('products');
    await db.delete('orders');
    await db.delete('visits');
    await db.delete('routes');
    await db.delete('sync_queue');
    await db.delete('visit_notes');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}

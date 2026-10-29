import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The catalogue's manufacturer list, kept on the device.
///
/// `/stocks/admin/all` takes `page`, `size`, `search` and `entrepot` and
/// nothing else: there is no endpoint that lists marques, so the only way to
/// know which ones STDP carries is to read the catalogue and keep what it
/// said. Doing that on every launch would be absurd, so the answer is written
/// down here and the sweep only runs when it has gone stale.
///
/// It survives signing out, deliberately. A marque list is the catalogue's own
/// metadata — the same for every representative on every device — not somebody
/// else's clients or stock figures, and throwing it away would cost the next
/// person to sign in a full sweep before the marque filter worked.
@immutable
class StockMarqueIndex {
  const StockMarqueIndex({
    this.marques = const <String>[],
    this.isComplete = false,
    this.pagesRead = 0,
    this.totalPages = 0,
    this.builtAt,
  });

  /// Marques in the spelling the backend sent, deduplicated case-insensitively.
  final List<String> marques;

  /// Whether the sweep that produced this list reached the end of the
  /// catalogue. A partial list is still worth keeping and still worth
  /// offering — it just must not be presented as the whole of it.
  final bool isComplete;

  final int pagesRead;
  final int totalPages;

  /// When the sweep last wrote to this index, complete or not.
  final DateTime? builtAt;

  static const StockMarqueIndex empty = StockMarqueIndex();

  bool get isEmpty => marques.isEmpty;

  /// Whether the list is old enough to be worth sweeping for again. An
  /// incomplete one is always worth another attempt.
  bool isStale(Duration freshness) {
    if (!isComplete || builtAt == null) {
      return true;
    }
    return DateTime.now().difference(builtAt!) >= freshness;
  }

  Map<String, dynamic> toJson() => {
    'marques': marques,
    'isComplete': isComplete,
    'pagesRead': pagesRead,
    'totalPages': totalPages,
    'builtAt': builtAt?.toIso8601String(),
  };

  factory StockMarqueIndex.fromJson(Map<String, dynamic> json) {
    final raw = json['marques'];
    final marques = <String>[];

    if (raw is List) {
      for (final item in raw) {
        final name = item?.toString().trim() ?? '';
        if (name.isNotEmpty) {
          marques.add(name);
        }
      }
    }

    final builtAtRaw = json['builtAt']?.toString();

    return StockMarqueIndex(
      marques: marques,
      isComplete: json['isComplete'] == true,
      pagesRead: _asInt(json['pagesRead']),
      totalPages: _asInt(json['totalPages']),
      builtAt: builtAtRaw == null ? null : DateTime.tryParse(builtAtRaw),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

/// Reads and writes [StockMarqueIndex] in shared preferences.
///
/// Failures are swallowed on purpose: this is a cache in front of a sweep that
/// can always be run again, and a marque filter that falls back to the marques
/// in the loaded rows is a far better outcome than a screen that will not open.
class StockMarqueIndexStore {
  const StockMarqueIndexStore();

  static const String _key = 'commercial_stock_marque_index';

  Future<StockMarqueIndex> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) {
        return StockMarqueIndex.empty;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return StockMarqueIndex.empty;
      }

      return StockMarqueIndex.fromJson(Map<String, dynamic>.from(decoded));
    } catch (error) {
      debugPrint('Marque index unreadable, sweeping again: $error');
      return StockMarqueIndex.empty;
    }
  }

  Future<void> write(StockMarqueIndex index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(index.toJson()));
    } catch (error) {
      debugPrint('Marque index not saved: $error');
    }
  }
}

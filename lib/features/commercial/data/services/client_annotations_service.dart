import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A note a commercial pinned to a client, like a ticket on a wall.
class ClientNote {
  const ClientNote({
    required this.id,
    required this.clientId,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String clientId;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  ClientNote copyWith({String? title, String? body, DateTime? updatedAt}) {
    return ClientNote(
      id: id,
      clientId: clientId,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'clientId': clientId,
    'title': title,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  static ClientNote? fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    final clientId = json['clientId']?.toString();
    if (id == null || id.isEmpty || clientId == null || clientId.isEmpty) {
      return null;
    }

    final created =
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now();
    return ClientNote(
      id: id,
      clientId: clientId,
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      createdAt: created,
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? created,
    );
  }
}

/// A date a commercial wants to be reminded about a client.
class ClientReminder {
  const ClientReminder({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.region,
    required this.title,
    required this.context,
    required this.dueAt,
    required this.done,
  });

  final String id;
  final String clientId;

  /// Denormalised so the reminders list can render without reloading clients.
  final String clientName;
  final String region;

  final String title;
  final String context;
  final DateTime dueAt;
  final bool done;

  ClientReminder copyWith({
    String? title,
    String? context,
    DateTime? dueAt,
    bool? done,
  }) {
    return ClientReminder(
      id: id,
      clientId: clientId,
      clientName: clientName,
      region: region,
      title: title ?? this.title,
      context: context ?? this.context,
      dueAt: dueAt ?? this.dueAt,
      done: done ?? this.done,
    );
  }

  bool get isOverdue => !done && dueAt.isBefore(DateTime.now());

  Map<String, dynamic> toJson() => {
    'id': id,
    'clientId': clientId,
    'clientName': clientName,
    'region': region,
    'title': title,
    'context': context,
    'dueAt': dueAt.toIso8601String(),
    'done': done,
  };

  static ClientReminder? fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    final dueAt = DateTime.tryParse(json['dueAt']?.toString() ?? '');
    if (id == null || id.isEmpty || dueAt == null) return null;

    return ClientReminder(
      id: id,
      clientId: json['clientId']?.toString() ?? '',
      clientName: json['clientName']?.toString() ?? '',
      region: json['region']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      context: json['context']?.toString() ?? '',
      dueAt: dueAt,
      done: json['done'] == true,
    );
  }
}

/// Local store for notes and reminders.
///
/// There is no server endpoint for either, so they live on the device, in the
/// same SharedPreferences the client draft and the registered pins use. That
/// means they are per-device and are not backed up — worth knowing before
/// relying on them.
class ClientAnnotationsService {
  ClientAnnotationsService._();

  static final ClientAnnotationsService instance = ClientAnnotationsService._();

  static const String _notesKey = 'commercial_client_notes';
  static const String _remindersKey = 'commercial_client_reminders';

  Future<List<ClientNote>> loadNotes() async {
    final raw = await _readList(_notesKey);
    return raw.map(ClientNote.fromJson).whereType<ClientNote>().toList();
  }

  Future<void> saveNotes(List<ClientNote> notes) =>
      _writeList(_notesKey, notes.map((note) => note.toJson()).toList());

  Future<List<ClientReminder>> loadReminders() async {
    final raw = await _readList(_remindersKey);
    return raw
        .map(ClientReminder.fromJson)
        .whereType<ClientReminder>()
        .toList();
  }

  Future<void> saveReminders(List<ClientReminder> reminders) => _writeList(
    _remindersKey,
    reminders.map((reminder) => reminder.toJson()).toList(),
  );

  Future<List<Map<String, dynamic>>> _readList(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      return decoded.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      // Corrupt storage should not take the map down with it.
      return [];
    }
  }

  Future<void> _writeList(String key, List<Map<String, dynamic>> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(items));
    } catch (_) {
      // Nothing useful to do here; the in-memory list stays correct.
    }
  }
}

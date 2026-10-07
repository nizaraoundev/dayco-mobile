import 'package:flutter/material.dart';

/// Visit status
enum VisitStatus { planned, inProgress, completed, skipped, rescheduled }

/// Note tag types
enum NoteTag { payment, stock, complaint, promotion, general, followUp }

/// Visit Note Model
class VisitNoteModel {
  final String id;
  final String visitId;
  final String content;
  final NoteTag tag;
  final List<String> photoUrls;
  final String? voiceNoteUrl;
  final DateTime createdAt;

  VisitNoteModel({
    required this.id,
    required this.visitId,
    required this.content,
    this.tag = NoteTag.general,
    this.photoUrls = const [],
    this.voiceNoteUrl,
    required this.createdAt,
  });

  String get tagLabel {
    switch (tag) {
      case NoteTag.payment:
        return 'Paiement';
      case NoteTag.stock:
        return 'Stock';
      case NoteTag.complaint:
        return 'Réclamation';
      case NoteTag.promotion:
        return 'Promotion';
      case NoteTag.general:
        return 'Général';
      case NoteTag.followUp:
        return 'Suivi';
    }
  }

  Color get tagColor {
    switch (tag) {
      case NoteTag.payment:
        return const Color(0xFF009846); // Green
      case NoteTag.stock:
        return const Color(0xFF008DD2); // Blue
      case NoteTag.complaint:
        return const Color(0xFFE31E24); // Red
      case NoteTag.promotion:
        return const Color(0xFFFBCB07); // Yellow
      case NoteTag.general:
        return const Color(0xFF626D77); // Gray
      case NoteTag.followUp:
        return const Color(0xFF7ED6C9); // Teal
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'visitId': visitId,
      'content': content,
      'tag': tag.index,
      'photoUrls': photoUrls,
      'voiceNoteUrl': voiceNoteUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory VisitNoteModel.fromJson(Map<String, dynamic> json) {
    return VisitNoteModel(
      id: json['id'],
      visitId: json['visitId'],
      content: json['content'],
      tag: NoteTag.values[json['tag'] ?? 4],
      photoUrls: json['photoUrls'] != null
          ? List<String>.from(json['photoUrls'])
          : [],
      voiceNoteUrl: json['voiceNoteUrl'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

/// Visit Model - Track visits to B2B clients
class VisitModel {
  final String id;
  final String clientId;
  final String clientName;
  final String clientAddress;
  final double clientLatitude;
  final double clientLongitude;
  final VisitStatus status;
  final DateTime plannedDate;
  final DateTime? startTime;
  final DateTime? endTime;
  final int? durationMinutes;
  final List<VisitNoteModel> notes;
  final List<String> orderIds; // Orders created during this visit
  final String? outcome; // Brief summary
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? syncStatus;
  final int sortOrder; // For route ordering

  VisitModel({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.clientAddress,
    required this.clientLatitude,
    required this.clientLongitude,
    this.status = VisitStatus.planned,
    required this.plannedDate,
    this.startTime,
    this.endTime,
    this.durationMinutes,
    this.notes = const [],
    this.orderIds = const [],
    this.outcome,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = 'pending',
    this.sortOrder = 0,
  });

  /// Get status label in French
  String get statusLabel {
    switch (status) {
      case VisitStatus.planned:
        return 'Planifiée';
      case VisitStatus.inProgress:
        return 'En cours';
      case VisitStatus.completed:
        return 'Terminée';
      case VisitStatus.skipped:
        return 'Reportée';
      case VisitStatus.rescheduled:
        return 'Reprogrammée';
    }
  }

  /// Get status color
  Color get statusColor {
    switch (status) {
      case VisitStatus.planned:
        return const Color(0xFF008DD2); // Blue
      case VisitStatus.inProgress:
        return const Color(0xFFFBCB07); // Yellow
      case VisitStatus.completed:
        return const Color(0xFF009846); // Green
      case VisitStatus.skipped:
        return const Color(0xFFE31E24); // Red
      case VisitStatus.rescheduled:
        return const Color(0xFF7ED6C9); // Teal
    }
  }

  /// Check if visit is today
  bool get isToday {
    final now = DateTime.now();
    return plannedDate.year == now.year &&
        plannedDate.month == now.month &&
        plannedDate.day == now.day;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clientId': clientId,
      'clientName': clientName,
      'clientAddress': clientAddress,
      'clientLatitude': clientLatitude,
      'clientLongitude': clientLongitude,
      'status': status.index,
      'plannedDate': plannedDate.toIso8601String(),
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'durationMinutes': durationMinutes,
      'notes': notes.map((e) => e.toJson()).toList(),
      'orderIds': orderIds,
      'outcome': outcome,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'syncStatus': syncStatus,
      'sortOrder': sortOrder,
    };
  }

  factory VisitModel.fromJson(Map<String, dynamic> json) {
    return VisitModel(
      id: json['id'],
      clientId: json['clientId'],
      clientName: json['clientName'],
      clientAddress: json['clientAddress'],
      clientLatitude: (json['clientLatitude'] ?? 0).toDouble(),
      clientLongitude: (json['clientLongitude'] ?? 0).toDouble(),
      status: VisitStatus.values[json['status'] ?? 0],
      plannedDate: DateTime.parse(json['plannedDate']),
      startTime: json['startTime'] != null
          ? DateTime.parse(json['startTime'])
          : null,
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      durationMinutes: json['durationMinutes'],
      notes: json['notes'] != null
          ? (json['notes'] as List)
                .map((e) => VisitNoteModel.fromJson(e))
                .toList()
          : [],
      orderIds: json['orderIds'] != null
          ? List<String>.from(json['orderIds'])
          : [],
      outcome: json['outcome'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      syncStatus: json['syncStatus'] ?? 'pending',
      sortOrder: json['sortOrder'] ?? 0,
    );
  }

  VisitModel copyWith({
    String? id,
    String? clientId,
    String? clientName,
    String? clientAddress,
    double? clientLatitude,
    double? clientLongitude,
    VisitStatus? status,
    DateTime? plannedDate,
    DateTime? startTime,
    DateTime? endTime,
    int? durationMinutes,
    List<VisitNoteModel>? notes,
    List<String>? orderIds,
    String? outcome,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? syncStatus,
    int? sortOrder,
  }) {
    return VisitModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      clientAddress: clientAddress ?? this.clientAddress,
      clientLatitude: clientLatitude ?? this.clientLatitude,
      clientLongitude: clientLongitude ?? this.clientLongitude,
      status: status ?? this.status,
      plannedDate: plannedDate ?? this.plannedDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      notes: notes ?? this.notes,
      orderIds: orderIds ?? this.orderIds,
      outcome: outcome ?? this.outcome,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

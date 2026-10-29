import 'package:flutter/material.dart';

import '../../../../core/theme/app_gradients.dart';

/// The three kinds of record a commercial can create.
///
/// A prospect is a sub-client with no parent yet, which is why the API models
/// both as sub-clients; for the person using the app they are different things,
/// so they get their own entry here.
enum ClientKind { b2b, subClient, prospect }

/// Single source of truth for what colour each kind of client is drawn in.
///
/// The same colour has to appear on the speed-dial button that creates the
/// record, on the form header while it is filled in, and on the map pin
/// afterwards — otherwise the colour teaches the user nothing.
class ClientPalette {
  ClientPalette._();

  /// Direct B2B clients keep the product blue: they are the baseline.
  static const Color b2b = Color(0xFF008DD2);

  /// Prospects are mustard — warm, clearly not the blue of a signed client.
  static const Color prospect = Color(0xFFD4A017);

  /// Used when a sub-client's parent is unknown.
  static const Color subClientFallback = Color(0xFF7C3AED);

  /// Sub-clients are coloured by the parent they hang off, so a commercial can
  /// read a parent's network off the map at a glance. Blues and mustards are
  /// deliberately absent so groups never read as "client" or "prospect".
  static const List<Color> subClientGroups = [
    Color(0xFFE11D48), // rose
    Color(0xFF7C3AED), // violet
    Color(0xFF059669), // emerald
    Color(0xFFEA580C), // orange
    Color(0xFFDB2777), // pink
    Color(0xFF0D9488), // teal
    Color(0xFF92400E), // brown
    Color(0xFF65A30D), // lime
  ];

  /// Stable per-parent colour: the same parent always gets the same one,
  /// across sessions and devices, because it is derived from the id itself.
  static Color subClientColor(String? parentId) {
    final id = parentId?.trim() ?? '';
    if (id.isEmpty) return subClientFallback;

    var hash = 0;
    for (final unit in id.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return subClientGroups[hash % subClientGroups.length];
  }

  static Color forKind(ClientKind kind, {String? parentId}) {
    switch (kind) {
      case ClientKind.b2b:
        return b2b;
      case ClientKind.prospect:
        return prospect;
      case ClientKind.subClient:
        return subClientColor(parentId);
    }
  }

  /// Maps the controller's own vocabulary onto a colour.
  ///
  /// Accepts both the form's `registrationType` values and the API's `type`
  /// values, since markers are built from one and the form from the other.
  /// A point dropped on the map before any kind has been chosen.
  static const Color pending = Color(0xFF64748B);

  static Color forType(String type, {String? parentId}) {
    switch (type.toLowerCase()) {
      case 'pending':
        return pending;
      case 'prospect':
        return prospect;
      case 'sous_client':
      case 'sub_client':
        return subClientColor(parentId);
      default:
        return b2b;
    }
  }

  /// Every surface that carries a kind's colour uses this, so the gradient
  /// direction and strength stay consistent.
  ///
  /// The formula moved to [AppGradients.fromColor] so stock levels and order
  /// statuses derive theirs identically; this stays as the name the client UI
  /// already calls.
  static LinearGradient gradient(Color color) => AppGradients.fromColor(color);

  static String label(ClientKind kind) {
    switch (kind) {
      case ClientKind.b2b:
        return 'Client B2B';
      case ClientKind.subClient:
        return 'Sous-client';
      case ClientKind.prospect:
        return 'Prospect';
    }
  }

  static IconData icon(ClientKind kind) {
    switch (kind) {
      case ClientKind.b2b:
        return Icons.business_outlined;
      case ClientKind.subClient:
        return Icons.account_tree_outlined;
      case ClientKind.prospect:
        return Icons.lightbulb_outline;
    }
  }
}

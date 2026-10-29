import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/commercial_order_models.dart';

/// Single source of truth for how an order status is drawn.
///
/// Laid out like [StockPalette] and [ClientPalette] so the three features read
/// the same way side by side. The colours follow the lifecycle rather than the
/// alphabet: waiting is amber, moving is blue, done is green, dead is red —
/// which is what a commercial scans a list of orders for.
class OrderPalette {
  OrderPalette._();

  /// Not sent yet: nothing has happened to it.
  static const Color brouillon = Color(0xFF9AA5AF);

  /// Waiting on someone: the one status that is a call to action.
  static const Color enAttente = Color(0xFFD4A017);

  /// Accepted, and on its way through: validated, confirmed, being prepared,
  /// shipped. All four are "moving", so they share a colour and are told apart
  /// by their label.
  static const Color enCours = Color(0xFF2F80ED);

  /// Delivered.
  static const Color livree = ColorManager.successColor;

  /// Cancelled.
  static const Color annulee = ColorManager.errorColor;

  /// A status this app has not been taught. Drawn as plain text so it is
  /// legible without pretending to mean anything.
  static const Color unknown = Color(0xFF9AA5AF);

  static Color forStatus(CommercialOrderStatus status) {
    switch (status) {
      case CommercialOrderStatus.brouillon:
        return brouillon;
      case CommercialOrderStatus.enAttente:
        return enAttente;
      case CommercialOrderStatus.validee:
      case CommercialOrderStatus.confirmee:
      case CommercialOrderStatus.reservee:
      case CommercialOrderStatus.enPreparation:
      case CommercialOrderStatus.expediee:
        return enCours;
      case CommercialOrderStatus.livree:
        return livree;
      case CommercialOrderStatus.annulee:
        return annulee;
      case CommercialOrderStatus.unknown:
        return unknown;
    }
  }

  /// The label for a status, in the French the rest of the app speaks.
  static String labelFor(CommercialOrderStatus status) {
    switch (status) {
      case CommercialOrderStatus.brouillon:
        return 'Brouillon';
      case CommercialOrderStatus.enAttente:
        return 'En attente';
      case CommercialOrderStatus.validee:
        return 'Validée';
      case CommercialOrderStatus.confirmee:
        return 'Confirmée';
      case CommercialOrderStatus.reservee:
        return 'Réservée';
      case CommercialOrderStatus.enPreparation:
        return 'En préparation';
      case CommercialOrderStatus.expediee:
        return 'Expédiée';
      case CommercialOrderStatus.livree:
        return 'Livrée';
      case CommercialOrderStatus.annulee:
        return 'Annulée';
      case CommercialOrderStatus.unknown:
        return 'Statut inconnu';
    }
  }

  /// The statuses offered as filters, in lifecycle order. [unknown] is left
  /// out: the backend has no such value to filter on.
  static const List<CommercialOrderStatus> filterable = [
    CommercialOrderStatus.enAttente,
    CommercialOrderStatus.validee,
    CommercialOrderStatus.confirmee,
    CommercialOrderStatus.enPreparation,
    CommercialOrderStatus.expediee,
    CommercialOrderStatus.livree,
    CommercialOrderStatus.annulee,
  ];
}

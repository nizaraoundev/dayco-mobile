import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/commercial_stock_models.dart';

/// Single source of truth for how a stock level is drawn.
///
/// The same three colours have to read the same way on the filter chips, on
/// the available-quantity figure of a card, on that card's level bar and in
/// the availability result — otherwise the colour teaches the user nothing.
/// Laid out like [ClientPalette] so both features stay legible side by side.
class StockPalette {
  StockPalette._();

  /// Comfortably in stock: the environmental green already used for success.
  static const Color inStock = ColorManager.successColor;

  /// Running low — the same mustard prospects wear on the map, so "needs
  /// attention" looks the same wherever it appears.
  static const Color low = Color(0xFFD4A017);

  /// Nothing left to sell today, but a resupply is announced. Blue rather
  /// than red: it is information, not a dead end, and it must not be mistaken
  /// for the one level a commercial cannot promise at all.
  static const Color incoming = Color(0xFF2F80ED);

  /// Nothing left to sell.
  static const Color out = ColorManager.errorColor;

  /// The share of a level bar already promised to a client's order.
  static const Color reserved = Color(0xFF9AA5AF);

  /// The rest of a level bar: counted in the total, yet neither available nor
  /// reserved.
  static const Color track = Color(0xFFE6E9EC);

  static Color forLevel(StockLevel level) {
    switch (level) {
      case StockLevel.inStock:
        return inStock;
      case StockLevel.low:
        return low;
      case StockLevel.incoming:
        return incoming;
      case StockLevel.out:
        return out;
    }
  }

  static String labelFor(StockLevel level) {
    switch (level) {
      case StockLevel.inStock:
        return 'EN STOCK';
      case StockLevel.low:
        return 'STOCK FAIBLE';
      case StockLevel.incoming:
        return 'EN ARRIVAGE';
      case StockLevel.out:
        return 'HORS STOCK';
    }
  }
}

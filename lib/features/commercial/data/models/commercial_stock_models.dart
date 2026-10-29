/// How much of a reference is left, as the stock screen reads it.
///
/// These mirror the backend's own `statut` values — `EN_STOCK`,
/// `EN_ARRIVAGE`, `HORS_STOCK` — with [low] added on top of `EN_STOCK` for a
/// quantity that has fallen to the row's own alert threshold. [incoming] is
/// what nothing-left becomes once a resupply is announced, which is the one
/// thing a commercial still has to know about a reference they cannot sell
/// today.
enum StockLevel { inStock, low, incoming, out }

class CommercialStockItem {
  final String? produitId;
  final String referenceProduit;
  final String designationProduit;
  final String fabricant;
  final double prixHt;
  final int quantite;
  final int quantiteReservee;
  final int quantiteDisponible;

  /// Per-reference threshold below which the quantity counts as low. The
  /// backend sets it per row, so it is read rather than guessed at.
  final int seuilAlerte;

  final bool enArrivage;
  final int quantiteArrivage;
  final int? delaiReapprovisionnementJours;
  final String? datePrevisionDisponibilite;
  final String statut;
  final String? entrepot;

  CommercialStockItem({
    required this.produitId,
    required this.referenceProduit,
    required this.designationProduit,
    required this.fabricant,
    required this.prixHt,
    required this.quantite,
    required this.quantiteReservee,
    required this.quantiteDisponible,
    required this.seuilAlerte,
    required this.enArrivage,
    required this.quantiteArrivage,
    required this.delaiReapprovisionnementJours,
    required this.datePrevisionDisponibilite,
    required this.statut,
    this.entrepot,
  });

  factory CommercialStockItem.fromJson(Map<String, dynamic> json) {
    return CommercialStockItem(
      produitId: _safeString(json['produitId']) ?? _safeString(json['id']),
      referenceProduit: _safeString(json['referenceProduit']) ?? '',
      designationProduit: _safeString(json['designationProduit']) ?? '',
      fabricant: _safeString(json['fabricant']) ?? '-',
      prixHt: _safeDouble(json['prixHT']),
      quantite: _safeInt(json['quantite']),
      quantiteReservee: _safeInt(json['quantiteReservee']),
      quantiteDisponible: _safeInt(json['quantiteDisponible']),
      seuilAlerte: _safeInt(json['seuilAlerte']),
      // Read under three spellings, as the B2B web client does: the backend
      // has returned this one as `enArrivage`, `enarrivage` and `EnArrivage`,
      // and a case that slips through would read as "nothing on the way".
      enArrivage:
          _safeBool(json['enArrivage']) ??
          _safeBool(json['enarrivage']) ??
          _safeBool(json['EnArrivage']) ??
          false,
      quantiteArrivage: _safeInt(json['quantiteArrivage']),
      delaiReapprovisionnementJours:
          json['delaiReapprovisionnementJours'] == null
          ? null
          : _safeInt(json['delaiReapprovisionnementJours']),
      datePrevisionDisponibilite: _safeString(
        json['datePrevisionDisponibilite'],
      ),
      // The backend's own default when it has nothing to say about a row.
      statut: _safeString(json['statut']) ?? 'HORS_STOCK',
      entrepot: _safeString(json['entrepot']),
    );
  }

  /// Fallback for a row the backend set no [seuilAlerte] on.
  static const int defaultLowStockThreshold = 5;

  /// The threshold this row is judged low against.
  int get lowStockThreshold =>
      seuilAlerte > 0 ? seuilAlerte : defaultLowStockThreshold;

  /// Whether a resupply is announced for this reference.
  ///
  /// Any of the three things the backend can say it with: the status, the
  /// flag, or a quantity on route. The delay and the forecast date are
  /// deliberately not part of this test — they are filled on plenty of rows
  /// that are simply in stock, so treating them as the signal would mark half
  /// the catalogue as arriving.
  bool get isEnArrivage {
    if (statut.toUpperCase().trim() == 'EN_ARRIVAGE') {
      return true;
    }
    return enArrivage || quantiteArrivage > 0;
  }

  /// The level the stock screen reads.
  ///
  /// The quantity is checked before [statut], not after: the backend has been
  /// seen reporting a reference as available when its available quantity had
  /// already reached zero, and a commercial quoting from that would promise
  /// stock that is not there.
  StockLevel get level {
    final normalized = statut.toUpperCase().trim();

    if (quantiteDisponible <= 0 ||
        normalized == 'HORS_STOCK' ||
        normalized.contains('RUPTURE')) {
      // Nothing to sell today, but "back in four days" and "do not promise
      // this one" are different answers to give a client.
      return isEnArrivage ? StockLevel.incoming : StockLevel.out;
    }

    if (quantiteDisponible <= lowStockThreshold) {
      return StockLevel.low;
    }

    return StockLevel.inStock;
  }
}

class CommercialStockPageResponse {
  final List<CommercialStockItem> content;
  final int totalElements;
  final int totalPages;
  final int size;
  final int number;

  CommercialStockPageResponse({
    required this.content,
    required this.totalElements,
    required this.totalPages,
    required this.size,
    required this.number,
  });

  factory CommercialStockPageResponse.fromJson(Map<String, dynamic> json) {
    final rawContent = json['content'];
    final content = <CommercialStockItem>[];

    if (rawContent is List) {
      for (final item in rawContent) {
        if (item is Map) {
          content.add(
            CommercialStockItem.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    return CommercialStockPageResponse(
      content: content,
      totalElements: _safeInt(json['totalElements']),
      totalPages: _safeInt(json['totalPages']),
      size: _safeInt(json['size']),
      number: _safeInt(json['number']),
    );
  }
}

class CommercialStockProductDetails {
  final String? produitId;
  final String? referenceProduit;
  final String? designationProduit;

  CommercialStockProductDetails({
    required this.produitId,
    required this.referenceProduit,
    required this.designationProduit,
  });

  factory CommercialStockProductDetails.fromJson(Map<String, dynamic> json) {
    return CommercialStockProductDetails(
      produitId: _safeString(json['produitId']) ?? _safeString(json['id']),
      referenceProduit: _safeString(json['referenceProduit']),
      designationProduit: _safeString(json['designationProduit']),
    );
  }
}

/// The stock figures the backend totals itself, from
/// `/api/v1/stocks/admin/stats`.
///
/// Worth one request rather than counting rows on this side: these are counts
/// over the whole catalogue, which a paged list could only ever approximate.
class CommercialStockStats {
  final int totalProduits;
  final int produitsDisponibles;
  final int produitsEnAlerte;
  final int produitsCritiques;
  final int produitsRupture;
  final int produitsEnArrivage;
  final double valeurTotaleStockHt;
  final int totalMouvementsAujourdhui;
  final int totalEntreesAujourdhui;
  final int totalSortiesAujourdhui;

  const CommercialStockStats({
    required this.totalProduits,
    required this.produitsDisponibles,
    required this.produitsEnAlerte,
    required this.produitsCritiques,
    required this.produitsRupture,
    required this.produitsEnArrivage,
    required this.valeurTotaleStockHt,
    required this.totalMouvementsAujourdhui,
    required this.totalEntreesAujourdhui,
    required this.totalSortiesAujourdhui,
  });

  /// What a dashboard shows before the call has answered, and what it falls
  /// back to if the call is refused: zeroes, which read as "nothing to
  /// report" rather than as invented figures.
  static const CommercialStockStats empty = CommercialStockStats(
    totalProduits: 0,
    produitsDisponibles: 0,
    produitsEnAlerte: 0,
    produitsCritiques: 0,
    produitsRupture: 0,
    produitsEnArrivage: 0,
    valeurTotaleStockHt: 0,
    totalMouvementsAujourdhui: 0,
    totalEntreesAujourdhui: 0,
    totalSortiesAujourdhui: 0,
  );

  factory CommercialStockStats.fromJson(Map<String, dynamic> json) {
    return CommercialStockStats(
      totalProduits: _safeInt(json['totalProduits']),
      produitsDisponibles: _safeInt(json['produitsDisponibles']),
      produitsEnAlerte: _safeInt(json['produitsEnAlerte']),
      produitsCritiques: _safeInt(json['produitsCritiques']),
      produitsRupture: _safeInt(json['produitsRupture']),
      produitsEnArrivage: _safeInt(json['produitsEnArrivage']),
      valeurTotaleStockHt: _safeDouble(json['valeurTotaleStockHT']),
      totalMouvementsAujourdhui: _safeInt(json['totalMouvementsAujourdhui']),
      totalEntreesAujourdhui: _safeInt(json['totalEntreesAujourdhui']),
      totalSortiesAujourdhui: _safeInt(json['totalSortiesAujourdhui']),
    );
  }
}

class CommercialPendingReservation {
  final String id;
  final String produitId;
  final String numeroCommande;
  final String clientId;
  final String clientRaisonSociale;
  final int quantiteInitiale;
  final int quantiteRestante;
  final String utilisateur;
  final String dateCreation;
  final String? dateSatisfaction;

  CommercialPendingReservation({
    required this.id,
    required this.produitId,
    required this.numeroCommande,
    required this.clientId,
    required this.clientRaisonSociale,
    required this.quantiteInitiale,
    required this.quantiteRestante,
    required this.utilisateur,
    required this.dateCreation,
    required this.dateSatisfaction,
  });

  factory CommercialPendingReservation.fromJson(Map<String, dynamic> json) {
    return CommercialPendingReservation(
      id: _safeString(json['id']) ?? '',
      produitId: _safeString(json['produitId']) ?? '',
      numeroCommande: _safeString(json['numeroCommande']) ?? '-',
      clientId: _safeString(json['clientId']) ?? '-',
      clientRaisonSociale: _safeString(json['clientRaisonSociale']) ?? '-',
      quantiteInitiale: _safeInt(json['quantiteInitiale']),
      quantiteRestante: _safeInt(json['quantiteRestante']),
      utilisateur: _safeString(json['utilisateur']) ?? '-',
      dateCreation: _safeString(json['dateCreation']) ?? '-',
      dateSatisfaction: _safeString(json['dateSatisfaction']),
    );
  }
}

String? _safeString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

/// Null when the key was absent or held something that is not a yes/no, so a
/// caller can try the next spelling instead of taking a default too early.
bool? _safeBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final text = value.trim().toLowerCase();
    if (text == 'true' || text == '1' || text == 'oui') return true;
    if (text == 'false' || text == '0' || text == 'non') return false;
  }
  return null;
}

int _safeInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double _safeDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

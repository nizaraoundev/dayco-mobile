/// Orders as the current backend returns them.
///
/// The names here are the backend's own (`statut`, `montantTTC`, `lignes`,
/// `numeroCommande`), not a translation of them, so that a field can be traced
/// to the payload it came from. The existing [OrderModel] in this folder is a
/// different thing: a local, offline-first order built for the sync service,
/// with its own English field names and an index-based status. Keeping the two
/// apart avoids a model that is half one contract and half the other.
library;

/// Where a record sits in the order lifecycle.
///
/// These are the exact strings `/api/v1/commandes` uses. [unknown] is not one
/// of them: it carries a value this app has not been taught, so an order the
/// backend adds a status for still lists and still reads correctly instead of
/// disappearing or crashing the page.
/// The quote-side statuses (`DEVIS_EN_COURS`, `DEVIS_ENVOYE`,
/// `DEVIS_ACCEPTE`, `DEVIS_REFUSE`, `DEVIS_EXPIRE`) are deliberately absent:
/// this screen lists orders, and anything unmapped falls to [unknown], which
/// displays what the backend said rather than guessing at it.
enum CommercialOrderStatus {
  brouillon,
  enAttente,
  validee,
  confirmee,
  reservee,
  enPreparation,
  expediee,
  livree,
  annulee,
  unknown,
}

/// Whether a record is an order or a quote. The same endpoints serve both and
/// the two are told apart by this field alone, so a list that means to show
/// orders has to say so.
enum CommercialOrderType { commande, devis, unknown }

/// How the client takes delivery.
///
/// The backend's create payload has no field for this: the B2B web client
/// writes it into `commentaire` as a sentence, and the address fields are only
/// sent for [livraisonStdDayco]. That is replicated rather than improved on —
/// a mode sent any other way would not reach whoever prepares the order.
enum CommercialDeliveryMode { livraisonStdDayco, receptionComptoir }

extension CommercialDeliveryModeX on CommercialDeliveryMode {
  String get raw {
    switch (this) {
      case CommercialDeliveryMode.livraisonStdDayco:
        return 'LIVRAISON_STD_DAYCO';
      case CommercialDeliveryMode.receptionComptoir:
        return 'RECEPTION_COMPTOIR_STDP_DAYCO';
    }
  }

  /// The wording the web client puts in the comment, kept identical so an
  /// order placed from the phone reads the same as one placed from the web.
  String get commentLabel {
    switch (this) {
      case CommercialDeliveryMode.livraisonStdDayco:
        return 'Livraison par STDP DAYCO';
      case CommercialDeliveryMode.receptionComptoir:
        return 'Réception au comptoir STDP DAYCO';
    }
  }

  /// The label for the picker.
  String get label {
    switch (this) {
      case CommercialDeliveryMode.livraisonStdDayco:
        return 'Livraison';
      case CommercialDeliveryMode.receptionComptoir:
        return 'Comptoir';
    }
  }

  bool get needsAddress => this == CommercialDeliveryMode.livraisonStdDayco;
}

/// One line of an order being written, before the backend has seen it.
///
/// Separate from [CommercialOrderLine], which is a line as it comes back: the
/// two carry different fields (`produitId` and the VAT rate go up, a line
/// total comes down) and only this one is mutable.
class CommercialOrderDraftLine {
  final String produitId;
  final String referenceProduit;
  final String designationProduit;
  final int quantite;
  final double prixUnitaireHt;
  final double remisePourcentage;

  CommercialOrderDraftLine({
    required this.produitId,
    required this.referenceProduit,
    required this.designationProduit,
    required this.quantite,
    required this.prixUnitaireHt,
    this.remisePourcentage = 0,
  });

  /// The VAT rate every line carries, as a percentage.
  ///
  /// The backend takes it per line rather than deriving it, and the web
  /// client's order path sends 19 — its quote path sends 0.19 for the same
  /// field, which cannot both be right. 19 is used here because that is what
  /// the order path does and what its own totals are computed with.
  static const double tauxTva = 19;

  double get totalHt =>
      prixUnitaireHt * quantite * (1 - remisePourcentage / 100);

  CommercialOrderDraftLine copyWith({
    int? quantite,
    double? remisePourcentage,
  }) {
    return CommercialOrderDraftLine(
      produitId: produitId,
      referenceProduit: referenceProduit,
      designationProduit: designationProduit,
      quantite: quantite ?? this.quantite,
      prixUnitaireHt: prixUnitaireHt,
      remisePourcentage: remisePourcentage ?? this.remisePourcentage,
    );
  }

  /// The keys are the backend's, exactly as the web client sends them.
  ///
  /// `produitId` is left out rather than sent empty when the stock row the
  /// line came from carried none: the reference is what the backend resolves
  /// a product by elsewhere, and an empty id is a value, not an absence.
  Map<String, dynamic> toJson() {
    return {
      if (produitId.trim().isNotEmpty) 'produitId': produitId.trim(),
      'referenceProduit': referenceProduit,
      'designationProduit': designationProduit,
      'quantite': quantite,
      'prixUnitaireHT': prixUnitaireHt,
      'tauxTVA': tauxTva,
      'remiseLignePourcentage': remisePourcentage,
    };
  }
}

class CommercialOrderLine {
  final String referenceProduit;
  final String designationProduit;
  final int quantite;
  final double prixUnitaireHt;
  final double remise;

  CommercialOrderLine({
    required this.referenceProduit,
    required this.designationProduit,
    required this.quantite,
    required this.prixUnitaireHt,
    required this.remise,
  });

  factory CommercialOrderLine.fromJson(Map<String, dynamic> json) {
    return CommercialOrderLine(
      referenceProduit: _safeString(json['referenceProduit']) ?? '-',
      designationProduit: _safeString(json['designationProduit']) ?? '',
      quantite: _safeInt(json['quantite']),
      prixUnitaireHt: _safeDouble(json['prixUnitaireHT']),
      remise: _safeDouble(json['remise']),
    );
  }

  /// What the line comes to after its discount. The backend returns no line
  /// total, so it is computed here rather than left for the widget to do.
  double get totalHt => prixUnitaireHt * quantite * (1 - remise / 100);
}

class CommercialOrder {
  final String id;
  final String numeroCommande;
  final CommercialOrderType type;
  final CommercialOrderStatus status;

  /// The status exactly as the backend spelled it, kept for the one case the
  /// enum cannot cover: showing a value this app does not know yet.
  final String statutRaw;

  final String clientRaisonSociale;
  final double montantHt;
  final double montantTtc;
  final String? dateCreation;
  final String? dateLivraisonSouhaitee;
  final String? modeLivraison;
  final List<CommercialOrderLine> lignes;

  CommercialOrder({
    required this.id,
    required this.numeroCommande,
    required this.type,
    required this.status,
    required this.statutRaw,
    required this.clientRaisonSociale,
    required this.montantHt,
    required this.montantTtc,
    required this.dateCreation,
    required this.dateLivraisonSouhaitee,
    required this.modeLivraison,
    required this.lignes,
  });

  factory CommercialOrder.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lignes'];
    final lignes = <CommercialOrderLine>[];

    if (rawLines is List) {
      for (final line in rawLines) {
        if (line is Map) {
          lignes.add(
            CommercialOrderLine.fromJson(Map<String, dynamic>.from(line)),
          );
        }
      }
    }

    final statut = _safeString(json['statut']) ?? '';

    return CommercialOrder(
      id: _safeString(json['id']) ?? '',
      numeroCommande: _safeString(json['numeroCommande']) ?? '-',
      type: _typeFromRaw(_safeString(json['type'])),
      status: statusFromRaw(statut),
      statutRaw: statut,
      clientRaisonSociale: _safeString(json['clientRaisonSociale']) ?? '-',
      montantHt: _safeDouble(json['montantHT']),
      montantTtc: _safeDouble(json['montantTTC']),
      dateCreation: _safeString(json['dateCreation']),
      dateLivraisonSouhaitee: _safeString(json['dateLivraisonSouhaitee']),
      modeLivraison: _safeString(json['modeLivraison']),
      lignes: lignes,
    );
  }

  /// Units ordered across every line.
  int get totalQuantite =>
      lignes.fold<int>(0, (sum, line) => sum + line.quantite);

  static CommercialOrderStatus statusFromRaw(String? raw) {
    switch ((raw ?? '').toUpperCase().trim()) {
      case 'BROUILLON':
        return CommercialOrderStatus.brouillon;
      case 'EN_ATTENTE':
        return CommercialOrderStatus.enAttente;
      case 'VALIDEE':
        return CommercialOrderStatus.validee;
      case 'CONFIRMEE':
        return CommercialOrderStatus.confirmee;
      case 'RESERVEE':
        return CommercialOrderStatus.reservee;
      case 'EN_PREPARATION':
        return CommercialOrderStatus.enPreparation;
      case 'EXPEDIEE':
        return CommercialOrderStatus.expediee;
      case 'LIVREE':
        return CommercialOrderStatus.livree;
      case 'ANNULEE':
        return CommercialOrderStatus.annulee;
      default:
        return CommercialOrderStatus.unknown;
    }
  }

  /// The string to send back when filtering on a status, or null for the one
  /// value that exists only on this side.
  static String? rawForStatus(CommercialOrderStatus status) {
    switch (status) {
      case CommercialOrderStatus.brouillon:
        return 'BROUILLON';
      case CommercialOrderStatus.enAttente:
        return 'EN_ATTENTE';
      case CommercialOrderStatus.validee:
        return 'VALIDEE';
      case CommercialOrderStatus.confirmee:
        return 'CONFIRMEE';
      case CommercialOrderStatus.reservee:
        return 'RESERVEE';
      case CommercialOrderStatus.enPreparation:
        return 'EN_PREPARATION';
      case CommercialOrderStatus.expediee:
        return 'EXPEDIEE';
      case CommercialOrderStatus.livree:
        return 'LIVREE';
      case CommercialOrderStatus.annulee:
        return 'ANNULEE';
      case CommercialOrderStatus.unknown:
        return null;
    }
  }

  static CommercialOrderType _typeFromRaw(String? raw) {
    switch ((raw ?? '').toUpperCase().trim()) {
      case 'COMMANDE':
        return CommercialOrderType.commande;
      case 'DEVIS':
        return CommercialOrderType.devis;
      default:
        return CommercialOrderType.unknown;
    }
  }
}

/// One page of orders, in the shape every paginated endpoint on this backend
/// uses. `pageable` is read before the flat fields because the orders
/// endpoints return both and the nested pair is the one that is always filled.
class CommercialOrderPageResponse {
  final List<CommercialOrder> content;
  final int totalElements;
  final int totalPages;
  final int number;
  final int size;

  CommercialOrderPageResponse({
    required this.content,
    required this.totalElements,
    required this.totalPages,
    required this.number,
    required this.size,
  });

  factory CommercialOrderPageResponse.fromJson(Map<String, dynamic> json) {
    final rawContent = json['content'];
    final content = <CommercialOrder>[];

    if (rawContent is List) {
      for (final item in rawContent) {
        if (item is Map) {
          content.add(
            CommercialOrder.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final pageable = json['pageable'];
    final pageableMap = pageable is Map
        ? Map<String, dynamic>.from(pageable)
        : const <String, dynamic>{};

    return CommercialOrderPageResponse(
      content: content,
      totalElements: _safeInt(json['totalElements']),
      totalPages: _safeInt(json['totalPages']),
      number: _safeInt(pageableMap['pageNumber'] ?? json['number']),
      size: _safeInt(pageableMap['pageSize'] ?? json['size']),
    );
  }
}

String? _safeString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int _safeInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double _safeDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

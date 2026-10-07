class CommercialStockItem {
  final String? produitId;
  final String referenceProduit;
  final String designationProduit;
  final String fabricant;
  final double prixHt;
  final int quantite;
  final int quantiteReservee;
  final int quantiteDisponible;
  final String statut;

  CommercialStockItem({
    required this.produitId,
    required this.referenceProduit,
    required this.designationProduit,
    required this.fabricant,
    required this.prixHt,
    required this.quantite,
    required this.quantiteReservee,
    required this.quantiteDisponible,
    required this.statut,
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
      statut: _safeString(json['statut']) ?? '-',
    );
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

class CommercialStockAvailability {
  final String? produitId;
  final int quantiteDemandee;
  final bool disponible;
  final int quantiteDisponible;
  final int? delaiReapprovisionnementJours;
  final String? datePrevisionDisponibilite;
  final String statut;
  final String message;

  CommercialStockAvailability({
    required this.produitId,
    required this.quantiteDemandee,
    required this.disponible,
    required this.quantiteDisponible,
    required this.delaiReapprovisionnementJours,
    required this.datePrevisionDisponibilite,
    required this.statut,
    required this.message,
  });

  factory CommercialStockAvailability.fromJson(Map<String, dynamic> json) {
    return CommercialStockAvailability(
      produitId: _safeString(json['produitId']) ?? _safeString(json['id']),
      quantiteDemandee: _safeInt(json['quantiteDemandee']),
      disponible: json['disponible'] == true,
      quantiteDisponible: _safeInt(json['quantiteDisponible']),
      delaiReapprovisionnementJours:
          json['delaiReapprovisionnementJours'] == null
          ? null
          : _safeInt(json['delaiReapprovisionnementJours']),
      datePrevisionDisponibilite: _safeString(
        json['datePrevisionDisponibilite'],
      ),
      statut: _safeString(json['statut']) ?? '-',
      message: _safeString(json['message']) ?? '',
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

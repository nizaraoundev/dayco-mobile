class ClientModel {
  final String? id;
  final String? codeClient;
  final String? nom;
  final String? raisonSociale;
  final String? matriculeFiscal;
  final String? telephone;
  final String? email;
  final double? remise;
  final String? commercialName;
  final String? commercialId;
  final String? boutiqueImagePath;
  final String? boutiqueImageUrl;
  final String? latitude;
  final String? longitude;

  ClientModel({
    this.id,
    this.codeClient,
    this.nom,
    this.raisonSociale,
    this.matriculeFiscal,
    this.telephone,
    this.email,
    this.remise,
    this.commercialName,
    this.commercialId,
    this.boutiqueImagePath,
    this.boutiqueImageUrl,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() {
    final trimmedId = id?.trim();
    final trimmedCodeClient = codeClient?.trim();
    final trimmedNom = nom?.trim();
    final trimmedRaisonSociale = raisonSociale?.trim();
    final trimmedMatriculeFiscal = matriculeFiscal?.trim();
    final trimmedTelephone = telephone?.trim();
    final trimmedEmail = email?.trim();
    final trimmedCommercialName = commercialName?.trim();
    final trimmedCommercialId = commercialId?.trim();
    final trimmedBoutiqueImagePath = boutiqueImagePath?.trim();
    final trimmedBoutiqueImageUrl = boutiqueImageUrl?.trim();
    final trimmedLatitude = latitude?.trim();
    final trimmedLongitude = longitude?.trim();
    final latitudeValue = trimmedLatitude == null
        ? null
        : double.tryParse(trimmedLatitude);
    final longitudeValue = trimmedLongitude == null
        ? null
        : double.tryParse(trimmedLongitude);

    return {
      if (trimmedId != null && trimmedId.isNotEmpty) 'id': trimmedId,
      if (trimmedCodeClient != null && trimmedCodeClient.isNotEmpty)
        'codeClient': trimmedCodeClient,
      if (trimmedNom != null && trimmedNom.isNotEmpty) 'nom': trimmedNom,
      if (trimmedRaisonSociale != null && trimmedRaisonSociale.isNotEmpty)
        'raisonSociale': trimmedRaisonSociale,
      if (trimmedMatriculeFiscal != null && trimmedMatriculeFiscal.isNotEmpty)
        'matriculeFiscal': trimmedMatriculeFiscal,
      if (trimmedTelephone != null && trimmedTelephone.isNotEmpty)
        'telephone': trimmedTelephone,
      if (trimmedEmail != null && trimmedEmail.isNotEmpty)
        'email': trimmedEmail,
      if (remise != null) 'remise': remise,
      if (trimmedCommercialName != null && trimmedCommercialName.isNotEmpty)
        'commercialName': trimmedCommercialName,
      if (trimmedCommercialId != null && trimmedCommercialId.isNotEmpty)
        'commercialId': trimmedCommercialId,
      if (trimmedBoutiqueImagePath != null &&
          trimmedBoutiqueImagePath.isNotEmpty)
        'boutiqueImagePath': trimmedBoutiqueImagePath,
      if (trimmedBoutiqueImageUrl != null && trimmedBoutiqueImageUrl.isNotEmpty)
        'boutiqueImageUrl': trimmedBoutiqueImageUrl,
      if (latitudeValue != null)
        'latitude': latitudeValue
      else if (trimmedLatitude != null && trimmedLatitude.isNotEmpty)
        'latitude': trimmedLatitude,
      if (longitudeValue != null)
        'longitude': longitudeValue
      else if (trimmedLongitude != null && trimmedLongitude.isNotEmpty)
        'longitude': trimmedLongitude,
    };
  }

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    return ClientModel(
      id: json['id']?.toString(),
      codeClient: json['codeClient'],
      nom: json['nom']?.toString(),
      raisonSociale: json['raisonSociale'] ?? '',
      matriculeFiscal: json['matriculeFiscal'] ?? '',
      telephone: json['telephone'] ?? '',
      email: json['email'] ?? '',
      remise: (json['remise'] as num?)?.toDouble(),
      commercialName: json['commercialName']?.toString(),
      commercialId: json['commercialId']?.toString(),
      boutiqueImagePath: json['boutiqueImagePath']?.toString(),
      boutiqueImageUrl: json['boutiqueImageUrl']?.toString(),
      latitude: json['latitude']?.toString(),
      longitude: json['longitude']?.toString(),
    );
  }
}

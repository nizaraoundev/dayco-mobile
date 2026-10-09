import '../../../../core/network/json_coercion.dart';
import '../../domain/entities/client.dart';
import '../../domain/entities/geo_position.dart';

/// Translates between the backend's loose JSON and the [Client] entity.
///
/// All the field-name tolerance the previous implementation spread across the
/// map controller, the client cards and the list tiles is consolidated here.
abstract final class ClientMapper {
  const ClientMapper._();

  /// Reads a record from `/api/v1/clients*`.
  static Client fromClientJson(Map<String, dynamic> json) =>
      _fromJson(json, fromSubClientEndpoint: false);

  /// Reads a record from `/api/v1/sub-clients*`.
  static Client fromSubClientJson(Map<String, dynamic> json) =>
      _fromJson(json, fromSubClientEndpoint: true);

  static Client _fromJson(
    Map<String, dynamic> json, {
    required bool fromSubClientEndpoint,
  }) {
    final parentIds = JsonCoercion.stringList(json['parentClientIds']);

    var kind = ClientKind.fromBackend(
      JsonCoercion.string(json['type']),
      fromSubClientEndpoint: fromSubClientEndpoint,
    );

    // The backend derives sub-client vs prospect from parentage. When `type` is
    // missing or stale, parentage is the authoritative signal, so trust it.
    if (kind.usesSubClientApi) {
      kind = parentIds.isEmpty ? ClientKind.prospect : ClientKind.subClient;
    }

    return Client(
      // Creation responses return the new identifier as `id` on the
      // sub-client endpoint but as `userId` on the B2B registration endpoint.
      id: JsonCoercion.firstString(json, const ['id', 'userId', '_id']),
      kind: kind,
      codeClient: JsonCoercion.string(json['codeClient']),
      raisonSociale: JsonCoercion.string(json['raisonSociale']),
      matriculeFiscal: JsonCoercion.string(json['matriculeFiscal']),
      nom: JsonCoercion.string(json['nom']),
      prenom: JsonCoercion.string(json['prenom']),
      nomAgence: JsonCoercion.string(json['nomAgence']),
      telephone: JsonCoercion.string(json['telephone']),
      email: JsonCoercion.string(json['email']),
      note: JsonCoercion.string(json['note']),
      remise: JsonCoercion.toDouble(json['remise']),
      commercialId: JsonCoercion.string(json['commercialId']),
      commercialName: JsonCoercion.string(json['commercialName']),
      imagePath: JsonCoercion.firstString(json, const [
        'boutiqueImagePath',
        'boutiqueImageUrl',
        'imagePath',
        'imageUrl',
        'image',
      ]),
      position: GeoPosition.tryCreate(
        JsonCoercion.toDouble(json['latitude']),
        JsonCoercion.toDouble(json['longitude']),
      ),
      parentClientIds: parentIds,
      brands: _readBrands(json),
      raw: json,
    );
  }

  /// Reads `marques`, which has historically been written in two different
  /// representations (see [brandsToPayload]), so both are accepted.
  static List<String> _readBrands(Map<String, dynamic> json) {
    final marques = json['marques'];
    if (marques is List) return JsonCoercion.stringList(marques);
    if (marques is String && marques.trim().isNotEmpty) {
      return marques.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  // ------------------------------------------------------------------ writing

  /// Builds the body for `POST /api/v1/auth/register/client`.
  ///
  /// Only non-empty fields are included, matching the original behaviour — the
  /// backend treats an explicit empty string differently from an absent key.
  /// `latitude`/`longitude` are sent as **strings** here, as the original B2B
  /// payload did; the sub-client payload sends them as numbers. That asymmetry
  /// is the backend's, and is preserved deliberately.
  static Map<String, dynamic> toB2bCreatePayload({
    required GeoPosition position,
    String codeClient = '',
    String raisonSociale = '',
    String matriculeFiscal = '',
    String telephone = '',
    String email = '',
    String commercialId = '',
    String commercialName = '',
  }) {
    return <String, dynamic>{
      'latitude': position.latitude.toString(),
      'longitude': position.longitude.toString(),
      if (codeClient.trim().isNotEmpty) 'codeClient': codeClient.trim(),
      if (raisonSociale.trim().isNotEmpty) 'raisonSociale': raisonSociale.trim(),
      if (matriculeFiscal.trim().isNotEmpty)
        'matriculeFiscal': matriculeFiscal.trim(),
      if (telephone.trim().isNotEmpty) 'telephone': telephone.trim(),
      if (email.trim().isNotEmpty) 'email': email.trim(),
      if (commercialId.trim().isNotEmpty) 'commercialId': commercialId.trim(),
      if (commercialName.trim().isNotEmpty)
        'commercialName': commercialName.trim(),
    };
  }

  /// Builds the body for `POST`/`PUT` on `/api/v1/sub-clients`.
  ///
  /// `parentClientIds` is **always** included, including when empty: an empty
  /// array is how the backend is told to make (or convert to) a `PROSPECT`.
  /// Omitting the key leaves the type unchanged, which is a different operation.
  static Map<String, dynamic> toSubClientPayload({
    required String nom,
    required String prenom,
    required String telephone,
    required String nomAgence,
    required List<String> parentClientIds,
    GeoPosition? position,
    String note = '',
    List<String> brands = const [],
    String commercialId = '',
  }) {
    return <String, dynamic>{
      'nom': nom.trim(),
      'prenom': prenom.trim(),
      'telephone': telephone.trim(),
      'nomAgence': nomAgence.trim(),
      'parentClientIds': parentClientIds,
      if (position != null) 'latitude': position.latitude,
      if (position != null) 'longitude': position.longitude,
      if (note.trim().isNotEmpty) 'note': note.trim(),
      if (brands.isNotEmpty) 'marques': brands,
      if (commercialId.trim().isNotEmpty) 'commercialId': commercialId.trim(),
    };
  }

  /// Builds a partial update body for a B2B client.
  ///
  /// Coordinates are sent as **strings**, matching both the original B2B create
  /// and update payloads. The sub-client endpoints take them as numbers. That
  /// asymmetry is the backend's, and changing it here risks a rejected update,
  /// so it is reproduced rather than tidied.
  static Map<String, dynamic> toB2bUpdatePayload({
    GeoPosition? position,
    List<String>? brands,
    String? codeClient,
    String? raisonSociale,
    String? matriculeFiscal,
    String? telephone,
    String? email,
    String? nom,
    String? note,
  }) {
    return <String, dynamic>{
      if (position != null) 'latitude': position.latitude.toString(),
      if (position != null) 'longitude': position.longitude.toString(),
      if (nom != null && nom.trim().isNotEmpty) 'nom': nom.trim(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      if (brands != null) 'marques': brands,
      if (codeClient != null) 'codeClient': codeClient.trim(),
      if (raisonSociale != null) 'raisonSociale': raisonSociale.trim(),
      if (matriculeFiscal != null) 'matriculeFiscal': matriculeFiscal.trim(),
      if (telephone != null) 'telephone': telephone.trim(),
      if (email != null) 'email': email.trim(),
    };
  }
}

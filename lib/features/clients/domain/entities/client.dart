import 'package:equatable/equatable.dart';

import 'geo_position.dart';

/// The three kinds of entity a representative manages.
///
/// They live behind two endpoint families but are one concept in the field, and
/// the map plots all three together, so they are modelled as one entity with a
/// discriminator rather than three parallel types.
enum ClientKind {
  /// A registered B2B client — `/api/v1/clients`, created via
  /// `/api/v1/auth/register/client`. Identified by `codeClient` /
  /// `raisonSociale`.
  b2b,

  /// A sub-client attached to at least one parent B2B client —
  /// `/api/v1/sub-clients` with a non-empty `parentClientIds`.
  subClient,

  /// A prospect: the same endpoint as [subClient] but with **no** parent.
  ///
  /// This is backend behaviour, not a client-side convention: posting
  /// `parentClientIds: []` to `/api/v1/sub-clients` makes the backend assign
  /// `type: PROSPECT`, and adding a parent later converts it to `SOUS_CLIENT`.
  prospect;

  bool get isB2b => this == ClientKind.b2b;

  /// Whether this kind is served by the `/sub-clients` endpoint family.
  bool get usesSubClientApi =>
      this == ClientKind.subClient || this == ClientKind.prospect;

  /// The `type` discriminator the backend uses in its payloads.
  String get backendType => switch (this) {
    ClientKind.b2b => 'CLIENT',
    ClientKind.subClient => 'SOUS_CLIENT',
    ClientKind.prospect => 'PROSPECT',
  };

  /// Reads the kind from a backend payload.
  ///
  /// [fromSubClientEndpoint] disambiguates the case where `type` is absent: a
  /// record returned by `/sub-clients` with no `type` is a sub-client, whereas
  /// one from `/clients` is a B2B client.
  static ClientKind fromBackend(
    String? type, {
    required bool fromSubClientEndpoint,
  }) {
    final normalised = (type ?? '').toUpperCase().trim();

    return switch (normalised) {
      'PROSPECT' => ClientKind.prospect,
      'SOUS_CLIENT' || 'SUB_CLIENT' || 'SOUSCLIENT' => ClientKind.subClient,
      'CLIENT' || 'B2B' => ClientKind.b2b,
      _ => fromSubClientEndpoint ? ClientKind.subClient : ClientKind.b2b,
    };
  }
}

/// A client, sub-client or prospect in the representative's portfolio.
///
/// Replaces the `Map<String, dynamic>` that was passed around the old map
/// controller and read with ad-hoc `_safeString(client['someKey'])` calls at
/// every use site. Parsing happens once, in the data layer.
class Client extends Equatable {
  const Client({
    required this.id,
    required this.kind,
    this.codeClient = '',
    this.raisonSociale = '',
    this.matriculeFiscal = '',
    this.nom = '',
    this.prenom = '',
    this.nomAgence = '',
    this.telephone = '',
    this.email = '',
    this.note = '',
    this.remise,
    this.commercialId = '',
    this.commercialName = '',
    this.imagePath = '',
    this.position,
    this.parentClientIds = const [],
    this.brands = const [],
    this.raw = const {},
  });

  final String id;
  final ClientKind kind;

  // B2B identity
  final String codeClient;
  final String raisonSociale;
  final String matriculeFiscal;

  // Sub-client / prospect identity
  final String nom;
  final String prenom;
  final String nomAgence;

  // Contact
  final String telephone;
  final String email;
  final String note;

  final double? remise;

  final String commercialId;
  final String commercialName;

  /// Raw image path or URL as returned by the backend. Resolving it to a
  /// downloadable URL is the data layer's job, not the entity's.
  final String imagePath;

  /// `null` when the client has not been located yet — the case the map's
  /// "add position" action exists for.
  final GeoPosition? position;

  final List<String> parentClientIds;

  /// Vehicle brands the client deals in, held as backend display names.
  final List<String> brands;

  /// The untouched payload this entity was parsed from.
  ///
  /// Kept so fields the entity does not model yet — `dateCreation`,
  /// `dateModification`, `availableBrands`, and anything the backend adds
  /// later — are not lost when existing map-based screens read a client that
  /// came through this repository. New code should use the typed fields;
  /// [toUiMap] exists for the screens not yet migrated.
  ///
  /// Deliberately excluded from [props]: it is derived from the same response
  /// as every typed field, so it adds nothing to equality, and deep-comparing a
  /// map on every state rebuild would be needlessly expensive.
  final Map<String, dynamic> raw;

  /// The entity as the map-shaped payload the not-yet-migrated screens expect.
  ///
  /// Starts from [raw] so no backend field is dropped, then overlays the
  /// normalised values — notably `latitude`/`longitude` as real numbers and a
  /// `type` that reflects the parentage rule — so those screens benefit from
  /// the parsing fixes without being rewritten.
  Map<String, dynamic> toUiMap() => <String, dynamic>{
    ...raw,
    'id': id,
    'type': kind.backendType,
    if (codeClient.isNotEmpty) 'codeClient': codeClient,
    if (raisonSociale.isNotEmpty) 'raisonSociale': raisonSociale,
    if (matriculeFiscal.isNotEmpty) 'matriculeFiscal': matriculeFiscal,
    if (nom.isNotEmpty) 'nom': nom,
    if (prenom.isNotEmpty) 'prenom': prenom,
    if (nomAgence.isNotEmpty) 'nomAgence': nomAgence,
    if (telephone.isNotEmpty) 'telephone': telephone,
    if (email.isNotEmpty) 'email': email,
    if (note.isNotEmpty) 'note': note,
    if (imagePath.isNotEmpty) 'boutiqueImagePath': imagePath,
    if (position != null) 'latitude': position!.latitude,
    if (position != null) 'longitude': position!.longitude,
    'parentClientIds': parentClientIds,
    if (brands.isNotEmpty) 'marques': brands,
  };

  bool get hasPosition => position != null;

  bool get hasImage => imagePath.trim().isNotEmpty;

  /// The name to show in lists, cards and marker info windows.
  ///
  /// Preserves the original precedence from `getClientDisplayName`:
  /// `raisonSociale` → `nomAgence` → `nom prenom` → `codeClient`. Returns empty
  /// when nothing is available; the presentation layer supplies the placeholder
  /// so this stays free of localisation concerns.
  String get displayName {
    if (raisonSociale.isNotEmpty) return raisonSociale;
    if (nomAgence.isNotEmpty) return nomAgence;

    final fullName = '$nom $prenom'.trim();
    if (fullName.isNotEmpty) return fullName;

    return codeClient;
  }

  /// Text a search query is matched against.
  String get searchHaystack =>
      '$displayName $codeClient $telephone $email $nomAgence'.toLowerCase();

  Client copyWith({
    String? id,
    ClientKind? kind,
    String? codeClient,
    String? raisonSociale,
    String? matriculeFiscal,
    String? nom,
    String? prenom,
    String? nomAgence,
    String? telephone,
    String? email,
    String? note,
    double? remise,
    String? commercialId,
    String? commercialName,
    String? imagePath,
    GeoPosition? position,
    List<String>? parentClientIds,
    List<String>? brands,
    Map<String, dynamic>? raw,
  }) => Client(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    codeClient: codeClient ?? this.codeClient,
    raisonSociale: raisonSociale ?? this.raisonSociale,
    matriculeFiscal: matriculeFiscal ?? this.matriculeFiscal,
    nom: nom ?? this.nom,
    prenom: prenom ?? this.prenom,
    nomAgence: nomAgence ?? this.nomAgence,
    telephone: telephone ?? this.telephone,
    email: email ?? this.email,
    note: note ?? this.note,
    remise: remise ?? this.remise,
    commercialId: commercialId ?? this.commercialId,
    commercialName: commercialName ?? this.commercialName,
    imagePath: imagePath ?? this.imagePath,
    position: position ?? this.position,
    parentClientIds: parentClientIds ?? this.parentClientIds,
    brands: brands ?? this.brands,
    raw: raw ?? this.raw,
  );

  @override
  List<Object?> get props => [
    id,
    kind,
    codeClient,
    raisonSociale,
    matriculeFiscal,
    nom,
    prenom,
    nomAgence,
    telephone,
    email,
    note,
    remise,
    commercialId,
    commercialName,
    imagePath,
    position,
    parentClientIds,
    brands,
  ];
}

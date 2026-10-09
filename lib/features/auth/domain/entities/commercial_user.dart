import 'package:equatable/equatable.dart';

/// The signed-in representative.
///
/// Built from two backend calls: `POST /api/v1/auth/login` supplies the identity
/// and roles, `GET /api/v1/user/{id}` supplies the profile detail. The previous
/// implementation scattered the result across ~20 individual `SharedPreferences`
/// keys (`connected_user_id`, `connected_user_nom`, `connected_user_regions`, …)
/// which every feature then re-read by hand; it is one object here.
class CommercialUser extends Equatable {
  const CommercialUser({
    required this.id,
    this.email = '',
    this.nom = '',
    this.prenom = '',
    this.telephone = '',
    this.raisonSociale = '',
    this.codeClient = '',
    this.userType = '',
    this.roles = const [],
    this.regions = const [],
    this.actif = true,
    this.derniereConnexion = '',
  });

  final String id;
  final String email;
  final String nom;
  final String prenom;
  final String telephone;

  /// Present for client-type accounts; empty for staff.
  final String raisonSociale;
  final String codeClient;
  final String userType;

  final List<String> roles;
  final List<String> regions;
  final bool actif;
  final String derniereConnexion;

  /// `"prenom nom"`, falling back to whatever identity the backend supplied.
  ///
  /// The original `UserModel.fullName` returned `'$prenom $nom'` unconditionally,
  /// which rendered as a bare space for accounts that carry only a
  /// `raisonSociale` — visible in the "Bienvenue  " greeting after login.
  String get fullName {
    final name = '$prenom $nom'.trim();
    if (name.isNotEmpty) return name;
    if (raisonSociale.isNotEmpty) return raisonSociale;
    if (codeClient.isNotEmpty) return codeClient;
    return email;
  }

  /// One or two letters for the avatar placeholder.
  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  /// Whether this account is a commercial representative.
  ///
  /// Drives the field-level edit restrictions the backend expects: a
  /// representative may fill a client field that is still blank but may not
  /// overwrite one that already has a value.
  bool get isCommercial =>
      roles.any((role) => role.toUpperCase().contains('COMMERCIAL'));

  bool get isAdmin => roles.any((role) => role.toUpperCase().contains('ADMIN'));

  @override
  List<Object?> get props => [
    id,
    email,
    nom,
    prenom,
    telephone,
    raisonSociale,
    codeClient,
    userType,
    roles,
    regions,
    actif,
    derniereConnexion,
  ];
}

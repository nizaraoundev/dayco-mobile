class UserModel {
  final String id;
  final String email;
  final String nom;
  final String prenom;
  final String telephone;
  final List<String> roles;
  final List<String> regions;
  final bool actif;
  final String dateCreation;
  final String dateModification;
  final String derniereConnexion;

  UserModel({
    required this.id,
    required this.email,
    required this.nom,
    required this.prenom,
    required this.telephone,
    required this.roles,
    required this.regions,
    required this.actif,
    required this.dateCreation,
    required this.dateModification,
    required this.derniereConnexion,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      nom: json['nom'] ?? '',
      prenom: json['prenom'] ?? '',
      telephone: json['telephone'] ?? '',
      roles: List<String>.from(json['roles'] ?? []),
      regions: List<String>.from(json['regions'] ?? []),
      actif: json['actif'] ?? false,
      dateCreation: json['dateCreation'] ?? '',
      dateModification: json['dateModification'] ?? '',
      derniereConnexion: json['derniereConnexion'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'nom': nom,
      'prenom': prenom,
      'telephone': telephone,
      'roles': roles,
      'regions': regions,
      'actif': actif,
      'dateCreation': dateCreation,
      'dateModification': dateModification,
      'derniereConnexion': derniereConnexion,
    };
  }

  String get fullName => '$prenom $nom';
}

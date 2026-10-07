class LoginResponse {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final String userId;
  final String email;
  final String raisonSociale;
  final String userType;
  final List<String> roles;
  final String? codeClient;

  LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
    required this.userId,
    required this.email,
    required this.raisonSociale,
    required this.userType,
    required this.roles,
    this.codeClient,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json['accessToken'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
      tokenType: json['tokenType'] ?? 'Bearer',
      expiresIn: json['expiresIn'] ?? 86400,
      userId: json['userId'] ?? '',
      email: json['email'] ?? '',
      raisonSociale: json['raisonSociale'] ?? '',
      userType: json['userType'] ?? '',
      roles: List<String>.from(json['roles'] ?? []),
      codeClient: json['codeClient'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'tokenType': tokenType,
      'expiresIn': expiresIn,
      'userId': userId,
      'email': email,
      'raisonSociale': raisonSociale,
      'userType': userType,
      'roles': roles,
      'codeClient': codeClient,
    };
  }
}

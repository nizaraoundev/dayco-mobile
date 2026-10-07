class LoginRequest {
  final String codeClient;
  final String password;

  LoginRequest({required this.codeClient, required this.password});

  Map<String, dynamic> toJson() {
    return {'codeClient': codeClient, 'password': password};
  }
}

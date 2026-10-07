// Development environment config
class EnvDev {

  static const String baseUrl = "http://10.0.2.2:8080";

  // Endpoints
  static const String catalogue = "/api/catalogue";
  static const String client = "/api/client";
  static const String commande = "/api/commande";
  static const String stock = "/api/stock";

  // Timeout
  static const int connectTimeout = 15000;
  static const int receiveTimeout = 15000;
}

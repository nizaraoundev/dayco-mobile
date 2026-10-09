/// Backend configuration.
///
/// The application talks to **two independent backends**, each with its own
/// `/api/v1/auth/login` and its own bearer token. Conflating them is what caused
/// the stock screen to invalidate the main session (see ARCHITECTURE_AUDIT C-1),
/// so the two are modelled as distinct [ApiBackend] values and their tokens are
/// stored under distinct keys.
enum ApiBackend {
  /// Auth, clients, sub-clients, prospects and file storage.
  main,

  /// Stock consultation. Requires the `X-Device-Id` header.
  stock,
}

/// Base URLs and timeouts, unchanged from the original services.
abstract final class ApiConfig {
  const ApiConfig._();

  static const String mainBaseUrl = 'https://www.stdp-dayco.com';
  static const String stockBaseUrl = 'https://b2b.stdp-dayco.com';

  /// Sent by the stock backend's login as `X-Device-Id`. The original value is
  /// preserved — the backend may key sessions on it.
  static const String stockDeviceId = 'commercial-web';

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 20);
  static const Duration sendTimeout = Duration(seconds: 30);

  static String baseUrlOf(ApiBackend backend) => switch (backend) {
    ApiBackend.main => mainBaseUrl,
    ApiBackend.stock => stockBaseUrl,
  };
}

/// Every endpoint the application calls, in one place.
///
/// Paths are reproduced verbatim from the previous implementation. The 404/405
/// fallbacks the old code relied on are preserved as explicit `*Fallback`
/// members so the compatibility behaviour stays visible rather than buried in a
/// `catch` block.
abstract final class ApiEndpoints {
  const ApiEndpoints._();

  // ---------------------------------------------------------------- main: auth
  static const String login = '/api/v1/auth/login';

  static String user(String id) => '/api/v1/user/$id';

  /// Used when [user] answers 404.
  static String userFallback(String id) => '/api/v1/users/$id';

  // ------------------------------------------------------------- main: clients
  static const String registerClient = '/api/v1/auth/register/client';
  static const String myClients = '/api/v1/clients/my-clients';

  static String client(String id) => '/api/v1/clients/$id';

  static String clientsByCommercial(String commercialId) =>
      '/api/v1/clients/commercial/$commercialId/clients';

  // --------------------------------------------------------- main: sub-clients
  static const String subClients = '/api/v1/sub-clients';

  static String subClient(String id) => '/api/v1/sub-clients/$id';

  static String subClientsByParent(String parentId) =>
      '/api/v1/sub-clients/parent/$parentId';

  static String subClientsByCommercial(String commercialId) =>
      '/api/v1/sub-clients/commercial/$commercialId';

  // --------------------------------------------------------------- main: files
  static String entityImage(String entityType, String entityId) =>
      '/api/v1/files/$entityType/$entityId/image';

  /// Used when [entityImage] answers 404.
  static String entityImageFallback(String entityType, String entityId) =>
      '/api/v1/files/upload/$entityType/$entityId/image';

  static const String fileDownloadPrefix = '/api/v1/files/download';

  // --------------------------------------------------------------- stock: read
  static const String stocksAdminAll = '/api/v1/stocks/admin/all';

  static String stockByProduct(String referenceOrId) =>
      '/api/v1/stocks/produit/$referenceOrId';

  static String stockAvailability(String referenceOrId) =>
      '/api/v1/stocks/produit/$referenceOrId/disponibilite';

  static String stockPendingReservations(String produitId) =>
      '/api/v1/stocks/admin/produit/$produitId/reservations-en-attente';
}

/// Entity type discriminators used by the file-upload endpoint.
abstract final class ApiEntityType {
  const ApiEntityType._();

  static const String client = 'client';
  static const String subClient = 'sub-client';
}

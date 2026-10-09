import 'dart:typed_data';

import '../../../../core/error/result.dart';
import '../entities/client.dart';
import '../entities/geo_position.dart';

/// A draft of a new or edited client, as the form holds it.
///
/// Carrying the form's intent as one value keeps the repository's signature
/// stable and lets the sub-client/prospect/B2B branching live in the data layer
/// where the endpoint differences belong.
class ClientDraft {
  const ClientDraft({
    required this.kind,
    this.id = '',
    this.codeClient = '',
    this.raisonSociale = '',
    this.matriculeFiscal = '',
    this.nom = '',
    this.prenom = '',
    this.nomAgence = '',
    this.telephone = '',
    this.email = '',
    this.note = '',
    this.position,
    this.parentClientIds = const [],
    this.brands = const [],
    this.imageBytes,
  });

  final ClientKind kind;

  /// Empty for a creation, set for an update.
  final String id;

  final String codeClient;
  final String raisonSociale;
  final String matriculeFiscal;
  final String nom;
  final String prenom;
  final String nomAgence;
  final String telephone;
  final String email;
  final String note;

  final GeoPosition? position;
  final List<String> parentClientIds;

  /// Backend display names, produced by `CarBrandCodec.encodeAll`.
  final List<String> brands;

  /// Photo of the shopfront, uploaded after the entity itself is created.
  final Uint8List? imageBytes;

  bool get isUpdate => id.isNotEmpty;
}

/// The application's single source of truth for the representative's portfolio.
///
/// This is the piece that fixes the synchronisation problem. Previously the map
/// controller, the clients page and the client-detail page each kept their own
/// `RxList` and each re-fetched independently, so creating a client on the map
/// did not update the list and editing from the list did not move the map pin.
/// Here, one cache is maintained and [portfolioChanges] notifies every screen,
/// so there is exactly one answer to "what clients exist".
abstract interface class ClientsRepository {
  /// The last known portfolio, or `null` before the first load.
  List<Client>? get cachedPortfolio;

  /// Emits the full portfolio whenever it changes, from any cause: a reload, a
  /// creation, an update or a deletion.
  Stream<List<Client>> get portfolioChanges;

  /// Loads every B2B client, sub-client and prospect for [commercialId].
  ///
  /// Concurrent calls are collapsed into one request, and a call issued while a
  /// load is already running joins it instead of opening a second connection.
  ///
  /// [forceRefresh] bypasses the freshness window; without it, a call made
  /// while the cache is still fresh returns the cache without touching the
  /// network.
  Future<Result<List<Client>>> loadPortfolio({
    required String commercialId,
    bool forceRefresh = false,
  });

  /// Fetches one client's full record.
  Future<Result<Client>> fetchClient(String id, {required ClientKind kind});

  /// Fetches the sub-clients attached to [parentClientId].
  Future<Result<List<Client>>> fetchSubClientsOfParent(String parentClientId);

  /// Creates the client described by [draft].
  ///
  /// Repeated submissions of the same draft while one is in flight are dropped,
  /// so a double tap cannot create two clients.
  Future<Result<Client>> createClient(ClientDraft draft);

  /// Applies [draft] to the existing client it identifies.
  Future<Result<Client>> updateClient(ClientDraft draft);

  /// Moves a client to [position] without touching its other fields.
  ///
  /// Separate from [updateClient] because relocating from the map must not
  /// resubmit form fields the representative did not open.
  Future<Result<Client>> updateClientPosition({
    required String id,
    required ClientKind kind,
    required GeoPosition position,
  });

  /// Deletes a sub-client or prospect. B2B clients cannot be deleted from the
  /// app; the backend exposes no such endpoint.
  Future<Result<void>> deleteSubClient(String id);

  /// Uploads a shopfront photo for an existing client.
  Future<Result<void>> uploadImage({
    required String id,
    required ClientKind kind,
    required Uint8List bytes,
  });

  /// Fetches an authenticated image's bytes, memoised per URL.
  Future<Result<Uint8List>> fetchImageBytes(String imagePathOrUrl);

  /// Drops every cached value. Called on sign-out so the next representative
  /// never sees the previous one's portfolio.
  void clearCache();
}

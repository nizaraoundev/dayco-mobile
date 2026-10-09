import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/config/api_config.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/json_coercion.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/single_flight.dart';
import '../domain/entities/client.dart';
import '../domain/entities/geo_position.dart';
import '../domain/repositories/clients_repository.dart';
import 'mappers/client_mapper.dart';

class ClientsRepositoryImpl implements ClientsRepository {
  ClientsRepositoryImpl({
    required ApiClient apiClient,
    Duration freshnessWindow = const Duration(minutes: 2),
  }) : _api = apiClient,
       _freshnessWindow = freshnessWindow;

  final ApiClient _api;

  /// How long a loaded portfolio is considered current.
  ///
  /// Without this, re-entering the map re-fetched the whole portfolio every
  /// time — and the old page re-created its controller on every rebuild, so
  /// that happened far more often than once per visit.
  final Duration _freshnessWindow;

  List<Client>? _portfolio;
  DateTime? _portfolioLoadedAt;

  final StreamController<List<Client>> _portfolioChanges =
      StreamController<List<Client>>.broadcast();

  /// Collapses concurrent loads of the same commercial's portfolio.
  final SingleFlight<String, Result<List<Client>>> _portfolioFlight =
      SingleFlight<String, Result<List<Client>>>();

  /// Collapses concurrent writes keyed by the draft being submitted, so a
  /// double tap on "Enregistrer" cannot create two clients.
  final SingleFlight<String, Result<Client>> _writeFlight =
      SingleFlight<String, Result<Client>>();

  /// Memoises authenticated image downloads. Bounded, because marker avatars
  /// would otherwise accumulate for every client ever displayed.
  final Map<String, Uint8List> _imageCache = <String, Uint8List>{};
  static const int _imageCacheLimit = 60;

  @override
  List<Client>? get cachedPortfolio => _portfolio == null
      ? null
      : List<Client>.unmodifiable(_portfolio!);

  @override
  Stream<List<Client>> get portfolioChanges => _portfolioChanges.stream;

  bool get _isFresh {
    final loadedAt = _portfolioLoadedAt;
    if (loadedAt == null) return false;
    return DateTime.now().difference(loadedAt) < _freshnessWindow;
  }

  // ----------------------------------------------------------------- reading

  @override
  Future<Result<List<Client>>> loadPortfolio({
    required String commercialId,
    bool forceRefresh = false,
  }) {
    final cached = _portfolio;
    if (!forceRefresh && cached != null && _isFresh) {
      return Future.value(Result.success(List<Client>.unmodifiable(cached)));
    }

    return _portfolioFlight.run(
      commercialId,
      () => _fetchPortfolio(commercialId),
    );
  }

  /// Loads B2B clients and sub-clients/prospects together.
  ///
  /// The two calls run concurrently: the original code awaited them in sequence
  /// from two separate `onInit` statements, so the map waited for the sum of
  /// both round-trips before showing any pin.
  Future<Result<List<Client>>> _fetchPortfolio(String commercialId) async {
    final responses = await Future.wait([
      _fetchB2bClients(commercialId),
      _fetchSubClientsAndProspects(commercialId),
    ]);

    final b2b = responses[0];
    final subClients = responses[1];

    // A total failure is a failure; a partial one is not. If only one family
    // fails the representative still gets the other half of their portfolio,
    // which matters in the field on a weak connection.
    if (b2b.isFailure && subClients.isFailure) {
      return Result.failure(b2b.failureOrNull!);
    }

    if (b2b.isFailure) {
      AppLogger.warn('B2B clients unavailable', error: b2b.failureOrNull);
    }
    if (subClients.isFailure) {
      AppLogger.warn('Sub-clients unavailable', error: subClients.failureOrNull);
    }

    final merged = _dedupeById([
      ...?b2b.valueOrNull,
      ...?subClients.valueOrNull,
    ]);

    _publish(merged);
    return Result.success(List<Client>.unmodifiable(merged));
  }

  /// `GET /api/v1/clients/commercial/{id}/clients`, falling back to
  /// `/my-clients` when no commercial id is known.
  Future<Result<List<Client>>> _fetchB2bClients(String commercialId) async {
    final path = commercialId.trim().isEmpty
        ? ApiEndpoints.myClients
        : ApiEndpoints.clientsByCommercial(commercialId.trim());

    final result = await _api.getList(path);
    return result.map(
      (rows) => rows.map(ClientMapper.fromClientJson).toList(growable: false),
    );
  }

  /// `GET /api/v1/sub-clients/commercial/{id}` — returns sub-clients *and*
  /// prospects in one response.
  Future<Result<List<Client>>> _fetchSubClientsAndProspects(
    String commercialId,
  ) async {
    if (commercialId.trim().isEmpty) {
      return const Result.success(<Client>[]);
    }

    final result = await _api.getList(
      ApiEndpoints.subClientsByCommercial(commercialId.trim()),
    );
    return result.map(
      (rows) => rows.map(ClientMapper.fromSubClientJson).toList(growable: false),
    );
  }

  @override
  Future<Result<Client>> fetchClient(
    String id, {
    required ClientKind kind,
  }) async {
    if (id.trim().isEmpty) {
      return const Result.failure(
        ValidationFailure(message: 'Identifiant client manquant'),
      );
    }

    final result = kind.usesSubClientApi
        ? await _api.getObject(ApiEndpoints.subClient(id))
        : await _api.getObject(ApiEndpoints.client(id));

    return result.map(
      kind.usesSubClientApi
          ? ClientMapper.fromSubClientJson
          : ClientMapper.fromClientJson,
    );
  }

  @override
  Future<Result<List<Client>>> fetchSubClientsOfParent(
    String parentClientId,
  ) async {
    final result = await _api.getList(
      ApiEndpoints.subClientsByParent(parentClientId),
    );
    return result.map(
      (rows) => rows.map(ClientMapper.fromSubClientJson).toList(growable: false),
    );
  }

  // ----------------------------------------------------------------- writing

  @override
  Future<Result<Client>> createClient(ClientDraft draft) async {
    final result = await _writeFlight.runOrSkip(
      _writeKeyFor(draft),
      () => _performCreate(draft),
    );
    return result ?? const Result.failure(CancelledFailure());
  }

  Future<Result<Client>> _performCreate(ClientDraft draft) async {
    final position = draft.position;
    if (position == null) {
      return const Result.failure(
        ValidationFailure(
          message: 'Sélectionnez la position de la boutique avant de créer',
        ),
      );
    }

    final created = draft.kind.usesSubClientApi
        ? await _createSubClient(draft, position)
        : await _createB2bClient(draft, position);

    if (created case FailureResult<Client>()) return created;

    var client = (created as Success<Client>).value;

    // The image is uploaded after creation because the entity id does not exist
    // until then. Awaited rather than fire-and-forget: the original code
    // launched it with `unawaited(...)`, so a failed upload was invisible and
    // the representative believed the photo had been saved.
    final bytes = draft.imageBytes;
    if (bytes != null && client.id.isNotEmpty) {
      final upload = await uploadImage(
        id: client.id,
        kind: client.kind,
        bytes: bytes,
      );
      if (upload case FailureResult<void>(:final failure)) {
        AppLogger.warn('Shopfront photo upload failed', error: failure);
      }
    }

    client = _upsert(client);
    return Result.success(client);
  }

  Future<Result<Client>> _createSubClient(
    ClientDraft draft,
    GeoPosition position,
  ) async {
    final payload = ClientMapper.toSubClientPayload(
      nom: draft.nom,
      prenom: draft.prenom,
      telephone: draft.telephone,
      nomAgence: draft.nomAgence,
      // An empty list is meaningful: the backend assigns type PROSPECT.
      parentClientIds: draft.parentClientIds,
      position: position,
      note: draft.note,
      brands: draft.brands,
    );

    final result = await _api.postObject(ApiEndpoints.subClients, body: payload);

    return result.map((json) {
      // Creation responses are sparse, so the draft fills the gaps rather than
      // leaving the new pin unlabelled until the next full reload.
      final created = ClientMapper.fromSubClientJson(json);
      return created.copyWith(
        nom: created.nom.isEmpty ? draft.nom : created.nom,
        prenom: created.prenom.isEmpty ? draft.prenom : created.prenom,
        nomAgence: created.nomAgence.isEmpty ? draft.nomAgence : created.nomAgence,
        telephone: created.telephone.isEmpty ? draft.telephone : created.telephone,
        position: created.position ?? position,
        parentClientIds: created.parentClientIds.isEmpty
            ? draft.parentClientIds
            : created.parentClientIds,
        brands: created.brands.isEmpty ? draft.brands : created.brands,
      );
    });
  }

  Future<Result<Client>> _createB2bClient(
    ClientDraft draft,
    GeoPosition position,
  ) async {
    final payload = ClientMapper.toB2bCreatePayload(
      position: position,
      codeClient: draft.codeClient,
      raisonSociale: draft.raisonSociale,
      matriculeFiscal: draft.matriculeFiscal,
      telephone: draft.telephone,
      email: draft.email,
    );

    final result = await _api.postObject(
      ApiEndpoints.registerClient,
      body: payload,
    );

    if (result case FailureResult<Map<String, dynamic>>(:final failure)) {
      return Result.failure(failure);
    }

    final json = (result as Success<Map<String, dynamic>>).value;
    var created = ClientMapper.fromClientJson(json).copyWith(
      kind: ClientKind.b2b,
      raisonSociale: JsonCoercion.string(json['raisonSociale']).isEmpty
          ? draft.raisonSociale
          : null,
      position: position,
    );

    // Brands are not accepted by the registration endpoint, so they are
    // applied with a follow-up update — preserving the original behaviour.
    if (draft.brands.isNotEmpty && created.id.isNotEmpty) {
      final brandsUpdate = await _api.putObject(
        ApiEndpoints.client(created.id),
        body: {'marques': draft.brands},
      );
      if (brandsUpdate case FailureResult<Map<String, dynamic>>(:final failure)) {
        AppLogger.warn('Could not save brands for new client', error: failure);
      } else {
        created = created.copyWith(brands: draft.brands);
      }
    }

    return Result.success(created);
  }

  @override
  Future<Result<Client>> updateClient(ClientDraft draft) async {
    if (!draft.isUpdate) {
      return const Result.failure(
        ValidationFailure(message: 'Client introuvable pour la mise à jour'),
      );
    }

    final result = await _writeFlight.runOrSkip(
      _writeKeyFor(draft),
      () => _performUpdate(draft),
    );
    return result ?? const Result.failure(CancelledFailure());
  }

  Future<Result<Client>> _performUpdate(ClientDraft draft) async {
    final updated = draft.kind.usesSubClientApi
        ? await _updateSubClient(draft)
        : await _updateB2bClient(draft);

    if (updated case FailureResult<Client>()) return updated;

    var client = (updated as Success<Client>).value;

    final bytes = draft.imageBytes;
    if (bytes != null && client.id.isNotEmpty) {
      final upload = await uploadImage(
        id: client.id,
        kind: client.kind,
        bytes: bytes,
      );
      if (upload case FailureResult<void>(:final failure)) {
        AppLogger.warn('Shopfront photo upload failed', error: failure);
      }
    }

    client = _upsert(client);
    return Result.success(client);
  }

  Future<Result<Client>> _updateSubClient(ClientDraft draft) async {
    final payload = ClientMapper.toSubClientPayload(
      nom: draft.nom,
      prenom: draft.prenom,
      telephone: draft.telephone,
      nomAgence: draft.nomAgence,
      parentClientIds: draft.parentClientIds,
      position: draft.position,
      note: draft.note,
      brands: draft.brands,
    );

    final result = await _api.putObject(
      ApiEndpoints.subClient(draft.id),
      body: payload,
    );

    return result.map((json) {
      final remote = ClientMapper.fromSubClientJson(json);
      // A sparse 200 must not blank the fields we just submitted.
      return _mergeAfterWrite(remote, draft);
    });
  }

  Future<Result<Client>> _updateB2bClient(ClientDraft draft) async {
    final payload = ClientMapper.toB2bUpdatePayload(
      position: draft.position,
      brands: draft.brands.isEmpty ? null : draft.brands,
      codeClient: draft.codeClient.isEmpty ? null : draft.codeClient,
      raisonSociale: draft.raisonSociale.isEmpty ? null : draft.raisonSociale,
      matriculeFiscal: draft.matriculeFiscal.isEmpty
          ? null
          : draft.matriculeFiscal,
      telephone: draft.telephone.isEmpty ? null : draft.telephone,
      email: draft.email.isEmpty ? null : draft.email,
      nom: draft.nom.isEmpty ? null : draft.nom,
      note: draft.note.isEmpty ? null : draft.note,
    );

    if (payload.isEmpty) {
      // Nothing the representative is allowed to change was filled in. Sending
      // an empty body would be a no-op round-trip reported as success.
      return const Result.failure(
        ValidationFailure(message: 'Aucune modification à enregistrer'),
      );
    }

    // Some deployments route only PATCH on this resource and answer 405 to PUT.
    final result = await _api.withStatusFallback(
      primary: () => _api.putObject(ApiEndpoints.client(draft.id), body: payload),
      fallback: () =>
          _api.patchObject(ApiEndpoints.client(draft.id), body: payload),
      onStatus: 405,
    );

    return result.map((json) {
      final remote = ClientMapper.fromClientJson(json);
      return _mergeAfterWrite(remote, draft);
    });
  }

  /// Reconciles a write response with the submitted draft.
  ///
  /// The backend returns partial bodies on update, so anything it omits falls
  /// back to what we sent — and `id`/`kind` always come from the draft, which
  /// is authoritative for the entity being edited.
  Client _mergeAfterWrite(Client remote, ClientDraft draft) {
    final existing = _findById(draft.id);

    return (existing ?? remote).copyWith(
      id: draft.id,
      kind: draft.kind,
      codeClient: remote.codeClient.isNotEmpty ? remote.codeClient : draft.codeClient,
      raisonSociale: remote.raisonSociale.isNotEmpty
          ? remote.raisonSociale
          : draft.raisonSociale,
      matriculeFiscal: remote.matriculeFiscal.isNotEmpty
          ? remote.matriculeFiscal
          : draft.matriculeFiscal,
      nom: remote.nom.isNotEmpty ? remote.nom : draft.nom,
      prenom: remote.prenom.isNotEmpty ? remote.prenom : draft.prenom,
      nomAgence: remote.nomAgence.isNotEmpty ? remote.nomAgence : draft.nomAgence,
      telephone: remote.telephone.isNotEmpty ? remote.telephone : draft.telephone,
      email: remote.email.isNotEmpty ? remote.email : draft.email,
      note: remote.note.isNotEmpty ? remote.note : draft.note,
      position: remote.position ?? draft.position,
      parentClientIds: draft.parentClientIds,
      brands: draft.brands.isNotEmpty ? draft.brands : remote.brands,
      imagePath: remote.imagePath.isNotEmpty ? remote.imagePath : null,
    );
  }

  @override
  Future<Result<Client>> updateClientPosition({
    required String id,
    required ClientKind kind,
    required GeoPosition position,
  }) async {
    final existing = _findById(id);

    // Only the coordinates are sent, so relocating a pin cannot clobber fields
    // the representative never opened.
    final payload = <String, dynamic>{
      'latitude': position.latitude,
      'longitude': position.longitude,
    };

    final Result<Map<String, dynamic>> result;
    if (kind.usesSubClientApi) {
      // This endpoint derives the type from parentage, so the current parents
      // must be echoed back or a sub-client silently becomes a prospect.
      if (existing != null) {
        payload['parentClientIds'] = existing.parentClientIds;
      }
      result = await _api.putObject(ApiEndpoints.subClient(id), body: payload);
    } else {
      result = await _api.withStatusFallback(
        primary: () => _api.putObject(ApiEndpoints.client(id), body: payload),
        fallback: () => _api.patchObject(ApiEndpoints.client(id), body: payload),
        onStatus: 405,
      );
    }

    if (result case FailureResult<Map<String, dynamic>>(:final failure)) {
      return Result.failure(failure);
    }

    final base = existing ?? Client(id: id, kind: kind);
    return Result.success(_upsert(base.copyWith(position: position)));
  }

  @override
  Future<Result<void>> deleteSubClient(String id) async {
    final result = await _api.delete(ApiEndpoints.subClient(id));

    if (result.isSuccess) _removeById(id);
    return result;
  }

  // ------------------------------------------------------------------- images

  @override
  Future<Result<void>> uploadImage({
    required String id,
    required ClientKind kind,
    required Uint8List bytes,
  }) async {
    final entityType = kind.usesSubClientApi
        ? ApiEntityType.subClient
        : ApiEntityType.client;

    final prefix = kind.usesSubClientApi ? 'sub_client' : 'client';
    final fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    FormData buildBody() => FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });

    // `FormData` is a single-use stream, so the fallback needs its own body.
    final result = await _api.withStatusFallback(
      primary: () => _api.postMultipart(
        ApiEndpoints.entityImage(entityType, id),
        body: buildBody(),
      ),
      fallback: () => _api.postMultipart(
        ApiEndpoints.entityImageFallback(entityType, id),
        body: buildBody(),
      ),
      onStatus: 404,
    );

    if (result case Success<Map<String, dynamic>>(:final value)) {
      final path = JsonCoercion.firstString(value, const [
        'boutiqueImagePath',
        'path',
        'fileName',
        'url',
        'value',
      ]);
      final existing = _findById(id);
      if (existing != null && path.isNotEmpty) {
        _upsert(existing.copyWith(imagePath: path));
      }
      return const Result.success(null);
    }

    return Result.failure(result.failureOrNull!);
  }

  @override
  Future<Result<Uint8List>> fetchImageBytes(String imagePathOrUrl) async {
    final raw = imagePathOrUrl.trim();
    if (raw.isEmpty) {
      return const Result.failure(
        ValidationFailure(message: 'Chemin d\'image vide'),
      );
    }

    final cached = _imageCache[raw];
    if (cached != null) return Result.success(cached);

    final result = await _api.getBytes(resolveImagePath(raw));

    if (result case Success<Uint8List>(:final value)) {
      if (_imageCache.length >= _imageCacheLimit) {
        _imageCache.remove(_imageCache.keys.first);
      }
      _imageCache[raw] = value;
    }

    return result;
  }

  /// Normalises the several shapes the backend uses to reference a stored file
  /// into a path the download endpoint accepts.
  ///
  /// Reproduces the original `_normalizeImageUrl` rules exactly: absolute URLs
  /// pass through, an `images/` prefix is rewritten, `clients/` and
  /// `sub-clients/` prefixes are kept, and a bare file name is assumed to live
  /// under `clients/`.
  static String resolveImagePath(String raw) {
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;

    final cleaned = raw.startsWith('/') ? raw.substring(1) : raw;

    if (cleaned.startsWith('api/v1/files/download/')) return '/$cleaned';

    if (cleaned.startsWith('images/')) {
      return '${ApiEndpoints.fileDownloadPrefix}/${cleaned.substring(7)}';
    }

    if (cleaned.startsWith('clients/') || cleaned.startsWith('sub-clients/')) {
      return '${ApiEndpoints.fileDownloadPrefix}/$cleaned';
    }

    return '${ApiEndpoints.fileDownloadPrefix}/clients/$cleaned';
  }

  // -------------------------------------------------------------- cache state

  /// Key under which a write is de-duplicated: the entity for an update, the
  /// submitted content for a creation (which has no id yet).
  String _writeKeyFor(ClientDraft draft) => draft.isUpdate
      ? 'update:${draft.kind.name}:${draft.id}'
      : 'create:${draft.kind.name}:${draft.codeClient}|${draft.raisonSociale}'
            '|${draft.nom}|${draft.prenom}|${draft.nomAgence}|${draft.telephone}';

  Client? _findById(String id) {
    if (id.isEmpty) return null;
    for (final client in _portfolio ?? const <Client>[]) {
      if (client.id == id) return client;
    }
    return null;
  }

  /// Inserts or replaces [client] in the cache and notifies listeners.
  Client _upsert(Client client) {
    if (client.id.isEmpty) return client;

    final next = List<Client>.of(_portfolio ?? const <Client>[]);
    final index = next.indexWhere((candidate) => candidate.id == client.id);

    if (index >= 0) {
      next[index] = client;
    } else {
      next.add(client);
    }

    _publish(next, touchTimestamp: false);
    return client;
  }

  void _removeById(String id) {
    final current = _portfolio;
    if (current == null) return;

    final next = current.where((client) => client.id != id).toList();
    if (next.length != current.length) _publish(next, touchTimestamp: false);
  }

  void _publish(List<Client> clients, {bool touchTimestamp = true}) {
    _portfolio = clients;
    if (touchTimestamp) _portfolioLoadedAt = DateTime.now();
    if (!_portfolioChanges.isClosed) {
      _portfolioChanges.add(List<Client>.unmodifiable(clients));
    }
  }

  /// Keeps one record per id. B2B and sub-client responses can both mention the
  /// same entity, and duplicate markers were visible on the map because of it.
  List<Client> _dedupeById(List<Client> clients) {
    final byId = <String, Client>{};
    final withoutId = <Client>[];

    for (final client in clients) {
      if (client.id.isEmpty) {
        withoutId.add(client);
      } else {
        byId[client.id] = client;
      }
    }

    return [...byId.values, ...withoutId];
  }

  @override
  void clearCache() {
    _portfolio = null;
    _portfolioLoadedAt = null;
    _imageCache.clear();
    _portfolioFlight.reset();
    _writeFlight.reset();
    if (!_portfolioChanges.isClosed) _portfolioChanges.add(const []);
  }

  Future<void> dispose() => _portfolioChanges.close();
}

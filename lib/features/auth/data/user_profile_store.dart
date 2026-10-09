import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/json_coercion.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/entities/commercial_user.dart';

/// Persists the connected representative's profile as a single JSON document.
///
/// The previous implementation spread one user across about twenty preference
/// keys (`connected_user_id`, `connected_user_nom`, `connected_user_prenom`,
/// `connected_user_telephone`, `connected_user_roles`, `connected_user_regions`,
/// `connected_user_actif`, `connected_user_date_creation`, …) written one
/// `await` at a time. That made every write non-atomic — an interrupted sign-in
/// left a half-populated profile — and `logout()` had to remember to remove all
/// twenty, which it did only by hand.
///
/// The profile is not secret (the tokens are, and they live in
/// [SessionStore]), so plain preferences are appropriate here.
class UserProfileStore {
  UserProfileStore({SharedPreferences? preferences}) : _injected = preferences;

  final SharedPreferences? _injected;
  SharedPreferences? _prefs;

  static const String _key = 'connected_user_profile';

  /// Keys written by the pre-refactor build, removed on first save so stale
  /// values can never be read back by any straggling code path.
  static const List<String> _legacyKeys = [
    'user_id',
    'user_email',
    'user_name',
    'user_roles',
    'user_profile',
    'connected_user_id',
    'connected_user_email',
    'connected_user_name',
    'connected_user_nom',
    'connected_user_prenom',
    'connected_user_telephone',
    'connected_user_roles',
    'connected_user_regions',
    'connected_user_actif',
    'connected_user_date_creation',
    'connected_user_date_modification',
    'connected_user_derniere_connexion',
  ];

  Future<SharedPreferences> get _store async =>
      _prefs ??= _injected ?? await SharedPreferences.getInstance();

  Future<CommercialUser?> read() async {
    try {
      final prefs = await _store;
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return _readLegacy(prefs);

      return _fromJson(JsonCoercion.asMap(jsonDecode(raw)));
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'Failed to read stored profile',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Reconstructs a profile written by the previous build so an existing
  /// install is not signed out by the upgrade.
  CommercialUser? _readLegacy(SharedPreferences prefs) {
    final id =
        prefs.getString('connected_user_id') ?? prefs.getString('user_id') ?? '';
    if (id.isEmpty) return null;

    return CommercialUser(
      id: id,
      email:
          prefs.getString('connected_user_email') ??
          prefs.getString('user_email') ??
          '',
      nom: prefs.getString('connected_user_nom') ?? '',
      prenom: prefs.getString('connected_user_prenom') ?? '',
      telephone: prefs.getString('connected_user_telephone') ?? '',
      raisonSociale: prefs.getString('user_name') ?? '',
      roles:
          prefs.getStringList('connected_user_roles') ??
          prefs.getStringList('user_roles') ??
          const [],
      regions: prefs.getStringList('connected_user_regions') ?? const [],
      actif: prefs.getBool('connected_user_actif') ?? true,
      derniereConnexion:
          prefs.getString('connected_user_derniere_connexion') ?? '',
    );
  }

  Future<void> write(CommercialUser user) async {
    try {
      final prefs = await _store;
      // One atomic write instead of twenty sequential ones.
      await prefs.setString(_key, jsonEncode(_toJson(user)));
      await _removeLegacyKeys(prefs);
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'Failed to persist profile',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await _store;
      await prefs.remove(_key);
      await _removeLegacyKeys(prefs);
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'Failed to clear profile',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _removeLegacyKeys(SharedPreferences prefs) async {
    for (final key in _legacyKeys) {
      if (prefs.containsKey(key)) await prefs.remove(key);
    }
  }

  static Map<String, dynamic> _toJson(CommercialUser user) => {
    'id': user.id,
    'email': user.email,
    'nom': user.nom,
    'prenom': user.prenom,
    'telephone': user.telephone,
    'raisonSociale': user.raisonSociale,
    'codeClient': user.codeClient,
    'userType': user.userType,
    'roles': user.roles,
    'regions': user.regions,
    'actif': user.actif,
    'derniereConnexion': user.derniereConnexion,
  };

  static CommercialUser? _fromJson(Map<String, dynamic> json) {
    final id = JsonCoercion.string(json['id']);
    if (id.isEmpty) return null;

    return CommercialUser(
      id: id,
      email: JsonCoercion.string(json['email']),
      nom: JsonCoercion.string(json['nom']),
      prenom: JsonCoercion.string(json['prenom']),
      telephone: JsonCoercion.string(json['telephone']),
      raisonSociale: JsonCoercion.string(json['raisonSociale']),
      codeClient: JsonCoercion.string(json['codeClient']),
      userType: JsonCoercion.string(json['userType']),
      roles: JsonCoercion.stringList(json['roles']),
      regions: JsonCoercion.stringList(json['regions']),
      actif: JsonCoercion.toBool(json['actif'], fallback: true),
      derniereConnexion: JsonCoercion.string(json['derniereConnexion']),
    );
  }
}

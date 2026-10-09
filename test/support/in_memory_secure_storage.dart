import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// An in-memory [FlutterSecureStorage] so [SessionStore] can be tested without
/// the Keystore/Keychain platform channel.
class InMemorySecureStorage extends FlutterSecureStorage {
  InMemorySecureStorage([Map<String, String>? initial])
    : _values = {...?initial},
      super();

  final Map<String, String> _values;

  /// Set to simulate a locked or corrupt keystore.
  bool throwOnAccess = false;

  Map<String, String> get snapshot => Map.unmodifiable(_values);

  void _guard() {
    if (throwOnAccess) {
      throw StateError('secure storage unavailable');
    }
  }

  @override
  Future<String?> read({
    required String key,
    AndroidOptions? aOptions,
    IOSOptions? iOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _guard();
    return _values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AndroidOptions? aOptions,
    IOSOptions? iOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _guard();
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AndroidOptions? aOptions,
    IOSOptions? iOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _guard();
    _values.remove(key);
  }

  @override
  Future<Map<String, String>> readAll({
    AndroidOptions? aOptions,
    IOSOptions? iOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _guard();
    return Map<String, String>.from(_values);
  }

  @override
  Future<void> deleteAll({
    AndroidOptions? aOptions,
    IOSOptions? iOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _guard();
    _values.clear();
  }

  @override
  Future<bool> containsKey({
    required String key,
    AndroidOptions? aOptions,
    IOSOptions? iOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _guard();
    return _values.containsKey(key);
  }
}

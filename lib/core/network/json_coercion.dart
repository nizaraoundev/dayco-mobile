/// Defensive readers for the loosely-typed JSON this backend returns.
///
/// The same four helpers were reimplemented in `auth_service.dart`,
/// `commercial_stock_service.dart` and `commercial_map_controller.dart`, with
/// subtly different behaviour in each. They live here once so the whole app
/// agrees on how to read a field.
abstract final class JsonCoercion {
  const JsonCoercion._();

  /// Coerces a decoded body into a JSON object.
  static Map<String, dynamic> asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    // An empty 200/204 body is legitimate for writes, so treat it as an empty
    // object rather than an error — the previous code threw here, which turned
    // successful updates into failures.
    if (data == null || (data is String && data.trim().isEmpty)) return const {};
    throw const FormatException('Expected a JSON object');
  }

  /// Coerces a decoded body into a list of JSON objects.
  ///
  /// Accepts a bare array, a Spring `Page` (`{"content": [...]}`) and
  /// `{"data": [...]}` — all three are returned by different endpoints of this
  /// backend. An empty or null body yields an empty list, which is how an empty
  /// portfolio must be represented (not as an error).
  static List<Map<String, dynamic>> asListOfMaps(dynamic data) {
    if (data == null) return const [];

    if (data is List) return _mapsFrom(data);

    if (data is Map) {
      for (final key in const ['content', 'data', 'items', 'results']) {
        final value = data[key];
        if (value is List) return _mapsFrom(value);
      }
      // A single object where a list was expected: treat it as a one-element list.
      if (data.isNotEmpty) return [Map<String, dynamic>.from(data)];
      return const [];
    }

    throw const FormatException('Expected a JSON array');
  }

  static List<Map<String, dynamic>> _mapsFrom(List<dynamic> source) => source
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);

  /// Never-null string read. Absent, null and `"null"` all become `''`.
  static String string(dynamic value) {
    if (value == null) return '';
    final text = value.toString().trim();
    return text == 'null' ? '' : text;
  }

  /// Parses a number that may arrive as `num`, numeric `String`, or null.
  ///
  /// Also accepts a comma decimal separator, which the backend has been seen to
  /// emit for coordinates under a French locale.
  static double? toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) {
      final result = value.toDouble();
      return result.isFinite ? result : null;
    }
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    final parsed = double.tryParse(text.replaceAll(',', '.'));
    return (parsed != null && parsed.isFinite) ? parsed : null;
  }

  static int? toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.isFinite ? value.toInt() : null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return int.tryParse(text) ?? double.tryParse(text)?.toInt();
  }

  /// Reads a boolean that may arrive as `bool`, `"true"`/`"false"`, or 0/1.
  static bool toBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase();
    return switch (text) {
      'true' || '1' || 'yes' || 'oui' => true,
      'false' || '0' || 'no' || 'non' => false,
      _ => fallback,
    };
  }

  /// Reads a list of strings, skipping blanks.
  static List<String> stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map(string)
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  /// Reads the first present, non-empty value among [keys].
  ///
  /// The backend names the same concept differently across endpoints (for
  /// instance a client's display name arrives as `raisonSociale`, `nomAgence`
  /// or `nom`/`prenom` depending on the entity), so readers need this.
  static String firstString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = string(json[key]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }
}

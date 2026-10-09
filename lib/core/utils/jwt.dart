import 'dart:convert';

/// Minimal JWT payload reader, used only to decide whether a stored token is
/// worth sending.
///
/// This performs **no signature verification** — that is the backend's job. Its
/// sole purpose is to avoid starting the app with a token the backend will
/// certainly reject, which previously produced a sign-in screen flash followed
/// by a 401 cascade.
abstract final class Jwt {
  const Jwt._();

  /// Decodes the payload, or returns `null` when the token is not a readable JWT.
  static Map<String, dynamic>? payload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;

    try {
      final decoded = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final json = jsonDecode(decoded);
      return json is Map<String, dynamic> ? json : null;
    } on Object {
      return null;
    }
  }

  /// The token's expiry, or `null` when it has no readable `exp`.
  static DateTime? expiryOf(String token) {
    final exp = payload(token)?['exp'];
    if (exp is! int) return null;
    return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
  }

  /// Whether [token] is expired, or unreadable (treated as expired).
  ///
  /// [leeway] is subtracted from the expiry so a token that will lapse
  /// mid-request is treated as already dead. The original implementation used no
  /// leeway, so a token with two seconds left passed the check and then failed
  /// the request it was attached to.
  static bool isExpired(
    String token, {
    Duration leeway = const Duration(seconds: 30),
    DateTime? now,
  }) {
    final expiry = expiryOf(token);
    // An opaque or malformed token cannot be reasoned about: treat it as
    // expired rather than optimistically sending it.
    if (expiry == null) return true;

    final reference = (now ?? DateTime.now()).toUtc();
    return reference.isAfter(expiry.subtract(leeway));
  }
}

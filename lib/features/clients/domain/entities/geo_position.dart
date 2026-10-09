import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// A geographic coordinate, independent of any map SDK.
///
/// The domain deliberately does not use `google_maps_flutter`'s `LatLng`: that
/// would make every piece of business logic require the plugin (and therefore a
/// platform channel) to be unit-tested. Conversion happens at the presentation
/// boundary.
class GeoPosition extends Equatable {
  const GeoPosition({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  /// Parses a coordinate pair, returning `null` when it is absent or unusable.
  ///
  /// `(0, 0)` is rejected. The backend stores exactly that for clients which
  /// have never been located, and the original code checked
  /// `lat != 0.0 && lng != 0.0` at each of its use sites. Centralising the rule
  /// means a never-located client can no longer leak onto the map as a pin in
  /// the Gulf of Guinea.
  static GeoPosition? tryCreate(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return null;
    if (!latitude.isFinite || !longitude.isFinite) return null;
    if (latitude == 0.0 && longitude == 0.0) return null;
    if (latitude.abs() > 90.0 || longitude.abs() > 180.0) return null;

    return GeoPosition(latitude: latitude, longitude: longitude);
  }

  /// Great-circle distance to [other] in metres.
  double distanceTo(GeoPosition other) {
    const earthRadiusMetres = 6371000.0;

    final dLat = _toRadians(other.latitude - latitude);
    final dLon = _toRadians(other.longitude - longitude);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(latitude)) *
            math.cos(_toRadians(other.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    return earthRadiusMetres * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180.0;

  @override
  List<Object?> get props => [latitude, longitude];

  @override
  String toString() =>
      'GeoPosition(${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)})';
}

import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../features/clients/domain/entities/geo_position.dart';
import '../error/failure.dart';
import '../error/result.dart';
import '../utils/app_logger.dart';

/// Device location, behind an interface so the rest of the app does not depend
/// on `geolocator` and can be unit-tested without a platform channel.
///
/// This file previously contained only the comment `// Location service`.
/// Location handling lived inline in the map controller, where a denied
/// permission produced a red `Get.snackbar` from inside business logic and a
/// hung GPS lookup had nothing to stop it.
abstract interface class LocationService {
  /// Ensures location permission, requesting it if it has not been decided.
  Future<Result<void>> ensurePermission();

  /// A single current fix.
  ///
  /// [timeout] is mandatory in effect: a GPS lookup can hang indefinitely
  /// indoors, and this is called during startup, so it must always settle.
  Future<Result<GeoPosition>> currentPosition({
    Duration timeout = const Duration(seconds: 8),
  });

  /// Whether the device's location services are switched on at all.
  Future<bool> isServiceEnabled();
}

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<bool> isServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } on Object catch (error) {
      AppLogger.warn('Could not read location service state', error: error);
      return false;
    }
  }

  @override
  Future<Result<void>> ensurePermission() async {
    try {
      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      return switch (permission) {
        LocationPermission.always ||
        LocationPermission.whileInUse => const Result.success(null),

        LocationPermission.deniedForever => const Result.failure(
          PermissionFailure(
            message:
                'La localisation est refusée. Activez-la dans les réglages '
                'pour voir votre position sur la carte.',
            isPermanentlyDenied: true,
          ),
        ),

        _ => const Result.failure(
          PermissionFailure(
            message: 'Autorisez la localisation pour voir votre position.',
          ),
        ),
      };
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'Location permission check failed',
        error: error,
        stackTrace: stackTrace,
      );
      return Result.failure(
        PermissionFailure(
          message: 'Localisation indisponible sur cet appareil.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<GeoPosition>> currentPosition({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final permission = await ensurePermission();
    if (permission case FailureResult<void>(:final failure)) {
      return Result.failure(failure);
    }

    if (!await isServiceEnabled()) {
      return const Result.failure(
        PermissionFailure(message: 'Le GPS de l\'appareil est désactivé.'),
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          // Bounds the platform call itself.
          timeLimit: timeout,
        ),
      // And bounds the Dart side, because the platform timeout is not honoured
      // on every Android implementation. Without this a startup fix could hang
      // the initialization screen forever.
      ).timeout(timeout + const Duration(seconds: 2));

      final geo = GeoPosition.tryCreate(position.latitude, position.longitude);
      if (geo == null) {
        return const Result.failure(
          UnexpectedFailure(message: 'Position GPS invalide.'),
        );
      }

      return Result.success(geo);
    } on TimeoutException {
      return const Result.failure(
        TimeoutFailure(message: 'Impossible d\'obtenir votre position.'),
      );
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'Failed to obtain a position',
        error: error,
        stackTrace: stackTrace,
      );
      return Result.failure(
        UnexpectedFailure(
          message: 'Impossible d\'obtenir votre position.',
          cause: error,
        ),
      );
    }
  }
}

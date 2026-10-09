import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/utils/app_logger.dart';
import '../../clients/domain/entities/client.dart';

/// Builds and caches the custom map pins.
///
/// This replaces `_buildClientMarkerIcon` (audit H-2), which for **every single
/// marker on every refresh** performed the whole pipeline from scratch:
///
/// 1. `rootBundle.load('assets/images/picker.png')` — uncached asset read,
/// 2. `instantiateImageCodec` decode,
/// 3. `PictureRecorder` + `Canvas` draw,
/// 4. `picture.toImage()` rasterise,
/// 5. `toByteData(format: png)` PNG encode.
///
/// With a hundred clients that was a hundred asset reads, decodes,
/// rasterisations and PNG encodes per refresh — and the refresh ran on every
/// marker drag frame and after every form keystroke.
///
/// Three things change here:
///
/// * The pin asset is decoded **once** and reused.
/// * Finished [BitmapDescriptor]s are cached under a key derived from what
///   actually affects the pixels, so a repeated refresh is pure cache hits.
/// * Concurrent requests for the same uncached icon share one build, instead of
///   racing to rasterise the same image several times.
class MarkerIconCache {
  MarkerIconCache({
    this.pinAsset = 'assets/images/picker.png',
    this.maxEntries = 120,
  });

  final String pinAsset;

  /// Cache ceiling. Entries are evicted oldest-first; the dominant working set
  /// is one icon per client kind plus one per client that has a photo.
  final int maxEntries;

  /// Logical size of the rendered marker, matching the original implementation
  /// so pin placement on the map is unchanged.
  static const Size _markerSize = Size(140, 180);
  static const double _pinTargetWidth = 120;
  static const double _avatarDiameter = 56;
  static const Offset _avatarCentre = Offset(70, 36);
  static const double _avatarRadius = 28;
  static const double _avatarRingWidth = 3;
  static const double _pinTop = 44;

  final Map<String, BitmapDescriptor> _cache = <String, BitmapDescriptor>{};
  final Map<String, Future<BitmapDescriptor>> _pending =
      <String, Future<BitmapDescriptor>>{};

  ui.Image? _pinImage;
  Future<ui.Image?>? _pinImageLoad;

  /// Device pixel ratio the cache was built for. When it changes (the app moved
  /// to another display) the cache is dropped so pins are not blurry.
  double _pixelRatio = 1.0;

  int get size => _cache.length;

  /// Returns the icon for a client pin, building it only on a cache miss.
  ///
  /// [avatarBytes] is the client's shopfront photo; when `null` the plain
  /// coloured pin is used.
  Future<BitmapDescriptor> iconFor({
    required ClientKind kind,
    Uint8List? avatarBytes,
    double pixelRatio = 1.0,
  }) {
    if (pixelRatio != _pixelRatio) {
      // Rebuilding at the new density is cheaper than shipping blurry pins.
      _pixelRatio = pixelRatio;
      clear();
    }

    final key = _keyFor(kind, avatarBytes);

    final cached = _cache[key];
    if (cached != null) return Future.value(cached);

    // Share one build between concurrent callers. Without this, the first
    // marker refresh after a load rasterises the same icon once per marker.
    final pending = _pending[key];
    if (pending != null) return pending;

    final build = _build(kind: kind, avatarBytes: avatarBytes)
        .then((descriptor) {
          _put(key, descriptor);
          return descriptor;
        })
        // The braces matter: `whenComplete` awaits a Future returned by its
        // callback, and `Map.remove` returns the removed value — which here is
        // this very future. An expression body would make the future wait on
        // itself and never complete, hanging every marker build.
        .whenComplete(() {
          _pending.remove(key);
        });

    _pending[key] = build;
    return build;
  }

  /// Builds the plain pin for each client kind ahead of time.
  ///
  /// Called once when the map is created, so the first portfolio load paints
  /// its markers from cache instead of rasterising during the first frames.
  Future<void> prewarm({double pixelRatio = 1.0}) async {
    await Future.wait(
      ClientKind.values.map(
        (kind) => iconFor(kind: kind, pixelRatio: pixelRatio),
      ),
    );
  }

  /// A key covering exactly the inputs that change the rendered pixels.
  ///
  /// For the avatar, the byte length plus a content hash identifies the image
  /// without retaining it or hashing megabytes — [Object.hashAll] over the
  /// whole buffer would be as expensive as the draw it is meant to avoid, so a
  /// strided sample is used instead.
  String _keyFor(ClientKind kind, Uint8List? avatarBytes) {
    if (avatarBytes == null || avatarBytes.isEmpty) {
      return '${kind.name}@$_pixelRatio';
    }
    return '${kind.name}@$_pixelRatio#${avatarBytes.length}'
        '.${_sampleHash(avatarBytes)}';
  }

  /// Hashes up to 64 evenly spaced bytes. Collisions would show the wrong photo
  /// on a pin, so length is part of the key as well.
  static int _sampleHash(Uint8List bytes) {
    const samples = 64;
    final stride = bytes.length <= samples ? 1 : bytes.length ~/ samples;

    var hash = 0x1f;
    for (var i = 0; i < bytes.length; i += stride) {
      hash = 0x1fffffff & (hash * 31 + bytes[i]);
    }
    return hash;
  }

  void _put(String key, BitmapDescriptor descriptor) {
    if (_cache.length >= maxEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = descriptor;
  }

  Future<BitmapDescriptor> _build({
    required ClientKind kind,
    Uint8List? avatarBytes,
  }) async {
    try {
      final pin = await _loadPinImage();
      if (pin == null) return _fallbackFor(kind);

      final scale = _pixelRatio;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.scale(scale);

      _drawPin(canvas, pin, kind);

      if (avatarBytes != null && avatarBytes.isNotEmpty) {
        final avatar = await _decode(
          avatarBytes,
          targetWidth: (_avatarDiameter * scale).round(),
        );
        if (avatar != null) {
          _drawAvatar(canvas, avatar);
          // The decoded avatar is not cached — the finished descriptor is —
          // so its native memory is released immediately.
          avatar.dispose();
        }
      }

      final picture = recorder.endRecording();
      final image = await picture.toImage(
        (_markerSize.width * scale).round(),
        (_markerSize.height * scale).round(),
      );
      picture.dispose();

      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      if (data == null) return _fallbackFor(kind);

      return BitmapDescriptor.bytes(
        data.buffer.asUint8List(),
        imagePixelRatio: scale,
      );
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'Failed to build marker icon for ${kind.name}',
        error: error,
        stackTrace: stackTrace,
      );
      return _fallbackFor(kind);
    }
  }

  void _drawPin(Canvas canvas, ui.Image pin, ClientKind kind) {
    final paint = Paint();
    final tint = _tintFor(kind);
    if (tint != null) {
      paint.colorFilter = ColorFilter.mode(tint, BlendMode.modulate);
    }

    // The decoded pin is already at _pinTargetWidth, so it is drawn at its
    // natural size and centred horizontally.
    final left = (_markerSize.width - pin.width / _pixelRatio) / 2;
    canvas.drawImage(pin, Offset(left, _pinTop), paint);
  }

  void _drawAvatar(Canvas canvas, ui.Image avatar) {
    canvas.drawCircle(
      _avatarCentre,
      _avatarRadius + _avatarRingWidth,
      Paint()..color = Colors.white,
    );

    final rect = Rect.fromCircle(center: _avatarCentre, radius: _avatarRadius);

    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    paintImage(canvas: canvas, rect: rect, image: avatar, fit: BoxFit.cover);
    canvas.restore();
  }

  /// Pin tint per kind, preserving the original colour coding so the map reads
  /// the same to the representatives who already use it.
  static Color? _tintFor(ClientKind kind) => switch (kind) {
    ClientKind.b2b => Colors.green,
    ClientKind.prospect => Colors.blue,
    ClientKind.subClient => Colors.orange,
  };

  static BitmapDescriptor _fallbackFor(ClientKind kind) =>
      BitmapDescriptor.defaultMarkerWithHue(switch (kind) {
        ClientKind.b2b => BitmapDescriptor.hueGreen,
        ClientKind.prospect => BitmapDescriptor.hueBlue,
        ClientKind.subClient => BitmapDescriptor.hueOrange,
      });

  /// Loads and decodes the pin asset once per cache lifetime.
  Future<ui.Image?> _loadPinImage() {
    final existing = _pinImage;
    if (existing != null) return Future.value(existing);

    return _pinImageLoad ??= _doLoadPinImage();
  }

  Future<ui.Image?> _doLoadPinImage() async {
    try {
      final data = await rootBundle.load(pinAsset);
      final image = await _decode(
        data.buffer.asUint8List(),
        targetWidth: (_pinTargetWidth * _pixelRatio).round(),
      );
      _pinImage = image;
      return image;
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'Could not load marker pin asset $pinAsset',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    } finally {
      _pinImageLoad = null;
    }
  }

  static Future<ui.Image?> _decode(Uint8List bytes, {int? targetWidth}) async {
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: targetWidth,
      );
      final frame = await codec.getNextFrame();
      // The codec is deliberately *not* disposed here: `frame.image` is owned
      // by it, and releasing the codec invalidates the image. Drawing an
      // invalidated image makes the subsequent `Picture.toImage()` never
      // complete, which is a silent hang rather than an error. The codec is
      // collected once the returned image is disposed by the caller.
      return frame.image;
    } on Object {
      // A corrupt shopfront photo must not take the marker down with it.
      return null;
    }
  }

  /// Drops every cached icon and the decoded pin.
  void clear() {
    _cache.clear();
    _pinImage?.dispose();
    _pinImage = null;
  }

  void dispose() {
    clear();
    _pending.clear();
  }
}

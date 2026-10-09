import 'dart:typed_data';

import 'package:dayco_mobile/features/cartography/presentation/marker_icon_cache.dart';
import 'package:dayco_mobile/features/clients/domain/entities/client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// These exercise the real rasterisation pipeline (`instantiateImageCodec`,
/// `Picture.toImage`, `Image.toByteData`), which only completes while the test
/// binding is pumping. They therefore run inside `testWidgets` +
/// `tester.runAsync` rather than a plain `test`, where those futures never
/// resolve.
void main() {
  late MarkerIconCache cache;

  setUp(() => cache = MarkerIconCache());
  tearDown(() => cache.dispose());

  /// Two visually distinct payloads. They need not decode successfully to
  /// exercise the cache's keying — a failed decode still yields a usable
  /// descriptor, which is itself asserted below.
  Uint8List bytesOf(int seed, {int length = 256}) =>
      Uint8List.fromList(List<int>.generate(length, (i) => (i * seed) % 256));

  group('caching', () {
    testWidgets('returns the identical descriptor on a repeat request', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final first = await cache.iconFor(kind: ClientKind.b2b);
        final second = await cache.iconFor(kind: ClientKind.b2b);

        // This is the property that removes the per-marker rasterisation: the
        // second request does no work at all.
        expect(identical(first, second), isTrue);
        expect(cache.size, 1);
      });
    });

    testWidgets('caches one entry per client kind', (tester) async {
      await tester.runAsync(() async {
        await cache.iconFor(kind: ClientKind.b2b);
        await cache.iconFor(kind: ClientKind.subClient);
        await cache.iconFor(kind: ClientKind.prospect);

        expect(cache.size, 3);
      });
    });

    testWidgets('a hundred markers of the same kind build one icon', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final icons = await Future.wait(
          List.generate(100, (_) => cache.iconFor(kind: ClientKind.subClient)),
        );

        expect(cache.size, 1);
        expect(icons.every((icon) => identical(icon, icons.first)), isTrue);
      });
    });

    testWidgets('concurrent misses for the same key share one build', (
      tester,
    ) async {
      await tester.runAsync(() async {
        // Issued in the same turn, so none can yet see another's cache entry —
        // they must coalesce on the pending future instead.
        final results = await Future.wait([
          cache.iconFor(kind: ClientKind.b2b),
          cache.iconFor(kind: ClientKind.b2b),
          cache.iconFor(kind: ClientKind.b2b),
        ]);

        expect(cache.size, 1);
        expect(identical(results[0], results[1]), isTrue);
        expect(identical(results[1], results[2]), isTrue);
      });
    });

    testWidgets('distinguishes two different photos for the same kind', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final a = await cache.iconFor(
          kind: ClientKind.b2b,
          avatarBytes: bytesOf(7),
        );
        final b = await cache.iconFor(
          kind: ClientKind.b2b,
          avatarBytes: bytesOf(11),
        );

        expect(identical(a, b), isFalse);
        expect(cache.size, 2);
      });
    });

    testWidgets('reuses the entry for identical photo bytes', (tester) async {
      await tester.runAsync(() async {
        final a = await cache.iconFor(
          kind: ClientKind.b2b,
          avatarBytes: bytesOf(7),
        );
        final b = await cache.iconFor(
          kind: ClientKind.b2b,
          avatarBytes: bytesOf(7),
        );

        expect(identical(a, b), isTrue);
        expect(cache.size, 1);
      });
    });

    testWidgets('treats empty photo bytes as no photo', (tester) async {
      await tester.runAsync(() async {
        final withNull = await cache.iconFor(kind: ClientKind.b2b);
        final withEmpty = await cache.iconFor(
          kind: ClientKind.b2b,
          avatarBytes: Uint8List(0),
        );

        expect(identical(withNull, withEmpty), isTrue);
        expect(cache.size, 1);
      });
    });

    testWidgets('distinguishes photos differing only in length', (tester) async {
      await tester.runAsync(() async {
        final short = await cache.iconFor(
          kind: ClientKind.b2b,
          avatarBytes: bytesOf(5, length: 128),
        );
        final long = await cache.iconFor(
          kind: ClientKind.b2b,
          avatarBytes: bytesOf(5, length: 129),
        );

        expect(identical(short, long), isFalse);
      });
    });
  });

  group('eviction', () {
    testWidgets('respects the cache ceiling', (tester) async {
      await tester.runAsync(() async {
        final bounded = MarkerIconCache(maxEntries: 4);
        addTearDown(bounded.dispose);

        for (var seed = 1; seed <= 20; seed++) {
          await bounded.iconFor(
            kind: ClientKind.b2b,
            avatarBytes: bytesOf(seed),
          );
        }

        expect(bounded.size, lessThanOrEqualTo(4));
      });
    });
  });

  group('pixel ratio', () {
    testWidgets('rebuilds when the display density changes', (tester) async {
      await tester.runAsync(() async {
        final at1x = await cache.iconFor(kind: ClientKind.b2b, pixelRatio: 1.0);
        final at3x = await cache.iconFor(kind: ClientKind.b2b, pixelRatio: 3.0);

        expect(identical(at1x, at3x), isFalse);
        // Stale-density entries are dropped rather than kept alongside.
        expect(cache.size, 1);
      });
    });
  });

  group('resilience', () {
    testWidgets('a missing pin asset still yields a usable descriptor', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final broken = MarkerIconCache(
          pinAsset: 'assets/images/does_not_exist.png',
        );
        addTearDown(broken.dispose);

        final icon = await broken.iconFor(kind: ClientKind.prospect);

        // Falls back to a default hued marker instead of leaving the map bare.
        expect(icon, isA<BitmapDescriptor>());
      });
    });

    testWidgets('an undecodable photo still yields a usable descriptor', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final icon = await cache.iconFor(
          kind: ClientKind.b2b,
          avatarBytes: Uint8List.fromList([0, 1, 2, 3]),
        );

        expect(icon, isA<BitmapDescriptor>());
      });
    });

    testWidgets('prewarm populates one icon per kind', (tester) async {
      await tester.runAsync(() async {
        await cache.prewarm();
        expect(cache.size, ClientKind.values.length);
      });
    });

    testWidgets('clear empties the cache and allows rebuilding', (tester) async {
      await tester.runAsync(() async {
        await cache.iconFor(kind: ClientKind.b2b);
        cache.clear();
        expect(cache.size, 0);

        await cache.iconFor(kind: ClientKind.b2b);
        expect(cache.size, 1);
      });
    });
  });
}

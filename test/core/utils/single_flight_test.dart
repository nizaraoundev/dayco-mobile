import 'dart:async';

import 'package:dayco_mobile/core/utils/single_flight.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SingleFlight', () {
    test('collapses concurrent calls for the same key into one execution', () async {
      final flight = SingleFlight<String, int>();
      var executions = 0;
      final gate = Completer<void>();

      Future<int> action() async {
        executions++;
        await gate.future;
        return 42;
      }

      final first = flight.run('clients', action);
      final second = flight.run('clients', action);
      final third = flight.run('clients', action);

      expect(executions, 1, reason: 'only the first caller should execute');

      gate.complete();
      expect(await Future.wait([first, second, third]), [42, 42, 42]);
    });

    test('runs different keys in parallel', () async {
      final flight = SingleFlight<String, String>();
      final gate = Completer<void>();

      final a = flight.run('a', () async {
        await gate.future;
        return 'a';
      });
      final b = flight.run('b', () async {
        await gate.future;
        return 'b';
      });

      expect(flight.activeCount, 2);

      gate.complete();
      expect(await Future.wait([a, b]), ['a', 'b']);
    });

    test('releases the key after a failure so retries are possible', () async {
      final flight = SingleFlight<String, int>();

      await expectLater(
        flight.run('save', () async => throw StateError('boom')),
        throwsStateError,
      );

      expect(
        flight.isRunning('save'),
        isFalse,
        reason: 'a failed call must not leave the key permanently busy',
      );

      // The key is reusable, so the user can retry.
      expect(await flight.run('save', () async => 7), 7);
    });

    test('runOrSkip drops the second concurrent call instead of joining it', () async {
      final flight = SingleFlight<String, int>();
      var executions = 0;
      final gate = Completer<void>();

      Future<int> action() async {
        executions++;
        await gate.future;
        return 1;
      }

      final first = flight.runOrSkip('submit', action);
      final second = flight.runOrSkip('submit', action);

      expect(await second, isNull, reason: 'double tap must be dropped');

      gate.complete();
      expect(await first, 1);
      expect(executions, 1);
    });
  });

  group('Mutex', () {
    test('serialises a double submit to a single execution', () async {
      final mutex = Mutex<String>();
      var submissions = 0;
      final gate = Completer<void>();

      Future<String> submit() async {
        submissions++;
        await gate.future;
        return 'created';
      }

      final first = mutex.runOrSkip(submit);
      final second = mutex.runOrSkip(submit);

      expect(mutex.isRunning, isTrue);
      expect(await second, isNull);

      gate.complete();
      expect(await first, 'created');
      expect(submissions, 1);
    });
  });

  group('LatestWins', () {
    test('discards a stale result that completes after a newer one', () async {
      final latest = LatestWins();
      final committed = <String>[];

      final slowFirst = Completer<String>();
      final fastSecond = Completer<String>();

      // First (slow) call starts.
      final firstRun = latest.run<String>(
        () => slowFirst.future,
        commit: committed.add,
      );

      // Second (fast) call starts and completes first.
      final secondRun = latest.run<String>(
        () => fastSecond.future,
        commit: committed.add,
      );

      fastSecond.complete('new');
      await secondRun;
      expect(committed, ['new']);

      // The older call now completes — its result must be thrown away.
      slowFirst.complete('stale');
      await firstRun;

      expect(
        committed,
        ['new'],
        reason: 'an older run must never overwrite a newer result',
      );
    });

    test('commits a result when it is still the latest', () async {
      final latest = LatestWins();
      final committed = <int>[];

      await latest.run<int>(() async => 1, commit: committed.add);
      await latest.run<int>(() async => 2, commit: committed.add);

      expect(committed, [1, 2]);
    });
  });
}

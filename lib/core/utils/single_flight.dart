import 'dart:async';

/// Collapses concurrent identical operations into one.
///
/// Addresses two distinct problems from the audit:
///
/// * **Duplicate requests.** Several screens fetched the same data from more
///   than one trigger — the map controller called both `loadMyClients()` and
///   `loadAllSubClientsAndProspectsForCommercial()` from `onInit`, and the page
///   re-created the controller on every rebuild, firing them again. With
///   [run], the second caller awaits the first call's future instead of opening
///   a second connection.
///
/// * **Double submit.** A representative tapping "Enregistrer" twice issued two
///   full creation round-trips, producing duplicate clients. [run] returns the
///   in-flight future for the same key, so the second tap is a no-op.
///
/// Keyed so that, for example, two different clients' detail loads still run in
/// parallel while two loads of *the same* client do not.
class SingleFlight<K, T> {
  final Map<K, Future<T>> _inFlight = {};

  /// Whether an operation for [key] is currently running.
  bool isRunning(K key) => _inFlight.containsKey(key);

  /// Number of operations currently running.
  int get activeCount => _inFlight.length;

  /// Runs [action] for [key], or joins the existing call if one is in flight.
  ///
  /// The entry is removed in a `finally`, so a thrown error cannot leave the key
  /// permanently "busy" — the bug pattern that produced buttons disabled
  /// forever after one failed request.
  Future<T> run(K key, Future<T> Function() action) {
    final existing = _inFlight[key];
    if (existing != null) return existing;

    // Started eagerly rather than via `Future(action)`, so the work begins in
    // this turn of the event loop. Deferring it would add a scheduling hop to
    // every request and make the ordering of concurrent calls unpredictable.
    late final Future<T> future;
    try {
      future = action();
    } on Object catch (error, stackTrace) {
      // A synchronous throw from `action` must still surface as a failed future,
      // not propagate out of `run` and bypass the bookkeeping below.
      return Future<T>.error(error, stackTrace);
    }

    _inFlight[key] = future;

    // The braces matter. `whenComplete` awaits a Future returned by its
    // callback, and `Map.remove` returns the removed value — a Future here. An
    // expression body would make the result wait on the entry it just removed;
    // it happens to be already-complete in this arrangement, but storing the
    // wrapper instead of `future` would turn it into a future awaiting itself,
    // which never completes.
    return future.whenComplete(() {
      _inFlight.remove(key);
    });
  }

  /// Runs [action] only if nothing is in flight for [key]; otherwise returns
  /// `null` immediately.
  ///
  /// Use this where joining the previous call would be wrong — a "save" button,
  /// where the second tap must be dropped rather than resolved with the first
  /// save's result.
  Future<T?> runOrSkip(K key, Future<T> Function() action) {
    if (_inFlight.containsKey(key)) return Future<T?>.value(null);
    return run(key, action);
  }

  /// Forgets all in-flight bookkeeping. Does not cancel the underlying work;
  /// call this from `close()` only.
  void reset() => _inFlight.clear();
}

/// A [SingleFlight] for operations that need no key.
class Mutex<T> {
  final SingleFlight<int, T> _delegate = SingleFlight<int, T>();

  bool get isRunning => _delegate.isRunning(0);

  Future<T> run(Future<T> Function() action) => _delegate.run(0, action);

  Future<T?> runOrSkip(Future<T> Function() action) =>
      _delegate.runOrSkip(0, action);

  void reset() => _delegate.reset();
}

/// Serialises async work so that only the newest request's result is applied.
///
/// This is the fix for the racing marker refresh (audit H-3): `_refreshMarkers()`
/// was `async`, awaited per-marker rasterisation, and ended with
/// `markers.assignAll(...)`. Concurrent invocations interleaved and a slower,
/// older run could finish last and overwrite the newer marker set, leaving the
/// map showing state the app had already moved past.
///
/// [run] stamps each call with an incrementing sequence number and only invokes
/// the commit callback when the completing call is still the latest one.
class LatestWins {
  int _issued = 0;
  int _applied = 0;

  /// Whether [sequence] is still the most recently issued operation.
  bool isCurrent(int sequence) => sequence == _issued;

  /// Runs [action], then calls [commit] only if no newer call was started in
  /// the meantime. Stale results are computed but discarded.
  Future<void> run<T>(
    Future<T> Function() action, {
    required void Function(T value) commit,
  }) async {
    final sequence = ++_issued;
    final value = await action();

    // A newer call superseded this one, or an even newer result already landed.
    if (sequence != _issued || sequence < _applied) return;

    _applied = sequence;
    commit(value);
  }

  void reset() {
    _issued = 0;
    _applied = 0;
  }
}

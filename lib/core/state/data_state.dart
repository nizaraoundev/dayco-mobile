import 'package:equatable/equatable.dart';

import '../error/failure.dart';

/// The lifecycle of an asynchronously loaded value.
///
/// The original controllers tracked this with loose, independent `RxBool`s
/// (`isLoading`, `isLoadingMore`, `isLoadingMyClients`, …) alongside a separate
/// list and a separate nullable error string. Nothing stopped those from
/// disagreeing — `isLoading == true` with data already present, or an error set
/// while loading never cleared — which is exactly how the app ended up stuck on
/// spinners and showing stale content.
///
/// [DataState] makes the states mutually exclusive, so the UI can only ever
/// render one of them, and every transition is explicit.
enum DataStatus {
  /// Nothing has been requested yet.
  initial,

  /// A first load is running; there is no data to show.
  loading,

  /// Loaded and non-empty.
  success,

  /// Loaded successfully, but the result set is empty. Distinguished from
  /// [success] so the UI can show a meaningful empty state rather than a blank
  /// list, and from [failure] so it does not show a retry button for a
  /// legitimately empty portfolio.
  empty,

  /// The load failed. [DataState.failure] is non-null in this state.
  failure,
}

/// An immutable snapshot of one asynchronously loaded collection or value.
///
/// [data] is retained across a [refreshing] reload so the UI can keep showing
/// the previous content instead of flashing a spinner — and retained on
/// [failure] so a failed refresh degrades to "stale data + error banner"
/// rather than losing the screen's content.
class DataState<T> extends Equatable {
  const DataState({
    this.status = DataStatus.initial,
    this.data,
    this.failure,
    this.isRefreshing = false,
    this.isLoadingMore = false,
  });

  const DataState.initial() : this();

  const DataState.loading() : this(status: DataStatus.loading);

  /// Builds the correct terminal state for [value], choosing [DataStatus.empty]
  /// over [DataStatus.success] when the collection is empty.
  factory DataState.loaded(T value) {
    final isEmpty = value is Iterable ? value.isEmpty : false;
    return DataState<T>(
      status: isEmpty ? DataStatus.empty : DataStatus.success,
      data: value,
    );
  }

  const DataState.failed(Failure failure, {T? staleData})
    : this(status: DataStatus.failure, failure: failure, data: staleData);

  final DataStatus status;
  final T? data;
  final Failure? failure;

  /// A reload running on top of existing [data] (pull-to-refresh).
  final bool isRefreshing;

  /// A next-page fetch running on top of existing [data].
  final bool isLoadingMore;

  bool get isInitial => status == DataStatus.initial;

  /// True only for a *blocking* first load. A refresh over existing data is
  /// deliberately not "loading", so the list is never replaced by a spinner.
  bool get isLoading => status == DataStatus.loading;

  bool get isSuccess => status == DataStatus.success;

  bool get isEmpty => status == DataStatus.empty;

  bool get hasFailed => status == DataStatus.failure;

  bool get hasData => data != null;

  /// True when any request is in flight — the signal for disabling submit
  /// buttons so a double tap cannot issue a second request.
  bool get isBusy => isLoading || isRefreshing || isLoadingMore;

  /// Non-null data, for the branches where the status guarantees it.
  T get requireData => data as T;

  DataState<T> toLoading() => DataState<T>(
    // A reload that already has data keeps showing it.
    status: hasData ? status : DataStatus.loading,
    data: data,
    isRefreshing: hasData,
  );

  DataState<T> toLoadingMore() => DataState<T>(
    status: status,
    data: data,
    isLoadingMore: true,
  );

  DataState<T> toLoaded(T value) => DataState<T>.loaded(value);

  DataState<T> toFailed(Failure failure) =>
      DataState<T>.failed(failure, staleData: data);

  DataState<T> copyWith({
    DataStatus? status,
    T? data,
    Failure? failure,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool clearFailure = false,
  }) => DataState<T>(
    status: status ?? this.status,
    data: data ?? this.data,
    failure: clearFailure ? null : (failure ?? this.failure),
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
  );

  @override
  List<Object?> get props => [
    status,
    data,
    failure,
    isRefreshing,
    isLoadingMore,
  ];
}

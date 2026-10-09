import 'failure.dart';

/// The outcome of an operation that can fail in a known way.
///
/// Repositories return `Result<T>` instead of throwing, so every caller is
/// forced by the type system to handle the failure path. That is what makes
/// "stuck forever on a spinner" structurally impossible: there is no way to
/// `await` a repository call and forget that it might not have succeeded.
sealed class Result<T> {
  const Result();

  const factory Result.success(T value) = Success<T>;

  const factory Result.failure(Failure failure) = FailureResult<T>;

  bool get isSuccess => this is Success<T>;

  bool get isFailure => this is FailureResult<T>;

  /// The value when successful, otherwise `null`.
  T? get valueOrNull => switch (this) {
    Success<T>(:final value) => value,
    FailureResult<T>() => null,
  };

  /// The failure when unsuccessful, otherwise `null`.
  Failure? get failureOrNull => switch (this) {
    Success<T>() => null,
    FailureResult<T>(:final failure) => failure,
  };

  /// Collapses both branches into a single value.
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(Failure failure) onFailure,
  }) => switch (this) {
    Success<T>(:final value) => onSuccess(value),
    FailureResult<T>(:final failure) => onFailure(failure),
  };

  /// Transforms the success value, preserving any failure.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Success<T>(:final value) => Result<R>.success(transform(value)),
    FailureResult<T>(:final failure) => Result<R>.failure(failure),
  };

  /// Chains another fallible operation onto a success.
  Result<R> flatMap<R>(Result<R> Function(T value) transform) => switch (this) {
    Success<T>(:final value) => transform(value),
    FailureResult<T>(:final failure) => Result<R>.failure(failure),
  };
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;

  @override
  String toString() => 'Success($value)';
}

final class FailureResult<T> extends Result<T> {
  const FailureResult(this.failure);

  final Failure failure;

  @override
  String toString() => 'FailureResult($failure)';
}

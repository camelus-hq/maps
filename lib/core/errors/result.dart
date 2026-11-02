import 'app_exception.dart';

/// The outcome of a use case: either [Ok] with a value or [Err] with an
/// [AppException]. Use cases return this instead of throwing at their callers.
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;

  const factory Result.err(AppException error) = Err<T>;

  bool get isOk => this is Ok<T>;

  bool get isErr => this is Err<T>;

  T? get valueOrNull => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>() => null,
  };

  AppException? get errorOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(:final error) => error,
  };

  /// Collapses both branches into a single value.
  R fold<R>({
    required R Function(T value) ok,
    required R Function(AppException error) err,
  }) => switch (this) {
    Ok<T>(:final value) => ok(value),
    Err<T>(:final error) => err(error),
  };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.error);

  final AppException error;
}

/// Typed failures that may cross the domain boundary.
///
/// Every failure that can reach the UI is one of these; nothing throws an
/// opaque `Exception` past a use case, so presentation can always render an
/// error state instead of crashing (AGENTS.md "Never crash").
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause});

  /// Human-readable and safe to show in an error state.
  final String message;

  /// The underlying error, for logging only — never shown to the user.
  final Object? cause;

  /// Whether this failure is a lost network connection (so the UI can show a
  /// "you're offline" state instead of a generic error). See [OfflineException].
  bool get isOffline => this is OfflineException;

  @override
  String toString() => '$runtimeType($message)';
}

/// A network request failed (connection, DNS, non-2xx).
final class NetworkException extends AppException {
  const NetworkException(super.message, {super.cause});
}

/// A network request failed because the device appears to be offline (no
/// route to the host / connection dropped). A subtype of [NetworkException] so
/// existing "network failed" handling still applies.
final class OfflineException extends NetworkException {
  const OfflineException(super.message, {super.cause});
}

/// A request exceeded its deadline.
final class RequestTimeoutException extends AppException {
  const RequestTimeoutException(super.message, {super.cause});
}

/// The requested resource does not exist.
final class NotFoundException extends AppException {
  const NotFoundException(super.message, {super.cause});
}

/// Input or a hostile payload failed validation.
final class ValidationException extends AppException {
  const ValidationException(super.message, {super.cause});
}

/// The feature is unavailable in this build or configuration.
final class UnsupportedException extends AppException {
  const UnsupportedException(super.message, {super.cause});
}

/// Fallback for anything unclassified.
final class UnknownException extends AppException {
  const UnknownException(super.message, {super.cause});
}

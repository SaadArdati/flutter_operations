/// Represents the state of an asynchronous operation.
///
/// Four primary variants exist and can be matched exhaustively with Dart 3's
/// sealed classes:
/// * **[IdleOperation]**: _Ready_ but **not-loading** state. This only
///   appears when `loadOnInit / listenOnInit` is set to `false` **or** when
///   `setIdle()` is called manually. It can still carry cached data.
/// * **[LoadingOperation]**: Operation in progress (optionally with cached
///   data). `IdleOperation` extends this class so a single pattern can cover
///   both cases when the extra distinction is not important.
/// * **[SuccessOperation]**: Operation finished successfully. Two subtypes
///   offer opt-in specificity (like [IdleOperation] / [LoadingOperation]):
///   * **[ValueSuccessOperation]**: Carries non-null data (`T`).
///   * **[VoidSuccessOperation]**: No data (delete, fire-and-forget, etc.).
///   Matching [SuccessOperation] covers both; match the subtypes for
///   type-safe access.
/// * **[ErrorOperation]**: Operation failed. Cached data from a previous
///   success is preserved when available for graceful degradation.
///
/// These variants unlock expressive and compile-time-checked UI code like:
/// ```dart
/// switch (state) {
///   IdleOperation() => const Text('Ready'),
///   LoadingOperation(data: null) => const CircularProgressIndicator(),
///   LoadingOperation(:var data?) => Stack(children:[DataView(data), const LinearProgressIndicator()]),
///   VoidSuccessOperation(:var message) => Text(message ?? 'Done!'),
///   ValueSuccessOperation(:var data) => DataView(data),
///   ErrorOperation(:var message, data: null) => ErrorBanner(message),
///   ErrorOperation(:var message, :var data?) => Stack(children:[DataView(data), ErrorBanner(message)]),
/// }
/// ```
sealed class OperationState<T> {
  /// Creates a state with an optional data parameter.
  const OperationState({T? data}) : _data = data;

  /// The data associated with the operation, if any.
  final T? _data;

  /// The data associated with the operation, if any.
  T? get data => _data;

  /// Whether this state has associated data.
  bool get hasData => _data != null;

  /// Whether this state has no associated data.
  bool get hasNoData => _data == null;

  /// A convenience getter to check if the operation is currently loading
  /// and not an idle state.
  bool get isLoading => this is LoadingOperation<T> && !isIdle;

  /// A convenience getter to check if the operation is idle.
  bool get isIdle => this is IdleOperation<T>;

  /// A convenience getter to check if the operation is not idle.
  bool get isNotIdle => !isIdle;

  /// A convenience getter to check if the operation is currently not loading.
  bool get isNotLoading => !isLoading;

  /// A convenience getter to check if the operation has successfully loaded
  /// data.
  bool get isSuccess => this is SuccessOperation<T>;

  /// A convenience getter to check if the operation has not successfully loaded
  /// data.
  bool get isNotSuccess => !isSuccess;

  /// A convenience getter to check if the operation has encountered an error.
  bool get isError => this is ErrorOperation<T>;

  /// A convenience getter to check if the operation has not encountered an
  /// error.
  bool get isNotError => !isError;
}

/// Represents an operation that is currently in progress.
/// Can optionally carry cached data from a previous successful operation.
base class LoadingOperation<T> extends OperationState<T> {
  /// Creates a loading state with optional cached data and idle flag.
  const LoadingOperation({super.data});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other.runtimeType == runtimeType &&
        other is LoadingOperation<T> &&
        other.data == data;
  }

  @override
  int get hashCode => Object.hash(runtimeType, data);

  @override
  String toString() => 'LoadingOperation(data: $data)';
}

/// Represents an idle operation that is ready but not currently loading.
/// Can optionally carry cached data from a previous successful operation.
final class IdleOperation<T> extends LoadingOperation<T> {
  /// Creates an idle loading state with optional cached data.
  const IdleOperation({super.data});

  @override
  String toString() => 'IdleOperation(data: $data)';
}

/// Represents a successfully completed operation.
///
/// This is the catch-all base type. Matching `case SuccessOperation()` in a
/// switch covers all success variants — but [data] returns `T?` because it
/// might be a [VoidSuccessOperation].
///
/// For type-safe access, match the subtypes instead:
/// * **[ValueSuccessOperation]**: Guarantees non-null [data] (`T`).
/// * **[VoidSuccessOperation]**: No data (delete, fire-and-forget, etc.).
///
/// This mirrors the [IdleOperation] / [LoadingOperation] pattern: you can
/// match the broad parent or the specific children — your choice.
///
/// ```dart
/// // Option 1: Broad match (data is T?, you handle nullability)
/// case SuccessOperation(:var data) => ...
///
/// // Option 2: Specific matches (compiler-guaranteed safety)
/// case VoidSuccessOperation(:var message) => Text(message ?? 'Done!'),
/// case ValueSuccessOperation(:var data) => DataView(data), // data is T
/// ```
///
/// Construction is backwards-compatible:
/// * `SuccessOperation(data: x)` creates a [ValueSuccessOperation].
/// * `SuccessOperation.empty()` creates a [VoidSuccessOperation].
sealed class SuccessOperation<T> extends OperationState<T> {
  /// Creates a success state with the operation's result data.
  ///
  /// This is a redirecting factory — the runtime type is
  /// [ValueSuccessOperation].
  const factory SuccessOperation({required T data, String? message}) =
      ValueSuccessOperation<T>;

  /// Creates an empty success state with no data.
  ///
  /// This is a redirecting factory — the runtime type is
  /// [VoidSuccessOperation].
  const factory SuccessOperation.empty({String? message}) =
      VoidSuccessOperation<T>;

  /// Internal generative constructor for subtypes.
  const SuccessOperation._({super.data, this.message});

  /// Whether the operation completed successfully but returned no data.
  ///
  /// Equivalent to `this is VoidSuccessOperation`.
  bool get empty => this is VoidSuccessOperation<T>;

  /// An optional message associated with the successful operation.
  final String? message;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other.runtimeType == runtimeType &&
        other is SuccessOperation<T> &&
        other._data == _data &&
        other.message == message;
  }

  @override
  int get hashCode => Object.hash(runtimeType, _data, message);

  @override
  String toString() => 'SuccessOperation(data: $_data, message: $message)';
}

/// A [SuccessOperation] that carries non-null result data.
///
/// The [data] getter returns `T` (non-nullable), guaranteed safe.
final class ValueSuccessOperation<T> extends SuccessOperation<T> {
  /// Creates a success state with the operation's result data.
  const ValueSuccessOperation({required T super.data, super.message})
    : super._();

  /// The data associated with the successful operation.
  ///
  /// Guaranteed non-null — safe to use without null checks.
  @override
  T get data => _data as T;

  @override
  String toString() => 'ValueSuccessOperation(data: $data, message: $message)';
}

/// A [SuccessOperation] that carries no data.
///
/// Use for operations like delete, logout, or fire-and-forget actions.
///
/// ```dart
/// switch (state) {
///   VoidSuccessOperation(:var message) => Text(message ?? 'Done!'),
///   ValueSuccessOperation(:var data) => DataView(data),
///   // ...
/// }
/// ```
final class VoidSuccessOperation<T> extends SuccessOperation<T> {
  /// Creates an empty success state with an optional message.
  const VoidSuccessOperation({super.message}) : super._();

  @override
  String toString() => 'VoidSuccessOperation(message: $message)';
}

/// Represents a failed operation with error details.
/// Can optionally retain cached data from a previous successful operation.
final class ErrorOperation<T> extends OperationState<T> {
  /// Creates an error state with the specified error details.
  const ErrorOperation({
    this.message,
    this.exception,
    this.stackTrace,
    super.data,
  });

  /// Human-readable error message for display to users.
  final String? message;

  /// The exception object that caused the error.
  final Object? exception;

  /// Stack trace from when the error occurred.
  final StackTrace? stackTrace;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other.runtimeType == runtimeType &&
        other is ErrorOperation<T> &&
        other.message == message &&
        other.exception == exception &&
        other.stackTrace == stackTrace &&
        other.data == data;
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, message, exception, stackTrace, data);

  @override
  String toString() =>
      'ErrorOperation(message: $message, exception: $exception, stackTrace: $stackTrace, data: $data)';
}

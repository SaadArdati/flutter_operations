/// Represents the state of an asynchronous operation.
///
/// Four runtime variants exist and can be matched exhaustively with Dart 3's
/// sealed classes:
/// * **[IdleOperation]**: _Ready_ but **not-loading** state. This only
///   appears when `loadOnInit / listenOnInit` is set to `false` **or** when
///   `setIdle()` is called manually. It can still carry cached data.
/// * **[LoadingOperation]**: Operation in progress (optionally with cached
///   data). `IdleOperation` extends this class so a single pattern can cover
///   both cases when the extra distinction is not important.
/// * **[SuccessOperation]**: Operation finished successfully. Use
///   `SuccessOperation.empty()` for "successful but no data" scenarios, then
///   check the `empty` flag.
/// * **[ErrorOperation]**: Operation failed. Cached data from a previous
///   success is preserved when available for graceful degradation.
///
/// These variants unlock expressive and compile-time-checked UI code like:
/// ```dart
/// switch (state) {
///   IdleOperation() => const Text('Ready'),
///   LoadingOperation(data: null) => const CircularProgressIndicator(),
///   LoadingOperation(:var data?) => Stack(children:[DataView(data), const LinearProgressIndicator()]),
///   SuccessOperation(:var data) => DataView(data),
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
  bool get hasData => data != null;

  /// Whether this state has no associated data.
  bool get hasNoData => data == null;

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
  int get hashCode => data.hashCode;

  @override
  String toString() => 'LoadingOperation(data: $data)';
}

final class IdleOperation<T> extends LoadingOperation<T> {
  /// Creates an idle loading state with optional cached data.
  const IdleOperation({super.data});

  @override
  String toString() => 'IdleOperation(data: $data)';
}

/// Represents a successfully completed operation with associated data.
/// The data is guaranteed to be non-null in this state.
final class SuccessOperation<T> extends OperationState<T> {
  /// Creates a success state with the operation's result data.
  const SuccessOperation({required T super.data}) : empty = data == null;

  /// Creates an empty success state, indicating the operation completed
  /// successfully but returned no data.
  const SuccessOperation.empty() : empty = true;

  /// Whether the operation completed successfully but returned no data.
  final bool empty;

  /// The data associated with the successful operation.
  @override
  T get data {
    if (empty) {
      try {
        return _data as T;
      } catch (_) {
        throw StateError('No data available in an empty operation');
      }
    }
    return _data as T;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SuccessOperation<T> &&
        other.data == data &&
        other.empty == empty;
  }

  @override
  int get hashCode => data.hashCode ^ empty.hashCode;

  @override
  String toString() => 'SuccessOperation(data: $data, empty: $empty)';
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
    return other is ErrorOperation<T> &&
        other.message == message &&
        other.exception == exception &&
        other.stackTrace == stackTrace &&
        other.data == data;
  }

  @override
  int get hashCode => Object.hash(message, exception, stackTrace, data);

  @override
  String toString() =>
      'ErrorOperation(message: $message, exception: $exception, stackTrace: $stackTrace, data: $data)';
}

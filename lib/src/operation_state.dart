library;

part 'helpers.dart';

enum _CopySentinel { unset }

/// Represents the state of an asynchronous operation.
///
/// Four runtime variants exist and can be matched exhaustively with Dart 3's
/// sealed classes:
/// * [IdleOperation]: Ready but not-loading state. Engines and hosts start
///   idle by default. Widgets start idle when `loadOnInit` or `listenOnInit`
///   is false; setters and cancellation can also publish idle. It can
///   still carry cached data.
/// * [LoadingOperation]: Operation in progress (optionally with cached
///   data). `IdleOperation` extends this class so a single pattern can cover
///   both cases when the extra distinction is not important.
/// * [SuccessOperation]: Operation finished successfully. The [data]
///   getter returns exactly `T`: non-null when `T` is non-nullable, nullable
///   when `T` is nullable. For operations that succeed without a meaningful
///   value (delete, logout, fire-and-forget), parameterize with `void`. Use a
///   nullable type when a meaningful result may legitimately be absent.
/// * [ErrorOperation]: Operation failed. Cached data from a previous
///   success is preserved when available for graceful degradation.
///
/// These variants unlock expressive and compile-time-checked UI code like:
/// ```dart
/// switch (state) {
///   IdleOperation() => const Text('Ready'),
///   LoadingOperation(data: null) => const CircularProgressIndicator(),
///   LoadingOperation(:final data?) => Stack(children: [
///     DataView(data),
///     const LinearProgressIndicator(),
///   ]),
///   ErrorOperation(:final message, data: null) => ErrorBanner(message ?? 'Unable to load data'),
///   ErrorOperation(:final message, :final data?) => Stack(children: [
///     DataView(data),
///     ErrorBanner(message ?? 'Unable to load data'),
///   ]),
///   SuccessOperation(:final data) => DataView(data),
/// }
/// ```
sealed class OperationState<T> {
  /// Creates a state with an optional data parameter.
  const OperationState({this._data});

  /// The data associated with the operation, if any.
  final T? _data;

  /// The data associated with the operation, if any.
  T? get data => _data;

  /// The data associated with the operation, as a nullable `T?`.
  ///
  /// Equivalent to [data] for [LoadingOperation], [IdleOperation], and
  /// [ErrorOperation], all of which already expose nullable data. For
  /// [SuccessOperation], this is [SuccessOperation.data] widened to `T?`,
  /// which is convenient when handling all states uniformly without pattern
  /// matching.
  T? get dataOrNull => _data;

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

  /// Copies this state, preserving omitted fields.
  ///
  /// Passing `data: null` clears data, except for [SuccessOperation] when
  /// `T` is non-nullable, in which case the existing data is preserved.
  OperationState<T> Function({T? data}) get copyWith => _copyWith;

  OperationState<T> _copyWith({Object? data = _CopySentinel.unset});
}

/// Represents an operation that is currently in progress.
/// Can optionally carry cached data from a previous successful operation.
base class LoadingOperation<T> extends OperationState<T> {
  /// Creates a loading state with optional cached data.
  const LoadingOperation({super.data});

  /// Copies this loading state, preserving omitted fields.
  /// Passing `data: null` clears cached data.
  @override
  LoadingOperation<T> Function({T? data}) get copyWith => _copyWith;

  @override
  LoadingOperation<T> _copyWith({Object? data = _CopySentinel.unset}) =>
      LoadingOperation<T>(
        data: identical(data, _CopySentinel.unset) ? this.data : data as T?,
      );

  /// Compares fields by equality, without deep collection comparison.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other.runtimeType == runtimeType &&
        other is LoadingOperation<T> &&
        other.data == data;
  }

  /// Hash of the fields used by equality.
  @override
  int get hashCode => Object.hash(runtimeType, data);

  /// Diagnostic representation of this snapshot.
  @override
  String toString() => 'LoadingOperation(data: $data)';
}

/// Represents an idle operation that is ready but not currently loading.
/// Can optionally carry cached data from a previous successful operation.
final class IdleOperation<T> extends LoadingOperation<T> {
  /// Creates an idle loading state with optional cached data.
  const IdleOperation({super.data});

  /// Copies this idle state, preserving omitted fields.
  /// Passing `data: null` clears cached data.
  @override
  IdleOperation<T> Function({T? data}) get copyWith => _copyWith;

  @override
  IdleOperation<T> _copyWith({Object? data = _CopySentinel.unset}) =>
      IdleOperation<T>(
        data: identical(data, _CopySentinel.unset) ? this.data : data as T?,
      );

  /// Diagnostic representation of this snapshot.
  @override
  String toString() => 'IdleOperation(data: $data)';
}

/// Represents a successfully completed operation with associated data.
///
/// The [data] getter returns exactly `T`: non-null when `T` is non-nullable,
/// nullable when `T` is nullable. The constructor enforces this at the call
/// site: `SuccessOperation<User>(data: null)` is a compile error, while
/// `SuccessOperation<User?>(data: null)` is allowed.
///
/// ## "Successful but no data"
///
/// Pick the type parameter that matches what the operation actually models:
///
/// ```dart
/// // Fire-and-forget mutations (delete, logout, PIN confirm):
/// class DeleteCubit extends Cubit<OperationState<void>> { ... }
///
/// // Successful but the value may legitimately be absent:
/// class CurrentUserCubit extends Cubit<OperationState<User?>> { ... }
/// ```
final class SuccessOperation<T> extends OperationState<T> {
  /// Creates a success state with the operation's result data.
  ///
  /// `data` must satisfy `T`. For non-nullable `T`, passing `null` is a
  /// compile-time error. For nullable `T` (e.g. `SuccessOperation<User?>`),
  /// `null` is allowed.
  const SuccessOperation({required T super.data, this.message});

  /// An optional message associated with the successful operation.
  ///
  /// Useful when a server returns a confirmation message alongside the
  /// payload (e.g. `{ "data": ..., "message": "Saved" }`).
  final String? message;

  /// The data associated with the successful operation.
  /// Returns exactly `T`, mirroring the type parameter.
  @override
  T get data => _data as T;

  /// Copies this success state, preserving omitted fields.
  ///
  /// Passing `message: null` clears the message. Passing `data: null` is
  /// valid only when `T` accepts null; otherwise the old data is preserved.
  @override
  SuccessOperation<T> Function({T? data, String? message}) get copyWith =>
      _copyWith;

  @override
  SuccessOperation<T> _copyWith({
    Object? data = _CopySentinel.unset,
    Object? message = _CopySentinel.unset,
  }) => SuccessOperation<T>(
    data: !identical(data, _CopySentinel.unset) && data is T ? data : this.data,
    message: identical(message, _CopySentinel.unset)
        ? this.message
        : message as String?,
  );

  /// Compares fields by equality, without deep collection comparison.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SuccessOperation<T> &&
        other._data == _data &&
        other.message == message;
  }

  /// Hash of the fields used by equality.
  @override
  int get hashCode => Object.hash(_data, message);

  /// Diagnostic representation of this snapshot.
  @override
  String toString() => 'SuccessOperation(data: $_data, message: $message)';
}

/// Represents a failed operation with error details.
/// Can optionally retain cached data from a previous successful operation.
final class ErrorOperation<T> extends OperationState<T> {
  /// Creates an error state with the specified error details.
  const ErrorOperation({this.message, this.error, this.stackTrace, super.data});

  /// Human-readable error message for display to users.
  final String? message;

  /// The error object that caused the error.
  final Object? error;

  /// Stack trace from when the error occurred.
  final StackTrace? stackTrace;

  /// Copies this error state, preserving omitted fields.
  /// Passing `null` explicitly clears the corresponding field.
  @override
  ErrorOperation<T> Function({
    T? data,
    String? message,
    Object? error,
    StackTrace? stackTrace,
  })
  get copyWith => _copyWith;

  @override
  ErrorOperation<T> _copyWith({
    Object? data = _CopySentinel.unset,
    Object? message = _CopySentinel.unset,
    Object? error = _CopySentinel.unset,
    Object? stackTrace = _CopySentinel.unset,
  }) => ErrorOperation<T>(
    data: identical(data, _CopySentinel.unset) ? this.data : data as T?,
    message: identical(message, _CopySentinel.unset)
        ? this.message
        : message as String?,
    error: identical(error, _CopySentinel.unset) ? this.error : error,
    stackTrace: identical(stackTrace, _CopySentinel.unset)
        ? this.stackTrace
        : stackTrace as StackTrace?,
  );

  /// Compares fields by equality, without deep collection comparison.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ErrorOperation<T> &&
        other.message == message &&
        other.error == error &&
        other.stackTrace == stackTrace &&
        other.data == data;
  }

  /// Hash of the fields used by equality.
  @override
  int get hashCode => Object.hash(message, error, stackTrace, data);

  /// Diagnostic representation of this snapshot.
  @override
  String toString() =>
      'ErrorOperation(message: $message, error: $error, '
      'stackTrace: $stackTrace, data: $data)';
}

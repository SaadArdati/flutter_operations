part of 'operation_state.dart';

/// Exposes all destinations when the receiver is an [OperationState].
///
/// Concrete variants expose only other destinations. Use `copyWith` to update
/// a known variant. Selection follows the receiver's static, promoted type.
extension OperationTransitions<T> on OperationState<T> {
  /// Available destinations for this statically typed state.
  AllTransitions<T> get transitionTo => AllTransitions<T>._(this);
}

/// Transitions from loading to idle, success, or error.
extension LoadingTransitions<T> on LoadingOperation<T> {
  /// Available destinations for this statically typed state.
  FromLoading<T> get transitionTo => FromLoading<T>._(this);
}

/// Transitions from idle to loading, success, or error.
extension IdleTransitions<T> on IdleOperation<T> {
  /// Available destinations for this statically typed state.
  FromIdle<T> get transitionTo => FromIdle<T>._(this);
}

/// Transitions from success to loading, idle, or error.
extension SuccessTransitions<T> on SuccessOperation<T> {
  /// Available destinations for this statically typed state.
  FromSuccess<T> get transitionTo => FromSuccess<T>._(this);
}

/// Transitions from error to loading, idle, or success.
extension ErrorTransitions<T> on ErrorOperation<T> {
  /// Available destinations for this statically typed state.
  FromError<T> get transitionTo => FromError<T>._(this);
}

/// All destinations available through an [OperationState] reference.
final class AllTransitions<T> extends _TransitionSource<T>
    with _ToLoading<T>, _ToIdle<T>, _ToSuccess<T>, _ToError<T> {
  const AllTransitions._(super.state);
}

/// Destinations available through a [LoadingOperation] reference.
final class FromLoading<T> extends _TransitionSource<T>
    with _ToIdle<T>, _ToSuccess<T>, _ToError<T> {
  const FromLoading._(LoadingOperation<T> super.state);
}

/// Destinations available through an [IdleOperation] reference.
final class FromIdle<T> extends _TransitionSource<T>
    with _ToLoading<T>, _ToSuccess<T>, _ToError<T> {
  const FromIdle._(IdleOperation<T> super.state);
}

/// Destinations available through a [SuccessOperation] reference.
final class FromSuccess<T> extends _TransitionSource<T>
    with _ToLoading<T>, _ToIdle<T>, _ToError<T> {
  const FromSuccess._(SuccessOperation<T> super.state);
}

/// Destinations available through an [ErrorOperation] reference.
final class FromError<T> extends _TransitionSource<T>
    with _ToLoading<T>, _ToIdle<T>, _ToSuccess<T> {
  const FromError._(ErrorOperation<T> super.state);
}

abstract class _TransitionSource<T> {
  const _TransitionSource(this._state);

  final OperationState<T> _state;

  T? _resolveData(Object? data) =>
      identical(data, _CopySentinel.unset) ? _state.dataOrNull : data as T?;
}

mixin _ToLoading<T> on _TransitionSource<T> {
  /// Creates a loading state, preserving cached data when omitted.
  /// Passing `data: null` clears the cached data.
  LoadingOperation<T> Function({T? data}) get loading => _loading;

  LoadingOperation<T> _loading({Object? data = _CopySentinel.unset}) =>
      LoadingOperation<T>(data: _resolveData(data));
}

mixin _ToIdle<T> on _TransitionSource<T> {
  /// Creates an idle state, preserving cached data when omitted.
  /// Passing `data: null` clears the cached data.
  IdleOperation<T> Function({T? data}) get idle => _idle;

  IdleOperation<T> _idle({Object? data = _CopySentinel.unset}) =>
      IdleOperation<T>(data: _resolveData(data));
}

mixin _ToSuccess<T> on _TransitionSource<T> {
  /// Creates a success state with an explicit result satisfying `T`.
  /// The optional message belongs to the new state.
  SuccessOperation<T> success({required T data, String? message}) =>
      SuccessOperation<T>(data: data, message: message);
}

mixin _ToError<T> on _TransitionSource<T> {
  /// Creates an error state, preserving cached data when omitted.
  /// Passing `data: null` clears the cached data.
  /// Error details come from these arguments; omitted details default to null.
  ErrorOperation<T> Function({
    T? data,
    String? message,
    Object? error,
    StackTrace? stackTrace,
  })
  get error => _error;

  ErrorOperation<T> _error({
    Object? data = _CopySentinel.unset,
    String? message,
    Object? error,
    StackTrace? stackTrace,
  }) => ErrorOperation<T>(
    data: _resolveData(data),
    message: message,
    error: error,
    stackTrace: stackTrace,
  );
}

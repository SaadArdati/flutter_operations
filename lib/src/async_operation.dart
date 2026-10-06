import 'dart:async';

import 'package:flutter/foundation.dart';

import 'message_zone.dart';
import 'operation.dart';
import 'operation_state.dart';

export 'operation.dart'
    show OperationChanged, OperationErrorCallback, OperationErrorMessage;

/// Work executed by an [AsyncOperation].
typedef AsyncOperationWork<T> = FutureOr<T> Function();

/// Defines how [AsyncOperation] handles a call made while one is running.
enum AsyncOperationConcurrency {
  /// Starts the new call and prevents older calls from publishing state.
  latest,

  /// Ignores the new call while the current call is running.
  first,
}

/// Owns the state and lifecycle of one asynchronous operation.
///
/// This class does not provide a reactive primitive. State managers can observe
/// [state] using the `onRead` and `onChanged` constructor callbacks,
/// or overriding [onRead] and [onChanged].
class AsyncOperation<T> extends Operation<T> {
  /// Creates an operation, initially idle unless [initialState] is supplied.
  ///
  /// Change hooks run synchronously after assignment, before lifecycle hooks.
  /// Equal snapshots suppress both notifications. Overrides should call
  /// `super` to retain configured callbacks. Callback exceptions are not
  /// isolated from operation execution.
  AsyncOperation({
    super.initialState,
    this.concurrency = .latest,
    super.onRead,
    super.onChanged,
    super.onLoading,
    this._onSuccess,
    super.onError,
    super.onIdle,
    super.errorMessage,
  });

  /// Determines how overlapping calls are handled.
  final AsyncOperationConcurrency concurrency;

  final ValueChanged<T>? _onSuccess;

  bool _running = false;

  /// Whether the current generation is running.
  /// Older invalidated work may still run. This getter does not track reads.
  bool get isRunning => _running;

  /// Runs [work] and owns its loading, success, and error transitions.
  ///
  /// Retains cache unless [cached] is false. Work errors become error
  /// snapshots rather than being rethrown. The Future does not return the
  /// result. Disposed owners and overlapping calls under
  /// [AsyncOperationConcurrency.first] are ignored.
  Future<void> run(AsyncOperationWork<T> work, {bool cached = true}) async {
    if (isDisposed || (_running && concurrency == .first)) {
      return;
    }

    final currentGeneration = nextGeneration();
    _running = true;
    try {
      setLoading(cached: cached);
      if (!isCurrentGeneration(currentGeneration)) return;

      final message = MessageCell(owner: this);
      try {
        final result = await runZoned(work, zoneValues: {messageKey: message});
        if (!isCurrentGeneration(currentGeneration)) return;
        _running = false;
        setSuccess(result, message: message.value);
      } catch (error, stackTrace) {
        if (!isCurrentGeneration(currentGeneration)) return;
        _running = false;
        final message = errorMessage(error, stackTrace);
        if (!isCurrentGeneration(currentGeneration)) return;
        setError(error, stackTrace, message: message, cached: cached);
      }
    } finally {
      if (identical(currentGeneration, generation)) _running = false;
    }
  }

  /// Updates [state] to success.
  void setSuccess(T data, {String? message}) => emitState(
    SuccessOperation<T>(data: data, message: message),
    () => onSuccess(data),
  );

  /// Cancels future state changes from current work and becomes idle.
  /// Does not abort underlying work or I/O. Retains cache unless [cached]
  /// is false. Manual setters do not invalidate pending results.
  void cancel({bool cached = true}) {
    if (isDisposed) return;
    nextGeneration();
    _running = false;
    setIdle(cached: cached);
  }

  /// Prevents all future work and state changes.
  void dispose() {
    if (disposeState()) _running = false;
  }

  /// Called when an unequal success snapshot is published.
  void onSuccess(T data) => _onSuccess?.call(data);
}

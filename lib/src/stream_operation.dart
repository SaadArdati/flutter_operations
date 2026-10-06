import 'dart:async';

import 'package:flutter/foundation.dart';

import 'message_zone.dart';
import 'operation.dart';
import 'operation_state.dart';

/// Creates a fresh source for each [StreamOperation.listen] call.
typedef StreamOperationSource<T> = Stream<T> Function();

/// Owns one stream subscription and its operation state.
///
/// Restarts invalidate old events immediately and await subscription cleanup
/// before creating the replacement. Cancellation failures propagate to the
/// caller and prevent further subscriptions on this operation.
class StreamOperation<T> extends Operation<T> {
  /// Creates a stream owner, initially idle unless [initialState] is supplied.
  StreamOperation({
    super.initialState,
    super.onRead,
    super.onChanged,
    super.onLoading,
    this._onData,
    super.onError,
    super.onIdle,
    this._onDone,
    super.errorMessage,
  });

  final ValueChanged<T>? _onData;
  final VoidCallback? _onDone;

  StreamSubscription<T>? _subscription;
  Future<void> _cleanup = Future.value();

  /// Establishes a subscription, not a wait for the stream to finish.
  ///
  /// Only the latest call can establish a replacement. Source creation and
  /// subscription errors become error state; cleanup failures throw.
  Future<void> listen(
    StreamOperationSource<T> source, {
    bool cached = true,
  }) async {
    if (isDisposed) return;
    final currentGeneration = nextGeneration();
    final cleanup = _cancelSubscription();
    setLoading(cached: cached);
    await cleanup;
    if (!isCurrentGeneration(currentGeneration)) return;

    // Reentrant lifecycle commands must wait for establishment and, if the
    // generation changes, cancellation of the subscription being created.
    final establishment = Completer<void>();
    _cleanup = establishment.future;
    final cell = MessageCell(owner: this);
    late final StreamSubscription<T> subscription;
    try {
      subscription = runZoned(
        () => source().listen(
          (value) {
            if (!isCurrentGeneration(currentGeneration)) return;
            final message = cell.value;
            cell.value = null;
            setData(value, message: message);
          },
          onError: (Object error, StackTrace trace) {
            if (!isCurrentGeneration(currentGeneration)) return;
            cell.value = null;
            setError(error, trace, cached: cached);
          },
          onDone: () {
            if (!isCurrentGeneration(currentGeneration)) return;
            cell.value = null;
            _subscription = null;
            onDone();
          },
        ),
        zoneValues: {messageKey: cell},
      );
    } catch (error, trace) {
      establishment.complete();
      if (isCurrentGeneration(currentGeneration)) {
        setError(error, trace, cached: cached);
      }
      return;
    }
    // Defend against a source factory that itself cancels/disposes the owner.
    if (!isCurrentGeneration(currentGeneration)) {
      establishment.complete(Future<void>.sync(subscription.cancel));
      await establishment.future;
      return;
    }
    _subscription = subscription;
    establishment.complete();
  }

  Future<void> _cancelSubscription() {
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) {
      _cleanup = _cleanup.then((_) => subscription.cancel());
    }
    return _cleanup;
  }

  /// Invalidates events immediately, becomes idle, and awaits cleanup.
  Future<void> cancel({bool cached = true}) {
    if (isDisposed) return _cleanup;
    nextGeneration();
    final cleanup = _cancelSubscription();
    setIdle(cached: cached);
    return cleanup;
  }

  /// Prevents publication immediately; completes when cleanup finishes.
  Future<void> dispose() {
    if (disposeState()) _cancelSubscription();
    return _cleanup;
  }

  /// Publishes success and an optional message without stopping the source.
  void setData(T data, {String? message}) => emitState(
    SuccessOperation<T>(data: data, message: message),
    () => onData(data),
  );

  /// Called after an unequal success snapshot; equal events suppress this hook.
  void onData(T data) => _onData?.call(data);

  /// Called on natural completion of the current source, retaining its snapshot.
  /// Cancellation and disposal do not invoke this hook.
  void onDone() => _onDone?.call();
}

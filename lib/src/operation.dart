import 'dart:async';

import 'package:flutter/foundation.dart';

import 'message_zone.dart';
import 'operation_state.dart';

/// Called immediately after an unequal operation state is assigned.
typedef OperationChanged<T> =
    void Function(OperationState<T> previous, OperationState<T> next);

/// Called when an operation publishes an error.
typedef OperationErrorCallback =
    void Function(Object error, StackTrace stackTrace, {String? message});

/// Converts an error into the message stored in an error snapshot.
typedef OperationErrorMessage =
    String Function(Object error, StackTrace stackTrace);

/// Shared state publication for asynchronous and stream execution engines.
///
/// Owns snapshots, reactive hooks, cached transitions, and message attachment.
/// Also owns generation invalidation and disposed-state bookkeeping.
/// Execution, cancellation commands, and resource cleanup remain in subclasses.
abstract class Operation<T> {
  /// Creates an initially idle state owner unless [initialState] is supplied.
  ///
  /// Callbacks run synchronously and are not isolated exception handlers.
  Operation({
    OperationState<T>? initialState,
    this._onRead,
    this._onChanged,
    this._onLoading,
    this._onError,
    this._onIdle,
    this._errorMessage,
  }) : _state = initialState ?? IdleOperation<T>();

  final VoidCallback? _onRead;
  final OperationChanged<T>? _onChanged;
  final VoidCallback? _onLoading;
  final OperationErrorCallback? _onError;
  final VoidCallback? _onIdle;
  final OperationErrorMessage? _errorMessage;

  OperationState<T> _state;
  Object _generation = Object();
  bool _disposed = false;

  /// Current snapshot; every read invokes [onRead].
  OperationState<T> get state {
    onRead();
    return _state;
  }

  /// Whether new work and state publication have been disabled.
  ///
  /// This property is not a tracked state read or a cleanup-completion signal.
  bool get isDisposed => _disposed;

  /// Current execution generation, without a tracked state read.
  @protected
  Object get generation => _generation;

  /// Invalidates previous execution with a fresh identity token.
  /// Non-const objects avoid numeric overflow and token identity reuse.
  @protected
  Object nextGeneration() => _generation = Object();

  /// Whether execution still belongs to the current, undisposed lifetime.
  @protected
  bool isCurrentGeneration(Object generation) =>
      !_disposed && identical(generation, _generation);

  /// Disables publication and invalidates execution once.
  ///
  /// Returns true on first disposal. Subclasses perform their own synchronous
  /// or asynchronous resource cleanup without changing that public contract.
  @protected
  bool disposeState() {
    if (_disposed) return false;
    _disposed = true;
    nextGeneration();
    return true;
  }

  /// Publishes idle without invalidating work or canceling subscriptions.
  void setIdle({bool cached = true}) => emitState(
    IdleOperation<T>(data: cached ? _state.dataOrNull : null),
    onIdle,
  );

  /// Publishes loading without starting or canceling work.
  void setLoading({bool cached = true}) => emitState(
    LoadingOperation<T>(data: cached ? _state.dataOrNull : null),
    onLoading,
  );

  /// Publishes an error, retaining cache unless [cached] is false.
  ///
  /// An absent [message] is formatted for the snapshot. [onError] receives
  /// the originally supplied nullable message, preserving setter semantics.
  void setError(
    Object error,
    StackTrace stackTrace, {
    String? message,
    bool cached = true,
  }) {
    final currentGeneration = generation;
    final next = ErrorOperation<T>(
      data: cached ? _state.dataOrNull : null,
      error: error,
      stackTrace: stackTrace,
      message: message ?? errorMessage(error, stackTrace),
    );
    // Formatting can synchronously cancel, restart, or dispose the owner.
    if (!isCurrentGeneration(currentGeneration)) return;
    emitState(next, () => onError(error, stackTrace, message: message));
  }

  /// Attaches text inside this owner's active execution zone.
  ///
  /// Async engines consume it on success; stream engines consume it per data
  /// event. Calls outside this owner's zone do nothing.
  void attachMessage(String message) {
    final cell = Zone.current[messageKey];
    if (cell case MessageCell cell? when identical(cell.owner, this)) {
      cell.value = message;
    }
  }

  /// Formats snapshot text, defaulting to diagnostic `error.toString()`.
  String errorMessage(Object error, StackTrace stackTrace) =>
      _errorMessage?.call(error, stackTrace) ?? error.toString();

  /// Tracks each [state] read without mutating state.
  /// Call `super` in overrides to retain the configured callback.
  void onRead() => _onRead?.call();

  /// Runs after assignment and before the corresponding lifecycle callback.
  /// Equal states and disposed owners suppress both callbacks.
  /// Call `super` in overrides to retain the configured callback.
  void onChanged(OperationState<T> previous, OperationState<T> next) =>
      _onChanged?.call(previous, next);

  /// Called after an unequal loading snapshot is published, excluding idle.
  void onLoading() => _onLoading?.call();

  /// Called after an unequal error snapshot is published.
  /// [message] can be null even when the snapshot contains formatted text.
  void onError(Object error, StackTrace stackTrace, {String? message}) =>
      _onError?.call(error, stackTrace, message: message);

  /// Called after an unequal idle snapshot is published.
  void onIdle() => _onIdle?.call();

  /// Publishes a subclass transition through the common notification boundary.
  ///
  /// Ignores equal states and disposed owners, assigns [next], invokes
  /// [onChanged], and then invokes [callback].
  @protected
  void emitState(OperationState<T> next, VoidCallback callback) {
    if (isDisposed || next == _state) return;
    final previous = _state;
    _state = next;
    onChanged(previous, next);
    callback();
  }
}

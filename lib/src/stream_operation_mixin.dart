import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';

import 'operation_state.dart';
import 'stream_operation.dart';

/// Adds one stream operation to an external host.
///
/// Hosts publish [operationChanged] and await [disposeOperation] at their
/// lifecycle boundary. Supplied controllers own their configuration/callbacks.
/// The [stream] method cannot coexist with a host's `stream` getter, such as
/// Cubit/BlocBase. Compose [StreamOperation] or delegate to a separate host.
mixin StreamOperationMixin<T> {
  late final StreamOperation<T> _operation = StreamOperation<T>(
    initialState: initialOperationState,
    onRead: operationRead,
    onChanged: operationChanged,
    errorMessage: errorMessage,
    onLoading: onLoading,
    onData: onData,
    onError: onError,
    onIdle: onIdle,
    onDone: onDone,
  );

  /// Return a stable controller within a host lifetime. Disposal owns it.
  StreamOperation<T> get operationController => _operation;

  /// Initial snapshot used by the lazily created default controller.
  OperationState<T> get initialOperationState => IdleOperation<T>();

  /// Current snapshot of the owned controller.
  OperationState<T> get operation => operationController.state;

  /// Creates a fresh source for each subscription attempt.
  Stream<T> stream();

  /// Restarts listening after cleanup; cancellation failures propagate.
  Future<void> listen({bool cached = true}) =>
      operationController.listen(stream, cached: cached);

  /// Invalidates events, becomes idle, and awaits cleanup.
  Future<void> cancel({bool cached = true}) =>
      operationController.cancel(cached: cached);

  /// Disables publication immediately and awaits owned subscription cleanup.
  Future<void> disposeOperation() => operationController.dispose();

  /// Attaches a message inside the active source zone, before `yield`.
  /// Calls outside this controller's source flow are ignored.
  @protected
  void attachMessage(String message) =>
      operationController.attachMessage(message);

  /// Publishes idle without canceling; optionally clears cached data.
  void setIdle({bool cached = true}) =>
      operationController.setIdle(cached: cached);

  /// Publishes loading without canceling; optionally clears cached data.
  void setLoading({bool cached = true}) =>
      operationController.setLoading(cached: cached);

  /// Publishes success and an optional message without stopping the source.
  void setData(T data, {String? message}) =>
      operationController.setData(data, message: message);

  /// Publishes an error without stopping the source; optionally clears cache.
  void setError(
    Object error,
    StackTrace trace, {
    String? message,
    bool cached = true,
  }) => operationController.setError(
    error,
    trace,
    message: message,
    cached: cached,
  );

  /// Tracks default-controller reads; does nothing by default.
  void operationRead() {}

  /// Publishes default-controller changes through the host notification mechanism.
  /// Called after assignment, before lifecycle hooks, only for unequal snapshots.
  void operationChanged(OperationState<T> previous, OperationState<T> next) {}

  /// Formats display text; defaults to diagnostic `error.toString()`.
  String errorMessage(Object error, StackTrace trace) => error.toString();

  /// Called after an unequal loading snapshot is published.
  void onLoading() {}

  /// Called after an unequal success snapshot is published.
  void onData(T data) {}

  /// Called after an unequal error snapshot; logs diagnostics by default.
  /// [message] may be null; the snapshot contains the resolved display text.
  void onError(Object error, StackTrace trace, {String? message}) {
    developer.log(
      message ?? errorMessage(error, trace),
      name: 'StreamOperationMixin',
      error: error,
      stackTrace: trace,
    );
  }

  /// Called after an unequal idle snapshot is published.
  void onIdle() {}

  /// Called on natural completion, retaining the last snapshot.
  void onDone() {}
}

/// Widget lifecycle adapter for [StreamOperation].
///
/// Owns startup, notification, rebuilding, and subscription disposal.
mixin StreamOperationStateMixin<T, K extends StatefulWidget> on State<K> {
  /// Notifies listeners of unequal snapshots; disposed with the widget.
  late final ValueNotifier<OperationState<T>> operationNotifier;
  late final StreamOperation<T> _operation;

  /// Current snapshot of the owned controller.
  OperationState<T> get operation => _operation.state;

  /// Whether to schedule listening after initialization; defaults to true.
  bool get listenOnInit => true;

  /// Whether transitions rebuild the whole widget; defaults to false.
  /// Otherwise observe [operationNotifier] with a `ValueListenableBuilder`.
  bool get globalRefresh => false;

  /// Initializes notification and optionally schedules listening.
  @override
  void initState() {
    super.initState();
    final initialState = listenOnInit
        ? LoadingOperation<T>()
        : IdleOperation<T>();
    operationNotifier = ValueNotifier<OperationState<T>>(initialState);
    _operation = StreamOperation<T>(
      initialState: initialState,
      onChanged: (_, next) {
        operationNotifier.value = next;
        if (mounted && globalRefresh) setState(() {});
      },
      errorMessage: errorMessage,
      onLoading: onLoading,
      onData: onData,
      onError: onError,
      onIdle: onIdle,
      onDone: onDone,
    );
    if (listenOnInit) Future.microtask(listen);
  }

  // Flutter disposal cannot await. Forward cleanup failures to the owning zone
  // rather than silently dropping asynchronous subscription errors.
  void _disposeSubscription() {
    final zone = Zone.current;
    _operation.dispose().then<void>(
      (_) {},
      onError: (Object error, StackTrace trace) =>
          zone.handleUncaughtError(error, trace),
    );
  }

  /// Invalidates events and disposes notification, then starts source cleanup.
  /// Asynchronous cleanup errors are forwarded to the owning zone.
  @override
  void dispose() {
    _disposeSubscription();
    operationNotifier.dispose();
    super.dispose();
  }

  /// Creates a fresh source for each subscription attempt.
  Stream<T> stream();

  /// Completes when the replacement subscription is established.
  Future<void> listen({bool cached = true}) =>
      _operation.listen(stream, cached: cached);

  /// Invalidates events immediately and awaits subscription cleanup.
  Future<void> cancel({bool cached = true}) =>
      _operation.cancel(cached: cached);

  /// Attaches a message inside the active source zone, before `yield`.
  /// Calls outside this controller's source flow are ignored.
  @protected
  void attachMessage(String message) => _operation.attachMessage(message);

  /// Publishes idle without canceling; optionally clears cached data.
  void setIdle({bool cached = true}) => _operation.setIdle(cached: cached);

  /// Publishes loading, or idle when [idle] is true, without canceling.
  /// Retains cached data unless [cached] is false.
  void setLoading({bool idle = false, bool cached = true}) {
    if (idle) {
      _operation.setIdle(cached: cached);
    } else {
      _operation.setLoading(cached: cached);
    }
  }

  /// Publishes success and an optional message without stopping the source.
  void setData(T data, {String? message}) =>
      _operation.setData(data, message: message);

  /// Publishes an error without stopping the source; optionally clears cache.
  void setError(
    Object error,
    StackTrace stackTrace, {
    String? message,
    bool cached = true,
  }) =>
      _operation.setError(error, stackTrace, message: message, cached: cached);

  /// Formats display text; defaults to diagnostic `error.toString()`.
  String errorMessage(Object error, StackTrace stackTrace) => error.toString();

  /// Called after an unequal error snapshot; logs diagnostics by default.
  /// [message] may be null; the snapshot contains the resolved display text.
  void onError(Object error, StackTrace stackTrace, {String? message}) {
    developer.log(
      message ?? errorMessage(error, stackTrace),
      name: 'StreamOperationStateMixin',
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Called after an unequal loading snapshot is published.
  void onLoading() {}

  /// Called after an unequal success snapshot is published.
  void onData(T value) {}

  /// Called after an unequal idle snapshot is published.
  void onIdle() {}

  /// Called on natural completion, retaining the last snapshot.
  void onDone() {}
}

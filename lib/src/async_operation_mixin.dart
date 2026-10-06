import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';

import 'async_operation.dart';
import 'operation_state.dart';

/// Adds one asynchronous operation to any host object.
///
/// Hosts own their lifecycle and must call [disposeOperation] when finished.
mixin AsyncOperationMixin<T> {
  late final AsyncOperation<T> _operation = AsyncOperation<T>(
    initialState: initialOperationState,
    onRead: operationRead,
    onChanged: operationChanged,
    errorMessage: errorMessage,
    onLoading: onLoading,
    onSuccess: onSuccess,
    onError: onError,
    onIdle: onIdle,
  );

  /// The owned operation used by every state read and command.
  ///
  /// Overrides must return one stable instance. [disposeOperation] disposes it.
  /// A supplied operation owns its configuration and callbacks; the default
  /// host hooks are wired only by the default implementation.
  AsyncOperation<T> get operationController => _operation;

  /// Called whenever the default operation state is read.
  void operationRead() {}

  /// The initial operation state.
  OperationState<T> get initialOperationState => IdleOperation<T>();

  /// The current operation state.
  OperationState<T> get operation => operationController.state;

  /// Fetches the data for this operation.
  FutureOr<T> fetch();

  /// Runs [fetch] with race protection and state transitions.
  Future<void> load({bool cached = true}) =>
      operationController.run(fetch, cached: cached);

  /// Convenience method to reload data.
  Future<void> reload({bool cached = true}) => load(cached: cached);

  /// Updates the state to idle.
  void setIdle({bool cached = true}) =>
      operationController.setIdle(cached: cached);

  /// Updates the state to loading.
  void setLoading({bool cached = true}) =>
      operationController.setLoading(cached: cached);

  /// Updates the state to success.
  void setSuccess(T data, {String? message}) =>
      operationController.setSuccess(data, message: message);

  /// Updates the state to error.
  void setError(
    Object error,
    StackTrace stackTrace, {
    String? message,
    bool cached = true,
  }) => operationController.setError(
    error,
    stackTrace,
    message: message,
    cached: cached,
  );

  /// Attaches a message to the success produced by the current [fetch].
  @protected
  void attachMessage(String message) =>
      operationController.attachMessage(message);

  /// Prevents future state changes from current work and becomes idle.
  void cancel({bool cached = true}) =>
      operationController.cancel(cached: cached);

  /// Disposes the owned operation.
  void disposeOperation() => operationController.dispose();

  /// Called immediately after the operation state changes.
  void operationChanged(OperationState<T> previous, OperationState<T> next) {}

  /// Converts an error into a human-readable message.
  String errorMessage(Object error, StackTrace stackTrace) => error.toString();

  /// Called when an error occurs.
  void onError(Object error, StackTrace stackTrace, {String? message}) {
    developer.log(
      message ?? errorMessage(error, stackTrace),
      error: error,
      stackTrace: stackTrace,
      name: 'AsyncOperationMixin',
    );
  }

  /// Called when data is successfully loaded.
  void onSuccess(T data) {}

  /// Called when the state transitions to loading.
  void onLoading() {}

  /// Called when the state transitions to idle.
  void onIdle() {}
}

/// Adds one asynchronous operation to a Flutter [State].
///
/// This adapter owns Flutter initialization, notification, rebuilding, and
/// disposal. Use [AsyncOperationMixin] for non-widget hosts.
mixin AsyncOperationStateMixin<T, K extends StatefulWidget> on State<K> {
  /// Notifier that broadcasts the current operation state.
  late final ValueNotifier<OperationState<T>> operationNotifier;

  late final AsyncOperation<T> _operation;

  /// The current operation state.
  OperationState<T> get operation => _operation.state;

  /// Whether to automatically load data when initialized.
  bool get loadOnInit => true;

  /// Whether the entire widget rebuilds on state changes.
  bool get globalRefresh => false;

  /// Initializes notification and optionally schedules loading.
  @override
  void initState() {
    super.initState();
    final initialState = loadOnInit
        ? LoadingOperation<T>()
        : IdleOperation<T>();
    operationNotifier = ValueNotifier<OperationState<T>>(initialState);
    _operation = AsyncOperation<T>(
      initialState: initialState,
      onChanged: (_, next) {
        operationNotifier.value = next;
        if (mounted && globalRefresh) setState(() {});
      },
      errorMessage: errorMessage,
      onLoading: onLoading,
      onSuccess: onSuccess,
      onError: onError,
      onIdle: onIdle,
    );

    if (loadOnInit) Future.microtask(load);
  }

  /// Rejects late completions and disposes the widget-owned notifier.
  @override
  void dispose() {
    _operation.dispose();
    operationNotifier.dispose();
    super.dispose();
  }

  /// Fetches the data for this widget.
  FutureOr<T> fetch();

  /// Runs [fetch] with race protection and state transitions.
  Future<void> load({bool cached = true}) =>
      _operation.run(fetch, cached: cached);

  /// Convenience method to reload data.
  Future<void> reload({bool cached = true}) => load(cached: cached);

  /// Updates the state to idle.
  void setIdle({bool cached = true}) => _operation.setIdle(cached: cached);

  /// Updates the state to loading.
  void setLoading({bool cached = true}) =>
      _operation.setLoading(cached: cached);

  /// Updates the state to success.
  void setSuccess(T data, {String? message}) =>
      _operation.setSuccess(data, message: message);

  /// Attaches a message to the success produced by the current [fetch].
  @protected
  void attachMessage(String message) => _operation.attachMessage(message);

  /// Updates the state to error.
  void setError(
    Object error,
    StackTrace stackTrace, {
    String? message,
    bool cached = true,
  }) =>
      _operation.setError(error, stackTrace, message: message, cached: cached);

  /// Converts an error into a human-readable message.
  String errorMessage(Object error, StackTrace stackTrace) => error.toString();

  /// Called when an error occurs.
  void onError(Object error, StackTrace stackTrace, {String? message}) {
    developer.log(
      message ?? errorMessage(error, stackTrace),
      error: error,
      stackTrace: stackTrace,
      name: 'AsyncOperationStateMixin',
    );
  }

  /// Called when data is successfully loaded.
  void onSuccess(T data) {}

  /// Called when the state transitions to loading.
  void onLoading() {}

  /// Called when the state transitions to idle.
  void onIdle() {}
}

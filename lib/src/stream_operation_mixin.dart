import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';

import 'message_zone.dart';
import 'operation_state.dart';

/// A mixin that adds stream-based state management to a [StatefulWidget].
///
/// Handles continuous data streams with automatic subscription management,
/// state transitions, and proper cleanup. Unlike [AsyncOperationMixin] which
/// deals with one-off operations, this mixin is built for sources that emit
/// multiple values over time (e.g. WebSockets, database listeners).
///
/// Example:
/// ```dart
/// class _ChatState extends State<ChatPage>
///     with StreamOperationMixin<List<Message>, ChatPage> {
///   @override
///   Stream<List<Message>> stream() => chatService.messagesStream();
/// }
/// ```
mixin StreamOperationMixin<T, K extends StatefulWidget> on State<K> {
  /// Notifier that broadcasts the current operation state.
  late final ValueNotifier<OperationState<T>> operationNotifier;

  /// Generation counter to prevent race conditions in stream operations.
  int _generation = 0;

  /// The current operation state.
  OperationState<T> get operation => operationNotifier.value;

  /// Whether to automatically start listening when initialized.
  /// Defaults to `true`.
  bool get listenOnInit => true;

  /// Whether the entire widget rebuilds on state changes.
  /// Defaults to `false`.
  bool get globalRefresh => false;

  /// The active stream subscription.
  StreamSubscription? _streamSubscription;

  @override
  void initState() {
    super.initState();
    operationNotifier = ValueNotifier<OperationState<T>>(
      listenOnInit ? LoadingOperation<T>() : IdleOperation<T>(),
    );

    if (listenOnInit) {
      Future.microtask(listen);
    }
  }

  @override
  void dispose() {
    operationNotifier.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }

  /// Creates and returns the stream to listen to.
  ///
  /// Override this method to provide the data stream for this operation.
  Stream<T> stream();

  /// Starts listening to the stream and manages subscription lifecycle.
  ///
  /// Initiates cancellation of the current subscription, then creates its
  /// replacement. Late events from an older subscription are ignored.
  ///
  /// Wraps the [stream] subscription in a [Zone] holding a per-call
  /// [MessageCell]. Any [attachMessage] calls made inside [stream]
  /// (typically inside an `async*` body before each `yield`) write to that
  /// cell; the message is then paired with the value on the resulting
  /// [SuccessOperation].
  void listen({bool cached = true}) {
    final currentGeneration = ++_generation;
    setLoading(cached: cached);
    _streamSubscription?.cancel();

    final cell = MessageCell();
    try {
      runZoned(() {
        _streamSubscription = stream().listen(
          (value) {
            if (!mounted || _generation != currentGeneration) return;
            final msg = cell.value;
            cell.value = null;
            setData(value, message: msg);
          },
          onError: (error, stackTrace) {
            if (!mounted || _generation != currentGeneration) return;
            setError(
              error,
              stackTrace,
              message: errorMessage(error, stackTrace),
              cached: cached,
            );
          },
          onDone: onDone,
        );
      }, zoneValues: {messageKey: cell});
    } catch (error, stackTrace) {
      if (!mounted || _generation != currentGeneration) return;
      setError(
        error,
        stackTrace,
        message: errorMessage(error, stackTrace),
        cached: cached,
      );
    }
  }

  /// Attaches an optional message to the next [setData] emission produced
  /// by the current [stream] subscription. Safe to call inside `async*`
  /// bodies before each `yield`. Outside a [listen] call this is a no-op.
  @protected
  void attachMessage(String message) {
    final cell = Zone.current[messageKey];
    if (cell case MessageCell cell?) cell.value = message;
  }

  /// Updates the state to idle.
  ///
  /// Preserves current data when [cached] is `true`, invokes [onIdle], and
  /// rebuilds the widget when [globalRefresh] is enabled.
  void setIdle({bool cached = true}) {
    final lastData = cached ? operationNotifier.value.data : null;
    final newOp = IdleOperation<T>(data: lastData);
    if (newOp == operationNotifier.value) {
      return;
    }

    operationNotifier.value = newOp;
    onIdle();

    if (mounted && globalRefresh) setState(() {});
  }

  /// Updates the state to loading, or idle if [idle] is `true`.
  void setLoading({bool idle = false, bool cached = true}) {
    final lastData = cached ? operationNotifier.value.data : null;
    final newOp = idle
        ? IdleOperation<T>(data: lastData)
        : LoadingOperation<T>(data: lastData);
    if (newOp == operationNotifier.value) {
      return;
    }

    operationNotifier.value = newOp;
    idle ? onIdle() : onLoading();

    if (mounted && globalRefresh) setState(() {});
  }

  /// Updates the state to success with the provided data.
  void setData(T data, {String? message}) {
    if (operationNotifier.value case SuccessOperation(
      data: final oldData,
      message: final oldMessage,
    ) when oldData == data && oldMessage == message) {
      return;
    }

    operationNotifier.value = SuccessOperation<T>(data: data, message: message);
    onData(data);

    if (mounted && globalRefresh) setState(() {});
  }

  /// Updates the state to error with the provided error details.
  void setError(
    Object error,
    StackTrace stackTrace, {
    String? message,
    bool cached = true,
  }) {
    final lastData = cached ? operationNotifier.value.data : null;
    final errorOp = ErrorOperation<T>(
      message: message ?? errorMessage(error, stackTrace),
      error: error,
      stackTrace: stackTrace,
      data: lastData,
    );

    if (errorOp == operationNotifier.value) {
      return;
    }

    operationNotifier.value = errorOp;
    onError(error, stackTrace, message: message);

    if (mounted && globalRefresh) setState(() {});
  }

  /// Converts an error and stack trace into a human-readable error message.
  /// Override to provide custom error message formatting.
  String errorMessage(Object error, StackTrace stackTrace) => error.toString();

  /// Called when an error occurs. Override for custom error handling.
  void onError(Object error, StackTrace stackTrace, {String? message}) {
    developer.log(
      message ?? errorMessage(error, stackTrace),
      name: 'StreamOperationMixin',
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Called when the state transitions to loading.
  void onLoading() {}

  /// Called when the stream emits a new value.
  void onData(T value) {}

  /// Called when the state transitions to idle.
  void onIdle() {}

  /// Called when the stream completes.
  void onDone() {}
}

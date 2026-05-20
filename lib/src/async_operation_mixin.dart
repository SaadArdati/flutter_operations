import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';

import 'message_zone.dart';
import 'operation_state.dart';

/// A mixin that adds asynchronous state management to a [StatefulWidget].
///
/// Handles one-time asynchronous operations with idle, loading,
/// success, and error states.
/// Unlike [StreamOperationMixin], which is intended for infinite data streams, this
/// mixin is perfect for discrete fetch operations that have a clear start and
/// end (e.g. HTTP requests, database reads, dialogs).
///
///
/// Example:
/// ```dart
/// class _PostsState extends State<PostsPage>
///     with AsyncOperationMixin<List<Post>, PostsPage> {
///   @override
///   Future<List<Post>> fetch() async {
///     return await api.getPosts();
///   }
/// }
/// ```
mixin AsyncOperationMixin<T, K extends StatefulWidget> on State<K> {
  /// Notifier that broadcasts the current operation state.
  late final ValueNotifier<OperationState<T>> operationNotifier;

  /// Generation counter to prevent race conditions in concurrent operations.
  int _generation = 0;

  /// The current operation state.
  OperationState<T> get operation => operationNotifier.value;

  /// Whether to automatically load data when initialized.
  /// Defaults to `true`.
  bool get loadOnInit => true;

  /// Whether the entire widget rebuilds on state changes.
  /// Defaults to `false`.
  bool get globalRefresh => false;

  @override
  void initState() {
    super.initState();
    operationNotifier = ValueNotifier<OperationState<T>>(
      loadOnInit ? LoadingOperation<T>() : IdleOperation<T>(),
    );

    if (loadOnInit) {
      Future.microtask(load);
    }
  }

  @override
  void dispose() {
    operationNotifier.dispose();
    super.dispose();
  }

  /// Fetches the data for this widget.
  ///
  /// Override this method to provide the data for this operation.
  FutureOr<T> fetch();

  /// Handles the complete loading lifecycle with race condition protection.
  ///
  /// Wraps the [fetch] call in a [Zone] holding a per-call [MessageCell].
  /// Any [attachMessage] calls made inside [fetch] (sync or after awaits)
  /// write to that cell; the message is then paired with the result on
  /// the resulting [SuccessOperation].
  FutureOr<void> load({bool cached = true}) async {
    final currentGeneration = ++_generation;
    setLoading(cached: cached);

    final cell = MessageCell();
    try {
      final result = await runZoned(
        () => fetch(),
        zoneValues: {messageKey: cell},
      );
      if (!mounted || _generation != currentGeneration) return;
      setSuccess(result, message: cell.value);
    } catch (exception, stackTrace) {
      if (!mounted || _generation != currentGeneration) return;
      setError(
        exception,
        stackTrace,
        message: errorMessage(exception, stackTrace),
        cached: cached,
      );
    }
  }

  /// Convenience method to reload data.
  FutureOr<void> reload({bool cached = true}) => load(cached: cached);

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

  /// Updates the state to loading.
  void setLoading({bool cached = true}) {
    final lastData = cached ? operationNotifier.value.data : null;
    final newOp = LoadingOperation<T>(data: lastData);
    if (newOp == operationNotifier.value) {
      return;
    }

    operationNotifier.value = newOp;
    onLoading();

    if (mounted && globalRefresh) setState(() {});
  }

  /// Updates the state to success with the provided data.
  void setSuccess(T data, {String? message}) {
    if (operationNotifier.value case SuccessOperation(
      data: final oldData,
      message: final oldMessage,
    ) when oldData == data && oldMessage == message) {
      return;
    }

    operationNotifier.value = SuccessOperation<T>(data: data, message: message);
    onSuccess(data);

    if (mounted && globalRefresh) setState(() {});
  }

  /// Attaches an optional message to the success state produced by the
  /// current [fetch] call. Safe to call from anywhere inside [fetch],
  /// including after awaits. Outside a [load] call this is a no-op.
  @protected
  void attachMessage(String message) {
    final cell = Zone.current[messageKey] as MessageCell?;
    cell?.value = message;
  }

  /// Updates the state to error with the provided exception details.
  void setError(
    Object exception,
    StackTrace stackTrace, {
    String? message,
    bool cached = true,
  }) {
    final lastData = cached ? operationNotifier.value.data : null;
    final errorOp = ErrorOperation<T>(
      message: message ?? errorMessage(exception, stackTrace),
      exception: exception,
      stackTrace: stackTrace,
      data: lastData,
    );

    if (errorOp == operationNotifier.value) {
      return;
    }

    operationNotifier.value = errorOp;
    onError(exception, stackTrace, message: message);

    if (mounted && globalRefresh) setState(() {});
  }

  /// Converts an exception and stack trace into a human-readable error message.
  /// Override to provide custom error message formatting.
  String errorMessage(Object exception, StackTrace stackTrace) =>
      exception.toString();

  /// Called when an error occurs. Override for custom error handling.
  void onError(Object exception, StackTrace stackTrace, {String? message}) {
    developer.log(
      message ?? errorMessage(exception, stackTrace),
      name: 'AsyncOperationMixin',
      error: exception,
      stackTrace: stackTrace,
    );
  }

  /// Called when data is successfully loaded. Override for custom handling.
  void onSuccess(T data) {}

  /// Called when the state transitions to loading. Override for custom handling.
  void onLoading() {}

  /// Called when the state transitions to idle. Override for custom handling.
  void onIdle() {}
}

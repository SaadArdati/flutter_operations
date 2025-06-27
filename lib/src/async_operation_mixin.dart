import 'dart:async';

import 'package:flutter/widgets.dart';

import 'operation_state.dart';

/// A mixin that adds asynchronous state management to a [StatefulWidget].
///
/// Handles one-time asynchronous operations with loading, success, and error
/// states. Unlike [StreamOperationMixin] which handles continuous streams,
/// this is designed for discrete fetch operations with a clear start and end.
///
/// Key features:
/// * Automatic state transitions between loading, success, and error
/// * Support for cached data during refresh operations
/// * Race condition prevention through generation tracking
/// * Optional global widget rebuilds or localized updates
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
  /// Must be implemented to define how to retrieve data.
  FutureOr<T> fetch();

  /// Loads data and updates the operation state accordingly.
  /// Handles the complete loading lifecycle with race condition protection.
  FutureOr<void> load({bool cached = true}) async {
    final currentGeneration = ++_generation;
    setLoading(cached: cached);

    try {
      final result = await fetch();
      if (!mounted || _generation != currentGeneration) return;

      setSuccess(result);
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
  void setLoading({bool idle = false, bool cached = true}) {
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
  void setSuccess(T data) {
    if (operationNotifier.value is SuccessOperation<T> &&
        operationNotifier.value.data == data) {
      return;
    }

    operationNotifier.value = SuccessOperation<T>(data: data);
    onSuccess(data);

    if (mounted && globalRefresh) setState(() {});
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
    print(message ?? errorMessage(exception, stackTrace));
    print(exception);
    print(stackTrace);
  }

  /// Called when data is successfully loaded. Override for custom handling.
  void onSuccess(T data) {}

  /// Called when the state transitions to loading. Override for custom handling.
  void onLoading() {}

  void onIdle() {}
}

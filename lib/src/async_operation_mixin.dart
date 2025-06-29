import 'dart:async';

import 'package:flutter/widgets.dart';

import 'operation_state.dart';

/// Internal exception used to detect when fetch/fetchWithMessage methods
///  are not overridden.
class _NotImplementedException implements Exception {
  final String methodName;

  const _NotImplementedException(this.methodName);

  @override
  String toString() =>
      'AsyncOperationMixinException: $methodName not implemented';
}

/// A mixin that adds asynchronous state management to a [StatefulWidget].
///
/// Handles one-time asynchronous operations with **idle**, **loading**,
/// **success**, and **error** states.
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
  /// You must override either this method OR [fetchWithMessage], but not both.
  ///
  /// This method is for simple cases where you only need to return data.
  /// For cases where you want to include a success message, override
  /// [fetchWithMessage] instead.
  ///
  /// Default implementation throws to indicate it must be overridden.
  FutureOr<T> fetch() => throw const _NotImplementedException('fetch');

  /// Fetches the data with an optional success message.
  ///
  /// You must override either this method OR [fetch], but not both.
  ///
  /// Default implementation throws to indicate it must be overridden.
  /// When overridden, return a record `(T, String?)` containing the data
  /// and optional message.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// Future<(User, String?)> fetchWithMessage() async {
  ///   // API returns a Map with 'data' and 'message' fields
  ///   final response = await http.get(Uri.parse('https://api.example.com/user'));
  ///   final json = jsonDecode(response.body);
  ///
  ///   // Decode the data
  ///   final user = User.fromJson(json['data']);
  ///
  ///   // Extract the message from server response
  ///   final message = json['message'] as String?;
  ///
  ///   return (user, message);
  /// }
  /// ```
  FutureOr<(T, String?)> fetchWithMessage() =>
      throw const _NotImplementedException('fetchWithMessage');

  /// Loads data and updates the operation state accordingly.
  /// Handles the complete loading lifecycle with race condition protection.
  FutureOr<void> load({bool cached = true}) async {
    final currentGeneration = ++_generation;
    setLoading(cached: cached);

    try {
      // Try fetchWithMessage() first
      (T, String?)? resultWithMessage;
      try {
        resultWithMessage = await fetchWithMessage();
      } on _NotImplementedException {
        // fetchWithMessage not overridden, try fetch()
      }

      if (resultWithMessage != null) {
        // fetchWithMessage() was overridden, validate fetch() is not
        try {
          await fetch();
          // If we get here, fetch() was also overridden (didn't throw)
          throw StateError(
            'Both fetch() and fetchWithMessage() are overridden. '
            'You must override exactly one of them.',
          );
        } on _NotImplementedException {
          // fetch() was not overridden, use fetchWithMessage result
          if (!mounted || _generation != currentGeneration) return;
          setSuccess(resultWithMessage.$1, message: resultWithMessage.$2);
          return;
        }
      }

      // fetchWithMessage() was not overridden, use fetch()
      final result = await fetch();
      if (!mounted || _generation != currentGeneration) return;

      setSuccess(result);
    } catch (exception, stackTrace) {
      if (!mounted || _generation != currentGeneration) return;

      // Check if neither method was overridden
      if (exception is _NotImplementedException) {
        throw StateError(
          'Neither fetch() nor fetchWithMessage() are overridden. '
          'You must override exactly one of them.',
        );
      }

      // Don't report our internal exception as an error
      if (exception is StateError) {
        // Re-throw StateError (from validation)
        rethrow;
      }

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

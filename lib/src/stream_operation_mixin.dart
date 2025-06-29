import 'dart:async';

import 'package:flutter/widgets.dart';

import 'operation_result.dart';
import 'operation_state.dart';

/// Internal exception used to detect when stream/streamWithMessage methods
///  are not overridden.
class _NotImplementedException implements Exception {
  final String methodName;

  const _NotImplementedException(this.methodName);

  @override
  String toString() =>
      'AsyncOperationMixinException: $methodName not implemented';
}

/// A mixin that adds stream-based state management to a [StatefulWidget].
///
/// Handles continuous data streams with automatic subscription management,
/// state transitions, and proper cleanup. Unlike [AsyncOperationMixin] which
/// deals with one-off operations, this mixin is built for sources that emit
/// **multiple** values over time (e.g. WebSockets, database listeners).
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
  /// You must override either this method OR [streamWithMessage],
  /// but not both.
  ///
  /// This method is for simple cases where you only need to return data.
  /// For cases where you want to include success messages, override
  /// [streamWithMessage] instead.
  ///
  /// Default implementation throws to indicate it must be overridden.
  Stream<T> stream() => throw const _NotImplementedException('stream');

  /// Creates and returns a stream that includes optional success messages.
  ///
  /// You must override either this method OR [stream], but not both.
  ///
  /// Default implementation throws to indicate it must be overridden.
  /// When overridden, return a stream of [OperationResult] objects containing
  ///  data and optional messages.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// Stream<OperationResult<User>> streamWithMessage() {
  ///   return userStream.map((jsonMap) {
  ///     // Stream emits Maps with 'data' and 'message' fields
  ///     final user = User.fromJson(jsonMap['data']);
  ///     final message = jsonMap['message'] as String?;
  ///     return OperationResult(user, message: message);
  ///   });
  /// }
  /// ```
  Stream<OperationResult<T>> streamWithMessage() =>
      throw const _NotImplementedException('streamWithMessage');

  /// Starts listening to the stream and manages subscription lifecycle.
  /// Cancels existing subscription and creates a new one.
  void listen({bool cached = true}) {
    final currentGeneration = ++_generation;
    setLoading(cached: cached);
    if (_streamSubscription != null) {
      _streamSubscription!.cancel();
    }

    try {
      // Try streamWithMessage() first
      Stream<OperationResult<T>>? streamWithMsg;
      try {
        streamWithMsg = streamWithMessage();
      } on _NotImplementedException {
        // streamWithMessage not overridden, try stream()
      }

      if (streamWithMsg != null) {
        // streamWithMessage() was overridden, validate stream() is not
        try {
          stream();
          // If we get here, stream() was also overridden (didn't throw),
          // We notify the developer that both methods are overridden.
          throw StateError(
            'Both stream() and streamWithMessage() are overridden. '
            'You must override exactly one of them.',
          );
        } on _NotImplementedException {
          // stream() was not overridden, use streamWithMessage
          _streamSubscription = streamWithMsg.listen(
            (result) {
              if (_generation == currentGeneration) {
                setData(result.data, message: result.message);
              }
            },
            onError: (exception, stackTrace) {
              if (!mounted || _generation != currentGeneration) return;

              setError(
                exception,
                stackTrace,
                message: errorMessage(exception, stackTrace),
                cached: cached,
              );
            },
            onDone: onDone,
          );
          return;
        }
      }

      // streamWithMessage() was not overridden, use stream()
      _streamSubscription = stream().listen(
        (value) {
          if (_generation == currentGeneration) {
            setData(value);
          }
        },
        onError: (exception, stackTrace) {
          if (!mounted || _generation != currentGeneration) return;

          setError(
            exception,
            stackTrace,
            message: errorMessage(exception, stackTrace),
            cached: cached,
          );
        },
        onDone: onDone,
      );
    } catch (exception, stackTrace) {
      if (!mounted || _generation != currentGeneration) return;

      // Check if neither method was overridden
      if (exception is _NotImplementedException) {
        throw StateError(
          'Neither stream() nor streamWithMessage() are overridden. '
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

  /// Called when the state transitions to loading.
  void onLoading() {}

  /// Called when the stream emits a new value.
  void onData(T value) {}

  /// Called when the state transitions to idle.
  void onIdle() {}

  /// Called when the stream completes.
  void onDone() {}
}

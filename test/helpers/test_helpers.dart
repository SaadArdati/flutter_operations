import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_operations/flutter_operations.dart';
import 'package:flutter_test/flutter_test.dart';

class TestData {
  final String value;
  final DateTime? timestamp;
  final Map<String, dynamic>? metadata;

  const TestData(this.value, {this.timestamp, this.metadata});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TestData &&
          other.value == value &&
          other.timestamp == timestamp &&
          _mapEquals(other.metadata, metadata));

  static bool _mapEquals(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(value, timestamp, metadata?.hashCode);

  @override
  String toString() =>
      'TestData($value${timestamp != null ? ', $timestamp' : ''}${metadata != null ? ', $metadata' : ''})';
}

class StreamTestData {
  final int value;
  const StreamTestData(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is StreamTestData && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'StreamTestData($value)';
}

class StateProperties {
  final bool isLoading;
  final bool isIdle;
  final bool isSuccess;
  final bool isError;
  final bool? hasData;

  const StateProperties({
    required this.isLoading,
    required this.isIdle,
    required this.isSuccess,
    required this.isError,
    this.hasData,
  });
}

class StateTestCase<T> {
  final String name;
  final OperationState<T> state;
  final StateProperties expected;

  const StateTestCase({
    required this.name,
    required this.state,
    required this.expected,
  });
}

void expectStateProperties<T>(
  OperationState<T> state,
  StateProperties expected, {
  String? reason,
}) {
  final prefix = reason != null ? '$reason: ' : '';

  expect(
    state.isLoading,
    expected.isLoading,
    reason: '${prefix}isLoading mismatch',
  );
  expect(
    state.isNotLoading,
    !expected.isLoading,
    reason: '${prefix}isNotLoading mismatch',
  );
  expect(state.isIdle, expected.isIdle, reason: '${prefix}isIdle mismatch');
  expect(
    state.isNotIdle,
    !expected.isIdle,
    reason: '${prefix}isNotIdle mismatch',
  );
  expect(
    state.isSuccess,
    expected.isSuccess,
    reason: '${prefix}isSuccess mismatch',
  );
  expect(
    state.isNotSuccess,
    !expected.isSuccess,
    reason: '${prefix}isNotSuccess mismatch',
  );
  expect(state.isError, expected.isError, reason: '${prefix}isError mismatch');
  expect(
    state.isNotError,
    !expected.isError,
    reason: '${prefix}isNotError mismatch',
  );

  if (expected.hasData != null) {
    expect(
      state.hasData,
      expected.hasData,
      reason: '${prefix}hasData mismatch',
    );
    expect(
      state.hasNoData,
      !expected.hasData!,
      reason: '${prefix}hasNoData mismatch',
    );
  }
}

void runStatePropertyTests<T>(List<StateTestCase<T>> testCases) {
  for (final testCase in testCases) {
    test(testCase.name, () {
      expectStateProperties(testCase.state, testCase.expected);
    });
  }
}

class MockAsyncWidget extends StatefulWidget {
  final Future<TestData> Function()? mockFetch;
  final bool? mockLoadOnInit;
  final bool? mockGlobalRefresh;
  final void Function(TestData)? onSuccessOverride;
  final void Function(Object, StackTrace, {String? message})? onErrorOverride;
  final void Function()? onLoadingOverride;
  final void Function()? onIdleOverride;
  final String Function(Object, StackTrace)? errorMessageOverride;

  const MockAsyncWidget({
    super.key,
    this.mockFetch,
    this.mockLoadOnInit,
    this.mockGlobalRefresh,
    this.onSuccessOverride,
    this.onErrorOverride,
    this.onLoadingOverride,
    this.onIdleOverride,
    this.errorMessageOverride,
  });

  @override
  State<MockAsyncWidget> createState() => _MockAsyncWidgetState();
}

class _MockAsyncWidgetState extends State<MockAsyncWidget>
    with AsyncOperationMixin<TestData, MockAsyncWidget> {
  @override
  bool get loadOnInit => widget.mockLoadOnInit ?? super.loadOnInit;

  @override
  bool get globalRefresh => widget.mockGlobalRefresh ?? true;

  @override
  Future<TestData> fetch() async {
    if (widget.mockFetch != null) {
      return await widget.mockFetch!();
    }
    return const TestData('default');
  }

  @override
  void onSuccess(TestData data) {
    super.onSuccess(data);
    widget.onSuccessOverride?.call(data);
  }

  @override
  void onError(Object exception, StackTrace stackTrace, {String? message}) {
    super.onError(exception, stackTrace, message: message);
    widget.onErrorOverride?.call(exception, stackTrace, message: message);
  }

  @override
  void onLoading() {
    super.onLoading();
    widget.onLoadingOverride?.call();
  }

  @override
  void onIdle() {
    super.onIdle();
    widget.onIdleOverride?.call();
  }

  @override
  String errorMessage(Object exception, StackTrace stackTrace) {
    if (widget.errorMessageOverride != null) {
      return widget.errorMessageOverride!(exception, stackTrace);
    }
    return super.errorMessage(exception, stackTrace);
  }

  void _setError() {
    setError(
      Exception('Manual error'),
      StackTrace.current,
      message: 'Manual error message',
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8.0),
                child: switch (operation) {
                  IdleOperation(data: null) => const Text('Idle'),
                  IdleOperation(:var data?) => Text('Idle with ${data.value}'),
                  LoadingOperation(data: null) => const Text('Loading'),
                  LoadingOperation(:var data?) => Text(
                    'Loading with ${data.value}',
                  ),
                  SuccessOperation(:var data) => Text(
                    'Success: ${data.value}',
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                  ErrorOperation(:var message, data: null) => Text(
                    'Error: $message',
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                  ErrorOperation(:var message, :var data?) => Text(
                    'Error: $message with ${data.value}',
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                },
              ),

              ElevatedButton(
                key: const Key('reload_cached'),
                onPressed: () => reload(cached: true),
                child: const Text('Reload Cached'),
              ),
              ElevatedButton(
                key: const Key('reload_fresh'),
                onPressed: () => reload(cached: false),
                child: const Text('Reload Fresh'),
              ),
              ElevatedButton(
                key: const Key('set_success'),
                onPressed: () => setSuccess(const TestData('manual')),
                child: const Text('Set Success'),
              ),
              ElevatedButton(
                key: const Key('set_error'),
                onPressed: _setError,
                child: const Text('Set Error'),
              ),
              ElevatedButton(
                key: const Key('set_idle'),
                onPressed: () => setIdle(),
                child: const Text('Set Idle'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MockStreamWidget extends StatefulWidget {
  final Stream<StreamTestData>? mockStream;
  final bool? mockListenOnInit;
  final bool? mockGlobalRefresh;
  final void Function(StreamTestData)? onDataOverride;
  final void Function(Object, StackTrace, {String? message})? onErrorOverride;
  final void Function()? onLoadingOverride;
  final void Function()? onIdleOverride;

  const MockStreamWidget({
    super.key,
    this.mockStream,
    this.mockListenOnInit,
    this.mockGlobalRefresh,
    this.onDataOverride,
    this.onErrorOverride,
    this.onLoadingOverride,
    this.onIdleOverride,
  });

  @override
  State<MockStreamWidget> createState() => _MockStreamWidgetState();
}

class _MockStreamWidgetState extends State<MockStreamWidget>
    with StreamOperationMixin<StreamTestData, MockStreamWidget> {
  @override
  bool get listenOnInit => widget.mockListenOnInit ?? false;

  @override
  bool get globalRefresh => widget.mockGlobalRefresh ?? true;

  @override
  Stream<StreamTestData> stream() {
    if (widget.mockStream != null) {
      return widget.mockStream!;
    }

    return Stream.fromIterable([
      const StreamTestData(1),
      const StreamTestData(2),
    ]);
  }

  @override
  void onData(StreamTestData value) {
    super.onData(value);
    widget.onDataOverride?.call(value);
  }

  @override
  void onError(Object exception, StackTrace stackTrace, {String? message}) {
    super.onError(exception, stackTrace, message: message);
    widget.onErrorOverride?.call(exception, stackTrace, message: message);
  }

  @override
  void onLoading() {
    super.onLoading();
    widget.onLoadingOverride?.call();
  }

  @override
  void onIdle() {
    super.onIdle();
    widget.onIdleOverride?.call();
  }

  void _setStreamError() {
    setError(
      Exception('Manual stream error'),
      StackTrace.current,
      message: 'Manual stream error message',
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8.0),
                child: switch (operation) {
                  IdleOperation(data: null) => const Text('Idle'),
                  IdleOperation(:var data?) => Text('Idle with ${data.value}'),
                  LoadingOperation(data: null) => const Text('Loading'),
                  LoadingOperation(:var data?) => Text(
                    'Loading with ${data.value}',
                  ),
                  SuccessOperation(:var data) => Text(
                    'Success: ${data.value}',
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                  ErrorOperation(:var message, data: null) => Text(
                    'Error: $message',
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                  ErrorOperation(:var message, :var data?) => Text(
                    'Error: $message with ${data.value}',
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                },
              ),

              ElevatedButton(
                key: const Key('listen_cached'),
                onPressed: () => listen(cached: true),
                child: const Text('Listen Cached'),
              ),
              ElevatedButton(
                key: const Key('listen_fresh'),
                onPressed: () => listen(cached: false),
                child: const Text('Listen Fresh'),
              ),
              ElevatedButton(
                key: const Key('set_data'),
                onPressed: () => setData(const StreamTestData(999)),
                child: const Text('Set Data'),
              ),
              ElevatedButton(
                key: const Key('set_error'),
                onPressed: _setStreamError,
                child: const Text('Set Error'),
              ),
              ElevatedButton(
                key: const Key('set_idle'),
                onPressed: () => setIdle(),
                child: const Text('Set Idle'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget createValueListenableWidget(
  ValueNotifier<OperationState<TestData>> notifier,
) {
  return MaterialApp(
    home: Scaffold(
      body: ValueListenableBuilder<OperationState<TestData>>(
        valueListenable: notifier,
        builder: (context, state, child) {
          return switch (state) {
            IdleOperation(data: null) => const Text('Idle'),
            IdleOperation(:var data?) => Text('Idle with ${data.value}'),
            LoadingOperation(data: null) => const Text('Loading'),
            LoadingOperation(:var data?) => Text('Loading with ${data.value}'),
            SuccessOperation(:var data) => Text('Success: ${data.value}'),
            ErrorOperation(:var message, data: null) => Text('Error: $message'),
            ErrorOperation(:var message, :var data?) => Text(
              'Error: $message with ${data.value}',
            ),
          };
        },
      ),
    ),
  );
}

final List<StateTestCase<TestData>> commonStateTestCases = [
  StateTestCase(
    name: 'LoadingOperation without data',
    state: const LoadingOperation<TestData>(),
    expected: const StateProperties(
      isLoading: true,
      isIdle: false,
      isSuccess: false,
      isError: false,
      hasData: false,
    ),
  ),
  StateTestCase(
    name: 'LoadingOperation with cached data',
    state: const LoadingOperation<TestData>(data: TestData('cached')),
    expected: const StateProperties(
      isLoading: true,
      isIdle: false,
      isSuccess: false,
      isError: false,
      hasData: true,
    ),
  ),
  StateTestCase(
    name: 'IdleOperation without data',
    state: const IdleOperation<TestData>(),
    expected: const StateProperties(
      isLoading: false,
      isIdle: true,
      isSuccess: false,
      isError: false,
      hasData: false,
    ),
  ),
  StateTestCase(
    name: 'IdleOperation with cached data',
    state: const IdleOperation<TestData>(data: TestData('cached')),
    expected: const StateProperties(
      isLoading: false,
      isIdle: true,
      isSuccess: false,
      isError: false,
      hasData: true,
    ),
  ),
  StateTestCase(
    name: 'SuccessOperation with data',
    state: const SuccessOperation<TestData>(data: TestData('success')),
    expected: const StateProperties(
      isLoading: false,
      isIdle: false,
      isSuccess: true,
      isError: false,
      hasData: true,
    ),
  ),
  StateTestCase(
    name: 'ErrorOperation without cached data',
    state: const ErrorOperation<TestData>(message: 'Error occurred'),
    expected: const StateProperties(
      isLoading: false,
      isIdle: false,
      isSuccess: false,
      isError: true,
      hasData: false,
    ),
  ),
  StateTestCase(
    name: 'ErrorOperation with cached data',
    state: const ErrorOperation<TestData>(
      message: 'Error occurred',
      data: TestData('cached'),
    ),
    expected: const StateProperties(
      isLoading: false,
      isIdle: false,
      isSuccess: false,
      isError: true,
      hasData: true,
    ),
  ),
];

class ControllableFuture<T> {
  final Completer<T> _completer = Completer<T>();

  Future<T> get future => _completer.future;

  void complete(T value) => _completer.complete(value);
  void completeError(Object error, [StackTrace? stackTrace]) =>
      _completer.completeError(error, stackTrace);

  bool get isCompleted => _completer.isCompleted;
}

class ControllableStreamController<T> {
  final StreamController<T> _controller = StreamController<T>();

  Stream<T> get stream => _controller.stream;

  void add(T value) => _controller.add(value);
  void addError(Object error, [StackTrace? stackTrace]) =>
      _controller.addError(error, stackTrace);
  void close() => _controller.close();

  bool get isClosed => _controller.isClosed;
}

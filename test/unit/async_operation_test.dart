import 'dart:async';

import 'package:flutter_operations/flutter_operations.dart';
import 'package:flutter_test/flutter_test.dart';

final class _TestOperation<T> extends AsyncOperation<T> {
  _TestOperation({super.initialState});

  final events = <String>[];
  String? callbackMessage;

  @override
  String errorMessage(Object error, StackTrace stackTrace) => 'formatted';

  @override
  void onLoading() => events.add('loading');

  @override
  void onSuccess(T data) => events.add('success');

  @override
  void onError(Object error, StackTrace stackTrace, {String? message}) {
    callbackMessage = message;
    events.add('error');
  }

  @override
  void onIdle() => events.add('idle');

  @override
  void onChanged(OperationState<T> previous, OperationState<T> next) {
    events.add('changed');
  }
}

void main() {
  test('onRead tracks reads, not transitions', () {
    var reads = 0;
    final operation = AsyncOperation<int>(onRead: () => reads++);

    expect(reads, 0);
    expect(operation.state, isA<IdleOperation<int>>());
    expect(reads, 1);

    operation.setSuccess(42);
    expect(reads, 1);
    expect(operation.state.dataOrNull, 42);
    expect(reads, 2);
    operation.dispose();
  });

  test('constructor callbacks receive transitions in order', () {
    final events = <String>[];
    final operation = AsyncOperation<int>(
      onChanged: (previous, next) => events.add('changed'),
      onLoading: () => events.add('loading'),
      onSuccess: (data) => events.add('success:$data'),
      onIdle: () => events.add('idle'),
    );

    operation.setLoading();
    operation.setSuccess(1);
    operation.setIdle();

    expect(events, [
      'changed',
      'loading',
      'changed',
      'success:1',
      'changed',
      'idle',
    ]);
  });

  test('nested lifecycle transitions notify once in transition order', () {
    final transitions = <(int?, int?)>[];
    late final AsyncOperation<int> operation;
    operation = AsyncOperation<int>(
      onChanged: (previous, next) {
        expect(identical(operation.state, next), isTrue);
        transitions.add((previous.dataOrNull, next.dataOrNull));
      },
      onSuccess: (value) {
        if (value == 1) operation.setSuccess(2);
      },
    );

    operation.setSuccess(1);

    expect(transitions, [(null, 1), (1, 2)]);
    expect(operation.state.dataOrNull, 2);
    operation.dispose();
  });

  test('direct transitions notify before their lifecycle callback', () {
    final operation = _TestOperation<int>();

    operation.setLoading();
    operation.setSuccess(1);
    operation.setIdle();

    expect(operation.events, [
      'changed',
      'loading',
      'changed',
      'success',
      'changed',
      'idle',
    ]);
  });

  test(
    'automatic errors preserve current cached data and resolved message',
    () async {
      final completer = Completer<int>();
      final operation = _TestOperation<int>();

      final running = operation.run(() => completer.future);
      operation.setSuccess(7);
      completer.completeError(StateError('failed'));
      await running;

      expect(
        operation.state,
        isA<ErrorOperation<int>>()
            .having((state) => state.data, 'data', 7)
            .having((state) => state.message, 'message', 'formatted'),
      );
      expect(operation.callbackMessage, 'formatted');
    },
  );

  test('direct errors preserve the nullable callback message', () {
    final operation = _TestOperation<int>();

    operation.setError(StateError('failed'), StackTrace.current);

    expect((operation.state as ErrorOperation<int>).message, 'formatted');
    expect(operation.callbackMessage, isNull);
  });

  test('latest run wins', () async {
    final first = Completer<int>();
    final second = Completer<int>();
    final operation = AsyncOperation<int>();

    final firstRun = operation.run(() => first.future);
    final secondRun = operation.run(() => second.future);
    second.complete(2);
    await secondRun;
    first.complete(1);
    await firstRun;

    expect((operation.state as SuccessOperation<int>).data, 2);
  });

  test('attachMessage only affects its receiving operation', () async {
    final first = AsyncOperation<int>();
    final second = AsyncOperation<int>();

    await first.run(() {
      second.attachMessage('wrong operation');
      return 1;
    });

    expect((first.state as SuccessOperation<int>).message, isNull);
  });

  test('first concurrency accepts a run started by onSuccess', () async {
    late AsyncOperation<int> operation;
    var runs = 0;
    operation = AsyncOperation<int>(
      concurrency: AsyncOperationConcurrency.first,
      onSuccess: (data) {
        if (data == 1) operation.run(() => ++runs);
      },
    );

    await operation.run(() => ++runs);
    await Future<void>.delayed(Duration.zero);

    expect(runs, 2);
    expect((operation.state as SuccessOperation<int>).data, 2);
  });

  test('cancel and dispose suppress late results', () async {
    final cancelled = Completer<int>();
    final disposed = Completer<int>();
    final operation = AsyncOperation<int>();

    final cancelledRun = operation.run(() => cancelled.future);
    operation.cancel();
    cancelled.complete(1);
    await cancelledRun;
    expect(operation.state, isA<IdleOperation<int>>());

    final disposedRun = operation.run(() => disposed.future);
    operation.dispose();
    disposed.complete(2);
    await disposedRun;
    expect(operation.state, isA<LoadingOperation<int>>());
  });
  for (final changed in [false, true]) {
    test(
      'throwing ${changed ? 'change' : 'loading'} hook releases first policy',
      () async {
        var fail = true;
        void hook() {
          if (fail) throw StateError('callback');
        }

        final operation = AsyncOperation<int>(
          concurrency: AsyncOperationConcurrency.first,
          onLoading: changed ? null : hook,
          onChanged: changed ? (_, _) => hook() : null,
        );
        await expectLater(operation.run(() => 1), throwsStateError);
        expect(operation.isRunning, isFalse);
        fail = false;
        await operation.run(() => 2);
        expect(operation.state.dataOrNull, 2);
        operation.dispose();
      },
    );
  }

  for (final dispose in [false, true]) {
    test(
      '${dispose ? 'dispose' : 'cancel'} in loading prevents work',
      () async {
        var runs = 0;
        late AsyncOperation<int> operation;
        operation = AsyncOperation<int>(
          onLoading: () {
            dispose ? operation.dispose() : operation.cancel();
          },
        );
        await operation.run(() => ++runs);
        expect(runs, 0);
        expect(operation.isRunning, isFalse);
        operation.dispose();
      },
    );
  }
  for (final restart in [false, true]) {
    test(
      'formatter ${restart ? 'restart' : 'cancel'} suppresses obsolete async error',
      () async {
        final replacement = Completer<int>();
        Future<void>? running;
        var errors = 0;
        late AsyncOperation<int> operation;
        operation = AsyncOperation<int>(
          errorMessage: (_, _) {
            if (restart) {
              running = operation.run(() => replacement.future);
            } else {
              operation.cancel();
            }
            return 'obsolete';
          },
          onError: (_, _, {message}) => errors++,
        );
        await operation.run(() => throw StateError('failed'));
        expect(operation.state.isLoading, restart);
        expect(operation.state.isIdle, !restart);
        expect(operation.isRunning, restart);
        expect(errors, 0);
        if (restart) {
          replacement.complete(2);
          await running;
          expect(operation.state.dataOrNull, 2);
        }
        operation.dispose();
      },
    );
  }
}

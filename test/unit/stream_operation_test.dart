import 'dart:async';

import 'package:flutter_operations/flutter_operations.dart';
import 'package:flutter_test/flutter_test.dart';

class _StreamHost with StreamOperationMixin<int> {
  _StreamHost(this.source);
  final Stream<int> source;
  int changes = 0;
  @override
  Stream<int> stream() => source;
  @override
  void operationChanged(
    OperationState<int> previous,
    OperationState<int> next,
  ) => changes++;
}

class _InjectedStreamHost extends _StreamHost {
  _InjectedStreamHost(super.source, this.operationController);
  @override
  final StreamOperation<int> operationController;
}

void main() {
  test('host mixin publishes transitions and owns disposal', () async {
    final controller = StreamController<int>();
    final host = _StreamHost(controller.stream);
    await host.listen();
    controller.add(9);
    await Future<void>.delayed(Duration.zero);
    expect(host.operation.dataOrNull, 9);
    expect(host.changes, 2);
    await host.cancel();
    expect(host.operation.isIdle, isTrue);
    await host.disposeOperation();
    expect(host.operationController.isDisposed, isTrue);
    await controller.close();
  });

  test(
    'injected stream controller routes reads, commands and disposal',
    () async {
      final controller = StreamController<int>();
      var changes = 0;
      final engine = StreamOperation<int>(onChanged: (_, _) => changes++);
      final host = _InjectedStreamHost(controller.stream, engine);
      await host.listen();
      host.setData(4);
      expect(identical(host.operation, engine.state), isTrue);
      expect(host.changes, 0);
      expect(changes, 2);
      await host.cancel();
      await host.disposeOperation();
      expect(engine.isDisposed, isTrue);
      await controller.close();
    },
  );

  test('tracks reads and notifies before data callbacks', () async {
    var reads = 0;
    final events = <String>[];
    late final StreamOperation<int> operation;
    operation = StreamOperation<int>(
      onRead: () => reads++,
      onChanged: (_, next) => events.add('change:${next.runtimeType}'),
      onData: (data) {
        expect(operation.state.dataOrNull, data);
        events.add('data:$data');
      },
    );
    expect(operation.state.isIdle, isTrue);
    expect(reads, 1);
    await operation.listen(() => Stream.value(42));
    await Future<void>.delayed(Duration.zero);
    expect(events.length, 3);
    expect(events.last, 'data:42');
    await operation.dispose();
  });

  test('restart waits for cleanup; only latest source is created', () async {
    final cleanup = Completer<void>();
    final first = StreamController<int>(onCancel: () => cleanup.future);
    final latest = StreamController<int>();
    final operation = StreamOperation<int>();
    await operation.listen(() => first.stream);
    first.add(1);
    await Future<void>.delayed(Duration.zero);

    var obsoleteCreated = false;
    var latestCreated = false;
    final obsolete = operation.listen(() {
      obsoleteCreated = true;
      return const Stream.empty();
    });
    final replacement = operation.listen(() {
      latestCreated = true;
      return latest.stream;
    });
    await Future<void>.delayed(Duration.zero);
    expect(obsoleteCreated, isFalse);
    expect(latestCreated, isFalse);
    expect(operation.state.dataOrNull, 1);
    cleanup.complete();
    await Future.wait([obsolete, replacement]);
    expect(obsoleteCreated, isFalse);
    expect(latestCreated, isTrue);
    latest.add(2);
    await Future<void>.delayed(Duration.zero);
    expect(operation.state.dataOrNull, 2);
    await operation.dispose();
    await first.close();
    await latest.close();
  });

  test('cancel becomes idle immediately and cancels pending restart', () async {
    final cleanup = Completer<void>();
    final controller = StreamController<int>(onCancel: () => cleanup.future);
    final operation = StreamOperation<int>();
    await operation.listen(() => controller.stream);
    var created = false;
    final restart = operation.listen(() {
      created = true;
      return const Stream.empty();
    });
    final cancel = operation.cancel(cached: false);
    expect(operation.state.isIdle, isTrue);
    expect(operation.state.hasNoData, isTrue);
    cleanup.complete();
    await Future.wait([restart, cancel]);
    expect(created, isFalse);
    await operation.dispose();
    await controller.close();
  });

  test('dispose blocks events and awaits the same pending cleanup', () async {
    final cleanup = Completer<void>();
    final controller = StreamController<int>(onCancel: () => cleanup.future);
    var done = 0;
    final operation = StreamOperation<int>(onDone: () => done++);
    await operation.listen(() => controller.stream);
    controller.add(7);
    final disposal = operation.dispose();
    expect(operation.isDisposed, isTrue);
    expect(identical(disposal, operation.dispose()), isTrue);
    var created = false;
    await operation.listen(() {
      created = true;
      return const Stream.empty();
    });
    expect(created, isFalse);
    cleanup.complete();
    await disposal;
    await controller.close();
    expect(operation.state.isLoading, isTrue);
    expect(done, 0);
  });

  test('cleanup failure propagates and prevents replacement', () async {
    final failure = StateError('cleanup failed');
    final controller = StreamController<int>(
      onCancel: () async => throw failure,
    );
    final operation = StreamOperation<int>();
    await operation.listen(() => controller.stream);
    var created = false;
    await expectLater(
      operation.listen(() {
        created = true;
        return const Stream.empty();
      }),
      throwsA(same(failure)),
    );
    expect(created, isFalse);
    await expectLater(operation.dispose(), throwsA(same(failure)));
    await controller.close();
  });

  test('source factory failures become errors and can restart', () async {
    final operation = StreamOperation<int>(
      errorMessage: (_, _) => 'Unable to connect',
    );
    operation.setData(4);
    await operation.listen(() => throw StateError('source'));
    expect(operation.state, isA<ErrorOperation<int>>());
    expect(operation.state.dataOrNull, 4);
    expect(
      (operation.state as ErrorOperation<int>).message,
      'Unable to connect',
    );
    await operation.listen(() => Stream.value(8), cached: false);
    await Future<void>.delayed(Duration.zero);
    expect(operation.state.dataOrNull, 8);
    await operation.dispose();
  });

  test('stream errors retain cache and listening continues', () async {
    final controller = StreamController<int>();
    final operation = StreamOperation<int>();
    await operation.listen(() => controller.stream);
    controller.add(1);
    await Future<void>.delayed(Duration.zero);
    controller.addError(StateError('offline'));
    await Future<void>.delayed(Duration.zero);
    expect(operation.state.isError, isTrue);
    expect(operation.state.dataOrNull, 1);
    controller.add(2);
    await Future<void>.delayed(Duration.zero);
    expect(operation.state.isSuccess, isTrue);
    expect(operation.state.dataOrNull, 2);
    await operation.dispose();
    await controller.close();
  });

  test(
    'messages are per emission and owned by the receiving operation',
    () async {
      final messages = <String?>[];
      final other = StreamOperation<int>();
      late final StreamOperation<int> operation;
      operation = StreamOperation<int>(
        onChanged: (_, next) {
          if (next case SuccessOperation(:final message)) messages.add(message);
        },
      );
      Stream<int> source() async* {
        operation.attachMessage('first');
        yield 1;
        other.attachMessage('wrong owner');
        yield 2;
        operation.attachMessage('third');
        yield 3;
      }

      operation.attachMessage('outside');
      await operation.listen(source);
      await Future<void>.delayed(Duration.zero);
      expect(messages, ['first', null, 'third']);
      await operation.dispose();
      await other.dispose();
    },
  );

  test('completion retains state and fires onDone once', () async {
    var done = 0;
    final operation = StreamOperation<int>(onDone: () => done++);
    await operation.listen(() => Stream.value(1));
    await Future<void>.delayed(Duration.zero);
    expect(done, 1);
    expect(operation.state.dataOrNull, 1);
    await operation.cancel();
    expect(done, 1);
    await operation.dispose();
  });

  test(
    'equal setters suppress notifications; idle does not unsubscribe',
    () async {
      var changes = 0;
      final controller = StreamController<int>();
      final operation = StreamOperation<int>(onChanged: (_, _) => changes++);
      operation.setData(3);
      operation.setData(3);
      expect(changes, 1);
      await operation.listen(() => controller.stream);
      operation.setIdle();
      controller.add(5);
      await Future<void>.delayed(Duration.zero);
      expect(operation.state.dataOrNull, 5);
      await operation.dispose();
      operation.setData(6);
      expect(operation.state.dataOrNull, 5);
      await controller.close();
    },
  );
  test(
    'factory restart waits for the subscription being established',
    () async {
      final cleanup = Completer<void>();
      final cancelled = Completer<void>();
      final first = StreamController<int>(
        onCancel: () {
          cancelled.complete();
          return cleanup.future;
        },
      );
      final second = StreamController<int>();
      final operation = StreamOperation<int>();
      late Future<void> restart;
      var created = false;
      final listening = operation.listen(() {
        restart = operation.listen(() {
          created = true;
          return second.stream;
        });
        return first.stream;
      });
      await cancelled.future;
      expect(created, isFalse);
      cleanup.complete();
      await Future.wait([listening, restart]);
      expect(created, isTrue);
      await operation.dispose();
      await first.close();
      await second.close();
    },
  );

  for (final dispose in [false, true]) {
    test(
      'factory ${dispose ? 'dispose' : 'cancel'} awaits establishment cleanup',
      () async {
        final cleanup = Completer<void>();
        final cancelled = Completer<void>();
        final controller = StreamController<int>(
          onCancel: () {
            cancelled.complete();
            return cleanup.future;
          },
        );
        final operation = StreamOperation<int>();
        late Future<void> stopping;
        var finished = false;
        final listening = operation.listen(() {
          stopping = dispose ? operation.dispose() : operation.cancel();
          stopping.then((_) => finished = true);
          return controller.stream;
        });
        await cancelled.future;
        await Future<void>.delayed(Duration.zero);
        expect(finished, isFalse);
        cleanup.complete();
        await Future.wait([listening, stopping]);
        expect(finished, isTrue);
        await operation.dispose();
        await controller.close();
      },
    );
  }
  test(
    'factory disposal propagates establishment cancellation failure',
    () async {
      final failure = StateError('cleanup failed');
      final controller = StreamController<int>(
        onCancel: () async => throw failure,
      );
      final operation = StreamOperation<int>();
      late Future<void> stopping;
      final listening = operation.listen(() {
        stopping = operation.dispose();
        return controller.stream;
      });
      await expectLater(listening, throwsA(same(failure)));
      await expectLater(stopping, throwsA(same(failure)));
      await expectLater(operation.dispose(), throwsA(same(failure)));
      await controller.close();
    },
  );
  for (final sourceFailure in [false, true]) {
    for (final restart in [false, true]) {
      test(
        'formatter ${restart ? 'restart' : 'cancel'} suppresses obsolete ${sourceFailure ? 'source' : 'stream'} error',
        () async {
          final source = StreamController<int>.broadcast();
          final replacement = StreamController<int>.broadcast();
          Future<void>? stopping;
          var errors = 0;
          late StreamOperation<int> operation;
          operation = StreamOperation<int>(
            errorMessage: (_, _) {
              stopping = restart
                  ? operation.listen(() => replacement.stream)
                  : operation.cancel();
              return 'obsolete';
            },
            onError: (_, _, {message}) => errors++,
          );
          if (sourceFailure) {
            await operation.listen(() => throw StateError('source failed'));
          } else {
            await operation.listen(() => source.stream);
            source.addError(StateError('stream failed'));
            await Future<void>.delayed(Duration.zero);
          }
          await stopping;
          expect(operation.state.isLoading, restart);
          expect(operation.state.isIdle, !restart);
          expect(errors, 0);
          if (restart) {
            replacement.add(2);
            await Future<void>.delayed(Duration.zero);
            expect(operation.state.dataOrNull, 2);
          }
          await operation.dispose();
          await source.close();
          await replacement.close();
        },
      );
    }
  }
}

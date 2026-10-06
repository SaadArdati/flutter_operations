import 'dart:async';

import 'package:flutter_operations/flutter_operations.dart';
import 'package:flutter_test/flutter_test.dart';

class _Host with AsyncOperationMixin<int> {
  _Host(this.result);

  final Future<int> result;
  int changes = 0;

  @override
  Future<int> fetch() => result;

  @override
  void operationChanged(
    OperationState<int> previous,
    OperationState<int> next,
  ) {
    changes++;
  }
}

class _InjectedHost extends _Host {
  _InjectedHost(super.result, this.operationController);

  @override
  final AsyncOperation<int> operationController;
}

void main() {
  test(
    'injected controller owns reads, commands, callbacks and disposal',
    () async {
      var changes = 0;
      final controller = AsyncOperation<int>(onChanged: (_, _) => changes++);
      final host = _InjectedHost(Future.value(42), controller);
      await host.load();
      expect(identical(host.operation, controller.state), isTrue);
      expect(host.operation.dataOrNull, 42);
      expect(changes, 2);
      expect(host.changes, 0); // Supplied controllers own their callbacks.

      host.setLoading();
      expect(controller.state.isLoading, isTrue);
      host.setSuccess(7);
      expect(controller.state.dataOrNull, 7);
      host.setError(StateError('failed'), StackTrace.current);
      expect(controller.state.isError, isTrue);
      host.setIdle();
      expect(controller.state.isIdle, isTrue);
      host.cancel();
      expect(controller.state.isIdle, isTrue);
      await host.reload();
      expect(controller.state.dataOrNull, 42);
      host.disposeOperation();
      expect(controller.isDisposed, isTrue);
    },
  );

  test('host mixin owns one operation lifecycle', () async {
    final host = _Host(Future.value(42));

    await host.load();

    expect(host.operation, const SuccessOperation<int>(data: 42));
    expect(host.changes, 2);
  });

  test('disposeOperation suppresses late completion', () async {
    final result = Completer<int>();
    final host = _Host(result.future);

    final running = host.load();
    host.disposeOperation();
    result.complete(42);
    await running;

    expect(host.operation, isA<LoadingOperation<int>>());
    expect(host.changes, 1);
  });
}

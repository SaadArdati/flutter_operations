import 'package:flutter/material.dart';
import 'package:flutter_operations/flutter_operations.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../shared/stream_operation_view.dart';

class CounterSignalsStore {
  CounterSignalsStore(this.repository) {
    operation = StreamOperation<int>(
      onChanged: (_, next) => state.value = next,
    );
  }
  final CounterRepository repository;
  final state = signal<OperationState<int>>(const IdleOperation());
  late final StreamOperation<int> operation;

  Future<void> listen() => operation.listen(repository.watch);
  Future<void> cancel() => operation.cancel();
  Future<void> dispose() async {
    try {
      await operation.dispose();
    } finally {
      state.dispose();
    }
  }
}

class MixinCounterSignalsStore with StreamOperationMixin<int> {
  MixinCounterSignalsStore(this.repository);
  final CounterRepository repository;
  final state = signal<OperationState<int>>(const IdleOperation());

  @override
  Stream<int> stream() => repository.watch();
  @override
  void operationChanged(
    OperationState<int> previous,
    OperationState<int> next,
  ) => state.value = next;

  Future<void> dispose() async {
    try {
      await disposeOperation();
    } finally {
      state.dispose();
    }
  }
}

class SignalsStreamIntegrationExample extends StatefulWidget {
  const SignalsStreamIntegrationExample({
    super.key,
    this.repository = const DemoCounterRepository(),
  });
  final CounterRepository repository;

  @override
  State<SignalsStreamIntegrationExample> createState() =>
      _SignalsStreamIntegrationExampleState();
}

class _SignalsStreamIntegrationExampleState
    extends State<SignalsStreamIntegrationExample> {
  late final composed = CounterSignalsStore(widget.repository);
  late final mixed = MixinCounterSignalsStore(widget.repository);

  @override
  void dispose() {
    StreamCleanup.report(composed.dispose());
    StreamCleanup.report(mixed.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamIntegrationPage(
    title: 'Signals Stream Integration',
    builder: (_, mixin) => SignalBuilder(
      key: ValueKey(mixin),
      builder: (_) => CounterOperationView(
        operation: mixin ? mixed.state.value : composed.state.value,
        listen: mixin ? mixed.listen : composed.listen,
        cancel: mixin ? mixed.cancel : composed.cancel,
      ),
    ),
  );
}

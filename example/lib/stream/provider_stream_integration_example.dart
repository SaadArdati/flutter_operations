import 'package:flutter/material.dart';
import 'package:flutter_operations/flutter_operations.dart';
import 'package:provider/provider.dart';

import '../shared/stream_operation_view.dart';

class CounterChangeNotifier extends ChangeNotifier {
  CounterChangeNotifier(this.repository) {
    operation = StreamOperation<int>(onChanged: (_, _) => notifyListeners());
  }
  final CounterRepository repository;
  late final StreamOperation<int> operation;

  Future<void> listen() => operation.listen(repository.watch);
  Future<void> cancel() => operation.cancel();

  @override
  void dispose() {
    StreamCleanup.report(operation.dispose());
    super.dispose();
  }
}

class MixinCounterChangeNotifier extends ChangeNotifier
    with StreamOperationMixin<int> {
  MixinCounterChangeNotifier(this.repository);
  final CounterRepository repository;

  @override
  Stream<int> stream() => repository.watch();
  @override
  void operationChanged(
    OperationState<int> previous,
    OperationState<int> next,
  ) => notifyListeners();

  @override
  void dispose() {
    StreamCleanup.report(disposeOperation());
    super.dispose();
  }
}

class ProviderStreamIntegrationExample extends StatelessWidget {
  const ProviderStreamIntegrationExample({
    super.key,
    this.repository = const DemoCounterRepository(),
  });
  final CounterRepository repository;

  @override
  Widget build(BuildContext context) => StreamIntegrationPage(
    title: 'Provider Stream Integration',
    builder: (_, mixin) => mixin
        ? ChangeNotifierProvider(
            create: (_) => MixinCounterChangeNotifier(repository),
            child: Consumer<MixinCounterChangeNotifier>(
              builder: (_, owner, _) => CounterOperationView(
                operation: owner.operation,
                listen: owner.listen,
                cancel: owner.cancel,
              ),
            ),
          )
        : ChangeNotifierProvider(
            create: (_) => CounterChangeNotifier(repository),
            child: Consumer<CounterChangeNotifier>(
              builder: (_, owner, _) => CounterOperationView(
                operation: owner.operation.state,
                listen: owner.listen,
                cancel: owner.cancel,
              ),
            ),
          ),
  );
}

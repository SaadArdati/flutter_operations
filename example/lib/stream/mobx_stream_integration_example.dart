import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_operations/flutter_operations.dart';
import 'package:mobx/mobx.dart';

import '../shared/stream_operation_view.dart';

class CounterMobxStore with Store {
  CounterMobxStore(this.repository) {
    operation = StreamOperation<int>(
      onRead: _atom.reportRead,
      onChanged: (_, _) => _atom.reportChanged(),
    );
  }
  final CounterRepository repository;
  final _atom = Atom(name: 'counterStream');
  late final StreamOperation<int> operation;

  OperationState<int> get state => operation.state;
  Future<void> listen() => operation.listen(repository.watch);
  Future<void> cancel() => operation.cancel();
  Future<void> dispose() => operation.dispose();
}

class MixinCounterMobxStore with Store, StreamOperationMixin<int> {
  MixinCounterMobxStore(this.repository);
  final CounterRepository repository;
  final _atom = Atom(name: 'mixinCounterStream');

  @override
  Stream<int> stream() => repository.watch();
  @override
  void operationRead() => _atom.reportRead();
  @override
  void operationChanged(
    OperationState<int> previous,
    OperationState<int> next,
  ) => _atom.reportChanged();
}

class MobxStreamIntegrationExample extends StatefulWidget {
  const MobxStreamIntegrationExample({
    super.key,
    this.repository = const DemoCounterRepository(),
  });
  final CounterRepository repository;

  @override
  State<MobxStreamIntegrationExample> createState() =>
      _MobxStreamIntegrationExampleState();
}

class _MobxStreamIntegrationExampleState
    extends State<MobxStreamIntegrationExample> {
  late final composed = CounterMobxStore(widget.repository);
  late final mixed = MixinCounterMobxStore(widget.repository);

  @override
  void dispose() {
    StreamCleanup.report(composed.dispose());
    StreamCleanup.report(mixed.disposeOperation());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamIntegrationPage(
    title: 'MobX Stream Integration',
    builder: (_, mixin) => Observer(
      builder: (_) => CounterOperationView(
        // Read inside Observer. An observable controller reference alone would
        // not track nested state; the operation's read hook tracks its Atom.
        operation: mixin ? mixed.operation : composed.state,
        listen: mixin ? mixed.listen : composed.listen,
        cancel: mixin ? mixed.cancel : composed.cancel,
      ),
    ),
  );
}

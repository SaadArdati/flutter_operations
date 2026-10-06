import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_operations/flutter_operations.dart';

import '../shared/stream_operation_view.dart';

class CounterCubit extends Cubit<OperationState<int>> {
  CounterCubit(this.repository) : super(const IdleOperation()) {
    operation = StreamOperation<int>(
      onChanged: (_, next) => emit(next),
      errorMessage: (_, _) => 'Connection interrupted; waiting for recovery.',
    );
  }

  final CounterRepository repository;
  late final StreamOperation<int> operation;

  Future<void> listen() => operation.listen(repository.watch);
  Future<void> cancel() => operation.cancel();

  @override
  Future<void> close() async {
    try {
      await operation.dispose();
    } finally {
      await super.close();
    }
  }
}

// Cubit already has a `stream` getter. The host mixin's `stream()` method
// cannot override it, so delegate to a domain host rather than changing APIs.
class MixinCounterCubit extends Cubit<OperationState<int>> {
  MixinCounterCubit(CounterRepository repository)
    : super(const IdleOperation()) {
    _host = _CounterHost(repository, emit);
  }
  late final _CounterHost _host;

  Future<void> listen() => _host.listen();
  Future<void> cancel() => _host.cancel();

  @override
  Future<void> close() async {
    try {
      await _host.disposeOperation();
    } finally {
      await super.close();
    }
  }
}

class _CounterHost with StreamOperationMixin<int> {
  _CounterHost(this.repository, this.publish);
  final CounterRepository repository;
  final void Function(OperationState<int>) publish;

  @override
  Stream<int> stream() => repository.watch();
  @override
  void operationChanged(
    OperationState<int> previous,
    OperationState<int> next,
  ) => publish(next);
  @override
  String errorMessage(Object error, StackTrace trace) =>
      'Connection interrupted; waiting for recovery.';
}

class BlocStreamIntegrationExample extends StatelessWidget {
  const BlocStreamIntegrationExample({
    super.key,
    this.repository = const DemoCounterRepository(),
  });
  final CounterRepository repository;

  @override
  Widget build(BuildContext context) => StreamIntegrationPage(
    title: 'Bloc Stream Integration',
    builder: (_, mixin) => mixin
        ? BlocProvider(
            create: (_) => MixinCounterCubit(repository),
            child: BlocBuilder<MixinCounterCubit, OperationState<int>>(
              builder: (context, state) {
                final owner = context.read<MixinCounterCubit>();
                return CounterOperationView(
                  operation: state,
                  listen: owner.listen,
                  cancel: owner.cancel,
                );
              },
            ),
          )
        : BlocProvider(
            create: (_) => CounterCubit(repository),
            child: BlocBuilder<CounterCubit, OperationState<int>>(
              builder: (context, state) {
                final owner = context.read<CounterCubit>();
                return CounterOperationView(
                  operation: state,
                  listen: owner.listen,
                  cancel: owner.cancel,
                );
              },
            ),
          ),
  );
}

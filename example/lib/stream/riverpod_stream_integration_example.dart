import 'package:flutter/material.dart';
import 'package:flutter_operations/flutter_operations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/stream_operation_view.dart';

final counterRepositoryProvider = Provider<CounterRepository>(
  (_) => const DemoCounterRepository(),
);
final counterStreamProvider =
    NotifierProvider.autoDispose<CounterStreamNotifier, OperationState<int>>(
      CounterStreamNotifier.new,
    );
final mixinCounterStreamProvider =
    NotifierProvider.autoDispose<
      MixinCounterStreamNotifier,
      OperationState<int>
    >(MixinCounterStreamNotifier.new);

class CounterStreamNotifier extends Notifier<OperationState<int>> {
  late StreamOperation<int> operation;
  late CounterRepository repository;

  @override
  OperationState<int> build() {
    repository = ref.watch(counterRepositoryProvider);
    final controller = StreamOperation<int>(
      onChanged: (_, next) => state = next,
    );
    operation = controller;
    // Capture this build's controller, not the replaceable field.
    ref.onDispose(() => StreamCleanup.report(controller.dispose()));
    return controller.state;
  }

  Future<void> listen() => operation.listen(repository.watch);
  Future<void> cancel() => operation.cancel();
}

class MixinCounterStreamNotifier extends Notifier<OperationState<int>>
    with StreamOperationMixin<int> {
  @override
  late StreamOperation<int> operationController;
  late CounterRepository repository;

  @override
  OperationState<int> build() {
    repository = ref.watch(counterRepositoryProvider);
    final controller = StreamOperation<int>(
      onRead: operationRead,
      onChanged: operationChanged,
      errorMessage: errorMessage,
      onLoading: onLoading,
      onData: onData,
      onError: onError,
      onIdle: onIdle,
      onDone: onDone,
    );
    operationController = controller;
    ref.onDispose(() => StreamCleanup.report(controller.dispose()));
    return controller.state;
  }

  @override
  Stream<int> stream() => repository.watch();
  @override
  void operationChanged(
    OperationState<int> previous,
    OperationState<int> next,
  ) => state = next;
}

class RiverpodStreamIntegrationExample extends StatelessWidget {
  const RiverpodStreamIntegrationExample({
    super.key,
    this.repository = const DemoCounterRepository(),
  });
  final CounterRepository repository;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [counterRepositoryProvider.overrideWithValue(repository)],
    child: StreamIntegrationPage(
      title: 'Riverpod Stream Integration',
      builder: (_, mixin) => _CounterView(mixin: mixin),
    ),
  );
}

class _CounterView extends ConsumerWidget {
  const _CounterView({required this.mixin});
  final bool mixin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (mixin) {
      final state = ref.watch(mixinCounterStreamProvider);
      final owner = ref.read(mixinCounterStreamProvider.notifier);
      return CounterOperationView(
        operation: state,
        listen: owner.listen,
        cancel: owner.cancel,
      );
    }
    final state = ref.watch(counterStreamProvider);
    final owner = ref.read(counterStreamProvider.notifier);
    return CounterOperationView(
      operation: state,
      listen: owner.listen,
      cancel: owner.cancel,
    );
  }
}

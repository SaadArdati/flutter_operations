import 'package:flutter/material.dart';
import 'package:flutter_operations/flutter_operations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/example_layout.dart';
import '../shared/models.dart';
import '../shared/services.dart';
import '../shared/user_operation_view.dart';

final _directProvider =
    NotifierProvider.autoDispose<_DirectNotifier, OperationState<User>>(
      _DirectNotifier.new,
    );

final _composedProvider =
    NotifierProvider.autoDispose<_ComposedNotifier, OperationState<User>>(
      _ComposedNotifier.new,
    );

final _mixinProvider =
    NotifierProvider.autoDispose<_MixinNotifier, OperationState<User>>(
      _MixinNotifier.new,
    );

class RiverpodIntegrationExample extends StatelessWidget {
  const RiverpodIntegrationExample({super.key});

  @override
  Widget build(BuildContext context) =>
      const ProviderScope(child: _RiverpodPage());
}

class _RiverpodPage extends ConsumerStatefulWidget {
  const _RiverpodPage();

  @override
  ConsumerState<_RiverpodPage> createState() => _RiverpodPageState();
}

class _RiverpodPageState extends ConsumerState<_RiverpodPage> {
  int selected = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Riverpod Integration')),
    body: ExampleBody(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DropdownButton<int>(
                value: selected,
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Direct state')),
                  DropdownMenuItem(value: 1, child: Text('Composed operation')),
                  DropdownMenuItem(value: 2, child: Text('Operation mixin')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => selected = value);
                },
              ),
            ),
          ),
          Expanded(
            child: switch (selected) {
              0 => UserOperationView(
                operation: ref.watch(_directProvider),
                run: ref.read(_directProvider.notifier).load,
                cancel: ref.read(_directProvider.notifier).cancel,
              ),
              1 => UserOperationView(
                operation: ref.watch(_composedProvider),
                run: ref.read(_composedProvider.notifier).load,
                cancel: ref.read(_composedProvider.notifier).cancel,
              ),
              2 => UserOperationView(
                operation: ref.watch(_mixinProvider),
                run: ref.read(_mixinProvider.notifier).load,
                cancel: ref.read(_mixinProvider.notifier).cancel,
              ),
              _ => throw StateError('Unknown integration'),
            },
          ),
        ],
      ),
    ),
  );
}

class _DirectNotifier extends Notifier<OperationState<User>> {
  @override
  OperationState<User> build() {
    ref.onDispose(() => _generation++);
    return IdleOperation();
  }

  int _generation = 0;

  Future<void> load() async {
    final generation = ++_generation;
    state = state.transitionTo.loading();
    try {
      final user = await MockApiService.fetchUser();
      if (!ref.mounted || generation != _generation) return;
      state = state.transitionTo.success(data: user);
    } catch (error, stackTrace) {
      if (!ref.mounted || generation != _generation) return;
      state = state.transitionTo.error(
        error: error,
        stackTrace: stackTrace,
        message: 'Unable to load user.',
      );
    }
  }

  void cancel() {
    _generation++;
    state = state.transitionTo.idle();
  }
}

class _ComposedNotifier extends Notifier<OperationState<User>> {
  late AsyncOperation<User> operation;

  @override
  OperationState<User> build() {
    final controller = AsyncOperation<User>(
      onChanged: (_, next) => state = next,
    );
    operation = controller;
    ref.onDispose(controller.dispose);
    return controller.state;
  }

  Future<void> load() => operation.run(MockApiService.fetchUser);
  void cancel() => operation.cancel();
}

class _MixinNotifier extends Notifier<OperationState<User>>
    with AsyncOperationMixin<User> {
  // Riverpod can rebuild a notifier without replacing it. Each build gets a
  // fresh controller; disposal remains tied to that exact instance.
  @override
  late AsyncOperation<User> operationController;

  @override
  OperationState<User> build() {
    final controller = AsyncOperation<User>(
      onRead: operationRead,
      onChanged: operationChanged,
      errorMessage: errorMessage,
      onLoading: onLoading,
      onSuccess: onSuccess,
      onError: onError,
      onIdle: onIdle,
    );
    operationController = controller;
    ref.onDispose(controller.dispose);
    return controller.state;
  }

  @override
  Future<User> fetch() => MockApiService.fetchUser();

  @override
  void operationChanged(
    OperationState<User> previous,
    OperationState<User> next,
  ) => state = next;
}

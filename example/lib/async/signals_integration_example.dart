import 'package:flutter/material.dart';
import 'package:flutter_operations/flutter_operations.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../shared/example_layout.dart';
import '../shared/models.dart';
import '../shared/services.dart';
import '../shared/user_operation_view.dart';

class SignalsIntegrationExample extends StatefulWidget {
  const SignalsIntegrationExample({super.key});

  @override
  State<SignalsIntegrationExample> createState() =>
      _SignalsIntegrationExampleState();
}

class _SignalsIntegrationExampleState extends State<SignalsIntegrationExample> {
  final direct = _DirectStore();
  final composed = _ComposedStore();
  final mixed = _MixinStore();
  int selected = 0;

  @override
  void dispose() {
    direct.dispose();
    composed.dispose();
    mixed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Signals Integration')),
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
            child: SignalBuilder(
              key: ValueKey(selected),
              builder: (_) => switch (selected) {
                0 => UserOperationView(
                  operation: direct.state.value,
                  run: direct.load,
                  cancel: direct.cancel,
                ),
                1 => UserOperationView(
                  operation: composed.state.value,
                  run: composed.load,
                  cancel: composed.cancel,
                ),
                _ => UserOperationView(
                  operation: mixed.state.value,
                  run: mixed.load,
                  cancel: mixed.cancel,
                ),
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _DirectStore {
  final state = signal<OperationState<User>>(IdleOperation());
  bool _disposed = false;

  int _generation = 0;

  Future<void> load() async {
    final generation = ++_generation;
    state.value = state.value.transitionTo.loading();
    try {
      final user = await MockApiService.fetchUser();
      if (_disposed || generation != _generation) return;
      state.value = state.value.transitionTo.success(data: user);
    } catch (error, stackTrace) {
      if (_disposed || generation != _generation) return;
      state.value = state.value.transitionTo.error(
        error: error,
        stackTrace: stackTrace,
        message: 'Unable to load user.',
      );
    }
  }

  void cancel() {
    _generation++;
    state.value = state.value.transitionTo.idle();
  }

  void dispose() {
    _disposed = true;
    _generation++;
    state.dispose();
  }
}

class _ComposedStore {
  final state = signal<OperationState<User>>(IdleOperation());
  late final operation = AsyncOperation<User>(
    onChanged: (_, next) => state.value = next,
  );

  Future<void> load() => operation.run(MockApiService.fetchUser);
  void cancel() => operation.cancel();

  void dispose() {
    operation.dispose();
    state.dispose();
  }
}

class _MixinStore with AsyncOperationMixin<User> {
  final state = signal<OperationState<User>>(IdleOperation());

  @override
  Future<User> fetch() => MockApiService.fetchUser();

  @override
  void operationChanged(
    OperationState<User> previous,
    OperationState<User> next,
  ) => state.value = next;

  void dispose() {
    disposeOperation();
    state.dispose();
  }
}

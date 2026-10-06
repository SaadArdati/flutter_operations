import 'package:flutter/material.dart';
import 'package:flutter_operations/flutter_operations.dart';
import 'package:provider/provider.dart';

import '../shared/example_layout.dart';
import '../shared/models.dart';
import '../shared/services.dart';
import '../shared/user_operation_view.dart';

class ProviderIntegrationExample extends StatefulWidget {
  const ProviderIntegrationExample({super.key});

  @override
  State<ProviderIntegrationExample> createState() =>
      _ProviderIntegrationExampleState();
}

class _ProviderIntegrationExampleState
    extends State<ProviderIntegrationExample> {
  int selected = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Provider Integration')),
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
              0 => ChangeNotifierProvider(
                create: (_) => _DirectStore(),
                child: Consumer<_DirectStore>(
                  builder: (context, store, _) => UserOperationView(
                    operation: store.operation,
                    run: store.load,
                    cancel: store.cancel,
                  ),
                ),
              ),
              1 => ChangeNotifierProvider(
                create: (_) => _ComposedStore(),
                child: Consumer<_ComposedStore>(
                  builder: (context, store, _) => UserOperationView(
                    operation: store.operation,
                    run: store.load,
                    cancel: store.cancel,
                  ),
                ),
              ),
              2 => ChangeNotifierProvider(
                create: (_) => _MixinStore(),
                child: Consumer<_MixinStore>(
                  builder: (context, store, _) => UserOperationView(
                    operation: store.operation,
                    run: store.load,
                    cancel: store.cancel,
                  ),
                ),
              ),
              _ => throw StateError('Unknown integration'),
            },
          ),
        ],
      ),
    ),
  );
}

class _DirectStore extends ChangeNotifier {
  OperationState<User> operation = IdleOperation();
  bool _disposed = false;

  void _publish(OperationState<User> next) {
    operation = next;
    notifyListeners();
  }

  int _generation = 0;

  Future<void> load() async {
    final generation = ++_generation;
    _publish(operation.transitionTo.loading());
    try {
      final user = await MockApiService.fetchUser();
      if (_disposed || generation != _generation) return;
      _publish(operation.transitionTo.success(data: user));
    } catch (error, stackTrace) {
      if (_disposed || generation != _generation) return;
      _publish(
        operation.transitionTo.error(
          error: error,
          stackTrace: stackTrace,
          message: 'Unable to load user.',
        ),
      );
    }
  }

  void cancel() {
    _generation++;
    _publish(operation.transitionTo.idle());
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

class _ComposedStore extends ChangeNotifier {
  late final _controller = AsyncOperation<User>(
    onChanged: (_, _) => notifyListeners(),
  );

  OperationState<User> get operation => _controller.state;

  Future<void> load() => _controller.run(MockApiService.fetchUser);

  void cancel() => _controller.cancel();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _MixinStore extends ChangeNotifier with AsyncOperationMixin<User> {
  @override
  Future<User> fetch() => MockApiService.fetchUser();

  @override
  void operationChanged(
    OperationState<User> previous,
    OperationState<User> next,
  ) => notifyListeners();

  @override
  void dispose() {
    disposeOperation();
    super.dispose();
  }
}

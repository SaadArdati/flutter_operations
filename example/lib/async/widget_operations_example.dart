import 'package:flutter/material.dart';
import 'package:flutter_operations/flutter_operations.dart';

import '../shared/example_layout.dart';
import '../shared/models.dart';
import '../shared/services.dart';
import '../shared/user_operation_view.dart';

class WidgetAsyncExample extends StatefulWidget {
  const WidgetAsyncExample({super.key});

  @override
  State<WidgetAsyncExample> createState() => _WidgetAsyncExampleState();
}

class _WidgetAsyncExampleState extends State<WidgetAsyncExample>
    with AsyncOperationStateMixin<User, WidgetAsyncExample> {
  bool rebuildWholeWidget = false;

  @override
  bool get loadOnInit => false;
  @override
  bool get globalRefresh => rebuildWholeWidget;
  @override
  Future<User> fetch() async {
    final response = await MockApiService.fetchUserWithMessage();
    if (response['message'] case final String message) attachMessage(message);
    return User.fromJson(response['data']);
  }

  @override
  String errorMessage(Object error, StackTrace trace) => 'Unable to load user.';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Widget-owned Future')),
    body: ExampleBody(
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Rebuild whole widget'),
            subtitle: const Text(
              'Otherwise only the notifier listener rebuilds.',
            ),
            value: rebuildWholeWidget,
            onChanged: (value) => setState(() => rebuildWholeWidget = value),
          ),
          Expanded(
            child: rebuildWholeWidget
                ? UserOperationView(
                    operation: operation,
                    run: load,
                    cancel: _reset,
                    cancelLabel: 'Set idle',
                  )
                : ValueListenableBuilder(
                    valueListenable: operationNotifier,
                    builder: (_, state, _) => UserOperationView(
                      operation: state,
                      run: load,
                      cancel: _reset,
                      cancelLabel: 'Set idle',
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextButton(
              onPressed: () => reload(cached: false),
              child: const Text('Reload without cache'),
            ),
          ),
        ],
      ),
    ),
  );

  // The widget adapter has no cancellation command; idle is a state change.
  void _reset() => setIdle();
}

class SearchExample extends StatefulWidget {
  const SearchExample({super.key});

  @override
  State<SearchExample> createState() => _SearchExampleState();
}

class _SearchExampleState extends State<SearchExample> {
  final query = TextEditingController();
  late final operation = AsyncOperation<List<Product>>(
    onChanged: (_, _) => setState(() {}),
    errorMessage: (error, trace) => 'Unable to search products.',
  );

  void _search() {
    final text = query.text.trim();
    operation.cancel(cached: false);
    if (text.isNotEmpty) {
      operation.run(() => MockApiService.searchProducts(text), cached: false);
    }
  }

  void _clear() {
    query.clear();
    operation.cancel(cached: false);
  }

  @override
  void dispose() {
    operation.dispose();
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Search on demand')),
    body: ExampleBody(
      child: Column(
        children: [
          TextField(
            controller: query,
            decoration: const InputDecoration(
              labelText: 'Product query',
              hintText: 'Search the demo catalog',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
            ),
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _search,
                icon: const Icon(Icons.search),
                label: const Text('Search'),
              ),
              TextButton(onPressed: _clear, child: const Text('Clear')),
            ],
          ),
          Expanded(
            child: switch (operation.state) {
              IdleOperation() => const Center(
                child: OperationMessage(
                  icon: Icons.search,
                  title: 'Find a product',
                  message: 'Enter a query to search.',
                ),
              ),
              LoadingOperation() => const Center(
                child: CircularProgressIndicator(),
              ),
              ErrorOperation(:final message) => Center(
                child: Text(message ?? 'Unable to search products.'),
              ),
              SuccessOperation(:final data) =>
                data.isEmpty
                    ? const Center(
                        child: OperationMessage(
                          icon: Icons.search_off,
                          title: 'No products found.',
                          message: 'Try another query.',
                        ),
                      )
                    : ListView(
                        children: [
                          for (final product in data)
                            ListTile(title: Text(product.name)),
                        ],
                      ),
            },
          ),
        ],
      ),
    ),
  );
}

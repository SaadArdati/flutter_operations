import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_operations/flutter_operations.dart';

import 'shared/models.dart';
import 'shared/services.dart';
import 'shared/widgets.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_operations Examples',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const ExampleHome(),
    );
  }
}

// ---------------------------------------------------------------------------
// Home
// ---------------------------------------------------------------------------

class ExampleHome extends StatelessWidget {
  const ExampleHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('flutter_operations Examples')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _tile(
            context,
            title: '1. Basic Async Fetch',
            subtitle:
                'ValueSuccessOperation, message field, cached data on reload',
            page: const BasicFetchExample(),
          ),
          _tile(
            context,
            title: '2. Fire-and-Forget (VoidSuccessOperation)',
            subtitle: 'Delete & feedback actions that succeed without data',
            page: const VoidSuccessExample(),
          ),
          _tile(
            context,
            title: '3. Stream Counter',
            subtitle: 'StreamOperationMixin with real-time updates',
            page: const StreamCounterExample(),
          ),
          _tile(
            context,
            title: '4. Search with IdleOperation',
            subtitle: 'loadOnInit: false, boolean getters, cached data',
            page: const SearchExample(),
          ),
          _tile(
            context,
            title: '5. Global Refresh + Catch-all Pattern',
            subtitle: 'globalRefresh = true, SuccessOperation broad match (T?)',
            page: const GlobalRefreshExample(),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget page,
  }) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. Basic Async Fetch
//
// Showcases:
//   - AsyncOperationMixin with fetchWithMessage()
//   - ValueSuccessOperation(:var data) for guaranteed non-null data
//   - SuccessOperation message field
//   - Cached data during reload (LoadingOperation(:var data?))
//   - Cached data on error  (ErrorOperation(:var data?))
//   - ValueListenableBuilder for scoped rebuilds
// ---------------------------------------------------------------------------

class BasicFetchExample extends StatefulWidget {
  const BasicFetchExample({super.key});

  @override
  State<BasicFetchExample> createState() => _BasicFetchExampleState();
}

class _BasicFetchExampleState extends State<BasicFetchExample>
    with AsyncOperationMixin<User, BasicFetchExample> {
  @override
  Future<(User, String?)> fetchWithMessage() async {
    final response = await MockApiService.fetchUserWithMessage();
    return (User.fromJson(response['data']), response['message'] as String?);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Basic Async Fetch')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder<OperationState<User>>(
          valueListenable: operationNotifier,
          builder: (context, op, _) => switch (op) {
            // Initial load — no cached data yet.
            LoadingOperation(data: null) => const LoadingStateWidget(
              message: 'Loading user...',
            ),

            // Reload — show stale data beneath a progress bar.
            LoadingOperation(:var data?) => Column(
              children: [
                const LoadingStateWidget(
                  message: 'Refreshing...',
                  showLinearProgress: true,
                ),
                const SizedBox(height: 16),
                Expanded(child: UserCard(user: data, isRefreshing: true)),
              ],
            ),

            // Unreachable for AsyncOperationMixin<User> (setSuccess always
            // creates ValueSuccessOperation), but required for exhaustiveness.
            VoidSuccessOperation() => const Center(
              child: Text('Completed with no data'),
            ),
            ValueSuccessOperation(:var data, :var message) => Column(
              children: [
                if (message != null) _successBanner(message),
                Expanded(child: UserCard(user: data)),
                const SizedBox(height: 16),
                _reloadButtons(),
              ],
            ),

            // Error without cached data.
            ErrorOperation(:var message, data: null) => ErrorStateWidget(
              message: message ?? 'Unknown error',
              onRetry: reload,
            ),

            // Error WITH cached data — show warning banner + stale data.
            ErrorOperation(:var message, :var data?) => Column(
              children: [
                ErrorStateWidget(
                  message: message ?? 'Refresh failed',
                  onRetry: reload,
                  showAsWarning: true,
                ),
                const SizedBox(height: 16),
                Expanded(child: UserCard(user: data)),
              ],
            ),
          },
        ),
      ),
    );
  }

  Widget _successBanner(String message) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.green.shade50,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.green.shade200),
    ),
    child: Row(
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: Colors.green.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _reloadButtons() => Row(
    children: [
      Expanded(
        child: ElevatedButton(
          onPressed: () => reload(cached: true),
          child: const Text('Refresh (Cached)'),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: ElevatedButton(
          onPressed: () => reload(cached: false),
          child: const Text('Refresh (Fresh)'),
        ),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// 2. Fire-and-Forget (VoidSuccessOperation)
//
// Showcases:
//   - VoidSuccessOperation for actions that succeed without data
//   - SuccessOperation.empty() redirecting factory
//   - .empty computed getter
//   - .message on VoidSuccessOperation
//   - hasData / hasNoData getters
//   - Boolean getters (isLoading, isNotLoading) for UI decoration
// ---------------------------------------------------------------------------

class VoidSuccessExample extends StatefulWidget {
  const VoidSuccessExample({super.key});

  @override
  State<VoidSuccessExample> createState() => _VoidSuccessExampleState();
}

class _VoidSuccessExampleState extends State<VoidSuccessExample>
    with AsyncOperationMixin<void, VoidSuccessExample> {
  @override
  bool get loadOnInit => false;

  String _selectedAction = 'delete';

  @override
  Future<void> fetch() async {
    switch (_selectedAction) {
      case 'delete':
        await MockApiService.deleteItem('item_42');
      case 'feedback':
        await MockApiService.submitFeedback('Great app!');
      default:
        await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  /// Runs the action, then uses setEmpty to emit VoidSuccessOperation.
  Future<void> _runAction() async {
    setLoading();
    try {
      await fetch();
      if (!mounted) return;

      final message = switch (_selectedAction) {
        'delete' => 'Item deleted successfully',
        'feedback' => 'Feedback submitted, thank you!',
        _ => 'Action completed',
      };
      // setEmpty creates a VoidSuccessOperation — the mixin counterpart
      // to SuccessOperation.empty().
      setEmpty(message: message);
    } catch (e, st) {
      if (!mounted) return;
      setError(e, st);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fire-and-Forget Actions')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder<OperationState<void>>(
          valueListenable: operationNotifier,
          builder: (context, op, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Action buttons — use isLoading to disable during operation.
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Choose an action:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'These operations succeed with no return data '
                        '(VoidSuccessOperation). '
                        'Buttons are disabled while loading via isNotLoading.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        children: [
                          ElevatedButton.icon(
                            // Boolean getter for UI decoration.
                            onPressed: op.isNotLoading
                                ? () {
                                    _selectedAction = 'delete';
                                    _runAction();
                                  }
                                : null,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete Item'),
                          ),
                          ElevatedButton.icon(
                            onPressed: op.isNotLoading
                                ? () {
                                    _selectedAction = 'feedback';
                                    _runAction();
                                  }
                                : null,
                            icon: const Icon(Icons.feedback_outlined),
                            label: const Text('Submit Feedback'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // State display — uses hasData, empty, message.
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'State inspector:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('runtimeType: ${op.runtimeType}'),
                      Text('isLoading: ${op.isLoading}'),
                      Text('isSuccess: ${op.isSuccess}'),
                      Text('hasData: ${op.hasData}'),
                      Text('hasNoData: ${op.hasNoData}'),
                      if (op case SuccessOperation(
                        :var empty,
                        :var message,
                      )) ...[
                        Text('empty: $empty'),
                        Text('message: $message'),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Result area.
              Expanded(
                child: Center(
                  child: switch (op) {
                    IdleOperation() => const Text(
                      'Tap an action button above',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    LoadingOperation() => const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Running action...'),
                      ],
                    ),

                    // VoidSuccessOperation — no data, just a message.
                    VoidSuccessOperation(:var message) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          message ?? 'Done!',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    // Unreachable: _runAction only emits VoidSuccessOperation.
                    // Included for compiler exhaustiveness.
                    ValueSuccessOperation() => const SizedBox.shrink(),

                    ErrorOperation(:var message) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          message ?? 'Action failed',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Stream Counter
//
// Showcases:
//   - StreamOperationMixin
//   - Exhaustive matching with Value/Void subtypes
// ---------------------------------------------------------------------------

class StreamCounterExample extends StatefulWidget {
  const StreamCounterExample({super.key});

  @override
  State<StreamCounterExample> createState() => _StreamCounterExampleState();
}

class _StreamCounterExampleState extends State<StreamCounterExample>
    with StreamOperationMixin<int, StreamCounterExample> {
  @override
  Stream<int> stream() => MockStreamService.counter();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stream Counter'),
        actions: [
          IconButton(onPressed: listen, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Center(
        child: ValueListenableBuilder<OperationState<int>>(
          valueListenable: operationNotifier,
          builder: (context, op, _) => switch (op) {
            LoadingOperation() => const CircularProgressIndicator(),
            VoidSuccessOperation() => const Text('Stream completed (no data)'),
            ValueSuccessOperation(:var data) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stream, size: 64, color: Colors.blue),
                const SizedBox(height: 16),
                Text(
                  '$data',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Updates every second',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
            ErrorOperation(:var message) => ErrorStateWidget(
              message: message ?? 'Stream error',
              onRetry: listen,
            ),
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Search with IdleOperation
//
// Showcases:
//   - loadOnInit: false → starts as IdleOperation
//   - globalRefresh: true → access `operation` directly in build()
//   - IdleOperation with and without cached data
//   - Boolean getters for disabling input during loading
//   - Cached data preserved across states
//   - SuccessOperation broad match (catch-all with T?)
// ---------------------------------------------------------------------------

class SearchExample extends StatefulWidget {
  const SearchExample({super.key});

  @override
  State<SearchExample> createState() => _SearchExampleState();
}

class _SearchExampleState extends State<SearchExample>
    with AsyncOperationMixin<List<Product>, SearchExample> {
  @override
  bool get loadOnInit => false;

  @override
  bool get globalRefresh => true;

  final _controller = TextEditingController();
  String _query = '';

  @override
  Future<List<Product>> fetch() => MockApiService.searchProducts(_query);

  void _search() {
    _query = _controller.text.trim();
    load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search with IdleOperation')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Input — boolean getters for decoration.
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    // isNotLoading disables input during search.
                    enabled: operation.isNotLoading,
                    decoration: const InputDecoration(
                      hintText: 'Try "Product", "Electronics", "Books"...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: operation.isNotLoading ? _search : null,
                  child: const Text('Go'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: operation.isNotLoading
                      ? () {
                          _controller.clear();
                          _query = '';
                          setIdle();
                        }
                      : null,
                  child: const Text('Clear'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Results.
            Expanded(
              child: switch (operation) {
                // Idle with no prior results.
                IdleOperation(data: null) => const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Search for products',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                ),

                // Idle with cached results from last search.
                IdleOperation(:var data?) => _productGrid(data, stale: true),

                // Loading states.
                LoadingOperation(data: null) => const LoadingStateWidget(
                  message: 'Searching...',
                ),
                LoadingOperation(:var data?) => Column(
                  children: [
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    Expanded(child: _productGrid(data, stale: true)),
                  ],
                ),

                // SuccessOperation catch-all — data is T? here.
                // Demonstrates the broad match where you handle nullability
                // yourself instead of splitting Value/Void.
                SuccessOperation(data: null) => const Center(
                  child: Text(
                    'No results',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ),
                SuccessOperation(:var data?) when data.isEmpty => const Center(
                  child: Text(
                    'No results found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ),
                SuccessOperation(:var data?) => Column(
                  children: [
                    Text(
                      '${data.length} result${data.length != 1 ? 's' : ''} '
                      'for "$_query"',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Expanded(child: _productGrid(data)),
                  ],
                ),

                ErrorOperation(:var message, data: null) => ErrorStateWidget(
                  message: message ?? 'Search failed',
                  onRetry: _search,
                ),
                ErrorOperation(:var message, :var data?) => Column(
                  children: [
                    ErrorStateWidget(
                      message: message ?? 'Search failed',
                      onRetry: _search,
                      showAsWarning: true,
                    ),
                    const SizedBox(height: 8),
                    Expanded(child: _productGrid(data, stale: true)),
                  ],
                ),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _productGrid(List<Product> products, {bool stale = false}) =>
      GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
        ),
        itemCount: products.length,
        itemBuilder: (_, i) =>
            ProductCard(product: products[i], isStale: stale),
      );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// 5. Global Refresh + Catch-all Pattern
//
// Showcases:
//   - globalRefresh = true (entire build rebuilds, no ValueListenableBuilder)
//   - SuccessOperation catch-all match (data is T?, you null-check yourself)
//   - Minimal boilerplate for simple screens
// ---------------------------------------------------------------------------

class GlobalRefreshExample extends StatefulWidget {
  const GlobalRefreshExample({super.key});

  @override
  State<GlobalRefreshExample> createState() => _GlobalRefreshExampleState();
}

class _GlobalRefreshExampleState extends State<GlobalRefreshExample>
    with AsyncOperationMixin<List<Product>, GlobalRefreshExample> {
  @override
  bool get globalRefresh => true;

  @override
  Future<List<Product>> fetch() => MockApiService.fetchProducts();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Global Refresh'),
        actions: [
          IconButton(
            onPressed: operation.isNotLoading ? reload : null,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        // Catch-all SuccessOperation match: data is T? (nullable).
        // This is the simplest pattern — you don't distinguish Value/Void,
        // you just null-check or use data? patterns.
        child: switch (operation) {
          LoadingOperation() => const LoadingStateWidget(
            message: 'Loading products...',
          ),

          // Broad match — covers both ValueSuccessOperation and
          // VoidSuccessOperation. data is List<Product>? here.
          SuccessOperation(:var data?) => GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
            ),
            itemCount: data.length,
            itemBuilder: (_, i) => ProductCard(product: data[i]),
          ),
          SuccessOperation() => const Center(
            child: Text('No products available'),
          ),

          ErrorOperation(:var message) => ErrorStateWidget(
            message: message ?? 'Failed to load products',
            onRetry: reload,
          ),
        },
      ),
    );
  }
}

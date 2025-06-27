import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_operations/flutter_operations.dart';

import 'shared/models.dart';
import 'shared/services.dart';
import 'shared/widgets.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Operation Mixins Examples',
      home: const ExampleHome(),
    );
  }
}

class ExampleHome extends StatelessWidget {
  const ExampleHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Operation Mixins Examples')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ExampleTile(
            title: 'Basic Async (ValueListenableBuilder)',
            description:
                'Best practices with ValueListenableBuilder for performance',
            onTap: () => _navigate(context, const BasicAsyncExample()),
          ),
          _ExampleTile(
            title: 'Search with IdleOperation',
            description:
                'Manual loading pattern with IdleOperation - starts idle, loads on demand',
            onTap: () => _navigate(context, const SearchExample()),
          ),
          _ExampleTile(
            title: 'Basic Stream',
            description: 'Simple StreamOperationMixin with real-time updates',
            onTap: () => _navigate(context, const BasicStreamExample()),
          ),
          _ExampleTile(
            title: 'Global Refresh Example',
            description:
                'Simple globalRefresh = true pattern for basic widgets',
            onTap: () => _navigate(context, const GlobalRefreshExample()),
          ),
          _ExampleTile(
            title: 'Advanced Custom Handlers & Error Patterns',
            description:
                'Sophisticated error handling, circuit breakers, fallback strategies',
            onTap: () =>
                _navigate(context, const AdvancedCustomHandlersExample()),
          ),
        ],
      ),
    );
  }

  void _navigate(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => page));
}

class _ExampleTile extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback onTap;

  const _ExampleTile({
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}

class BasicAsyncExample extends StatefulWidget {
  const BasicAsyncExample({super.key});

  @override
  State<BasicAsyncExample> createState() => _BasicAsyncExampleState();
}

class _BasicAsyncExampleState extends State<BasicAsyncExample>
    with AsyncOperationMixin<User, BasicAsyncExample> {
  @override
  Future<User> fetch() => MockApiService.fetchUser();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Basic Async Operation Mixin Example')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder<OperationState<User>>(
          valueListenable: operationNotifier,
          builder: (context, operation, _) => switch (operation) {
            LoadingOperation(data: null) => const LoadingStateWidget(
              message: 'Loading user...',
            ),

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

            SuccessOperation(:var data) => Column(
              children: [
                Expanded(child: UserCard(user: data)),
                const SizedBox(height: 16),
                Row(
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
                ),
              ],
            ),

            ErrorOperation(:var message, data: null) => ErrorStateWidget(
              message: message ?? 'Unknown error occurred',
              onRetry: () => reload(),
            ),

            ErrorOperation(:var message, :var data?) => Column(
              children: [
                ErrorStateWidget(
                  message: message ?? 'Unknown error occurred',
                  onRetry: () => reload(),
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
}

class BasicStreamExample extends StatefulWidget {
  const BasicStreamExample({super.key});

  @override
  State<BasicStreamExample> createState() => _BasicStreamExampleState();
}

class _BasicStreamExampleState extends State<BasicStreamExample>
    with StreamOperationMixin<int, BasicStreamExample> {
  @override
  Stream<int> stream() => MockStreamService.counter();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Basic Stream Example'),
        actions: [
          IconButton(
            onPressed: () => listen(),
            icon: const Icon(Icons.play_arrow),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder<OperationState<int>>(
          valueListenable: operationNotifier,
          builder: (context, value, child) => switch (operation) {
            LoadingOperation() => const LoadingStateWidget(
              message: 'Connecting to stream...',
            ),

            SuccessOperation(:var data) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.stream, size: 64, color: Colors.blue),
                  const SizedBox(height: 16),
                  Text(
                    'Counter: $data',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Stream updates automatically every second',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => listen(),
                    child: const Text('Restart Stream'),
                  ),
                ],
              ),
            ),

            ErrorOperation(:var message) => ErrorStateWidget(
              message: message ?? 'Stream connection failed',
              onRetry: () => listen(),
            ),
          },
        ),
      ),
    );
  }
}

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
      appBar: AppBar(title: Text('Global Refresh Example')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: switch (operation) {
          LoadingOperation() => const LoadingStateWidget(
            message: 'Loading products...',
          ),

          SuccessOperation(:var data) => GridView.builder(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
            ),
            itemCount: data.length,
            itemBuilder: (context, index) => ProductCard(product: data[index]),
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

enum ErrorCategory {
  network,
  timeout,
  authentication,
  serverError,
  circuitBreaker,
}

class AdvancedCustomHandlersExample extends StatefulWidget {
  const AdvancedCustomHandlersExample({super.key});

  @override
  State<AdvancedCustomHandlersExample> createState() =>
      _AdvancedCustomHandlersExampleState();
}

class _AdvancedCustomHandlersExampleState
    extends State<AdvancedCustomHandlersExample>
    with AsyncOperationMixin<User, AdvancedCustomHandlersExample> {
  @override
  bool get globalRefresh => true;

  final List<String> _eventLog = [];
  bool _forceError = false;
  int _retryCount = 0;
  int _consecutiveFailures = 0;
  Timer? _retryTimer;
  Timer? _circuitBreakerTimer;
  bool _circuitBreakerOpen = false;

  @override
  Future<User> fetch() async {
    if (_circuitBreakerOpen) {
      throw Exception('Circuit breaker is open - too many failures');
    }
    return MockApiService.fetchUser(shouldFail: _forceError);
  }

  /// Advanced error categorization and custom messages
  @override
  String errorMessage(Object exception, StackTrace stackTrace) {
    final message = exception.toString();

    if (message.contains('Circuit breaker is open')) {
      return 'Service temporarily unavailable. Cooling down...';
    } else if (message.contains('Failed to load user data')) {
      return 'Network connection failed. Check your internet connection.';
    } else if (message.contains('timeout')) {
      return 'Request timed out. Server might be overloaded.';
    } else if (message.contains('unauthorized')) {
      return 'Authentication expired. Please log in again.';
    } else if (message.contains('500')) {
      return 'Server error. Our team has been notified.';
    }
    return 'An unexpected error occurred. Please try again.';
  }

  ErrorCategory _categorizeError(Object exception) {
    final message = exception.toString();
    if (message.contains('Circuit breaker is open')) {
      return ErrorCategory.circuitBreaker;
    }
    if (message.contains('Failed to load user data')) {
      return ErrorCategory.network;
    }
    if (message.contains('timeout')) {
      return ErrorCategory.timeout;
    }
    if (message.contains('unauthorized')) {
      return ErrorCategory.authentication;
    }
    if (message.contains('500')) {
      return ErrorCategory.serverError;
    }
    return ErrorCategory.network;
  }

  @override
  void onSuccess(User data) {
    super.onSuccess(data);
    _retryCount = 0;
    _consecutiveFailures = 0;
    _retryTimer?.cancel();

    // Close circuit breaker on success
    if (_circuitBreakerOpen) {
      _circuitBreakerOpen = false;
      _circuitBreakerTimer?.cancel();
      _addEvent('SUCCESS: Circuit breaker closed - service recovered');
    }

    _addEvent('SUCCESS: User ${data.name} loaded successfully');
  }

  @override
  void onError(Object exception, StackTrace stackTrace, {String? message}) {
    super.onError(exception, stackTrace, message: message);
    _consecutiveFailures++;

    final category = _categorizeError(exception);
    _addEvent(
      'ERROR: ${message ?? exception.toString()} [Category: ${category.name}]',
    );

    if (_consecutiveFailures >= 3 && !_circuitBreakerOpen) {
      _circuitBreakerOpen = true;
      _addEvent(
        'CIRCUIT BREAKER: Opened due to $_consecutiveFailures consecutive failures',
      );

      _circuitBreakerTimer = Timer(const Duration(seconds: 30), () {
        _circuitBreakerOpen = false;
        _addEvent('CIRCUIT BREAKER: Automatically closed after cooldown');
      });
      return;
    }

    if (!_circuitBreakerOpen && _retryCount < 3) {
      final delay = _getRetryDelay(category, _retryCount);
      _addEvent(
        'RETRY: Strategy for ${category.name} - retry in ${delay.inSeconds}s (attempt ${_retryCount + 1}/3)',
      );

      _retryTimer = Timer(delay, () {
        _retryCount++;
        reload();
      });
    } else if (_retryCount >= 3) {
      _addEvent('FALLBACK: Max retries exceeded - consider fallback strategy');
    }
  }

  Duration _getRetryDelay(ErrorCategory category, int retryCount) =>
      switch (category) {
        // Exponential: 2, 4, 8
        ErrorCategory.network => Duration(seconds: (2 << retryCount)),
        // Linear: 5, 10, 15
        ErrorCategory.timeout => Duration(seconds: 5 + (retryCount * 5)),
        // Immediate for auth errors
        ErrorCategory.authentication => const Duration(seconds: 1),
        // Long delays: 10, 20, 30
        ErrorCategory.serverError => Duration(seconds: 10 + (retryCount * 10)),
        ErrorCategory.circuitBreaker => const Duration(seconds: 30),
      };

  @override
  void onLoading() {
    super.onLoading();
    _addEvent('LOADING: Started fetching user data');
  }

  void _addEvent(String event) {
    if (!mounted) return;
    setState(() {
      _eventLog.add(
        '${DateTime.now().toIso8601String().substring(11, 19)}: $event',
      );
      if (_eventLog.length > 12) {
        _eventLog.removeAt(0);
      }
    });
  }

  void _resetCircuitBreaker() {
    if (!mounted) return;

    setState(() {
      _circuitBreakerOpen = false;
      _consecutiveFailures = 0;
      _retryCount = 0;
    });
    _circuitBreakerTimer?.cancel();
    _retryTimer?.cancel();
    _addEvent('MANUAL: Circuit breaker reset');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Advanced Custom Handlers & Error Patterns'),
        actions: [
          IconButton(
            onPressed: () => setState(() => _eventLog.clear()),
            icon: const Icon(Icons.clear),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Advanced Error Simulation:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    if (_circuitBreakerOpen) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red),
                        ),
                        child: const Text(
                          'Circuit Breaker OPEN',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Force Error:'),
                    Switch(
                      value: _forceError,
                      onChanged: (value) => setState(() => _forceError = value),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () => reload(),
                      child: const Text('Reload'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _circuitBreakerOpen
                          ? _resetCircuitBreaker
                          : null,
                      child: const Text('Reset CB'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Consecutive Failures: $_consecutiveFailures | Retry Count: $_retryCount',
                ),
              ],
            ),
          ),

          Container(
            height: 200,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Advanced Event Log (Circuit Breaker, Retry Strategies):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _eventLog.length,
                    itemBuilder: (context, index) {
                      final event = _eventLog[index];
                      Color color = Colors.black;
                      if (event.contains('ERROR')) {
                        color = Colors.red;
                      } else if (event.contains('SUCCESS')) {
                        color = Colors.green;
                      } else if (event.contains('CIRCUIT BREAKER')) {
                        color = Colors.orange;
                      } else if (event.contains('RETRY')) {
                        color = Colors.blue;
                      }
                      return Text(
                        event,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: color,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: switch (operation) {
                LoadingOperation() => const LoadingStateWidget(
                  message: 'Loading...',
                ),

                SuccessOperation(:var data) => Column(
                  children: [
                    Expanded(child: UserCard(user: data)),
                    const SizedBox(height: 16),
                    const Text(
                      '✅ Success handler with circuit breaker management',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                ErrorOperation(:var message, data: null) => ErrorStateWidget(
                  title: 'Advanced Error Handler',
                  message: message ?? 'Unknown error occurred',
                  onRetry: () {
                    _retryTimer?.cancel();
                    _retryCount = 0;
                    reload();
                  },
                ),

                ErrorOperation(:var message, :var data?) => Column(
                  children: [
                    ErrorStateWidget(
                      message: message ?? 'Unknown error occurred',
                      onRetry: () => reload(),
                      showAsWarning: true,
                    ),
                    const SizedBox(height: 16),
                    Expanded(child: UserCard(user: data)),
                  ],
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SearchExample extends StatefulWidget {
  const SearchExample({super.key});

  @override
  State<SearchExample> createState() => _SearchExampleState();
}

class _SearchExampleState extends State<SearchExample>
    with AsyncOperationMixin<List<Product>, SearchExample> {
  @override
  bool get loadOnInit => false; // Start in IdleOperation - don't auto-load

  final TextEditingController _searchController = TextEditingController();
  String _currentQuery = '';

  @override
  Future<List<Product>> fetch() => MockApiService.searchProducts(_currentQuery);

  void _performSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setIdle();
      return;
    }

    _currentQuery = query;
    // Manually trigger loading
    load();
  }

  void _clearSearch() {
    _searchController.clear();
    _currentQuery = '';
    setIdle();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search with IdleOperation')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search input section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Search Products',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This example demonstrates IdleOperation - the widget starts idle and only loads when you search.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Enter product name...',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.search),
                            ),
                            onSubmitted: (_) => _performSearch(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _performSearch,
                          child: const Text('Search'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _clearSearch,
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // State indicator
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                'Current State: ${switch (operation) {
                  IdleOperation(data: null) => 'IdleOperation (no data) - Ready to search',
                  IdleOperation(data: _) => 'IdleOperation (with cached data) - Showing previous results',
                  LoadingOperation(data: null) => 'LoadingOperation (no data) - Searching...',
                  LoadingOperation(data: _) => 'LoadingOperation (with cached data) - Searching with cached results shown',
                  SuccessOperation(data: _) => 'SuccessOperation - Search completed successfully',
                  ErrorOperation(data: null) => 'ErrorOperation (no data) - Search failed',
                  ErrorOperation(data: _) => 'ErrorOperation (with cached data) - Search failed, showing cached results',
                }}',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.blue.shade700,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Results section
            Expanded(
              child: ValueListenableBuilder<OperationState<List<Product>>>(
                valueListenable: operationNotifier,
                builder: (context, operation, _) => switch (operation) {
                  // IdleOperation - only appears because loadOnInit = false
                  IdleOperation(data: null) => const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Ready to Search',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Enter a search term and press Search to begin',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),

                  // IdleOperation with cached data from previous search
                  IdleOperation(:var data?) => Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Text(
                          'Showing cached results for previous search. Enter new search term to search again.',
                          style: TextStyle(color: Colors.orange.shade700),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 200,
                              ),
                          itemCount: data.length,
                          itemBuilder: (context, index) => ProductCard(
                            product: data[index],
                            isStale: true, // Indicate this is cached data
                          ),
                        ),
                      ),
                    ],
                  ),

                  LoadingOperation(data: null) => const LoadingStateWidget(
                    message: 'Searching products...',
                  ),

                  LoadingOperation(:var data?) => Column(
                    children: [
                      const LoadingStateWidget(
                        message: 'Searching...',
                        showLinearProgress: true,
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 200,
                              ),
                          itemCount: data.length,
                          itemBuilder: (context, index) =>
                              ProductCard(product: data[index], isStale: true),
                        ),
                      ),
                    ],
                  ),

                  SuccessOperation(:var data) when data.isEmpty => const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No Results Found',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Try a different search term',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),

                  SuccessOperation(:var data) => Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Text(
                          'Found ${data.length} product${data.length != 1 ? 's' : ''} for "$_currentQuery"',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 200,
                              ),
                          itemCount: data.length,
                          itemBuilder: (context, index) =>
                              ProductCard(product: data[index]),
                        ),
                      ),
                    ],
                  ),

                  ErrorOperation(:var message, data: null) => ErrorStateWidget(
                    title: 'Search Failed',
                    message: message ?? 'Failed to search products',
                    onRetry: () => _performSearch(),
                  ),

                  ErrorOperation(:var message, :var data?) => Column(
                    children: [
                      ErrorStateWidget(
                        message: message ?? 'Search failed',
                        onRetry: () => _performSearch(),
                        showAsWarning: true,
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 200,
                              ),
                          itemCount: data.length,
                          itemBuilder: (context, index) =>
                              ProductCard(product: data[index], isStale: true),
                        ),
                      ),
                    ],
                  ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

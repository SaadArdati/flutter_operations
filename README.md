# Flutter Operations

[![Pub Version](https://img.shields.io/pub/v/flutter_operations.svg)](https://pub.dev/packages/flutter_operations)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> This package emerged
>
from [Exhaustive Pattern Matching for Exhausted Flutter Developers](https://medium.com/@saadoardati/exhaustive-pattern-matching-for-exhausted-flutter-developers-cd6837459862),
> exploring how Dart's sealed classes and switch expressions can transform async state management.

A lightweight, type-safe operation state management utility for Flutter that eliminates the common dance of manually
juggling `isLoading`, `error`, and `data` fields. Instead of relying on discipline to keep these mutually exclusive
states in sync, this package leverages Dart's sealed classes and exhaustive pattern matching to make illegal states
unrepresentable.

## The Problem This Solves

Every Flutter developer knows this repetitive pattern:

```dart
class MyWidgetState extends State<MyWidget> {
  bool isLoading = true;
  String? error;
  Object? data;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      data = await repository.fetchData();
      setState(() => isLoading = false);
    } catch (e) {
      setState(() {
        isLoading = false;
        error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? CircularProgressIndicator()
        : error != null
        ? Text('Error: $error')
        : Text('Data: $data');
  }
}
```

## Problems with this approach

- **Mutually exclusive states aren't enforced**: Nothing prevents `isLoading = true` and `error != null` simultaneously
- **Repetitive boilerplate**: This pattern is copy-pasted across dozens of widgets
- **Error-prone**: Easy to forget updating one of the three fields during state transitions
- **Not exhaustive**: The compiler can't verify you've handled all possible state combinations

## The Solution: AsyncOperationMixin and StreamOperationMixin

This package transforms the above into:

```dart
import 'package:flutter_operations/flutter_operations.dart';

class _MyWidgetState extends State<MyWidget>
    with AsyncOperationMixin<MyData, MyWidget> {

  @override
  Future<MyData> fetch() => repository.fetchData();

  @override
  Widget build(BuildContext context) {
    return switch (operation) {
      LoadingOperation(data: null) => const CircularProgressIndicator(),
      LoadingOperation(:var data?) =>
          Column(
            children: [
              Expanded(child: DataWidget(data)),
              const LinearProgressIndicator(),
            ],
          ),
      SuccessOperation(:var data) => DataWidget(data),
      ErrorOperation(:var message, data: null) =>
          Column(
            children: [
              Text('Error: $message'),
              ElevatedButton(onPressed: reload, child: Text('Retry')),
            ],
          ),
      ErrorOperation(:var message, :var data?) =>
          Column(
            children: [
              DataWidget(data),
              ErrorBanner(message),
            ],
          ),
    };
  }
}
```

### Benefits of this approach

- **Type-safe**: Illegal states are impossible to represent.
- **Exhaustive**: The compiler forces you to handle every possible state combination.
- **Cached data support**: Show stale data during refreshes for better UX.
- **Minimal boilerplate**: Write `fetch()` once, get full state management.
- **Race condition protection**: Built-in generation tracking prevents outdated results from mixing with new states.

## Features

- **Two specialized mixins**:
    - `AsyncOperationMixin`: For one-time operations (API calls, database queries).
    - `StreamOperationMixin`: For continuous streams (real-time updates, WebSocket connections).
- **Sealed class states** with exhaustive pattern matching using `OperationState<T>`.
- **Two distinct loading patterns**:
    - **Autoloading** (default): `loadOnInit = true` → starts with `LoadingOperation`.
    - **Manual loading**: `loadOnInit = false` → starts with `IdleOperation`.
- **Optional idle state**: `IdleOperation` only exists when you need manual loading control.
- **Convenience getters**: Check states easily with `isLoading`, `isIdle`, `isSuccess`, `isError`, etc.
- **Automatic lifecycle management** with proper cleanup and mounted checks.
- **Flexible UI updates** - Choose between `ValueListenableBuilder` or global widget rebuilds.

As stated in
the [original article](https://medium.com/@saadoardati/exhaustive-pattern-matching-for-exhausted-flutter-developers-cd6837459862):

> "AsyncOperationMixin is not aiming to be your next global state management solution... Instead, it's a pragmatic,
> lightweight utility designed for a very specific and common scenario: managing the lifecycle of asynchronous
> operations that are tightly scoped to a single widget."

## Usage

### AsyncOperationMixin - One-time Operations

Perfect for screens that load data once with optional refresh capabilities. **Two patterns available:**

#### Auto-Loading Pattern (Default)

Most common use case - data loads immediately when the widget initializes:

```dart
import 'package:flutter_operations/flutter_operations.dart';

class PostsPageState extends State<PostsPage>
    with AsyncOperationMixin<List<Post>, PostsPage> {
  // loadOnInit defaults to true

  @override
  Future<List<Post>> fetch() async {
    final response = await http.get(Uri.parse('https://api.example.com/posts'));
    if (response.statusCode != 200) {
      throw Exception('Failed to load posts: ${response.statusCode}');
    }
    return Post.listFromJson(response.body);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Posts')),
      body: switch (operation) {
        LoadingOperation(data: null) => const Center(child: CircularProgressIndicator()),
        ErrorOperation(:var message, data: null) =>
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message ?? 'An error occurred'),
                  ElevatedButton(onPressed: reload, child: const Text('Retry')),
                ],
              ),
            ),
        // Data is guaranteed to be available in all of these expressions.
        LoadingOperation(:var data?) ||
        ErrorOperation(:var data?) ||
        SuccessOperation(:var data) =>
            RefreshIndicator(
              onRefresh: reload,
              child: ListView.builder(
                itemCount: data.length,
                itemBuilder: (context, index) => PostTile(data[index]),
              ),
            ),
      // No IdleOperation - starts loading immediately
      },
    );
  }
}
```

#### Manual Loading Pattern

For search screens, user-triggered actions, or widgets that should wait for user action:

```dart
class SearchPageState extends State<SearchPage>
    with AsyncOperationMixin<List<Post>, SearchPage> {
  @override
  bool get loadOnInit => false; // Start idle, wait for user action

  String _query = '';

  @override
  Future<List<Post>> fetch() => api.searchPosts(_query);

  void _onSearch(String query) {
    _query = query;
    load(); // Manually trigger loading
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: switch (operation) {
      // IdleOperation is relevant here
        IdleOperation() => SearchPrompt(onSearch: _onSearch),
        LoadingOperation() => const Center(child: CircularProgressIndicator()),
        SuccessOperation(:var data) => SearchResults(data, onNewSearch: _onSearch),
        ErrorOperation(:var message) => ErrorView(message, onRetry: () => load()),
      },
    );
  }
}
```

### Using Convenience Getters

The package provides convenient getters for checking states without pattern matching. In practical scenarios, you will
find these useful instead of having a dozen switch expressions in your widget build methods for simple checks.
Switch expressions can be overkill for some cases as illustrated below.

```dart
@override
Widget build(BuildContext context) {
  return ElevatedButton(
    onPressed: operation.isNotLoading ? load : null,
    child: Text(operation.isLoading ? 'Loading...' : 'Load Data'),
  );
}
```

```dart
@override
Widget build(BuildContext context) {
  if (operation.isLoading) {
    return const CircularProgressIndicator();
  }

  if (operation.isError) {
    return ErrorWidget('Something went wrong');
  }

  if (operation.isSuccess || operation.hasData) {
    return DataWidget(operation.data);
  }

  if (operation.isIdle) {
    return const Text('Ready to load');
  }

  return const SizedBox(); // Fallback
}
```

Available convenience getters:

- `isLoading` / `isNotLoading` - true for active loading operations.
- `isIdle` / `isNotIdle` - **only relevant when `loadOnInit = false`**.
- `isSuccess` / `isNotSuccess` - true for successful operations.
- `isError` / `isNotError` - true for failed operations.
- `hasData` / `hasNoData` - true when cached or fresh data is available.

### StreamOperationMixin - Continuous Data Streams

Ideal for real-time data that updates continuously:

```dart
import 'package:flutter_operations/flutter_operations.dart';

class ChatPageState extends State<ChatPage>
    with StreamOperationMixin<List<Message>, ChatPage> {

  @override
  Stream<List<Message>> stream() =>
      FirebaseFirestore.instance
          .collection('messages')
          .snapshots()
          .map((snapshot) =>
          snapshot.docs
              .map((doc) => Message.fromJson(doc.data()))
              .toList());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder(
        valueListenable: operationNotifier,
        builder: (context, operation, _) =>
        switch (operation) {
          IdleOperation() => const Text('Ready to connect'),
          LoadingOperation() => const CircularProgressIndicator(),
          ErrorOperation(:var message) => ErrorWidget(message: message),
          SuccessOperation(:var data) => MessagesList(messages: data),
        },
      ),
    );
  }
}
```

## Advanced Usage

### Handling Empty Success States

For operations that may complete successfully but return no data:

```dart
void fn() {
  if (operation is SuccessOperation<List<Item>> && operation.empty) {
    return const Text('No items found');
  }

  // Alternatively, use the getters.
  if (operation.isSuccess && operation.hasNoData) {
    return const Text('No items found');
  }

  // Pattern matching with empty check
  switch (operation) {
    SuccessOperation(empty: true) => const Text('No data available'),
    SuccessOperation(:var data) => DataWidget(data),
  // ... other cases
  }
}
```

### Managing Idle States

Use `setIdle()` to put operations in a ready-but-not-loading state:

```dart
class MyState extends State<MyWidget> with AsyncOperationMixin<Data, MyWidget> {
  @override
  bool get loadOnInit => false; // Start in idle state

  @override
  Future<Data> fetch() => repository.getData();

  @override
  void onIdle() {
    // Called when transitioning to idle state
    print('Operation is now idle');
  }

  void resetToIdle() {
    setIdle(cached: true); // Keep existing data if any
  }
}
```

### Choosing Update Strategies

**Option 1: ValueListenableBuilder (Recommended)**

```dart
@override
Widget build(BuildContext context) {
  return ValueListenableBuilder(
    valueListenable: operationNotifier,
    builder: (context, operation, _) =>
    switch (operation) {
      IdleOperation(data: null) => const Text('Ready to load'),
      LoadingOperation(data: null) => const CircularProgressIndicator(),
      LoadingOperation(:var data?) =>
          Column(
            children: [
              DataWidget(data),
              const LinearProgressIndicator(),
            ],
          ),
      SuccessOperation(:var data) => DataWidget(data),
      ErrorOperation(:var message, data: null) => ErrorWidget(message),
      ErrorOperation(:var message, :var data?) =>
          Column(
            children: [
              DataWidget(data),
              ErrorBanner(message)
            ],
          ),
      IdleOperation(:var data?) => DataWidget(data),
    },
  );
}
```

**Option 2: Global Refresh (Simple)**

```dart
class MyState extends State<MyWidget> with AsyncOperationMixin<MyData, MyWidget> {
  @override
  bool get globalRefresh => true;

  @override
  Future<MyData> fetch() => repository.fetchData();

  @override
  Widget build(BuildContext context) {
    return switch (operation) {
      IdleOperation(data: null) => const Text('Ready to load'),
      LoadingOperation(data: null) => const CircularProgressIndicator(),
      LoadingOperation(:var data?) =>
          Column(
            children: [
              DataWidget(data),
              const LinearProgressIndicator(),
            ],
          ),
      SuccessOperation(:var data) => DataWidget(data),
      ErrorOperation(:var message, data: null) => ErrorWidget(message),
      ErrorOperation(:var message, :var data?) =>
          Column(
            children: [
              DataWidget(data),
              ErrorBanner(message),
            ],
          ),
      IdleOperation(:var data?) => DataWidget(data),
    };
  }
}
```

### Data Handling

```dart
class MyState extends State<MyWidget>
    with AsyncOperationMixin<MyData, MyWidget> {

  @override
  String errorMessage(Object exception, StackTrace stackTrace) {
    if (exception is NetworkException) {
      return 'Network connection failed. Please check your internet.';
    }
    return 'An unexpected error occurred. Please try again.';
  }

  @override
  void onError(Object exception, StackTrace stackTrace, {String? message}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message ?? errorMessage(exception, stackTrace))),
    );
  }

  @override
  void onSuccess(MyData data) {
    // Handle successful data retrieval
    Analytics.trackEvent('data_loaded', {'data_length': data.length});
  }

  @override
  void onLoading() {
    Logger.log('Loading data for MyWidget');
  }

  @override
  void onIdle() {
    Logger.log('MyWidget is now idle');
  }
}
```

## The Four Operation States

The package defines states using sealed classes, with `IdleOperation` being **optional** and only relevant for manual
loading scenarios:

### Core States (Always Present)

### `LoadingOperation<T>`

- Represents an ongoing operation.
- Can optionally carry cached data from previous successful operations.
- This is what you'll see in auto-loading widgets (`loadOnInit = true`).

### `SuccessOperation<T>`

- Represents a completed operation with data.
- Data is guaranteed to be available and type-safe.
- Supports empty success states with `SuccessOperation.empty()`.

### `ErrorOperation<T>`

- Represents a failed operation with error details.
- Can optionally retain cached data for graceful degradation.
- Includes message, exception, and stack trace information.

### Optional State (Manual Loading Only)

### `IdleOperation<T>`

- **Only exists when `loadOnInit = false`** or when explicitly set via `setIdle()`.
- Can optionally carry cached data from previous operations.
- Extends `LoadingOperation` but with `isIdle = true` and `isLoading = false`.
- **Not required in pattern matching** unless your widget uses manual loading.

## Two Distinct Use Cases

This design elegantly handles two common scenarios:

### 1. Auto-Loading Widgets (Default Behavior)

```dart
class _PostsPageState extends State<PostsPage>
    with AsyncOperationMixin<List<Post>, PostsPage> {
  // loadOnInit defaults to true

  @override
  Future<List<Post>> fetch() => api.getPosts();

  @override
  Widget build(BuildContext context) {
    // No IdleOperation needed - starts loading immediately
    return switch (operation) {
      LoadingOperation(data: null) => const CircularProgressIndicator(),
      LoadingOperation(:var data?) => RefreshableList(data),
      SuccessOperation(:var data) => PostsList(data),
      ErrorOperation(:var message) => ErrorWidget(message),
    };
  }
}
```

### 2. Manual Loading Widgets

```dart
class _SearchPageState extends State<SearchPage>
    with AsyncOperationMixin<List<Result>, SearchPage> {
  @override
  bool get loadOnInit => false; // Start in idle state

  @override
  Future<List<Result>> fetch() => api.search(query);

  @override
  Widget build(BuildContext context) {
    // Now IdleOperation is relevant
    return switch (operation) {
      IdleOperation() => SearchPrompt(onSearch: load),
      LoadingOperation() => const CircularProgressIndicator(),
      SuccessOperation(:var data) => ResultsList(data),
      ErrorOperation(:var message) => ErrorWidget(message),
    };
  }
}
```

## Pattern Matching Examples

The power comes from exhaustive pattern matching.
**IdleOperation is optional** - include it only when your widget needs manual loading control:

```dart
@override
Widget build(BuildContext context) {
  // Auto-loading widget - no IdleOperation needed
  return switch (operation) {
    LoadingOperation(data: null) => const LoadingWidget(),
    LoadingOperation(:var data?) =>
        Column(
          children: [
            DataDisplay(data),
            const LinearProgressIndicator(),
          ],
        ),
    SuccessOperation(:var data) => DataDisplay(data),
    ErrorOperation(:var message, data: null) => ErrorWidget(message),
    ErrorOperation(:var message, :var data?) =>
        Column(
          children: [
            DataDisplay(data),
            ErrorBanner(message),
          ],
        ),
  };
}

// Manual loading widget - IdleOperation included
@override
Widget build(BuildContext context) {
  return switch (operation) {
    IdleOperation(data: null) => const Text('Ready to start'),
    IdleOperation(:var data?) =>
        Column(
          children: [
            DataDisplay(data),
            ElevatedButton(onPressed: load, child: Text('Refresh')),
          ],
        ),
  // ... rest of the cases same as above
  };
}
```

## When to Use This Package

### Perfect for:

- **Simple data loading screens**: User profiles, settings pages, static content.
- **User-triggered operations**: Use manual loading pattern (`loadOnInit = false`).
- **One-off dialogs or bottom sheets**: That need to fetch some data.
- **Prototype development**: Where you need quick async state management.
- **Coexisting with larger solutions**: Use alongside complete state management solutions for lightweight isolated
  components.

### Consider alternatives when:

- **Multiple coordinated operations**: Need to manage several interdependent async calls.
- **Complex business logic**: Requires sophisticated state machines or business rules.
- **Already using a standardized solution**: Consistency across your app is more valuable than the benefits here.
- **Advanced features needed**: Sophisticated caching, offline support, complex data synchronization.

## Contributing

Contributions are welcome! This package emerged from real-world usage patterns and continues to evolve based on more
use cases are identified.

If you have ideas, improvements, or bug fixes, please open an issue or submit a pull request.


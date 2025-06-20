# Flutter Operations

[![Pub Version](https://img.shields.io/pub/v/flutter_operations.svg)](https://pub.dev/packages/flutter_operations)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> This package emerged
> from [Exhaustive Pattern Matching for Exhausted Flutter Developers](https://medium.com/@saadoardati/exhaustive-pattern-matching-for-exhausted-flutter-developers-cd6837459862),
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
- **Race condition protection**: Built-in generation tracking prevents outdated results,

## Features

- **Two specialized mixins**:
    - `AsyncOperationMixin`: For one-time operations (API calls, database queries).
    - `StreamOperationMixin`: For continuous streams (real-time updates, WebSocket connections).
- **Sealed class states** with exhaustive pattern matching using `OperationState<T>`.
- **Automatic lifecycle management** with proper cleanup and mounted checks.
- **Flexible UI updates** - Choose between `ValueListenableBuilder` or global widget rebuilds.

As stated in the [original article](https://medium.com/@saadoardati/exhaustive-pattern-matching-for-exhausted-flutter-developers-cd6837459862):

> "AsyncOperationMixin is not aiming to be your next global state management solution... Instead, it's a pragmatic,
> lightweight utility designed for a very specific and common scenario: managing the lifecycle of asynchronous
> operations that are tightly scoped to a single widget."

## Usage

### AsyncOperationMixin - One-time Operations

Perfect for screens that load data once with optional refresh capabilities:

```dart
import 'package:flutter_operations/flutter_operations.dart';

class PostsPageState extends State<PostsPage>
    with AsyncOperationMixin<List<Post>, PostsPage> {

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
      },
    );
  }
}
```

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

### Choosing Update Strategies

**Option 1: ValueListenableBuilder (Recommended)**

```dart
@override
Widget build(BuildContext context) {
  return ValueListenableBuilder(
    valueListenable: operationNotifier,
    builder: (context, operation, _) =>
      switch (operation) {
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
    Toast.show(
      message ?? errorMessage(exception, stackTrace),
      duration: Duration(seconds: 3),
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message ?? errorMessage(exception, stackTrace))),
    );
  }
  
  @override
  void onData(MyData data) {
    // Handle successful data retrieval, e.g., logging or analytics, showing a toast, showing a dialog, etc...
    Analytics.trackEvent('data_loaded', {'data_length': data.length});
  }
  
  @override
  void onLoading() {
    Logger.log('Loading data for MyWidget');
  }
}
```

## The Three Operation States

The package defines three mutually exclusive states using sealed classes:

### `LoadingOperation<T>`

- Represents an ongoing operation.
- Can optionally carry cached data from previous successful operations.

### `SuccessOperation<T>`

- Represents a completed operation with non-null data.
- Data is guaranteed to be available and type-safe.

### `ErrorOperation<T>`

- Represents a failed operation with error details.
- Can optionally retain cached data for graceful degradation.
- Includes message, exception, and stack trace information.

## Pattern Matching Examples

The power comes from exhaustive pattern matching:

```dart
return switch (operation) {
  // Initial loading - no previous data
  LoadingOperation(data: null) => const LoadingWidget(),
  
  // Background refresh - show stale data with loading indicator
  LoadingOperation(:var data?) => Column(
    children: [
        DataDisplay(data),
        const LinearProgressIndicator(),
      ],
    ),
  
  // Success, guaranteed non-null data
  SuccessOperation(:var data) => DataDisplay(data),
  
  // Error with no fallback data
  ErrorOperation(:var message, data: null) => ErrorWidget(message),
  
  // Error with cached data, show data with error indication
  ErrorOperation(:var message, :var data?) => 
    Column(
      children: [
        DataDisplay(data),
        ErrorBanner(message),
      ],
    ),
};
```

## When to Use This Package

### Perfect for:

- **Simple data loading screens**: User profiles, settings pages, static content.
- **One-off dialogs or bottom sheets**: That need to fetch some easy data.
- **Prototype development**: Where you need quick async state management.
- **Coexisting with larger solutions**: Use alongside real and complete state management solutions for light isolated components.

### Consider alternatives when:

- **Multiple coordinated operations**: Need to manage several interdependent async calls.
- **Complex business logic**: Requires sophisticated state machines or business rules.
- **Already using a standardized solution**: Consistency is valuable.
- **Advanced features needed**: Sophisticated caching, offline support, complex data synchronization.

## Contributing

Contributions are welcome! This package emerged from real-world usage patterns and continues to evolve based on more
use cases are identified.

If you have ideas, improvements, or bug fixes, please open an issue or submit a pull request.


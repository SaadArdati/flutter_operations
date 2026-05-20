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

### Handling "Successful but No Data"

Pick the type parameter that matches what the operation actually models. There is no separate empty-success state. Two patterns cover the common cases:

**1. Fire-and-forget mutations (delete, logout, PIN confirm):** parameterize with `void`.

```dart
class DeleteCubit extends Cubit<OperationState<void>> {
  // Inside the Cubit, `super()` and `emit()` both infer the operation's
  // type argument from `OperationState<void>` — no need to repeat `<void>`.
  DeleteCubit() : super(const IdleOperation());

  Future<void> deleteItem(String id) async {
    emit(const LoadingOperation());
    try {
      await api.delete(id);
      emit(const SuccessOperation(data: null));
    } catch (e, stack) {
      emit(ErrorOperation(message: e.toString(), exception: e, stackTrace: stack));
    }
  }
}

// In the widget:
switch (state) {
  LoadingOperation() => const CircularProgressIndicator(),
  SuccessOperation() => const Text('Deleted'),
  ErrorOperation(:var message) => Text('Failed: $message'),
  // ...
}
```

> The `data:` argument is still required at the constructor; pass `null`. The `data` field is never read in switch arms because `void` is unreadable. The mixins (`AsyncOperationMixin<void, W>`) call `setSuccess` internally with the void result; you do not need to construct `SuccessOperation<void>` by hand if you use the mixin.

**2. Legitimately optional success values:** parameterize with `T?`.

```dart
class CurrentUserCubit extends Cubit<OperationState<User?>> { ... }

switch (state) {
  SuccessOperation(data: null) => const Text('No user signed in'),
  SuccessOperation(:var data) => UserView(data),
  // ...
}

// Or non-pattern style:
if (state.isSuccess && state.hasNoData) {
  return const Text('No user signed in');
}
```

### Using Success Messages

The `SuccessOperation` includes an optional `message` field for server confirmation messages or other success-related
information. Call `attachMessage(String)` inside `fetch()` before returning data, and the mixin will populate
`SuccessOperation.message` automatically:

```dart
class MyState extends State<MyWidget>
    with AsyncOperationMixin<MyData, MyWidget> {

  @override
  Future<MyData> fetch() async {
    final response = await http.get(Uri.parse('https://api.example.com/data'));
    final json = jsonDecode(response.body);

    final data = MyData.fromJson(json['data']);
    final message = json['message'] as String?;
    if (message != null) attachMessage(message);
    return data;
  }

  @override
  Widget build(BuildContext context) {
    return switch (operation) {
      // Access message in pattern matching
      SuccessOperation(:var data, :var message?) => Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.green.shade50,
            child: Text(message),
          ),
          DataWidget(data),
        ],
      ),
      // ... other cases
    };
  }
}
```

You can also access the message directly:

```dart
if (operation case SuccessOperation(:final message?)) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
```

For streams, call `attachMessage` inside `stream()` before yielding each value:

```dart
@override
Stream<Message> stream() async* {
  await for (final raw in chatService.messagesStream()) {
    if (raw.serverMessage != null) attachMessage(raw.serverMessage!);
    yield raw.data;
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

- Represents a completed operation. The `data` getter returns exactly `T`: non-null when `T` is non-nullable, nullable when `T` is nullable. Never throws.
- For "successful but no data" scenarios, parameterize with `void` (fire-and-forget) or a nullable type like `User?` (legitimately optional payload).
- Includes an optional `message` field for success-related information (e.g., server confirmation messages separate from
  the main data payload).

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

The four sealed states unlock several distinct match styles. Pick the one that matches how much detail your UI cares about. Every pattern below is covered by a corresponding test in `test/unit/operation_state_test.dart` under "Pattern matching variants".

### 1. Full fan-out (most explicit)

When every state combination deserves its own widget. **IdleOperation is optional**: include it only when your widget supports manual loading.

```dart
@override
Widget build(BuildContext context) {
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
```

### 2. Data-presence shortcut (skip the per-state ceremony)

When the UI only cares about "is there data to render?", match on the base `OperationState` and let `(:final data?)` collapse Loading-with-cache, Success, and Error-with-cache into a single arm.

```dart
return switch (operation) {
  OperationState(:final data?) => DataDisplay(data),
  OperationState() => const LoadingWidget(),
};
```

Two arms, exhaustive, no nested handling. Trade-off: you lose the ability to overlay a spinner or an error banner over the cached view. Reach for this on read-only screens where Loading and Success are visually identical once data exists.

### 3. OR pattern for shared rendering across state types

When the data-bearing arms share rendering but you still want to fall through to a spinner for the empty cases. The `||` (or) pattern lets you spell out exactly which states carry data without giving up specificity.

```dart
return switch (operation) {
  LoadingOperation(:var data?) ||
  SuccessOperation(:var data) ||
  ErrorOperation(:var data?) =>
      RefreshIndicator(onRefresh: reload, child: DataList(data)),
  _ => const CircularProgressIndicator(),
};
```

Useful when you want the data view to remain visible during reloads and after errors, without copy-pasting the renderer.

### 4. Error-first, then catch-all (errors win over cache)

A common UX rule: an error banner should always be authoritative, even if cached data is present. Match `ErrorOperation` first; everything else flows through a generic data-presence arm.

```dart
return switch (operation) {
  ErrorOperation(:var message) => ErrorBanner(message),
  OperationState(:final data?) => DataDisplay(data),
  _ => const CircularProgressIndicator(),
};
```

Order matters: Dart matches top to bottom, so the error arm is preferred even when `ErrorOperation` also carries cached `data`.

### 5. Guards with `when` (branch on payload content)

Use guards to branch on properties of the data without an extra `if` inside the body.

```dart
return switch (operation) {
  SuccessOperation(:var data) when data.isEmpty => const EmptyStateWidget(),
  SuccessOperation(:var data) => ListView.builder(itemCount: data.length, ...),
  LoadingOperation() => const CircularProgressIndicator(),
  ErrorOperation(:var message) => ErrorWidget(message),
};
```

### 6. Collapse Idle into Loading (when the distinction does not matter)

`IdleOperation` extends `LoadingOperation`, so matching `LoadingOperation` alone catches both. Skip the idle arm when the widget renders them identically.

```dart
return switch (operation) {
  LoadingOperation(data: null) => const CircularProgressIndicator(),
  LoadingOperation(:var data?) => DataDisplayWithSpinner(data),
  SuccessOperation(:var data) => DataDisplay(data),
  ErrorOperation(:var message, :var data?) => ErrorOverlay(data, message),
  ErrorOperation(:var message) => ErrorWidget(message),
};
```

If you do want them separate, match `IdleOperation` *before* `LoadingOperation`. Order matters: `LoadingOperation` would otherwise subsume `IdleOperation`.

```dart
return switch (operation) {
  IdleOperation(data: null) => const Text('Tap to start'),
  IdleOperation(:var data?) => ResultPreview(data),
  LoadingOperation() => const CircularProgressIndicator(),
  // ...
};
```

### 7. Imperative shortcuts via getters (no switch at all)

Pattern matching is not mandatory. For simple UI gates (button disabled while loading, conditional spinner overlay, etc.), boolean getters and `dataOrNull` are often clearer than a full switch.

```dart
ElevatedButton(
  onPressed: operation.isLoading ? null : reload,
  child: operation.isLoading
      ? const CircularProgressIndicator()
      : const Text('Refresh'),
);

// Or read the data nullably regardless of state:
final cached = operation.dataOrNull;
if (cached != null) return DataDisplay(cached);
return const CircularProgressIndicator();
```

Mix and match: use patterns for the main render branch, getters for incidental UI hints (snackbars, button states, focus management).

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


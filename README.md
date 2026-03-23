# Flutter Operations

[![Pub Version](https://img.shields.io/pub/v/flutter_operations.svg)](https://pub.dev/packages/flutter_operations)
[![Pub Points](https://img.shields.io/pub/points/flutter_operations)](https://pub.dev/packages/flutter_operations/score)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Type-safe async state management for Flutter using sealed classes and exhaustive pattern matching. No more juggling
`isLoading`, `error`, and `data` fields.

> Emerged
> from [Exhaustive Pattern Matching for Exhausted Flutter Developers](https://medium.com/@saadoardati/exhaustive-pattern-matching-for-exhausted-flutter-developers-cd6837459862).

## Features

- **Sealed class states** with compile-time exhaustive pattern matching
- **Works beautifully with BLoC/Cubits** -- use `OperationState<T>` as your Cubit state type for zero-boilerplate async
  Cubits
- **Two specialized mixins**: `AsyncOperationMixin` (one-shot) and `StreamOperationMixin` (continuous) for
  StatefulWidget use
- **Cached data preservation** during loading and error states for seamless UX
- **Value and Void success types**: `ValueSuccessOperation<T>` guarantees non-null data; `VoidSuccessOperation` handles
  fire-and-forget
- **Idle state** for manual loading control (`loadOnInit: false` / `listenOnInit: false`)
- **Convenience getters**: `isLoading`, `isSuccess`, `isError`, `isIdle`, `hasData`, and negated forms
- **Automatic lifecycle management** with mounted checks and generation tracking

## Getting Started

```yaml
dependencies:
  flutter_operations: ^2.0.0
```

```dart
import 'package:flutter_operations/flutter_operations.dart';
```

## The Problem

```dart
// The pattern every Flutter developer repeats:
bool isLoading = true;
String? error;
Object? data;
// Nothing enforces mutual exclusivity. Bugs happen.
```

## The Solution

```dart
class _MyPageState extends State<MyPage>
    with AsyncOperationMixin<User, MyPage> {

  @override
  Future<User> fetch() => api.getUser();

  @override
  Widget build(BuildContext context) {
    return switch (operation) {
      LoadingOperation()              => const CircularProgressIndicator(),
      ValueSuccessOperation(:var data) => UserCard(data),
      VoidSuccessOperation()           => const Text('Done'),
      ErrorOperation(:var message)     => Text(message ?? 'Error'),
    };
  }
}
```

The compiler forces you to handle every state. Illegal states are unrepresentable.

## Using with BLoC / Cubits

`OperationState<T>` is a standalone sealed class -- it works as a Cubit state type with zero extra setup. No custom
state files needed:

```dart
class UserCubit extends Cubit<OperationState<User>> {
  UserCubit(this._repo) : super(const LoadingOperation());

  final UserRepository _repo;

  Future<void> loadUser() async {
    emit(LoadingOperation(data: state.data)); // preserve cached data
    try {
      final user = await _repo.getUser();
      emit(SuccessOperation(data: user));
    } catch (e) {
      emit(ErrorOperation(message: e.toString(), data: state.data));
    }
  }

  Future<void> deleteUser() async {
    emit(LoadingOperation(data: state.data));
    try {
      await _repo.deleteUser();
      emit(SuccessOperation.empty(message: 'User deleted'));
    } catch (e) {
      emit(ErrorOperation(message: e.toString(), data: state.data));
    }
  }
}
```

Then in your widget, the same exhaustive switch expressions apply:

```dart
BlocBuilder<UserCubit, OperationState<User>>
(
builder: (context, state) => switch (state) {
LoadingOperation(data: null) => const CircularProgressIndicator(),
LoadingOperation(:var data?) => UserCard(data, refreshing: true),
VoidSuccessOperation(:var message) => Text(message ?? 'Done'),
ValueSuccessOperation(:var data) => UserCard(data),
ErrorOperation(:var message) => Text(message ?? 'Error'),
},
)
```

This gives you BLoC's architecture (testability, separation of concerns, reusability across widgets) with
`OperationState`'s exhaustive pattern matching and cached data support. The two complement each other perfectly -- BLoC
manages *where* state lives, `OperationState` manages *what* that state looks like.

The mixins (`AsyncOperationMixin` / `StreamOperationMixin`) are the lightweight alternative for cases where a full Cubit
is overkill -- dialogs, bottom sheets, one-off screens. Use whichever fits.

## State Hierarchy

```
OperationState<T>  (sealed)
 +-- LoadingOperation<T>  (base) ---- optionally carries cached data
 |    +-- IdleOperation<T>  (final) - ready but not loading
 +-- SuccessOperation<T>  (sealed) -- catch-all, data is T?
 |    +-- ValueSuccessOperation<T>  (final) - data is T (non-null)
 |    +-- VoidSuccessOperation<T>   (final) - no data
 +-- ErrorOperation<T>  (final) ----- message, exception, stackTrace, cached data
```

**Opt-in specificity** -- match the parent to cover all children, or match children individually for type-safe access:

```dart
// Broad: SuccessOperation covers both Value and Void (data is T?)
case SuccessOperation(:var data?) => DataView(data),
case SuccessOperation() => const Text('No data'),

// Specific: compiler-guaranteed types
case ValueSuccessOperation(:var data) => DataView(data), // data is T
case VoidSuccessOperation(:var message) => Text(message ?? '
Done
'
)
,
```

Same pattern applies to `LoadingOperation` / `IdleOperation`.

## Usage

### Auto-Loading (Default)

Data loads immediately when the widget initializes:

```dart
class _PostsPageState extends State<PostsPage>
    with AsyncOperationMixin<List<Post>, PostsPage> {

  @override
  Future<List<Post>> fetch() => api.getPosts();

  @override
  Widget build(BuildContext context) {
    return switch (operation) {
      LoadingOperation(data: null)     => const CircularProgressIndicator(),
      LoadingOperation(:var data?)     => Stack(children: [PostsList(data), const LinearProgressIndicator()]),
      ValueSuccessOperation(:var data) => PostsList(data),
      VoidSuccessOperation()           => const Text('No posts'),
      ErrorOperation(:var message, data: null)  => ErrorView(message ?? 'Failed'),
      ErrorOperation(:var message, :var data?)  => Column(children: [ErrorBanner(message), PostsList(data)]),
    };
  }
}
```

### Manual Loading (`loadOnInit: false`)

For search, user-triggered actions, or widgets that wait for input:

```dart
class _SearchPageState extends State<SearchPage>
    with AsyncOperationMixin<List<Result>, SearchPage> {
  @override
  bool get loadOnInit => false;

  String _query = '';

  @override
  Future<List<Result>> fetch() => api.search(_query);

  void _onSearch(String query) {
    _query = query;
    load();
  }

  @override
  Widget build(BuildContext context) {
    return switch (operation) {
      IdleOperation()                  => SearchPrompt(onSearch: _onSearch),
      LoadingOperation()               => const CircularProgressIndicator(),
      ValueSuccessOperation(:var data) => ResultsList(data),
      VoidSuccessOperation()           => const Text('No results'),
      ErrorOperation(:var message)     => ErrorView(message ?? 'Search failed'),
    };
  }
}
```

### Fire-and-Forget (`VoidSuccessOperation`)

For delete, logout, or actions that succeed without returning data:

```dart
class _DeletePageState extends State<DeletePage>
    with AsyncOperationMixin<void, DeletePage> {
  @override
  bool get loadOnInit => false;

  @override
  Future<void> fetch() => api.deleteItem(itemId);

  void _onDelete() {
    setLoading();
    fetch().then((_) {
      if (!mounted) return;
      setEmpty(message: 'Item deleted'); // emits VoidSuccessOperation
    }).catchError((e, st) {
      if (!mounted) return;
      setError(e, st);
    });
  }

  @override
  Widget build(BuildContext context) {
    return switch (operation) {
      IdleOperation()                       => ElevatedButton(onPressed: _onDelete, child: const Text('Delete')),
      LoadingOperation()                    => const CircularProgressIndicator(),
      VoidSuccessOperation(:var message)    => Text(message ?? 'Deleted'),
      ValueSuccessOperation()               => const SizedBox.shrink(), // exhaustiveness
      ErrorOperation(:var message)          => Text(message ?? 'Failed'),
    };
  }
}
```

### Streams (`StreamOperationMixin`)

For continuous data that updates over time. Uses `stream()` or `streamWithMessage()` (override exactly one), and
`listen()` to (re-)subscribe:

```dart
class _ChatPageState extends State<ChatPage>
    with StreamOperationMixin<List<Message>, ChatPage> {

  @override
  Stream<List<Message>> stream() =>
      firestore.collection('messages').snapshots().map(/* ... */);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: operationNotifier,
      builder: (context, op, _) => switch (op) {
        LoadingOperation()               => const CircularProgressIndicator(),
        ValueSuccessOperation(:var data) => MessageList(data),
        VoidSuccessOperation()           => const Text('No messages'),
        ErrorOperation(:var message)     => Text(message ?? 'Connection lost'),
      },
    );
  }
}
```

Stream-specific APIs: `listenOnInit` (defaults to `true`), `listen()` to re-subscribe, `setData()` / `onData()` (the
stream equivalents of `setSuccess()` / `onSuccess()`), and `onDone()` for stream completion.

### Success Messages

Override `fetchWithMessage()` to return data alongside a server message:

```dart
@override
Future<(User, String?)> fetchWithMessage() async {
  final json = await api.getUserWithMeta();
  return (User.fromJson(json['data']), json['message'] as String?);
}

// In your switch:
ValueSuccessOperation(:var data, :var message) => Column(
  children: [
    if (message != null) SuccessBanner(message),
    UserCard(data),
  ],
),
```

### Convenience Getters

For UI decoration where a full switch is overkill:

```dart
ElevatedButton
(
onPressed: operation.isNotLoading ? load : null,
child: Text(operation.isLoading ? 'Loading...' :
'
Refresh
'
)
,
)
```

Available on all states: `isLoading` / `isNotLoading`, `isIdle` / `isNotIdle`, `isSuccess` / `isNotSuccess`, `isError` /
`isNotError`, `hasData` / `hasNoData`.

> **Note:** `isLoading` returns `false` for `IdleOperation` (idle is ready-but-not-loading). If you need to check for "
> any non-resolved state", use `isLoading || isIdle` or match `LoadingOperation()` in a switch (which covers both).

### Reloading and Cached Data

`load()` and `reload()` accept a `cached` parameter that controls whether previous data is preserved during the loading
state:

```dart
reload(); // default: cached = true, shows stale data during refresh

reload
(
cached
:
false
); // clears data, shows a fresh loading spinner
```

The same `cached` parameter is available on `setLoading()`, `setError()`, and `setIdle()`. This is key for graceful
UX -- users see stale content instead of a blank screen during background refreshes.

> For `StreamOperationMixin`, the equivalent is `listen(cached: ...)` to re-subscribe to the stream.

### Update Strategies

**ValueListenableBuilder** (recommended, scoped rebuilds):

```dart
ValueListenableBuilder(
  valueListenable: operationNotifier,
  builder: (context, op, _) => switch (op) { /* ... */ },
)
```

**Global refresh** (simple, entire widget rebuilds):

```dart
@override
bool get globalRefresh => true;

// Then use `operation` directly in build()
```

### Lifecycle Callbacks

```dart
@override
void onSuccess(User data) => analytics.track('user_loaded');
// StreamOperationMixin uses onData(T value) instead of onSuccess.

@override
void onEmpty(String? message) => showSnackBar(message ?? 'Done');

@override
void onError(Object e, StackTrace st, {String? message}) =>
    logger.error(message ?? 'Failed', error: e);

@override
void onLoading() => logger.info('Loading...');

@override
void onIdle() => logger.info('Idle');

// StreamOperationMixin also provides onDone() for stream completion.

@override
String errorMessage(Object exception, StackTrace stackTrace) {
  if (exception is NetworkException) return 'Check your connection.';
  return 'Something went wrong.';
}
```

## When to Use This Package

`OperationState<T>` is a **general-purpose async state type**. It shines in two complementary roles:

**As a Cubit/BLoC state type** -- use `OperationState<T>` as the state for any Cubit that manages a single async
operation. You get exhaustive pattern matching, cached data support, and Value/Void success types without writing custom
state classes. This is the recommended approach for production apps.

**As a StatefulWidget mixin** -- use `AsyncOperationMixin` or `StreamOperationMixin` when a full Cubit would be
overkill: dialogs, bottom sheets, settings pages, one-off screens, prototypes.

Both approaches use the same `OperationState<T>` sealed hierarchy, so you can start with a mixin and graduate to a Cubit
without rewriting your switch expressions.

## Migration from 1.x to 2.0

### SuccessOperation is now sealed with two subtypes

`SuccessOperation<T>` is now `sealed` with `ValueSuccessOperation<T>` and `VoidSuccessOperation<T>`.

**Construction is unchanged** -- redirecting factory constructors handle it:

```dart
SuccessOperation
(
data
:
x
) // creates ValueSuccessOperation (same as before)
SuccessOperation
.
empty
(
) // creates VoidSuccessOperation (same as before)
```

### `.data` on `SuccessOperation` now returns `T?`

Previously, `SuccessOperation.data` returned `T` and threw on empty. Now it returns `T?`. Use `ValueSuccessOperation`
for guaranteed `T`:

```dart
// Before:
case SuccessOperation(:var data) => Text(data.name), // data was T

// After -- two options:
case ValueSuccessOperation(:var data) => Text(data.name), // data is T
case SuccessOperation(:var data?) => Text(data.name),      // data is T via null-check pattern
```

### `dataOrNull` removed

The base `data` getter already returns `T?`. Replace `state.dataOrNull` with `state.data`.

### `empty` is now a computed getter

Still works: `if (success.empty)` returns `true` for `VoidSuccessOperation`. No longer a stored field.

### New: `setEmpty()` on mixins

For emitting `VoidSuccessOperation` from mixin code:

```dart
setEmpty
(
message
:
'
Item deleted
'
); // emits VoidSuccessOperation
```

### Switch exhaustiveness

If you match `ValueSuccessOperation` and `VoidSuccessOperation` individually (instead of `SuccessOperation` as a
catch-all), the compiler now enforces both are handled:

```dart
// This now requires BOTH cases:
case VoidSuccessOperation() => ...,
case ValueSuccessOperation() => ...
,

// Or use the catch-all:
case
SuccessOperation
(
)
=>
...
, // covers both
```

## Contributing

Contributions welcome! Open an issue or submit a pull request
at [GitHub](https://github.com/SaadArdati/flutter_operations).

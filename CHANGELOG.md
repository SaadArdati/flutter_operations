## 2.0.0

A focused redesign on two fronts: the success state's type-honesty (no more `SuccessOperation.empty()` runtime trap), and the override surface (single `fetch()` / `stream()` plus an optional `attachMessage(String)` channel). The dual-method pattern is gone; the `bool empty` flag is gone; the `StateError`-throwing `data` getter is gone.

### BREAKING CHANGES

#### Override surface

- **Removed `fetchWithMessage()` and `streamWithMessage()` overrides.** Replaced by a single required override per mixin (`fetch()` / `stream()`) plus an optional `attachMessage(String)` channel.
- **`fetch()` and `stream()` are now abstract.** Missing overrides surface as compile-time errors instead of runtime `StateError`s.
- **Removed `(T, String?)` record return shape** from override signatures. Optional success messages flow through `attachMessage(String)` instead.

#### Success state

- **Removed `SuccessOperation.empty()` constructor and `bool empty` field.** The dedicated "empty success" state added surface area to model what is already expressible via the type parameter (`<void>` for fire-and-forget, `<T?>` for legitimately optional payloads).
- **`SuccessOperation.data` no longer throws `StateError`.** The previous "empty" runtime trap is gone. `data` returns exactly `T`: non-null when `T` is non-nullable, nullable when `T` is nullable.

### New Features

- **`attachMessage(String)`** on both `AsyncOperationMixin` and `StreamOperationMixin`. Call from inside `fetch()` (async) or before each `yield` (stream `async*`) to attach an optional message to the resulting `SuccessOperation`. Internally backed by a per-call `Zone` cell, so concurrent fetches and re-listens are race-safe by construction.

### Bug Fixes

- **Stream mixin `mounted` guard on data callbacks.** Both `onData` paths in `StreamOperationMixin` now check `mounted` before calling `setData`. Previously, late stream emissions could write to a disposed `ValueNotifier` after the widget had unmounted.
- **`LoadingOperation.hashCode` now includes `runtimeType`.** Previously, `IdleOperation<T>(data: x)` and `LoadingOperation<T>(data: x)` shared a `hashCode` while being unequal under `==`, causing poor distribution in hash-based collections. The fix uses `Object.hash(runtimeType, data)`.

### Why these changes

**The success state.** `SuccessOperation` in 1.x carried a `bool empty` flag and a `StateError`-throwing `data` getter to support `SuccessOperation.empty()`. This forced the type system to lie: `SuccessOperation<User>.data` claimed non-null `User` while runtime could throw. The fix is to let `T` speak for itself: if the operation may have no value, the consumer says so via `<User?>` or `<void>`; otherwise `data` is guaranteed non-null with no runtime trap.

**The override surface.** The dual `fetch()` / `fetchWithMessage()` API required runtime validation ("exactly one must be overridden") and forced callers who wanted a message to wrap their result in a `(T, String?)` record. The new shape uses Dart's `Zone` to thread an optional message channel through `fetch()` without touching its return type. Calls to `attachMessage` from inside `fetch` (or before each `yield` inside `stream`) write to a per-call cell that the mixin reads when materializing the `SuccessOperation`. Concurrent fetches each get their own cell, so the race protection is structural.

### How `attachMessage` works

The mixins wrap each `load()` / `listen()` call in a `runZoned` block holding a per-call `MessageCell`. `attachMessage` reads `Zone.current` to find the cell. After fetch resolves (one-shot) or each emission arrives (stream), the mixin reads the cell synchronously and pairs the message with the value. The cell read happens before any await in the listener body, so async generator back-pressure pairs each yield with its own message.

```dart
class _UserState extends State<UserWidget>
    with AsyncOperationMixin<User, UserWidget> {
  @override
  Future<User> fetch() async {
    final response = await api.getUser();
    if (response.serverMessage != null) attachMessage(response.serverMessage!);
    return response.data;
  }
}
```

### Migration from 1.5.x

#### `SuccessOperation.empty()` is gone: pick the right type parameter

If the operation never produces a value (delete, logout, fire-and-forget), parameterize with `void`:

```dart
// Before (1.5.x):
class DeleteCubit extends Cubit<OperationState<DeleteResult>> {
  void run() {
    // ... do the delete ...
    emit(const SuccessOperation.empty());
  }
}

// After (2.0.0): the cubit's T was a lie; the operation is fire-and-forget.
class DeleteCubit extends Cubit<OperationState<void>> {
  void run() {
    // ... do the delete ...
    emit(const SuccessOperation(data: null));
  }
}
```

If the operation may legitimately produce no value (current user when signed out, search result), parameterize with `T?`:

```dart
// Before (1.5.x): "logged-out" expressed as an empty success of <User>
class CurrentUserCubit extends Cubit<OperationState<User>> {
  void signOut() => emit(const SuccessOperation.empty());
}

// After (2.0.0): the cubit's T is honestly nullable.
class CurrentUserCubit extends Cubit<OperationState<User?>> {
  void signOut() => emit(const SuccessOperation(data: null));
}
```

#### `state.empty` is gone: qualify with the success type

`state.empty` was on `SuccessOperation` and implied success. `state.hasNoData` is on the base `OperationState` and is also true for `LoadingOperation()` and `ErrorOperation()` without cached data, so a naive replacement changes branch semantics:

```dart
// Before (1.5.x):
if (state is SuccessOperation && state.empty) { ... }

// After (2.0.0): keep the SuccessOperation check explicit
if (state is SuccessOperation && state.hasNoData) { ... }
// or use a pattern:
if (state case SuccessOperation(data: null)) { ... }
```

#### Pattern matching equivalents

```dart
switch (state) {
  // Before:
  SuccessOperation(empty: true) => const Text('Done'),
  SuccessOperation(:var data) => DataView(data),

  // After (for OperationState<User?>):
  SuccessOperation(data: null) => const Text('Done'),
  SuccessOperation(:var data?) => DataView(data),

  // After (for OperationState<void>):
  SuccessOperation() => const Text('Done'),
}
```

#### `fetchWithMessage()` and `streamWithMessage()` are gone: use `attachMessage`

```dart
// Before (1.5.x):
@override
Future<(User, String?)> fetchWithMessage() async {
  final response = await api.getUser();
  return (response.data, response.message);
}

// After (2.0.0):
@override
Future<User> fetch() async {
  final response = await api.getUser();
  if (response.message != null) attachMessage(response.message!);
  return response.data;
}
```

Same shape for streams: drop the `streamWithMessage()` override and call `attachMessage(...)` before each `yield` inside `stream()` (which can be plain `Stream<T>` or `async*`).

---

## 1.5.0

### New Features

- **Promoted `dataOrNull` getter to `OperationState` base class** — Previously only available on `SuccessOperation`,
  `dataOrNull` is now accessible on all state types (`LoadingOperation`, `IdleOperation`, `ErrorOperation`,
  `SuccessOperation`). This allows safe nullable data access without pattern-matching first. For
  `SuccessOperation.empty()`
  states, it returns `null` instead of throwing like the `data` getter does.

### Improvements

- **Replaced `print()` with `developer.log()` in default `onError` handlers** — Both `AsyncOperationMixin` and
  `StreamOperationMixin` now use `dart:developer`'s `log()` for default error logging. This integrates with Flutter
  DevTools, provides structured metadata (error object, stack trace, category name), and is automatically filtered out
  in release builds. Zero new dependencies.
- **Fixed `analysis_options.yaml`** — Now correctly uses `package:flutter_lints/flutter.yaml` to match the
  `flutter_lints` dev dependency, enabling Flutter-specific lint rules.
- **Improved dual-override validation comments** — Added clarifying comments explaining why the `fetch()`/`stream()`
  validation call is side-effect-free in the happy path.
- **Added doc comment for nullable `T` edge case on `SuccessOperation`** — Documents the behavior when `T` itself is
  nullable (e.g., `SuccessOperation<String?>(data: null)`).

### Bug Fixes

- **Fixed `_NotImplementedException.toString` in `StreamOperationMixin`** — Was incorrectly displaying
  `AsyncOperationMixinException` instead of `StreamOperationMixinException`.
- **Made `idle` parameter functional in `StreamOperationMixin.setLoading`** — The parameter was previously accepted but
  never used. Now `setLoading(idle: true)` correctly produces an `IdleOperation` and invokes the `onIdle` callback.
- **Fixed `Product.examples()` in example app** — `Random().nextInt(3)` only selected from 3 of 9 categories. Now uses
  `random.nextInt(categories.length)` with a single `Random` instance.
- **Fixed timer leak in `AdvancedCustomHandlersExample`** — Added `dispose()` override to cancel `_retryTimer` and
  `_circuitBreakerTimer`, preventing callbacks firing on unmounted widgets.
- **Fixed `BasicStreamExample` builder** — Now uses the `value` parameter from `ValueListenableBuilder` instead of
  reading `operation` directly.

---

## 1.4.0

### BREAKING CHANGES

- **`SuccessOperation.empty()` no longer accepts a `data` parameter** - The constructor now always creates a truly empty
  state. Previously, passing `data` would create a non-empty state with `empty = false`, which was confusing.

### Bug Fixes

- **Fixed crash when comparing empty `SuccessOperation` states** - The `==` operator and `hashCode` now use the internal
  `_data` field instead of calling the throwing `data` getter. This fixes issues with Bloc/Cubit state comparison when
  emitting `SuccessOperation.empty()`.
- **Fixed `hasData`/`hasNoData` getters throwing on empty operations** - These now safely check the internal field.
- **Fixed `toString()` for empty operations** - No longer throws when converting empty states to string.

### New Features

- **Added `dataOrNull` getter to `SuccessOperation`** - Provides safe nullable access to data without throwing. Use this
  when you're unsure if the operation is empty, or in contexts where you want to handle both cases uniformly.

### Migration

If you were using `SuccessOperation.empty(data: someValue)`, this will no longer compile. This usage was semantically
incorrect - use `SuccessOperation(data: someValue)` instead for non-empty states.

```dart
// Before (incorrect usage that will no longer compile):
SuccessOperation.empty
(
data: myData) // ❌ Removed

// After (correct usage):
SuccessOperation(data: myData) // ✅ Use this for non-empty
SuccessOperation.
empty
(
) // ✅ Use this for truly empty
```

---

## 1.3.0

### BREAKING CHANGES

- **Removed `OperationResult<T>` class** - Replaced with Dart records `(T, String?)` for less cpu and memory churn.
- `fetchWithMessage()` now returns `FutureOr<(T, String?)>` instead of `FutureOr<OperationResult<T>>`.
- `streamWithMessage()` now returns `Stream<(T, String?)>` instead of `Stream<OperationResult<T>>`.

### Migration

If you're using `fetchWithMessage()` or `streamWithMessage()`, update your code:

**Before (1.2.0):**

```dart
@override
Future<OperationResult<User>> fetchWithMessage() async {
  final user = User.fromJson(json['data']);
  final message = json['message'] as String?;
  return OperationResult(user, message: message);
}
```

**After (1.3.0):**

```dart
@override
Future<(User, String?)> fetchWithMessage() async {
  final user = User.fromJson(json['data']);
  final message = json['message'] as String?;
  return (user, message);
}
```

**Before (1.2.0) - Streams:**

```dart
@override
Stream<OperationResult<Message>> streamWithMessage() {
  return messageStream.map((jsonMap) {
    final data = Message.fromJson(jsonMap['data']);
    final message = jsonMap['message'] as String?;
    return OperationResult(data, message: message);
  });
}
```

**After (1.3.0) - Streams:**

```dart
@override
Stream<(Message, String?)> streamWithMessage() {
  return messageStream.map((jsonMap) {
    final data = Message.fromJson(jsonMap['data']);
    final message = jsonMap['message'] as String?;
    return (data, message);
  });
}
```

The behavior remains the same - the only change is the API surface. All other functionality, including message handling
in `SuccessOperation`, works exactly as before.

## 1.2.0

### New

- Added `OperationResult<T>` class to hold data with optional success messages.
- Added `fetchWithMessage()` method to `AsyncOperationMixin` for returning data with messages.
- Added `streamWithMessage()` method to `StreamOperationMixin` for streams with messages.
- Added optional `message` field to `SuccessOperation<T>` for success-related information.
- Updated `setSuccess()` and `setData()` methods to accept optional `message` parameter.

### Changed

- `fetch()` and `fetchWithMessage()` are now both optional - exactly one must be overridden.
- `stream()` and `streamWithMessage()` are now both optional - exactly one must be overridden.
- Smart method detection: tries `*WithMessage()` first, falls back to standard method.
- Throws an error messages when neither or both methods are overridden.

### Usage

```dart
// Simple case - no message
@override
Future<User> fetch() async => api.getUser();

// With message - use fetchWithMessage()
@override
Future<OperationResult<User>> fetchWithMessage() async {
  // API returns a Map with 'data' and 'message' fields
  final response = await http.get(Uri.parse('https://api.example.com/user'));
  final json = jsonDecode(response.body);

  // Decode the data
  final user = User.fromJson(json['data'];

      // Extract the message from server response
      final message = json['message'] as String?;

      return OperationResult(user, message: message);
}
```

### Migration:

- Existing code using `fetch()` continues to work without changes.
- To add success messages, override `fetchWithMessage()` instead of `fetch()`.
- Access messages in pattern matching: `SuccessOperation(:var data, :var message?)`.

## 1.1.1

- Address format warnings.

## 1.2.0

### New

- Added `OperationResult<T>` class to hold data with optional success messages.
- Added `fetchWithMessage()` method to `AsyncOperationMixin` for returning data with messages.
- Added `streamWithMessage()` method to `StreamOperationMixin` for streams with messages.
- Added optional `message` field to `SuccessOperation<T>` for success-related information.
- Updated `setSuccess()` and `setData()` methods to accept optional `message` parameter.

### Changed

- `fetch()` and `fetchWithMessage()` are now both optional - exactly one must be overridden.
- `stream()` and `streamWithMessage()` are now both optional - exactly one must be overridden.
- Smart method detection: tries `*WithMessage()` first, falls back to standard method.
- Throws an error messages when neither or both methods are overridden.

### Usage

```dart
// Simple case - no message
@override
Future<User> fetch() async => api.getUser();

// With message - use fetchWithMessage()
@override
Future<OperationResult<User>> fetchWithMessage() async {
  // API returns a Map with 'data' and 'message' fields
  final response = await http.get(Uri.parse('https://api.example.com/user'));
  final json = jsonDecode(response.body);

  // Decode the data
  final user = User.fromJson(json['data'];

      // Extract the message from server response
      final message = json['message'] as String?;

      return OperationResult(user, message: message);
}
```

### Migration:

- Existing code using `fetch()` continues to work without changes.
- To add success messages, override `fetchWithMessage()` instead of `fetch()`.
- Access messages in pattern matching: `SuccessOperation(:var data, :var message?)`.

## 1.1.1

- Address format warnings.

## 1.1.0

### BREAKING CHANGES:

- Removed `idle` parameter from `LoadingOperation`
- Added `IdleOperation<T>` class extending `LoadingOperation<T>`
- Changed `LoadingOperation` from `final` to `base` class
- Added convenience getters: `hasNoData`, `isLoading`, `isIdle`, `isSuccess`, `isError`, etc.
- Added `SuccessOperation.empty()` constructor and `empty` property
- Added `setIdle()` method to both mixins
- Removed `doesGlobalRefresh` parameter from internal methods

**Migration:**

- Replace `LoadingOperation.idle` checks with `operation.isIdle`
- Handle `IdleOperation` in pattern matching when `loadOnInit = false`
- Update equality checks due to `LoadingOperation` structure changes

## 1.0.1

- Update README.md

## 1.0.0

- Initial release.

## 1.6.0

### BREAKING CHANGES

- **`SuccessOperation` is now `sealed`** with two subtypes:
  - **`ValueSuccessOperation<T>`**: Carries non-null data. `data` returns `T`.
  - **`VoidSuccessOperation<T>`**: No data (fire-and-forget). `data` returns `null`.
- **`SuccessOperation.data` now returns `T?`** instead of `T`. Use `ValueSuccessOperation(:var data)` for
  guaranteed non-null access, or `SuccessOperation(:var data?)` with a null-check pattern.
- **Removed `dataOrNull` getter** — The base `data` getter already returns `T?`, making `dataOrNull` redundant.
- **`empty` is now a computed getter** — `bool get empty => this is VoidSuccessOperation<T>`. No longer a stored field.
  Behavior is unchanged.

### New Features

- **`ValueSuccessOperation<T>`** — Guarantees non-null `data` (`T`). Created via `SuccessOperation(data: x)`.
- **`VoidSuccessOperation<T>`** — For operations that succeed without data. Created via `SuccessOperation.empty()`.
- **`setEmpty({String? message})`** — New method on both `AsyncOperationMixin` and `StreamOperationMixin` for emitting
  `VoidSuccessOperation`. Use for delete, logout, or fire-and-forget actions.
- **`onEmpty(String? message)`** — New lifecycle callback on both mixins, fired when `setEmpty()` is called.
- **Exhaustive matching on success subtypes** — Because `SuccessOperation` is sealed, matching `ValueSuccessOperation`
  and `VoidSuccessOperation` individually is now compiler-enforced.

### Improvements

- **Consistent `runtimeType` in equality and hashCode** — All state classes now include `runtimeType` in both
  `operator ==` and `hashCode` for correctness in hash-based collections.
- **Stream mixin `mounted` guard on data callbacks** — Both `onData` callbacks in `StreamOperationMixin` now check
  `mounted` before setting state, preventing writes to disposed `ValueNotifier`s.
- **Comprehensive test suite** — 91 tests covering: reflexive/symmetric/transitive equality, cross-type inequality,
  hashCode stability and consistency, const canonicalization, toString for all types, edge cases (nullable T, empty
  collections, Value vs Void with same data).
- **Rewritten example app** — Five examples showcasing all package features: basic fetch, fire-and-forget, streams,
  search with idle, and global refresh patterns.

### Migration

Construction is unchanged — redirecting factory constructors handle the new types transparently:

```dart
SuccessOperation
(
data
:
x
) // creates ValueSuccessOperation (same call site)
SuccessOperation
.
empty
(
) // creates VoidSuccessOperation (same call site)
```

Switch expressions that use `SuccessOperation` as a catch-all continue to work. To opt into type-safe access,
match the subtypes individually. See README for full migration guide.

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
  final response = await http.get(Uri.parse('https://api.example.com/user'));
  final json = jsonDecode(response.body);
  final user = User.fromJson(json['data']);
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

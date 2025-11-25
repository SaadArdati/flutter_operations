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

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

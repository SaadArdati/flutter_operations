# flutter_operations patterns

## Payload pattern spelling

Choose the pattern that states the intent; do not use `Object()` as a non-null payload marker.

| Intent | Pattern |
|---|---|
| Bind data, retaining its declared nullability | `SuccessOperation(:final data)` |
| Require non-null data and use it | `OperationState(:final data?)` |
| Require non-null data without using it | `OperationState(data: _?)` |
| Match missing data | `LoadingOperation(data: null)` |
| Ignore data entirely | `SuccessOperation()` |

`final data` and `_` both accept null; neither replaces a non-null check. Prefer omitting an ignored property to `data: _`. `Object()` is a valid object pattern, not an allocation, but obscures a simple null check.

For a non-nullable payload, initial loading and uncached errors can precede a shared content branch:

```dart
// state is OperationState<List<Entity>>.
return switch (state) {
  LoadingOperation(data: null) => const LoadingView(),
  ErrorOperation(data: null, :final message) => ErrorView(message),
  OperationState(:final data?) => EntityList(data),
};
```

If content intentionally comes from another observable collection, use `OperationState(data: _?)` for that last arm instead. Do not bind a variable that the branch never uses.

This three-arm shape assumes non-nullable success data. For `T?` or `void`, include an explicit `SuccessOperation` arm for successful null/completion; non-null data is not the definition of success. Keep switches exhaustive and handle idle separately when it differs from loading.

## Branch order

Prefer success/data UI, including empty-data success, as the final branch or success group when semantically safe. Put loading/error/idle-specific branches first. This is a style preference, not an anti-pattern prohibition. Preserve top-to-bottom matching: error-first may intentionally override cached content, and idle precedes loading when distinct. Do not move a catch-all before a data branch.

## Full exhaustive rendering

Use separate arms when initial loading, refresh, terminal failure, and failure with cached content render differently.

```dart
return switch (state) {
  IdleOperation(data: null) => const StartView(),
  IdleOperation(:final data?) => Preview(data),
  LoadingOperation(data: null) => const LoadingView(),
  LoadingOperation(:final data?) => DataView(data, refreshing: true),
  ErrorOperation(:final message, data: null) => ErrorView(message),
  ErrorOperation(:final message, :final data?) =>
    DataView(data, error: message),
  SuccessOperation(:final data) => DataView(data),
};
```

`IdleOperation` must precede `LoadingOperation` because idle is a loading subtype.

## Collapse idle into loading

When idle and loading render identically, omit the idle arm:

```dart
return switch (state) {
  LoadingOperation(data: null) => const LoadingView(),
  LoadingOperation(:final data?) => DataView(data, refreshing: true),
  ErrorOperation(:final message) => ErrorView(message),
  SuccessOperation(:final data) => DataView(data),
};
```

The loading patterns include idle.

## Data-presence rendering

When the UI only cares whether data exists:

```dart
return switch (state) {
  OperationState(data: null) => const LoadingView(),
  OperationState(:final data?) => DataView(data),
};
```

This intentionally discards state-specific overlays.

## Error-first rendering

When any error should override cached content:

```dart
return switch (state) {
  ErrorOperation(:final message) => ErrorView(message),
  OperationState(data: null) => const LoadingView(),
  OperationState(:final data?) => DataView(data),
};
```

Dart matches top to bottom, so error remains authoritative even when it carries data.

## Payload guards

```dart
return switch (state) {
  LoadingOperation() => const LoadingView(),
  ErrorOperation(:final message) => ErrorView(message),
  SuccessOperation(:final data) when data.isEmpty => const EmptyView(),
  SuccessOperation(:final data) => ResultsView(data),
};
```

## Incidental UI gates

Do not build a full switch for a button gate or nullable cache read.

```dart
ElevatedButton(
  onPressed: state.isNotLoading ? reload : null,
  child: Text(state.isLoading ? 'Refreshing...' : 'Refresh'),
);

final cached = state.dataOrNull;
```

## Transition versus copy

Use `transitionTo` when changing runtime variant:

```dart
final loading = state.transitionTo.loading();
final success = loading.transitionTo.success(data: result);
final failure = success.transitionTo.error(
  message: 'Offline',
  error: error,
  stackTrace: stackTrace,
);
```

Use `copyWith` when retaining the runtime variant:

```dart
final revised = failure.copyWith(
  message: 'Please try again',
  stackTrace: null,
);
```

## Cached-data rules

Loading, idle, and error destinations preserve current data when omitted:

```dart
state.transitionTo.loading();
state.transitionTo.idle();
state.transitionTo.error(message: 'Offline');
```

Clear cache explicitly:

```dart
state.transitionTo.loading(data: null);
state.transitionTo.error(data: null, message: 'Session expired');
```

Success never inherits cache implicitly because it requires a new `data: T` result.

## Manual construction

Use constructors when there is no prior state to transition from. Let the declared type supply constructor arguments:

```dart
OperationState<User> state = const IdleOperation();
OperationState<User?> lookup = const SuccessOperation(data: null);
OperationState<void> command = const SuccessOperation(data: null);
```

For an existing state, use the transitions above instead of copying `dataOrNull` into a new constructor. If the same concrete variant is already known, use `copyWith`.

## User-facing errors

Pass resolved localized text as `message`, and preserve diagnostics in `error` and `stackTrace`. These examples use direct user-facing text because no localization system is assumed. Do not pass exception strings or untranslated keys. For mixins, override `errorMessage`; the default diagnostic string is not suitable for display. Since `ErrorOperation.message` is nullable, render a localized fallback when absent.

## Success messages

Mixin-owned async work:

```dart
@override
Future<User> fetch() async {
  final response = await api.fetchUser();
  if (response.message case final message?) attachMessage(message);
  return response.user;
}
```

Mixin-owned streams:

```dart
@override
Stream<User> stream() async* {
  await for (final event in repository.events()) {
    if (event.message case final message?) attachMessage(message);
    yield event.user;
  }
}
```

Manual state:

```dart
state = state.transitionTo.success(data: user, message: 'Loaded');
```

## Rendering side effects

Switch expressions choose UI. They should not navigate, show snackbars, or report analytics. Use mixin lifecycle callbacks or the surrounding state architecture's listeners for side effects.

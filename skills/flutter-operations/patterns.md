# flutter_operations patterns

## Full exhaustive rendering

Use separate arms when initial loading, refresh, terminal failure, and failure with cached content render differently.

```dart
return switch (state) {
  IdleOperation(data: null) => const StartView(),
  IdleOperation(:final data?) => Preview(data),
  LoadingOperation(data: null) => const LoadingView(),
  LoadingOperation(:final data?) => DataView(data, refreshing: true),
  SuccessOperation(:final data) => DataView(data),
  ErrorOperation(:final message, data: null) => ErrorView(message),
  ErrorOperation(:final message, :final data?) =>
    DataView(data, error: message),
};
```

`IdleOperation` must precede `LoadingOperation` because idle is a loading subtype.

## Collapse idle into loading

When idle and loading render identically, omit the idle arm:

```dart
return switch (state) {
  LoadingOperation(data: null) => const LoadingView(),
  LoadingOperation(:final data?) => DataView(data, refreshing: true),
  SuccessOperation(:final data) => DataView(data),
  ErrorOperation(:final message) => ErrorView(message),
};
```

The loading patterns include idle.

## Data-presence rendering

When the UI only cares whether data exists:

```dart
return switch (state) {
  OperationState(:final data?) => DataView(data),
  OperationState() => const LoadingView(),
};
```

This intentionally discards state-specific overlays.

## Shared renderer for data-bearing variants

```dart
return switch (state) {
  LoadingOperation(:final data?) ||
  SuccessOperation(:final data) ||
  ErrorOperation(:final data?) => DataView(data),
  OperationState() => const LoadingView(),
};
```

Use this when cached loading, success, and cached error share the same primary content.

## Error-first rendering

When any error should override cached content:

```dart
return switch (state) {
  ErrorOperation(:final message) => ErrorView(message),
  OperationState(:final data?) => DataView(data),
  OperationState() => const LoadingView(),
};
```

Dart matches top to bottom, so error remains authoritative even when it carries data.

## Payload guards

```dart
return switch (state) {
  SuccessOperation(:final data) when data.isEmpty => const EmptyView(),
  SuccessOperation(:final data) => ResultsView(data),
  LoadingOperation() => const LoadingView(),
  ErrorOperation(:final message) => ErrorView(message),
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

Prefer transitions when a current state exists. When constructing directly, propagate cache yourself:

```dart
state = LoadingOperation(data: state.dataOrNull);
state = ErrorOperation(
  message: 'Refresh failed',
  error: error,
  stackTrace: stackTrace,
  data: state.dataOrNull,
);
```

Use `error:`, not the removed `exception:` parameter.

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

---
title: Cache, transitions & copies
sidebar:
  order: 2
---

Use constructors for initial state, `transitionTo` to change variant, and `copyWith` to edit the same variant.

```dart
OperationState<User> state = const IdleOperation();
state = state.transitionTo.loading();
state = state.transitionTo.success(data: user, message: 'Loaded');
state = state.transitionTo.error(
  message: 'Offline', error: error, stackTrace: trace,
);
state = state.transitionTo.idle();
```

Helpers create snapshots. They do not publish, start work, guard races, or dispose resources.

## Cache retention

Loading, idle, and error transitions retain current data when `data` is omitted. Passing `data: null` clears it. Success requires a new value satisfying `T`; it never implicitly inherits cache.

```dart
final refreshing = state.transitionTo.loading();
final newSearch = state.transitionTo.loading(data: null);
final offline = state.transitionTo.error(message: 'Offline');
```

Engines use `cached: true` by default. Use `run(work, cached: false)` or `listen(source, cached: false)` when switching identity, search criteria, or account should discard old content.

## Destination availability follows static type

| Receiver | Destinations |
| --- | --- |
| `OperationState<T>` | loading, idle, success, error |
| `LoadingOperation<T>` | idle, success, error |
| `IdleOperation<T>` | loading, success, error |
| `SuccessOperation<T>` | loading, idle, error |
| `ErrorOperation<T>` | loading, idle, success |

Concrete receivers omit their own variant. Promotion can change which extension applies. Use `copyWith` when retaining a known concrete variant.

```dart
final revised = errorState.copyWith(
  message: 'Please try again',
  stackTrace: null,
);
```

## Omitted versus explicit null

`copyWith()` preserves omitted fields. Loading/idle/error allow explicit null to clear data. Error copies allow clearing message, error, and stack trace. Success copies allow clearing message; `data: null` clears data only when `T` accepts null, otherwise the existing data remains.

Transitioning to error does not inherit error metadata. Omitted `message`, `error`, and `stackTrace` default to null. Only cache is inherited.

Keep generic types on the outer owner when inference supplies context. `OperationState<User> state = const IdleOperation()`. An uncontextualized `final state = IdleOperation<User>()` does need its type argument.

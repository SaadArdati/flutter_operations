---
name: flutter-operations
description: Use when writing or modifying Dart or Flutter code that imports `package:flutter_operations/flutter_operations.dart`, including widget-owned Future or Stream work, operation state in Bloc, Cubit, Riverpod, Provider, ChangeNotifier, controllers or services, cached refresh UI, command state, exhaustive matching, state transitions, or choosing T as non-nullable, nullable, or void.
license: BSD-3-Clause
metadata:
  author: Saad Ardati
  version: "3.0.0"
  repository: https://github.com/SaadArdati/flutter_operations
  homepage: https://pub.dev/packages/flutter_operations
  keywords: dart, flutter, async, result-type, sealed-class, state-management, stream, pattern-matching
  category: development
---

# flutter_operations

`flutter_operations` is both:

1. an architecture-neutral `OperationState<T>` model for any state holder; and
2. two widget lifecycle mixins for Futures and Streams owned by one `StatefulWidget`.

Do not reduce it to a Bloc helper or assume a mixin is always required. It models requests, refreshes, searches, commands, submissions, uploads, permissions, subscriptions, database listeners, WebSockets, sensors, and any other work with an idle/loading/success/error lifecycle.

## Required discovery pass

Before writing code, answer these three questions.

### 1. Who owns the state?

- A single `StatefulWidget` owns the operation: consider a mixin.
- Cubit, Bloc, Riverpod, Provider, ChangeNotifier, a controller, reducer, service, or plain Dart object already owns state: store `OperationState<T>` directly. Do not force a widget mixin into an external state holder.

### 2. How many values can the source produce?

- One completion: `AsyncOperationMixin<T, Widget>` or manual `OperationState<T>` transitions.
- Repeated values: `StreamOperationMixin<T, Widget>` or an external subscription that publishes `OperationState<T>`.

### 3. What does success mean?

- Success always has a value: `T`, such as `User`.
- A meaningful value may legitimately be absent: `T?`, such as `User?`.
- Completion is the result: `void`, such as save, delete, logout, submit, upload, or permission confirmation.

Then read [use-cases.md](use-cases.md) for the matching integration recipe. Read [patterns.md](patterns.md) when designing rendering, cached-data behavior, `copyWith`, or `transitionTo`. Read [anti-patterns.md](anti-patterns.md) before finalizing manually managed states.

## Capability map

| Need | Use |
|---|---|
| Widget-owned API request, database read, computation, permission, or command | `AsyncOperationMixin` |
| Widget-owned Firestore, WebSocket, connectivity, location, or sensor source | `StreamOperationMixin` |
| Existing Bloc, Cubit, Riverpod, Provider, or controller | `OperationState<T>` directly |
| Wait for user input before starting | `loadOnInit => false` or `listenOnInit => false` |
| Keep content visible while refreshing | Loading state with cached data |
| Keep content usable after a failed refresh | Error state with cached data |
| Save, delete, logout, submit, or upload | `OperationState<void>` or `AsyncOperationMixin<void, W>` |
| Change to another runtime state | `state.transitionTo.<destination>()` |
| Update fields without changing the runtime state | `state.copyWith(...)` |
| Attach a success message in a mixin | `attachMessage(...)` inside the active source flow |
| Attach a success message outside a mixin | `SuccessOperation(message: ...)` or `transitionTo.success(message: ...)` |
| Render every state safely | Exhaustive Dart pattern matching |
| Gate a button or read cached data incidentally | `isLoading`, `isNotLoading`, `dataOrNull`, and related getters |

## State model

```text
sealed OperationState<T>
  +-- base LoadingOperation<T>      optional cached T
  |     +-- final IdleOperation<T>  ready, not actively loading
  +-- final SuccessOperation<T>     required data: T
  +-- final ErrorOperation<T>       optional cached T, message, error, stackTrace
```

`IdleOperation` extends `LoadingOperation`. A `LoadingOperation()` pattern includes idle unless an `IdleOperation()` arm appears first.

`SuccessOperation<T>.data` is exactly `T`. It never throws and does not widen a non-nullable type.

Every state has:

- `data`, `dataOrNull`, `hasData`, and `hasNoData`;
- `isIdle`, `isLoading`, `isSuccess`, `isError`, and their negations;
- `copyWith` for preserving the current variant;
- `transitionTo` for creating another variant.

Loading, idle, and error transitions preserve current data when `data` is omitted. Explicit `data: null` clears it. A success transition always requires `data: T`.

Concrete variants expose only other destinations. A base `OperationState<T>` exposes all destinations because its runtime variant is not statically known.

## Mixin selection

| Concept | Async mixin | Stream mixin |
|---|---|---|
| Source override | `fetch()` | `stream()` |
| Start automatically | `loadOnInit` | `listenOnInit` |
| Start or restart | `load()` / `reload()` | `listen()` |
| Publish success manually | `setSuccess()` | `setData()` |
| Success callback | `onSuccess()` | `onData()` |
| Source completion | Not applicable | `onDone()` |

Both mixins expose `operation`, `operationNotifier`, `setIdle`, `setLoading`, `setError`, `onIdle`, `onLoading`, `onError`, `errorMessage`, `attachMessage`, and `globalRefresh`.

The mixins already guard async completions against disposal and stale generations. Do not add redundant mounted or generation guards around their internal lifecycle. Code in consumer callbacks must still follow normal Flutter safety when it performs its own asynchronous work or uses `BuildContext`.

`globalRefresh` defaults to `false`. Prefer a `ValueListenableBuilder` around the affected subtree. Enable global refresh only when the entire owning widget must rebuild for each transition.

## Success messages

In `AsyncOperationMixin`, call `attachMessage` inside the active `fetch()` flow, including after awaits.

In `StreamOperationMixin`, call it inside an `async*` body immediately before the matching `yield`.

Calls outside the active `load()` or `listen()` zone are no-ops. For manually managed states, pass the message directly when constructing or transitioning to success.

## Hard rules

1. Choose `T` from the meaning of success, not from the current UI.
2. Preserve cached data during loading and error unless clearing it is intentional.
3. Use `transitionTo` for another variant and `copyWith` for the same variant.
4. Match `IdleOperation` before `LoadingOperation` when their UI differs.
5. Use `error:`, never the removed `exception:` argument or field.
6. Do not invent retry, debounce, cancellation, or orchestration APIs. The package does not provide them.
7. Do not claim `setIdle()` cancels a stream subscription. It changes operation state only.
8. Do not use `attachMessage` for manually managed state.
9. Do not add a mixin when an existing state holder already owns the operation.
10. Keep UI side effects out of render branches. Use lifecycle callbacks or the surrounding architecture's listener mechanism.

## Quick example

```dart
OperationState<User> state = const IdleOperation();

Future<void> refresh() async {
  state = state.transitionTo.loading();
  try {
    state = state.transitionTo.success(data: await repository.fetchUser());
  } catch (error, stackTrace) {
    state = state.transitionTo.error(
      message: 'Refresh failed',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
```

This works inside Cubit, Bloc, Riverpod, Provider, ChangeNotifier, a controller, a reducer, a service, or plain Dart. See [use-cases.md](use-cases.md) for widget mixins, streams, commands, and architecture-specific examples.

## Source of truth

- Public API: `lib/src/operation_state.dart`, `lib/src/helpers.dart`, `lib/src/async_operation_mixin.dart`, `lib/src/stream_operation_mixin.dart`
- Integration recipes: [use-cases.md](use-cases.md)
- Rendering and transition recipes: [patterns.md](patterns.md)
- Common mistakes: [anti-patterns.md](anti-patterns.md)

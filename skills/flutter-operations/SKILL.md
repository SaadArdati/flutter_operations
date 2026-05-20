---
name: flutter-operations
description: Use when writing or modifying Dart/Flutter code that imports `package:flutter_operations/flutter_operations.dart`. Triggers on wiring AsyncOperationMixin or StreamOperationMixin onto a State, designing exhaustive switches over OperationState, choosing the type parameter T (non-nullable, nullable, or void), or propagating cached data through Loading and Error states.
license: BSD-3-Clause
authors:
  - Saad Ardati
repository: https://github.com/SaadArdati/flutter_operations
homepage: https://pub.dev/packages/flutter_operations
keywords:
  - dart
  - flutter
  - async
  - result-type
  - sealed-class
  - state-management
  - stream
  - pattern-matching
categories:
  - development
  - dart
  - flutter
metadata:
  version: 2.0.0
---

# flutter_operations

Type-safe async operation state for Flutter using sealed classes and exhaustive pattern matching. Four states (Idle, Loading, Success, Error), two mixins (one-shot and streaming), one rule: the operation's payload type `T` is what the developer wrote. Nothing is injected, nothing throws on read, nothing has to be unboxed at the call site.

## When to use

- Writing or modifying Dart code that imports `package:flutter_operations/flutter_operations.dart`.
- Adding `AsyncOperationMixin<T, K>` or `StreamOperationMixin<T, K>` to a `State<K>`.
- Designing the switch over `OperationState<T>` in a widget's `build`.
- Choosing the type parameter `T`: a non-nullable type (`User`), a legitimately-nullable type (`User?`), or fire-and-forget (`void`).
- Propagating cached data across state transitions (Loading-with-cache, Error-with-cache).

## Boundaries

- Widget-scoped utility. Not Bloc, Provider, or Riverpod. Each mixin owns one operation per `State` via a `ValueNotifier`. For cross-screen state, host an `OperationState<T>` field inside whatever state manager the app already uses; this package gives you the type, not the propagation.
- No retry, debounce, or cancellation primitives ship with the package. Generation-based race protection is internal to the mixin; exposed only via `reload()` (one-shot) or `listen()` (stream).
- Do not invent APIs not in `lib/src/`. If a primitive seems missing, surface the gap.

## The five sealed types

```
sealed OperationState<T>
  |
  +-- base LoadingOperation<T>      // in progress, optional cached T?
  |     |
  |     +-- final IdleOperation<T>  // ready but not actively loading
  |
  +-- final SuccessOperation<T>     // data: T exactly (non-null iff T is non-nullable)
  +-- final ErrorOperation<T>       // message, exception, stackTrace, optional cached T?
```

`IdleOperation extends LoadingOperation`. Matching `LoadingOperation` in a switch subsumes Idle unless Idle is matched first.

Base `OperationState<T>` getters: `data` (T?), `dataOrNull` (T?, same as data), `hasData`, `hasNoData`, `isLoading`, `isIdle`, `isSuccess`, `isError` (plus negations).

`SuccessOperation<T>.data` overrides to return exactly `T`. For `<User>`, non-null. For `<User?>`, may be null. For `<void>`, the field exists but is unreadable; the case is still matchable. Never throws.

## Choose T

```
operation always produces a value on success?
  yes -> T = the concrete value type (e.g. <User>)
  no, value may be absent this time -> T = nullable (e.g. <User?>)
  no, operation never returns anything (delete, logout, fire-and-forget) -> T = void
```

The decision lives at the call site. `T` speaks for itself.

## Pick a mixin

```
one-shot operation (HTTP call, DB query)?
  -> AsyncOperationMixin<T, K extends StatefulWidget> on State<K>
     Override fetch().

continuous stream (WebSocket, listener)?
  -> StreamOperationMixin<T, K extends StatefulWidget> on State<K>
     Override stream().
```

Both expose `operation: OperationState<T>` (via `operationNotifier: ValueNotifier<OperationState<T>>`), the `loadOnInit`/`listenOnInit` toggle (default `true`), `globalRefresh` (default `false`), and the same setter/callback surface. Naming differs slightly:

| Concept | Async mixin | Stream mixin |
|---|---|---|
| Emit success | `setSuccess(T data, {String? message})` | `setData(T value, {String? message})` |
| React to success | `onSuccess(T data)` | `onData(T value)` |
| Drive a run | `load()` / `reload({cached})` | `listen({cached})` |
| Attach a success message | `attachMessage(String)` (call from inside fetch) | `attachMessage(String)` (call before each yield) |

Shared: `setError(Object e, StackTrace s, {String? message, bool cached})`, `setIdle({cached})`, `setLoading({cached})`, `onError`, `onIdle`, `onLoading`, `errorMessage(e, s)`.

For an optional success message, call `attachMessage(String)` from inside `fetch` or `stream` (the latter before each `yield`). The string becomes `SuccessOperation.message` on the resulting state.

## Pattern matching

Several useful styles. Pick the one that matches how much detail the UI needs.

**Full fan-out:** every state has its own arm.

```dart
switch (operation) {
  LoadingOperation(data: null) => const CircularProgressIndicator(),
  LoadingOperation(:var data?) => Stack(children: [DataView(data), const LinearProgressIndicator()]),
  SuccessOperation(:var data) => DataView(data),
  ErrorOperation(:var message, data: null) => ErrorBanner(message),
  ErrorOperation(:var message, :var data?) => Stack(children: [DataView(data), ErrorBanner(message)]),
}
```

**Data-presence shortcut:** when the UI only cares whether data exists.

```dart
switch (operation) {
  OperationState(:final data?) => DataView(data),
  OperationState() => const CircularProgressIndicator(),
}
```

**OR-pattern aggregation:** shared renderer across data-bearing states.

```dart
switch (operation) {
  LoadingOperation(:var data?) || SuccessOperation(:var data) || ErrorOperation(:var data?) =>
      RefreshIndicator(onRefresh: reload, child: DataList(data)),
  _ => const CircularProgressIndicator(),
}
```

**Error-first then catch-all:** errors win over cached data.

```dart
switch (operation) {
  ErrorOperation(:var message) => ErrorBanner(message),
  OperationState(:final data?) => DataView(data),
  _ => const CircularProgressIndicator(),
}
```

**Guards with `when`:** branch on payload content.

```dart
switch (operation) {
  SuccessOperation(:var data) when data.isEmpty => const EmptyStateView(),
  SuccessOperation(:var data) => ListView(...),
  LoadingOperation() => const CircularProgressIndicator(),
  ErrorOperation(:var message) => ErrorBanner(message),
}
```

**Collapsing Idle into Loading:** if the screen renders them the same, just match `LoadingOperation`. If they differ, put `IdleOperation` first (subtype matches first).

**Imperative shortcuts:** for button-disabled gates and one-off reads, `operation.isLoading` and `operation.dataOrNull` are cleaner than a switch.

## Conventions

1. **`T` is honest.** If the operation may return null, write `<T?>`. If it never returns a value, write `<void>`. Pick the type parameter that matches what the operation actually produces.
2. **`SuccessOperation<T>.data` is exactly `T`.** For `<User>`, `User`. For `<User?>`, `User?`. For `<void>`, unreadable but matchable. Never throws.
3. **Cached data lives on Loading and Error, not Success.** `LoadingOperation(data: state.dataOrNull)` and `ErrorOperation(message: '...', data: state.dataOrNull)` keep stale data visible during reloads and failures. Success always carries fresh data.
4. **Override `fetch()` (async) or `stream()` (streaming) exactly once.** Both are abstract; the analyzer flags missing overrides at compile time.
5. **`IdleOperation` extends `LoadingOperation`.** Order matters: `IdleOperation` arms must precede `LoadingOperation` if they render differently. Otherwise omit `IdleOperation` entirely; `LoadingOperation` catches both.
6. **Pattern-match in widgets, getters for incidental UI.** Switch for the main render branch. `state.isLoading` / `state.dataOrNull` for button gates, snackbars, focus management.
7. **The mixin guards `mounted` and generation tracking internally.** Do not duplicate those checks around `setSuccess` / `setData` / `setError` calls.
8. **`globalRefresh: true`** rebuilds the whole widget on every state change. Default is `false` (only `ValueListenableBuilder` listeners update). Stay on the default unless non-listening parts of the tree also need to rebuild.

## Anti-pattern index

Symptom in code -> see `anti-patterns.md`.

- `LoadingOperation()` emitted with no data when prior state had cache -> #1

## Source pointers

- `lib/src/operation_state.dart`
- `lib/src/async_operation_mixin.dart`
- `lib/src/stream_operation_mixin.dart`
- `example/lib/main.dart` (five runnable scenarios)
- `test/unit/operation_state_test.dart` (pattern-matching variants and equality semantics)

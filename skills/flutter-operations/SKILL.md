---
name: flutter-operations
description: Use when writing or modifying Dart or Flutter code that imports `package:flutter_operations/flutter_operations.dart`, including widget-owned Future or Stream work, operation state in Bloc, Cubit, Riverpod, Provider, ChangeNotifier, controllers or services, cached refresh UI, command state, exhaustive matching, state transitions, or choosing T as non-nullable, nullable, or void.
license: BSD-3-Clause
metadata:
  author: Saad Ardati
  version: "4.0.0"
  repository: https://github.com/SaadArdati/flutter_operations
  homepage: https://pub.dev/packages/flutter_operations
  keywords: dart, flutter, async, result-type, sealed-class, state-management, stream, pattern-matching
  category: development
---

# flutter_operations

Version 4 separates immutable state, execution, and UI ownership. Verify the consumer's installed version before applying these APIs; see [migration.md](migration.md) for 3.x.

## Choose the owner first

| Requirement | Choose |
|---|---|
| Existing execution/lifecycle machinery; only need typed snapshots | `OperationState<T>` directly |
| Reusable execution, multiple operations, composition, configurable concurrency | `AsyncOperation<T>` fields |
| One operation on a Cubit, Notifier, ChangeNotifier, store, service, or controller | `AsyncOperationMixin<T>` |
| One widget owns a Future | `AsyncOperationStateMixin<T, Widget>` |
| Host owns a subscription or needs awaitable cleanup | `StreamOperation<T>` |
| One stream on an external host | `StreamOperationMixin<T>` |
| One widget owns a Stream | `StreamOperationStateMixin<T, Widget>` |
| Specialized operation behavior | Extend `AsyncOperation<T>`; optionally mix in MobX `Store` |
| Inject a specialized engine into a host mixin | Override `operationController`; explicitly transfer ownership |

Do not force manual async state handling just because a state manager already exists. Direct state is an option, not the default replacement for execution safety. Prefer composition for multiple independent operations; prefer the host mixin for one operation with a `fetch()` method.

Declare `T` from success semantics: `User` requires a value, `User?` allows successful absence, `void` means completion. Async execution accepts a Future or synchronous result; streams use `StreamOperation<T>` or the widget stream adapter.

## Read the matching recipe

- [use-cases.md](use-cases.md): standalone execution, widget Future/Stream, commands, cache, manual state.
- [integrations.md](integrations.md): Cubit/Bloc, Provider, Riverpod, Signals, MobX; direct/composed/mixin alternatives, inheritance, getter overrides, injection.
- [patterns.md](patterns.md): exhaustive rendering, payload patterns, transitions, messages.
- [anti-patterns.md](anti-patterns.md): notification, lifecycle, nullability, and ownership traps.
- [migration.md](migration.md): 3.x → 4.0 names and behavior.

## Shared publication base

`AsyncOperation<T>` and `StreamOperation<T>` extend `Operation<T>`. It owns state storage, read/change hooks, cached idle/loading/error transitions, error formatting, owner-scoped messages, and protected `emitState`. Use the base for common state projections or specialized engines. Generation invalidation and disposed-state bookkeeping are shared through protected helpers. Execution, success/data hooks, public cancellation, and resource cleanup stay concrete; there is no generic cleanup method or `FutureOr<void>` lifecycle contract.

## Execution contract

`AsyncOperation<T>` starts idle. `run(work, cached: true)` owns loading/success/error, last-value retention, generation tracking, and error formatting. `latest` (default) rejects older completions; `first` ignores overlapping calls. Neither policy queues work. `cancel()` invalidates pending results and becomes idle; it does not abort HTTP, a Future, or other external work. `dispose()` rejects future work/publication. Manual setters do not invalidate in-flight work; use `cancel()` when that is intended.

`onRead()` runs when `state` is read. `onChanged(previous, next)` runs once per unequal state transition, after assignment and before its lifecycle callback. Both accept constructor callbacks or method overrides; call `super` to retain configured callbacks. No `stateChanged`/`onStateChanged` parallel API. `isRunning` and `isDisposed` are not reactively tracked by state hooks.

The host mixin provides `operation`, `operationController`, `fetch`, `load`/`reload`, setters, `cancel`, `disposeOperation`, `operationRead`, and `operationChanged`. It does not auto-start, own a Flutter lifecycle, expose `operationNotifier`, or notify a framework by itself. Wire `operationChanged` to the host's notification mechanism and dispose at the host boundary. Widget mixins own startup/disposal and expose `operationNotifier` and `globalRefresh` (false by default).

`StreamOperationMixin.stream()` conflicts with Cubit/BlocBase's `stream` getter. Stream Cubits/Blocs must compose `StreamOperation<T>` or delegate to a separate mixin host.

## Stream execution contract

`StreamOperation<T>` starts idle and accepts a factory: `await operation.listen(repository.watchUsers)`. Each restart invalidates old events immediately, awaits old subscription cancellation, and creates a fresh source only if still current. `listen` completes when subscribed, not when the stream ends. `cancel` becomes idle immediately and awaits cleanup; `dispose` blocks publication immediately and awaits cleanup. Source/data errors become error state; data errors do not stop listening. Cancellation failures propagate through returned Futures and prevent replacements. Natural completion preserves the last state and calls `onDone` once for the current subscription.

State hooks match AsyncOperation: `onRead` / `onChanged(previous, next)`; stream callbacks use `onData` / `onDone`. Messages are owner-scoped and consumed per emission. Use `StreamOperationMixin<T>` for a host with `stream()`, `operationChanged`, and awaitable `disposeOperation`; composition works in any host. The existing widget `StreamOperationStateMixin<T, Widget>` delegates to this engine, exposes awaitable `listen`/`cancel`, and forwards asynchronous disposal failures to the owning zone because Flutter disposal cannot await.

## Authoring rules

- Keep state management dependencies out of the core. Frameworks publish through `emit`, `state = next`, `notifyListeners`, signals, or MobX Atoms.
- Do not duplicate generation/disposal guards around operation-owned execution. Manual async owners must guard both success and failure after awaits. Consumer-owned async side effects still need their own lifecycle checks.
- Use `transitionTo` for changes of variant, `copyWith` for same-variant edits, constructors for initial state. Loading/idle/error transitions retain cache unless `data: null` is explicit; execution uses `cached: false` to clear it.
- Infer constructor type arguments from typed fields, returns, `emit`, and arguments to explicitly typed generic calls: `signal<OperationState<User>>(IdleOperation())`, not `IdleOperation<User>()`. Put the type on the outer owner/call, not on nested constructors. Retain explicit types only when inference lacks context.
- Keep diagnostics in `error` and `stackTrace`; provide resolved display text through `message`/`errorMessage`. The default error formatter is diagnostic `error.toString()`.
- Collapse variant arms with identical rendering into `OperationState(:final data?)` when content requires non-null data, or `OperationState(:final data)` when nullable data is accepted. Put loading/error/idle-specific arms first; keep separate arms only for different behavior.
- Prefer success/data UI, including empty-data success, as the last branch or final success group when semantically safe. Put loading/error/idle-specific branches first. This is a style preference, not a correctness prohibition; preserve intentional error-first precedence and pattern coverage.
- Match `IdleOperation` before `LoadingOperation` when their UI differs: idle is a loading subtype. Keep sealed switches exhaustive.
- Bind payload with `:final data`, require non-null with `:final data?`, check unused non-null with `data: _?`, absence with `data: null`, or omit an irrelevant property. Never use `data: Object()` as a null-check idiom. Bare `_`/`final data` also match null. Nullable/void success needs explicit handling.
- `attachMessage` belongs inside the active operation's `run`/`fetch` zone or a stream's `async*` flow before `yield`; outside calls are ignored. For manual state, pass `message` on success.
- Keep UI side effects outside builders. A read hook must track reads, not mutate state. Read hooks must not initiate state transitions. Callback exceptions are not isolated from execution; avoid throwing from notification hooks. Lifecycle callbacks can start subsequent work.

## State model

`OperationState<T>` is sealed: `LoadingOperation<T>`, its subtype `IdleOperation<T>`, `SuccessOperation<T>`, and `ErrorOperation<T>`. Success `.data` is exactly `T`; other variants hold optional cached data. Common getters include `dataOrNull`, `hasData`/`hasNoData`, status getters and their negations. Concrete transition helpers omit their own variant; base-state helpers expose all destinations.

## Source of truth

Check `lib/src/async_operation.dart`, `async_operation_mixin.dart`, `stream_operation.dart`, `stream_operation_mixin.dart`, and `operation_state.dart`. Runnable comparisons live in `example/lib/async/*_integration_example.dart` and `example/lib/stream/*_stream_integration_example.dart`; lifecycle checks live in `example/test/integration_examples_test.dart`. Examples are alternatives, not a requirement to add every layer to an app.

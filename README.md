# Flutter Operations

[![Pub Version](https://img.shields.io/pub/v/flutter_operations.svg)](https://pub.dev/packages/flutter_operations)
[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD--3--Clause-blue.svg)](https://opensource.org/license/bsd-3-clause)

<img src="https://raw.githubusercontent.com/SaadArdati/flutter_operations/main/screenshots/header.png" alt="flutter_operations: async UI with type-safe states" width="100%">

`flutter_operations` provides typed state and lifecycle management for asynchronous work in Flutter. It supports requests, commands, refreshes, and live subscriptions within your existing application architecture.

Async interfaces need to represent loading, success, failure, and cached data. Their execution layer must also define how overlapping requests update state and how pending work behaves when its owner is disposed. Stream subscriptions require additional control over replacement, cancellation, and cleanup.

`OperationState<T>` represents the UI state with a sealed type hierarchy. `AsyncOperation<T>` and `StreamOperation<T>` manage execution, reject stale results, and retain cached data when requested. Host and widget mixins connect those engines to the appropriate lifecycle.

The package works with Bloc, Riverpod, Provider, Signals, MobX, or widget-owned state. It does not replace those architectures or add dependencies on them.

The original state model was introduced in [Exhaustive Pattern Matching for Exhausted Flutter Developers](https://medium.com/@saadoardati/exhaustive-pattern-matching-for-exhausted-flutter-developers-cd6837459862). Version 4 extends that model with reusable execution controllers and explicit ownership adapters.

## Install

Requires Dart **3.12+** and a Flutter SDK that bundles it.

```yaml
dependencies:
  flutter_operations: ^4.0.0
```

```dart
import 'package:flutter_operations/flutter_operations.dart';
```

## One request, one owner

```dart
final user = AsyncOperation<User>(
  onChanged: (_, next) => publish(next),
  errorMessage: (_, _) => 'Unable to load user',
);

await user.run(repository.fetchUser);

// At the owner's lifecycle boundary:
user.dispose();
```

The operation owns loading, success, error, cached data, and generation tracking. By default, a newer run wins and older completions cannot replace it. Your state manager decides how to publish the snapshots. `publish`, `repository`, and `User` above belong to your app.

Render those snapshots exhaustively:

```dart
// operation is OperationState<User>.
final Widget body = switch (operation) {
  IdleOperation(data: null) => const Text('Ready'),
  LoadingOperation(data: null) => const CircularProgressIndicator(),
  ErrorOperation(data: null, :final message) =>
    ErrorView(message ?? 'Unable to load user'),
  OperationState(:final data?) => ProfileView(data),
};
```

This deliberately shares content across success and cached states. Add separate branches when a refresh indicator or cached-error banner should accompany the content. Successful null and completion-only results need their own handling.

For repeated updates, use the matching stream engine:

```dart
final updates = StreamOperation<User>(
  onChanged: (_, next) => publish(next),
  errorMessage: (_, _) => 'Unable to update user',
);

await updates.listen(repository.watchUser);
// At the owner's lifecycle boundary:
await updates.dispose();
```

A restart rejects stale events immediately and waits for previous subscription cleanup before creating its replacement. `listen()` completes when subscribed, not when the stream ends. Stream errors can recover with later data.

## Choose how much you need

| Your owner | Use |
|---|---|
| Execution is already managed elsewhere | `OperationState<T>` directly |
| A controller, service, or store owns one or several operations | Compose `AsyncOperation<T>` or `StreamOperation<T>` |
| An external host wants inherited operation methods | `AsyncOperationMixin<T>` or `StreamOperationMixin<T>` |
| A widget owns the Future lifecycle | `AsyncOperationStateMixin<T, Widget>` |
| A widget owns the subscription lifecycle | `StreamOperationStateMixin<T, Widget>` |

Host mixins need explicit framework notification and disposal. Widget adapters provide startup, a notifier, and Flutter lifecycle cleanup. MobX can track operation reads and changes; Cubit can emit the snapshots. The core has no state-management package dependencies.

Cubit already exposes a `stream` getter, so its stream integration uses composition or delegates to a separate host rather than mixing in the conflicting `stream()` method. You do not need every approach in one app.

## The four states

| State | Meaning | Data |
|---|---|---|
| `IdleOperation<T>` | Ready, but not actively running | Optional cached `T` |
| `LoadingOperation<T>` | Work is in progress | Optional cached `T` |
| `SuccessOperation<T>` | Work completed successfully | Required `T` |
| `ErrorOperation<T>` | Work failed | Optional cached `T`, message, error, and stack trace |

`IdleOperation<T>` extends `LoadingOperation<T>`. A `LoadingOperation()` pattern therefore matches both unless `IdleOperation()` appears first. This is intentional: screens that render idle and loading identically need only one arm.

### Choose an honest result type

The success payload is exactly `T`.

```dart
OperationState<User>   // Every success contains a User.
OperationState<User?>  // A successful lookup may contain no User.
OperationState<void>   // The command succeeds without a meaningful value.
```

`SuccessOperation<User>.data` is `User`. It does not return `User?` and does not throw. For delete, logout, save, confirmation, and other command-style operations, use `void`:

```dart
final state = const SuccessOperation<void>(data: null, message: 'Deleted');
```

## Use case 1: Own a Future inside a widget

Use `AsyncOperationStateMixin` for a request, database read, computation, permission check, command, or any other one-shot operation tied to a widget lifecycle.

```dart
class _ProfilePageState extends State<ProfilePage>
    with AsyncOperationStateMixin<User, ProfilePage> {
  @override
  Future<User> fetch() => repository.fetchUser(widget.userId);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: operationNotifier,
      builder: (context, operation, _) => switch (operation) {
        LoadingOperation(data: null) =>
          const Center(child: CircularProgressIndicator()),
        ErrorOperation(:final message, data: null) => ErrorView(
          message: message ?? 'Could not load the profile',
          onRetry: reload,
        ),
        OperationState(:final data?) => RefreshIndicator(
          onRefresh: reload,
          child: ProfileView(user: data),
        ),
      },
    );
  }
}
```

By default, `loadOnInit` is `true`. The mixin:

- starts in `LoadingOperation` and calls `fetch()` after initialization;
- publishes `SuccessOperation<T>` or `ErrorOperation<T>`;
- preserves cached data during reloads and failures by default;
- ignores stale completions when a newer load starts;
- ignores completions after disposal;
- exposes lifecycle callbacks without requiring them.

### Wait for user input

Search, confirmation, and permission flows often should not start immediately. Return `false` from `loadOnInit` to begin in `IdleOperation`.

```dart
class _SearchPageState extends State<SearchPage>
    with AsyncOperationStateMixin<List<Result>, SearchPage> {
  @override
  bool get loadOnInit => false;

  @override
  bool get globalRefresh => true; // This example reads operation in build.

  String query = '';

  @override
  Future<List<Result>> fetch() => api.search(query);

  void search(String value) {
    query = value;
    load(cached: false);
  }

  @override
  Widget build(BuildContext context) => switch (operation) {
    IdleOperation() => SearchPrompt(onSubmitted: search),
    LoadingOperation() => const CircularProgressIndicator(),
    ErrorOperation(:final message) => ErrorView(message: message),
    SuccessOperation(:final data) => SearchResults(data),
  };
}
```

Use `setIdle()` to publish a ready snapshot without invalidating pending work. On external async hosts, use `cancel()` to invalidate pending results before returning to idle. `setIdle(cached: true)` keeps existing data; `setIdle(cached: false)` clears it.

## Use case 2: Own a Stream inside a widget

Use `StreamOperationStateMixin` for database snapshots, WebSockets, connectivity, location, sensors, or any source that can emit more than once.

```dart
class _ChatPageState extends State<ChatPage>
    with StreamOperationStateMixin<List<Message>, ChatPage> {
  @override
  Stream<List<Message>> stream() => chatRepository.watchRoom(widget.roomId);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: operationNotifier,
      builder: (context, operation, _) => switch (operation) {
        LoadingOperation(data: null) =>
          const Center(child: CircularProgressIndicator()),
        ErrorOperation(:final message, data: null) =>
          ErrorView(message: message),
        OperationState(:final data?) => MessagesList(data),
      },
    );
  }
}
```

`listenOnInit` defaults to `true`. Set it to `false` to begin idle and call `listen()` later. Calling `listen()` replaces the current subscription and starts a new generation, so late values and errors from an older generation cannot replace current state. Restarts await prior cancellation; await `listen()` when cleanup completion matters. `cancel()` invalidates events and publishes idle immediately, then completes when cancellation finishes. `setIdle()` only publishes a snapshot and leaves the subscription active. Disposal invalidates immediately and forwards asynchronous cleanup errors to the owning zone.

## Use case 3: Integrate with any state manager

### Cubit with the host mixin

```dart
class UserCubit extends Cubit<OperationState<User>>
    with AsyncOperationMixin<User> {
  UserCubit(this.repository) : super(const IdleOperation());
  final UserRepository repository;

  @override
  Future<User> fetch() => repository.fetchUser();

  @override
  void operationChanged(OperationState<User> previous, OperationState<User> next) {
    emit(next);
  }

  @override
  String errorMessage(Object error, StackTrace trace) => 'Unable to load user';

  @override
  Future<void> close() {
    disposeOperation();
    return super.close();
  }
}
```

Use inherited `load`, `reload`, and `cancel`. `BlocBuilder` still consumes `OperationState<User>`; no manual generation counter or async disposal guard is needed for operation-owned execution.

### Composition and standalone execution

```dart
final user = AsyncOperation<User>(
  onChanged: (previous, next) => publish(next),
  errorMessage: (error, trace) => 'Unable to load user',
);

await user.run(repository.fetchUser);
// At the owner's disposal boundary:
user.dispose();
```

Keep separate operations for independent requests. `latest` is the default concurrency policy; `first` ignores calls while running. `cancel()` invalidates pending results and becomes idle, but does not abort underlying I/O. `setIdle()` only changes state. `run` completes without returning the payload; inspect `state` for success or error.

### Standalone stream execution

```dart
final updates = StreamOperation<User>(
  onChanged: (previous, next) => publish(next),
  errorMessage: (error, trace) => 'Unable to update user',
);
await updates.listen(repository.watchUser);
await updates.cancel();
await updates.dispose();
```

Restarts invalidate old callbacks immediately and await cancellation before creating the next source. `listen` completes when the subscription is established, not when its stream finishes. Stream errors allow later data recovery; completion retains the last snapshot and invokes `onDone`. Cleanup failures propagate and block replacements. Sources must cooperate with asynchronous cancellation: a blocked `async*` source may require its underlying awaited work to finish before cleanup completes.

The widget stream adapter delegates to this engine. `listen` and `cancel` are awaitable; Flutter disposal invalidates immediately and forwards cleanup errors to the owning zone.

### Shared operation contract

`AsyncOperation<T>` and `StreamOperation<T>` extend `Operation<T>`, which provides state access, read/change hooks, cached transitions, error formatting, message attachment, generation tracking, and disposal bookkeeping. Their execution policies and cleanup contracts remain separate. The base does not introduce a generic cancellation or disposal method.

### Hooks and callback ordering

`state` reads invoke `onRead`. Unequal snapshots are assigned before `onChanged(previous, next)` and then the lifecycle callback. Equal snapshots suppress both callbacks, including repeated equal stream data. Call `super` in overrides to retain constructor callbacks. The flags `isRunning` and `isDisposed` do not invoke read hooks. Callbacks run synchronously and are not an isolated error boundary.

`onError` receives the explicit setter message, which may be null even when the error snapshot has formatted text. Use the snapshot for resolved display text. Default engine formatting is diagnostic `error.toString()`; override it for user-facing messages.

### Native framework publication

| Framework | Composition callback / host hook |
|---|---|
| Cubit | `emit(next)` |
| Riverpod Notifier | `state = next`; controller and disposal tied to each build lifetime |
| Provider / ChangeNotifier | `notifyListeners()`; render controller state |
| Signals | `signal.value = next`; dispose controller before signal |
| MobX | Atom-backed `onRead` and `onChanged`; ordinary getters can remain reactive |

MobX `Store` is a mixin, so a store can extend an operation subclass while mixing in `Store`. `@observable` on an operation field does not observe inner transitions, and `@computed` needs an already-reactive read. A reusable Atom bridge avoids copied observable state.

The host mixin also exposes `operationController` for an overridden getter or constructor-injected engine. The supplied instance owns callback configuration and is disposed by `disposeOperation`; its unused lazy default is never constructed. Overriding only the visible state getter does not reroute commands.

Direct `OperationState<T>` remains useful when execution is already managed elsewhere. Its transition helpers do not provide cancellation, generations, or disposal checks: manually managed async work must guard both successful and failed completions.

### Runnable comparisons

- [Standalone Future execution](example/lib/async/standalone_async_operation_example.dart) and [standalone stream execution](example/lib/stream/standalone_stream_operation_example.dart)
- [Widget Future/search](example/lib/async/widget_operations_example.dart) and [widget stream](example/lib/stream/widget_stream_example.dart)
- [Cubit: direct, composed, and mixin](example/lib/async/bloc_integration_example.dart)
- [Riverpod](example/lib/async/riverpod_integration_example.dart), [Provider](example/lib/async/provider_integration_example.dart), and [Signals](example/lib/async/signals_integration_example.dart): three ownership approaches each
- [MobX](example/lib/async/mobx_integration_example.dart): composition, read hooks, computed getters, inheritance, reusable mixins, and injection

Stream comparisons also cover [Cubit](example/lib/stream/bloc_stream_integration_example.dart), [Riverpod](example/lib/stream/riverpod_stream_integration_example.dart), [Provider](example/lib/stream/provider_stream_integration_example.dart), [Signals](example/lib/stream/signals_stream_integration_example.dart), and [MobX](example/lib/stream/mobx_stream_integration_example.dart).

These are alternatives, not layers every app needs. The core has no state-management package dependencies.

## Use case 4: Keep content visible during refresh and failure

Cached data is a first-class part of loading and error states.

```dart
final items = AsyncOperation<List<Item>>(
  onChanged: (_, next) => publish(next),
  errorMessage: (error, trace) => 'Refresh failed',
);

Future<void> refresh() => items.run(repository.fetchItems);
// Dispose items at the owner lifecycle boundary.
```

Execution retains the last data by default, including on failure. For manually managed state, `transitionTo` preserves it as well, but the host must supply stale-result and disposal guards. Pass `data: null` when a transition must deliberately clear cached data:

```dart
state = state.transitionTo.loading(data: null);
```

## Use case 5: Model commands, not only queries

Operations also describe work whose result is completion itself: save, delete, upload, logout, payment confirmation, permission requests, form submission, and navigation prerequisites.

```dart
class _SaveButtonState extends State<SaveButton>
    with AsyncOperationStateMixin<void, SaveButton> {
  @override
  bool get loadOnInit => false;

  @override
  bool get globalRefresh => true; // Rebuild the button on transitions.

  @override
  Future<void> fetch() async {
    await repository.save(widget.draft);
    attachMessage('Saved');
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: operation.isNotLoading ? load : null,
      child: Text(operation.isLoading ? 'Saving...' : 'Save'),
    );
  }
}
```

Use lifecycle callbacks for side effects such as analytics, snackbars, or coordination with surrounding code:

```dart
@override
void onSuccess(void data) {
  Navigator.of(context).pop(true);
}
```

## Use case 6: Build explicit state transitions

Every state exposes `transitionTo`. Concrete variants expose only other destinations, while an `OperationState<T>` reference exposes all destinations.

```dart
OperationState<User> state = const IdleOperation();

state = state.transitionTo.loading();
state = state.transitionTo.success(data: user, message: 'Loaded');
state = state.transitionTo.error(message: 'Offline', error: networkError);
state = state.transitionTo.idle();
```

Loading, idle, and error transitions preserve current data when `data` is omitted. Passing `data: null` clears it. Success always requires a value satisfying `T`.

Destination availability follows the receiver's static or promoted type:

```dart
if (state case SuccessOperation<User> success) {
  success.transitionTo.loading(); // Available.
  success.transitionTo.error();   // Available.
  // success.transitionTo.success(...) is intentionally unavailable.
}
```

Use `copyWith` when the runtime variant should stay the same:

```dart
final updated = errorState.copyWith(
  message: 'Please try again',
  stackTrace: null,
);
```

Omitted fields are preserved. Explicit `null` clears nullable fields, subject to the selected state's documented type constraints.

## Success messages

`SuccessOperation` can carry an optional message separately from its data.

For an async mixin, call `attachMessage` anywhere inside the active `fetch()` flow, including after an `await`:

```dart
@override
Future<User> fetch() async {
  final response = await api.fetchUser();
  if (response.message case final message?) attachMessage(message);
  return response.user;
}
```

For a stream mixin, call it inside an `async*` body immediately before the corresponding `yield`:

```dart
@override
Stream<Message> stream() async* {
  await for (final event in repository.events()) {
    if (event.message case final message?) attachMessage(message);
    yield event.data;
  }
}
```

The message is scoped to the active `load()` or `listen()` zone. Calls outside that flow are no-ops. For manually constructed states, pass `message` directly to `SuccessOperation` or `transitionTo.success`.

## Rendering patterns

### Full detail

Use separate arms when the UI distinguishes initial loading, refresh, terminal failure, and failure with cached content.

```dart
return switch (operation) {
  IdleOperation(data: null) => const StartView(),
  IdleOperation(:final data?) => Preview(data),
  LoadingOperation(data: null) => const LoadingView(),
  LoadingOperation(:final data?) => DataView(data, refreshing: true),
  ErrorOperation(:final message, data: null) => ErrorView(message: message),
  ErrorOperation(:final message, :final data?) =>
    DataView(data, error: message),
  SuccessOperation(:final data) => DataView(data),
};
```

### Data presence only

Use the base type when state identity does not affect rendering.

```dart
return switch (operation) {
  OperationState(data: null) => const LoadingView(),
  OperationState(:final data?) => DataView(data),
};
```

### Error first

Put error first when it should override cached-data rendering.

```dart
return switch (operation) {
  ErrorOperation(:final message) => ErrorView(message: message),
  OperationState(data: null) => const LoadingView(),
  OperationState(:final data?) => DataView(data),
};
```

### Payload guards

```dart
return switch (operation) {
  LoadingOperation() => const LoadingView(),
  ErrorOperation(:final message) => ErrorView(message: message),
  SuccessOperation(:final data) when data.isEmpty => const EmptyView(),
  SuccessOperation(:final data) => ResultsView(data),
};
```

For small gates, the convenience getters are clearer than a switch:

```dart
ElevatedButton(
  onPressed: operation.isNotLoading ? reload : null,
  child: Text(operation.isLoading ? 'Refreshing...' : 'Refresh'),
);
```

Available getters include `isLoading`, `isIdle`, `isSuccess`, `isError`, their `isNot...` counterparts, `hasData`, `hasNoData`, and `dataOrNull`.

## Host and widget mixins

`AsyncOperationMixin<T>` is host-neutral: implement `fetch`, publish in `operationChanged`, and call `disposeOperation` at the owner boundary. `StreamOperationMixin<T>` similarly supplies `stream`, awaitable `listen`/`cancel`, and awaitable `disposeOperation`. It does not auto-start or expose a widget notifier. Its default operation reports reads through `operationRead`.

The following table applies to **widget** adapters: `AsyncOperationStateMixin<T, Widget>` and `StreamOperationStateMixin<T, Widget>`.

## Widget mixin reference

| Purpose | Async mixin | Stream mixin |
|---|---|---|
| Source | `fetch()` | `stream()` |
| Start automatically | `loadOnInit` | `listenOnInit` |
| Start or restart | `load()` / `reload()` | `listen()` |
| Publish success manually | `setSuccess()` | `setData()` |
| Success callback | `onSuccess()` | `onData()` |
| Completion callback | Not applicable | `onDone()` |

Both mixins also expose:

- `operation` and `operationNotifier`;
- `setIdle`, `setLoading`, and `setError`;
- `onIdle`, `onLoading`, and `onError`;
- `errorMessage` for display-message formatting;
- `globalRefresh`, which defaults to `false`.

With the default `globalRefresh: false`, rebuild only the listening subtree with `ValueListenableBuilder`. Set it to `true` only when the entire owning widget must rebuild on each transition.

## Scope and trade-offs

Use this package when one operation benefits from explicit lifecycle state and exhaustive handling. It works especially well for:

- page and component data loading;
- pull-to-refresh with cached content;
- search and user-triggered work;
- form submissions and command buttons;
- Firestore, WebSocket, sensor, and connectivity streams;
- local controllers and existing state-management systems;
- tests that need precise operation-state assertions.

Use a larger state machine or orchestration layer when several operations must coordinate atomically, when offline synchronization is the main problem, or when the domain has many states that are not meaningfully idle/loading/success/error. You can still use `OperationState<T>` for individual operations inside that larger model.

## Migrating from 3.x

Rename widget uses of `AsyncOperationMixin<T, Widget>` to `AsyncOperationStateMixin<T, Widget>`. The single-argument `AsyncOperationMixin<T>` is now for external hosts. Likewise rename widget `StreamOperationMixin<T, Widget>` to `StreamOperationStateMixin<T, Widget>`; the single-argument stream mixin is host-neutral. Version 4 requires Dart 3.12 or newer; use a Flutter SDK that bundles it. The widget stream adapter now returns `Future<void>` from `listen` and exposes awaitable `cancel`. Await cleanup where possible; widget disposal routes asynchronous cleanup failures to the owning zone. Future widget notifications now precede lifecycle callbacks. Existing standalone state constructors/transitions remain supported. See the [migration guide](skills/flutter-operations/migration.md).

## Agent support

Install the optional skill for Claude Code, Codex, Cursor, Gemini CLI, and other supported agents:

```bash
npx skills add SaadArdati/flutter_operations --skill flutter-operations
```

Add `-g` for a global installation.

For Claude Code, install the plugin in one step from inside a session:

```text
/plugin install flutter-operations --marketplace SaadArdati/flutter_operations
```

Or from your terminal:

```bash
claude plugin marketplace add SaadArdati/flutter_operations
claude plugin install flutter-operations@flutter-operations
```


## Contributing

Issues and pull requests are welcome at [github.com/SaadArdati/flutter_operations](https://github.com/SaadArdati/flutter_operations).

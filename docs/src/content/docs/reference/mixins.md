---
title: Host & widget mixins
sidebar:
  order: 3
---

Host mixins and widget adapters share execution semantics, not lifecycle ownership.

## Host Future mixin

```dart
class UserController with AsyncOperationMixin<User> {
  UserController(this.repository);
  final UserRepository repository;

  @override
  Future<User> fetch() => repository.fetchUser();
  @override
  void operationChanged(OperationState<User> previous, OperationState<User> next) {
    publish(next);
  }
  @override
  String errorMessage(Object error, StackTrace trace) => 'Unable to load user';

  void dispose() => disposeOperation();
}
```

The example assumes an application-defined `publish` function. The host supplies `fetch(): FutureOr<T>`. It exposes `operation`, `operationController`, `initialOperationState`, `load`/`reload({cached = true})`, all AsyncOperation setters, `cancel({cached = true})`, and synchronous `disposeOperation()`. Its protected `attachMessage` delegates to the owned engine.

Host hooks include `operationRead`, `operationChanged(previous, next)`, `errorMessage`, `onLoading`, `onSuccess`, `onError`, and `onIdle`. The default `onError` logs via `dart:developer`. There is **no automatic startup, notifier, globalRefresh, or disposal**. Initial state defaults to idle. Override `initialOperationState` when needed.

## Host Stream mixin

`StreamOperationMixin<T>` requires `stream(): Stream<T>`. It exposes `operation`, `operationController`, `initialOperationState`, `listen({cached = true})`, `cancel({cached = true})`, and `disposeOperation()`. All three lifecycle commands return `Future<void>` with stream cleanup semantics. Setters use `setData`, not `setSuccess`. Hooks use `onData` and `onDone`, not `onSuccess`; other read/change/error/loading/idle hooks match the host Future mixin.

No auto-start or framework notification is provided. Await `disposeOperation` where the host lifecycle supports it.

## Widget Future adapter

`AsyncOperationStateMixin<T, K extends StatefulWidget>` applies to `State<K>`. Implement `fetch`. It owns its internal operation and `ValueNotifier<OperationState<T>> operationNotifier`.

| Option / member | Behavior |
| --- | --- |
| `loadOnInit` | true by default; starts loading, schedules load in a microtask |
| `globalRefresh` | false by default; true calls `setState` after notification when mounted |
| `operation` | Current snapshot |
| `operationNotifier` | Use with ValueListenableBuilder for local rebuilds |
| `load`, `reload`, setters | Same cached-state behavior as engine |
| `attachMessage` | Protected helper inside active fetch |
| `dispose` | Adapter disposes engine and notifier, then calls super |

When `loadOnInit` is false, initial state is idle. Initial loading already equals the first run's loading snapshot, so do not rely on an initial `onLoading` callback firing. The adapter does not expose a configurable host `operationController` or async `cancel` wrapper. Compose an engine if you need explicit concurrency/cancellation configuration.

## Widget Stream adapter

`StreamOperationStateMixin<T, K extends StatefulWidget>` requires `stream()`. `listenOnInit` defaults true, `globalRefresh` false. It exposes `operation`, `operationNotifier`, awaitable `listen` and `cancel`, `setIdle`, `setLoading`, `setData`, `setError`, and protected `attachMessage`. Its `setLoading({idle = false, cached = true})` additionally retains the widget compatibility option for setting idle.

Callbacks are `onLoading`, `onData`, `onError`, `onIdle`, `onDone`, and `errorMessage`. Disposal invalidates events immediately, disposes the notifier, and forwards async subscription cleanup errors to the current zone because Flutter disposal cannot await.

Widget adapters notify before lifecycle callbacks. Override lifecycle methods only with normal `super` calls. `setIdle` changes state but does not cancel an active subscription or invalidate pending Future work.

See [Widgets & commands](../../guides/widgets/) for rendering and [Injection & inheritance](../../guides/injection/) for host controller customization.

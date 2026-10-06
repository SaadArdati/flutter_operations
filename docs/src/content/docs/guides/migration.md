---
title: Migrate from 3.x
sidebar:
  order: 5
---

## Rename widget adapters

```dart
// Published 3.x, Flutter State only:
with AsyncOperationMixin<User, ProfilePage>
// 4.0, same widget ownership:
with AsyncOperationStateMixin<User, ProfilePage>
```

Rename the stream equivalent from `StreamOperationMixin<T, Widget>` to `StreamOperationStateMixin<T, Widget>`.

Do not merely remove the widget argument. `AsyncOperationMixin<T>` and `StreamOperationMixin<T>` now mean host-neutral mixins with explicit publication and disposal. They have no automatic startup, `operationNotifier`, or `globalRefresh`.

The widget Future adapter retains `fetch`, `loadOnInit`, `load`/`reload`, `operation`, notifier, setters, callbacks, messages, and globalRefresh. Its notifier continues to update before lifecycle callbacks, as in 3.x. With `globalRefresh` enabled, whole-widget rebuilding is now scheduled before those callbacks too.

The widget stream adapter delegates to StreamOperation. `listen` returns `Future<void>` and waits for previous cleanup. New `cancel` also returns cleanup completion. Flutter disposal invalidates immediately and forwards asynchronous cleanup errors to the owning zone.

## Adopt execution ownership when useful

Direct `OperationState<T>` remains supported. No rewrite is required solely to adopt 4.0. Compose an operation or use a host mixin when moving generation/disposal ownership out of handwritten host code. Keep one execution owner and explicit framework notification.

AsyncOperation introduces latest/first overlap policy. Cancel invalidates publication but does not abort external I/O. StreamOperation serializes resource cleanup before replacement.

## Update the SDK

Dart 3.12+ is required. Use a compatible Flutter SDK. Public named constructor arguments remain `onRead`, `onChanged`, `data`, etc.; private initializing formals do not rename the public API.

## Unreleased prototype names are not 3.x migration history

| Development prototype | Final 4.0 |
| --- | --- |
| `stateRead` / `onStateRead` | `onRead` |
| `stateChanged` / `onStateChanged` | `onChanged(previous, next)` |
| `onChanged(next)` after lifecycle callback | Two-argument callback before lifecycle callback |
| `OperationStateChanged<T>` | `OperationChanged<T>` |

Host hooks remain `operationRead` and `operationChanged`. Supplied `operationController` instances own their own callback wiring.

## Upgrade checklist

- Widget owners use the two-argument State adapter names.
- Hosts publish changes and dispose at their actual lifetime boundary.
- Operation change callbacks accept previous and next snapshots.
- Nullable/void success is handled independently from data presence.
- MobX tracks reads and changes; observable engine references are insufficient.
- Cubit publishes snapshots; stream hosts account for the `stream` naming collision.
- Riverpod owns a fresh controller per build lifetime.
- Stream cleanup failures are awaited or explicitly routed to an error boundary.

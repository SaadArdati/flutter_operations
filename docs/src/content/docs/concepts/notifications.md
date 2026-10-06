---
title: Reactive reads & change hooks
sidebar:
  order: 3
---

An operation is not a ChangeNotifier, signal, observable, or stream of state. Its hooks make integration explicit.

## Shared publication layer

Both execution engines extend `Operation<T>`. The base owns snapshots, read and change hooks, cached idle/loading/error transitions, error formatting, and owner-scoped message attachment. A subclass publishes through protected `emitState`, which enforces equality, disposal suppression, assignment, and callback ordering without creating tracked internal reads.

The base also owns the generation identity token and disposed flag. Protected helpers invalidate execution, test whether a generation is current, and disable publication idempotently. Success/data callbacks, public cancellation, and resource cleanup remain in the concrete engines. The base exposes `isDisposed` but does not define `cancel` or `dispose`. Async cleanup remains synchronous; stream cleanup remains awaitable.

## Engine hooks

`onRead()` runs on every `state` getter read. `onChanged(previous, next)` runs once per unequal transition, after assignment and before `onLoading`, `onSuccess`/`onData`, `onError`, or `onIdle`.

```dart
final operation = AsyncOperation<User>(
  onRead: trackRead,
  onChanged: (previous, next) => publish(next),
  onSuccess: (user) => recordLoaded(user),
);
```

Lifecycle callbacks see the assigned snapshot. Equal state suppresses change notification and its lifecycle callback. Stream `onDone` is a subscription event, not a state transition.

Constructor callbacks and method overrides are supported. Call `super.onRead()` and `super.onChanged(previous, next)` in subclasses to retain configured callbacks. There is no parallel `stateChanged` API.

## Host hooks

The default host controller maps engine hooks to `operationRead()` and `operationChanged(previous, next)`. Override them to track/publish into your framework. Injected controllers do not automatically receive that wiring.

## Tracking limits

`isRunning` and `isDisposed` are not reported through `onRead`. Nor are mutations inside normal mutable payloads. Make derived UI depend on tracked state or provide additional framework primitives when needed.

Read hooks track dependencies, not mutate state. Avoid recursive transitions from change hooks and do not throw from notification callbacks. A lifecycle callback can start a subsequent operation after the previous run has completed. Callbacks execute inside operation flow, not an isolated exception sink. Synchronous actions/batches do not span an `await`; Atom notification alone does not make unrelated writes transactional.

Keep navigation, snackbars, and analytics outside builders. Use lifecycle callbacks or framework listeners. Consumer-owned asynchronous side effects still need lifecycle checks even when operation-owned work is safe.

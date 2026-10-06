---
title: StreamOperation API
sidebar:
  order: 2
---

`StreamOperation<T>` owns one subscription. It starts idle. Pass a **factory** that can create a fresh source for every actual restart.

```dart
final users = StreamOperation<List<User>>(
  onChanged: (_, next) => publish(next),
  errorMessage: (_, _) => 'Unable to update users',
);
await users.listen(repository.watchUsers);
await users.cancel();
await users.dispose();
```

## Constructor and hooks

Constructor options include `initialState`, `onRead`, `onChanged`, `onLoading`, `onData`, `onError`, `onIdle`, `onDone`, and `errorMessage`. Types match AsyncOperation except `onData` replaces `onSuccess`; `onDone` takes no arguments. There is no async `concurrency` option and no `isRunning` property.

```dart
typedef StreamOperationSource<T> = Stream<T> Function();
```

Constructor callbacks are also overridable methods. The shared callback typedefs are documented in [AsyncOperation API](../async-operation/).

## Commands and properties

| Member | Contract |
| --- | --- |
| `state` | Snapshot; invokes `onRead()` |
| `isDisposed` | Lifecycle flag, not reactively tracked |
| `listen(source, {cached = true}) → Future<void>` | Completes when replacement is established, not when source ends |
| `cancel({cached = true}) → Future<void>` | Invalidates events and becomes idle immediately; awaits cleanup |
| `dispose() → Future<void>` | Blocks work/publication immediately; awaits cleanup; idempotent |
| `setIdle({cached = true})` | Changes state without stopping subscription |
| `setLoading({cached = true})` | Changes state without creating subscription |
| `setData(T data, {String? message})` | Publishes success |
| `setError(Object error, StackTrace trace, {String? message, cached = true})` | Publishes error with resolved display message |
| `attachMessage(String message)` | Attaches to next emission in this owner's subscription zone |

State hooks have the same assignment/change/lifecycle ordering and equality suppression as AsyncOperation. Manual setters do not invalidate events. Disposal preserves the last snapshot.

## Serialized replacement

1. A listen call invalidates old data, error, and done callbacks immediately.
2. It detaches the old subscription and enters loading.
3. It awaits the serialized cancellation chain.
4. Only the latest still-current request creates and subscribes to its source.

Rapid restarts do not create sources for requests superseded while waiting for cleanup. Cancellation that never finishes prevents replacement. This is resource ordering, not a queued stream-processing policy.

## Error and done behavior

Source-factory and subscription-establishment errors become error state. Stream data errors also become error state, but do not stop listening; a later value can recover to success. Natural completion calls current `onDone()` and leaves the last snapshot unchanged, including loading for an empty stream.

Cleanup failures propagate to the caller. `listen`, `cancel`, and `dispose` propagate subscription cancellation failures through their returned Futures. A rejected cleanup chain prevents later subscriptions on this engine. Handle/report the failure and replace the owner only once you have dealt with the resource failure; retrying `listen` is not a recovery mechanism.

When `setError` formats an absent message, the snapshot stores resolved text but `onError` receives the original message argument, possibly null. Read state for the resolved display text. Do not throw from callbacks or recursively mutate through notification hooks.

## Cancellation and disposal

Subscription cancellation invokes the source's cancellation contract. It does not promise that an unrelated producer, socket, or backend job stops. Shut down that resource at its actual owner when needed.

Await cleanup in asynchronous host lifecycles. Flutter's synchronous `dispose` cannot await. The widget adapter invalidates immediately and forwards asynchronous cleanup failures to its owning zone. A custom synchronous host must explicitly route failures rather than discard a cleanup Future. See [Lifecycle & testing](../../guides/testing/).

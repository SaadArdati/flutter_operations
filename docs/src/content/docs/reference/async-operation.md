---
title: AsyncOperation API
sidebar:
  order: 1
---

`AsyncOperation<T>` owns one Future or synchronous computation. It starts with `IdleOperation<T>` unless `initialState` is supplied.

## Constructor

| Named option | Type / default |
| --- | --- |
| `initialState` | `OperationState<T>?`, defaults to idle |
| `concurrency` | `AsyncOperationConcurrency`, defaults to `.latest` |
| `onRead` | `void Function()?` |
| `onChanged` | `OperationChanged<T>?` |
| `onLoading`, `onIdle` | `void Function()?` |
| `onSuccess` | `void Function(T)?` |
| `onError` | `OperationErrorCallback?` |
| `errorMessage` | `OperationErrorMessage?` |

Public option names do not have underscores. Dart 3.12 private initializing formals are an implementation detail.

```dart
typedef AsyncOperationWork<T> = FutureOr<T> Function();
typedef OperationChanged<T> =
    void Function(OperationState<T> previous, OperationState<T> next);
typedef OperationErrorCallback =
    void Function(Object error, StackTrace stackTrace, {String? message});
typedef OperationErrorMessage =
    String Function(Object error, StackTrace stackTrace);
```

## Commands and properties

| Member | Contract |
| --- | --- |
| `state` | Snapshot; getter invokes `onRead()` |
| `isRunning`, `isDisposed` | Lifecycle flags, not tracked state reads |
| `run(work, {cached = true}) → Future<void>` | Runs synchronous/Future work; loading then success/error |
| `setIdle({cached = true})` | Changes state, does not cancel work |
| `setLoading({cached = true})` | Changes state, does not start work |
| `setSuccess(T data, {String? message})` | Publishes a required result |
| `setError(Object error, StackTrace stackTrace, {String? message, cached = true})` | Publishes failure; formats absent message |
| `attachMessage(String message)` | Sets success message only inside this owner's run zone |
| `cancel({cached = true})` | Invalidates work publication and becomes idle |
| `dispose()` | Idempotently rejects future work and all publication |

The callback names are also overridable methods. `errorMessage(error, trace)` uses its configured formatter or `error.toString()`. Configure a resolved user-facing message if you display it.

## Concurrency is publication policy

**latest** starts every accepted call immediately. Only the newest generation may publish completion. Earlier calls keep executing and their own `run` Futures finish when their work finishes. A newer loading state can equal the old loading state and suppress duplicate callbacks even though new work started.

**first** ignores calls while the accepted work is running. It neither queues nor returns that work's result. The ignored call's returned Future completes without executing its closure.

Neither policy debounces, queues, retries, or aborts external I/O.

## Cancellation is not source abort

```dart
operation.cancel(cached: false);
```

This advances the generation, clears `isRunning`, and publishes idle. It does not cancel an HTTP request or Future. Source cancellation belongs to the repository/client. In `first` mode a new run can begin after cancel even if the old external work remains active.

Manual setters do not advance the generation. If you want to reject pending completion, call `cancel` rather than only `setIdle` or `setSuccess`.

## Errors and callbacks

Ordinary work failures become `ErrorOperation`. `run` is not a payload Future; inspect state instead of catching `run` for normal error UI. Formatter, change, and lifecycle callbacks must not throw because they execute inside the engine's control flow and are not isolated error handlers.

For `setError` without an explicit message, state stores the resolved formatter text, while the lifecycle callback receives the originally supplied `message` argument (possibly null). Read the current state for its resolved message. During a normal `run` failure the resolved text is passed explicitly.

State is assigned before `onChanged`, then its lifecycle callback. All are suppressed for equal snapshots or after disposal. Disposing leaves the last snapshot readable; it does not publish idle.

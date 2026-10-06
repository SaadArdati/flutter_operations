---
title: Choose an owner
sidebar:
  order: 2
---

Choose one execution owner before choosing a notification bridge.

| Requirement | Use | Lifecycle responsibility |
| --- | --- | --- |
| An existing framework or domain layer manages execution | `OperationState<T>` directly | Existing owner guards success, failure, cancellation, and disposal |
| Multiple operations or configurable concurrency | `AsyncOperation<T>` fields | Dispose each engine |
| One request on a store, Cubit, service, or controller | `AsyncOperationMixin<T>` | Publish changes and call `disposeOperation()` |
| One widget owns a request | `AsyncOperationStateMixin<T, Widget>` | Adapter owns initialization and disposal |
| Host owns repeated events | `StreamOperation<T>` | Await cancellation/disposal |
| One stream on an external host | `StreamOperationMixin<T>` | Publish changes and await `disposeOperation()` |
| One widget owns repeated events | `StreamOperationStateMixin<T, Widget>` | Adapter owns startup and routes cleanup failures |
| Reusable specialized behavior | Extend an operation | Subclass preserves engine contract |
| Host receives a specialized engine | Override `operationController` | Injection transfers disposal ownership |

A state manager does not automatically make direct state the best choice. If direct state would require writing a new generation counter, disposal guards, and stale-error handling, compose an operation instead.

Framework state exposes snapshots published by the operation. Keep the operation as the execution owner rather than updating those snapshots independently. Use a separate engine for each independent request or subscription. A host mixin represents one operation.

## Choose the payload from success semantics

| Type | Meaning of success |
| --- | --- |
| `User` | A user is required |
| `User?` | A successful lookup may return no user |
| `void` | Completion is the meaningful result |

Do not use an arbitrary nullable payload to represent a command. Do not infer success from `hasData`. Nullable lookups and commands can succeed without data.

## When a larger state machine is needed

Use domain orchestration for atomic coordination, offline sync, retries, queues, or states beyond idle/loading/success/error. Operations can remain fields inside that model. They do not replace domain invariants.

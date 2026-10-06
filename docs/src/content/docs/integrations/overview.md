---
title: Integration map
sidebar:
  order: 1
---

Keep state-manager dependencies outside the core package. Frameworks publish snapshots or track reads; operations own execution only when you choose that layer.

| Framework | Direct state | Composed engine | Host mixin |
| --- | --- | --- | --- |
| Cubit | emit guarded snapshots | `onChanged: (_, next) => emit(next)` | `operationChanged => emit(next)` for Future work |
| Riverpod | assign guarded state | Controller per build; `state = next` | Explicit controller replacement per build |
| Provider / ChangeNotifier | assign + notifyListeners | Read engine state; notify changes | Read operation; notify in host hook |
| Signals | publish guarded signal snapshots | Publish next into signal | Publish in host change hook |
| MobX | Observable snapshots + actions + guards | Atom read/change bridge | Atom-backed host read/change hooks |

For each framework, direct state is appropriate when execution is already owned elsewhere. Otherwise composition or a host mixin avoids inventing another generation/disposal mechanism. The runnable Future examples compare all three approaches. Stream examples compare composition and a host mixin, using delegation for Cubit because of its `stream` name collision.

## Futures and streams use the same notification boundary

A stream engine changes snapshots with `onData`/`onDone` rather than `onSuccess`. It also needs awaitable cleanup. A synchronous framework disposal hook must forward cleanup failures explicitly. This difference belongs at the owner boundary, not inside a UI builder.

## Dependency selection

Install only the framework your app uses. Import its own APIs alongside `package:flutter_operations/flutter_operations.dart`. The examples' framework dependencies are demonstration choices, not transitive requirements of flutter_operations.

- [Cubit & Bloc](../bloc/)
- [Provider & ChangeNotifier](../provider/)
- [Riverpod](../riverpod/)
- [Signals](../signals/)
- [MobX](../mobx/)

The snippets use application-specific repositories, models, and views. See the [example catalog](../../guides/examples/) for compiled application implementations and test locations.

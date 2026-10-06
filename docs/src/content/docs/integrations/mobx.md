---
title: MobX Atoms, computed & adapters
sidebar:
  order: 6
---

MobX integration must track operation state reads and changes. Observing the engine reference alone does not track its state transitions.

## Callback factory, no subclass or state mirror

```dart
abstract final class MobxOperations {
  static AsyncOperation<T> create<T>({String? name}) {
    final atom = Atom(name: name);
    return AsyncOperation<T>(
      onRead: atom.reportRead,
      onChanged: (_, _) => atom.reportChanged(),
    );
  }
}
```

This minimal factory forwards only a name. Add actual constructor options when your app needs error formatting, initial state, callbacks, or concurrency. The factory exposes only the options declared in its signature.

```dart
final user = MobxOperations.create<User>(name: 'user');
OperationState<User> get userState => user.state;
```

Read userState **inside** Observer/reaction. The forwarding getter is reactive because its engine read reaches the Atom. One Atom represents one independently tracked operation.

## Extend the engine

```dart
class MobxAsyncOperation<T> extends AsyncOperation<T> {
  MobxAsyncOperation({super.initialState, super.concurrency, super.errorMessage});
  final _atom = Atom(name: 'operation');

  @override
  void onRead() {
    _atom.reportRead();
    super.onRead();
  }
  @override
  void onChanged(OperationState<T> previous, OperationState<T> next) {
    super.onChanged(previous, next);
    _atom.reportChanged();
  }
}
```

MobX `Store` is a mixin. A generated store can extend this adapter and use `with Store`, then add normal annotations and generated part/class-alias setup. Inheritance exposes the full operation mutation API; composition can hide it behind domain commands.

## Host mixin bridge

```dart
mixin MobxOperationMixin<T> on AsyncOperationMixin<T> {
  final _atom = Atom(name: 'operation');

  @override
  void operationRead() {
    _atom.reportRead();
    super.operationRead();
  }
  @override
  void operationChanged(OperationState<T> previous, OperationState<T> next) {
    super.operationChanged(previous, next);
    _atom.reportChanged();
  }
}
```

Use `with Store, AsyncOperationMixin<User>, MobxOperationMixin<User>`, implement fetch, and disposeOperation. For a one-off bridge, override the operation getter to report an Atom read then return super.operation, and report changes to the same Atom. Do not redirect the getter to a second execution engine.

A specialized engine can also be injected through operationController. The receiving store owns disposal, and the injected engine owns its callback/configuration wiring. See [Injection](../../guides/injection/).

## Computed properties require tracked dependencies

A plain forwarding getter needs no `@computed`. Computed is useful for derived projections such as combined busy status, but requires normal Store/codegen setup and already-tracked dependencies.

`@observable` on an operation field tracks replacement, not inner state changes. Observable final fields and observable explicit getters are rejected by the generator. `@computed` around an untracked operation cannot make it reactive. Do not use a copied state or artificial revision counter to compensate for missing Atom hooks.

Mutable payload internals, isRunning, and isDisposed are not observed by state hooks. Atom notifications may run reactions immediately and do not provide an action/transaction for unrelated observable updates; apply MobX actions/batching where those writes require it. A synchronous action does not cover an await.

## Direct state and streams

Direct state uses observable snapshots plus appropriate actions and its own execution/lifecycle guards. StreamOperation supports the same Atom bridge through onRead/onChanged; host stream adapters use operationRead/operationChanged. Own and report asynchronous stream cleanup failures separately.

The snippets illustrate integration boundaries and omit application scaffolding. The runnable MobX Future comparison includes callback composition, host hooks, extension, computed projections, getter overrides, and injection. Regenerate its `.g.dart` with build_runner when changing annotated code; never hand-edit generated output.

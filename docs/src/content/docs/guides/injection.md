---
title: Injection & inheritance
sidebar:
  order: 3
---

## Compose by default for multiple operations

An operation field keeps execution reusable without occupying a superclass slot. It also lets a store hide mutation behind domain methods. Extend an operation when reusable behavior belongs to the operation itself, for example a MobX read/change bridge.

```dart
class TracedOperation<T> extends AsyncOperation<T> {
  TracedOperation({super.initialState, super.concurrency, super.errorMessage});

  @override
  void onChanged(OperationState<T> previous, OperationState<T> next) {
    super.onChanged(previous, next);
    trace(next);
  }
}
```

The example assumes an application-defined `trace` function. Forward the constructor options your adapter intends to support. A minimal subclass does not automatically expose every base constructor option.

Cubit, ChangeNotifier, and Notifier already occupy the superclass slot. MobX `Store` is a mixin and can accompany an operation superclass. See [MobX](../../integrations/mobx/).

## Inject through operationController

```dart
class UserStore with AsyncOperationMixin<User> {
  UserStore(this.repository, this.operationController);
  final UserRepository repository;

  @override
  final AsyncOperation<User> operationController;

  @override
  Future<User> fetch() => repository.fetchUser();
}
```

The injected engine is owned by the receiving store. Its inherited commands, state reads, message attachment, and `disposeOperation` route through `operationController`. The default lazy engine is never constructed when this getter is overridden.

Configure callbacks, concurrency, error formatting, and initial state on the supplied engine. Host hooks are wired only by the default controller implementation. Injection does not automatically attach `operationChanged`, `operationRead`, or lifecycle callbacks.

Return one stable instance during a host lifetime. Never create a new engine per getter read. Overriding only `operation` changes state reads but leaves commands routed through the original controller. Override `operationController` to replace both. Do not share one owned engine among multiple disposing hosts.

The same controller contract applies to `StreamOperationMixin`. A Riverpod build boundary may legitimately replace a controller for a new lifetime; it must dispose the exact old instance. See [Riverpod](../../integrations/riverpod/).

---
title: Signals
sidebar:
  order: 5
---

```dart
class UserStore with AsyncOperationMixin<User> {
  UserStore(this.repository);
  final UserRepository repository;
  final state = signal<OperationState<User>>(const IdleOperation());

  @override
  Future<User> fetch() => repository.fetchUser();
  @override
  String errorMessage(Object error, StackTrace trace) => 'Unable to load user';
  @override
  void operationChanged(OperationState<User> previous, OperationState<User> next) {
    state.value = next;
  }

  void dispose() {
    disposeOperation();
    state.dispose();
  }
}
```

`SignalBuilder(builder: (_) => UserView(store.state.value))` tracks the signal read. The signal exposes the current snapshot to the framework. The operation remains responsible for execution. Dispose the operation before its signal.

Composition publishes through `AsyncOperation(onChanged: (_, next) => state.value = next)`. Direct state publishes signal snapshots using the host's existing execution guards; guard both error and success paths.

Do not assume MobX Atom APIs exist in Signals. Publish operation snapshots into a signal using its supported API. A specialized bridge requires that library's actual primitives.

## Streams and owner changes

Use StreamOperation or StreamOperationMixin with the same signal publication hook. Dispose the stream engine before disposing its signal and handle asynchronous cleanup failures at the synchronous owner boundary.

When switching unrelated example owners inside one cached SignalBuilder subtree, key that subtree by the selected owner so dependencies bind to the new owner. The runnable comparisons demonstrate this. Ordinary mutable payload changes and engine lifecycle flags are not automatically made signal dependencies.

---
title: Provider & ChangeNotifier
sidebar:
  order: 3
---

```dart
class UserStore extends ChangeNotifier with AsyncOperationMixin<User> {
  UserStore(this.repository);
  final UserRepository repository;

  @override
  Future<User> fetch() => repository.fetchUser();
  @override
  String errorMessage(Object error, StackTrace trace) => 'Unable to load user';
  @override
  void operationChanged(OperationState<User> previous, OperationState<User> next) {
    notifyListeners();
  }
  @override
  void dispose() {
    disposeOperation();
    super.dispose();
  }
}
```

Create with `ChangeNotifierProvider(create: ...)`; read `store.operation` inside `Consumer<UserStore>`. Provider owns instances it creates. For an externally supplied `.value` instance, follow your application's ownership rules rather than disposing twice.

## Composition and direct state

Composition stores an operation with `onChanged: (_, _) => notifyListeners()` and reads its state. No copied snapshot field is needed. Direct state stores a snapshot, assigns transitions, and calls notifyListeners after each accepted transition. A direct owner must also supply generation/disposal protection for both success and failure.

## Streams

Compose StreamOperation or use StreamOperationMixin with `stream()` and the same notify hook. ChangeNotifier disposal is synchronous; invalidate the engine immediately and explicitly forward its cleanup Future errors to the owning zone. The [lifecycle guide](../../guides/testing/) shows the pattern. Do not notify after notifier disposal or silently discard a failed cleanup Future.

Provider adds subscription and injection convenience. It does not automatically observe nested operation mutation; notification remains your store's responsibility.

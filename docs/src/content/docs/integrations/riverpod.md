---
title: Riverpod build lifetimes
sidebar:
  order: 4
---

Use a `NotifierProvider.autoDispose<..., OperationState<User>>`. Watch the provider state for rendering and read its notifier for commands. The following example assumes an application-defined repository provider.

```dart
class UserNotifier extends Notifier<OperationState<User>> {
  late AsyncOperation<User> operation;

  @override
  OperationState<User> build() {
    final controller = AsyncOperation<User>(
      onChanged: (_, next) => state = next,
      errorMessage: (_, _) => 'Unable to load user',
    );
    operation = controller;
    ref.onDispose(controller.dispose);
    return controller.state;
  }

  Future<void> load() => operation.run(ref.read(repositoryProvider).fetchUser);
  void cancel() => operation.cancel();
}
```

The Notifier object can survive a rebuild. Create a fresh controller for each build lifetime. Do not reassign a late-final field in every build or reuse an already-disposed controller. Capture the local controller in disposal rather than a closure that later reads a replacement field.

## Host mixin alternative

Override `operationController` with a replaceable field and assign it in build. Wire `onRead: operationRead`, `onChanged: operationChanged`, `errorMessage`, and any host lifecycle callbacks explicitly when constructing that controller. Return its state; register the local instance's disposal. Implement fetch through `ref.read(repositoryProvider)` and publish through `operationChanged => state = next`.

Composition is shorter here. The mixin adds fetch/reload/setters/message helpers; it does not eliminate Riverpod build lifetime ownership.

## Direct state

A direct Notifier uses its existing async execution rules or manual generations. Guard publication after awaits with lifetime/current-generation checks on both success and error. The runnable direct example uses `ref.mounted` and invalidates its generation on disposal. Typed transitions alone do not prevent stale publication.

## Streams

Use the same controller-per-build lifetime for StreamOperation or StreamOperationMixin. `ref.onDispose` is a synchronous callback, so explicitly route cleanup Future failures to the captured owning error zone instead of returning an ignored Future. Await cancel/listen in commands where possible. The source must be restartable and old callbacks must not publish into a rebuilt lifetime.

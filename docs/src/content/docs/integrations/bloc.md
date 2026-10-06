---
title: Cubit & Bloc
sidebar:
  order: 2
---

## Future host mixin

```dart
class UserCubit extends Cubit<OperationState<User>>
    with AsyncOperationMixin<User> {
  UserCubit(this.repository) : super(const IdleOperation());
  final UserRepository repository;

  @override
  Future<User> fetch() => repository.fetchUser();
  @override
  String errorMessage(Object error, StackTrace trace) => 'Unable to load user';
  @override
  void operationChanged(OperationState<User> previous, OperationState<User> next) {
    emit(next);
  }
  @override
  Future<void> close() {
    disposeOperation();
    return super.close();
  }
}
```

Render `BlocBuilder<UserCubit, OperationState<User>>`; call inherited load/cancel. Keep Cubit initial state and engine initial state aligned if customizing them.

## Composition

For several operations or explicit concurrency, create `AsyncOperation<User>(initialState: state, onChanged: (_, next) => emit(next))` in the constructor. Run the repository method through it and dispose before `super.close()`. Render immutable snapshots rather than `Cubit<AsyncOperation<User>>`. Cubit suppresses repeated emissions of the same engine instance.

Direct-state owners call `emit(state.transitionTo...)` after their existing execution guards. They must guard both late success and late error and invalidate on close/cancel. Use direct state when the Cubit already manages execution and lifecycle safety.

## Stream naming collision

Cubit/BlocBase already has a `stream` getter. `StreamOperationMixin<T>` requires a `stream()` method. They cannot be mixed directly on the same Cubit.

Compose `StreamOperation<T>` in Cubit, or delegate to a separate domain host using the mixin and publish its changes into Cubit. The runnable stream comparison uses those alternatives; it is not a direct Cubit stream-mixin implementation. Await the engine/domain-host disposal in `close` before closing Cubit.

## Event-driven Bloc is not Cubit with a different name

Do not store an event handler's `Emitter` in a long-lived operation callback. It becomes invalid after the handler completes. Route changes through the Bloc event model and honor its event concurrency rules. The Cubit examples do not apply directly to Bloc event handlers.

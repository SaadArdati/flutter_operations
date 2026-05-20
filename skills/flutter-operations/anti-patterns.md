# flutter_operations: Anti-patterns

Shapes the type system and analyzer will not catch on their own.

## 1. Dropping cached data on transitions

Manually emitting a fresh `LoadingOperation<T>()` or `ErrorOperation<T>(message: ...)` without data inside a Cubit or Bloc throws away cached state. Pull-to-refresh feels broken; the screen flashes empty before the new payload arrives.

Inside the mixins this is handled automatically: `setLoading(cached: true)` and `setError(..., cached: true)` (both defaults) propagate `state.dataOrNull` into the new state. Manual `emit` calls outside the mixin need to do it themselves:

```dart
emit(LoadingOperation(data: state.dataOrNull));
// ...
emit(ErrorOperation(
  message: e.toString(),
  exception: e,
  stackTrace: st,
  data: state.dataOrNull,
));
```

## 2. Restating the type argument that inference already supplies

Operation state types take a single generic parameter `T` that the surrounding context already names. Inside a `Cubit<OperationState<User>>` or a class declared `with AsyncOperationMixin<User, MyWidget>`, every call to `emit(...)`, `setSuccess(...)`, or `setData(...)` expects an operation parameterized over `User`. Writing the generic again on the construction site is noise; Dart's type inference fills it in.

```dart
// Don't do this:
class UserCubit extends Cubit<OperationState<User>> {
  Future<void> load() async {
    emit(LoadingOperation<User>(data: state.dataOrNull));
    final user = await api.getUser();
    emit(SuccessOperation<User>(data: user));
  }
}

// Do this:
class UserCubit extends Cubit<OperationState<User>> {
  Future<void> load() async {
    emit(LoadingOperation(data: state.dataOrNull));
    final user = await api.getUser();
    emit(SuccessOperation(data: user));
  }
}
```

Why it matters: when you later change `User` to `User?` (the operation may produce null) or `void` (it is fire-and-forget), only the class signature needs updating. Construction sites stay valid. Explicit `<User>` annotations have to be found and rewritten everywhere.

The explicit generic IS needed in a few places:

- Standalone constants outside any typed context: `const SuccessOperation<void>(data: null)`.
- Type assertions in tests: `op as SuccessOperation<String>`, `isA<SuccessOperation<int>>()`.
- Documenting the type itself in prose or class diagrams.

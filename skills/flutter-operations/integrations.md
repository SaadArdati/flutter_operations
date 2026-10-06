# State-management integrations (4.0)

Choose one execution owner. Direct `OperationState` is appropriate when the framework/domain already manages work; composition and the host mixin supply generation tracking and disposal safety when it does not. These recipes assume application-specific `User`, repository, and rendering types. Configure user-facing error messages; snippets focus on the integration boundary.

## Comparison map

| Framework | Direct state | Composed operation | Host mixin |
|---|---|---|---|
| Cubit | `emit(next)` with manual guards | `onChanged: (_, next) => emit(next)` | `operationChanged => emit(next)` |
| Riverpod Notifier | `state = next` with manual guards | controller per build; publish `state` | override controller per build; publish `state` |
| Provider/ChangeNotifier | assign snapshot, `notifyListeners()` | read controller state, notify on changes | read `operation`, notify on changes |
| Signals | `signal.value = next` with manual guards | publish into signal from callback | publish into signal from host hook |
| MobX | observable snapshot + actions + manual guards | Atom-backed operation; observe its state | read/change hooks bridge to an Atom |

Runnable direct/composed/mixin comparisons: `example/lib/async/bloc_integration_example.dart`, `riverpod_integration_example.dart`, `provider_integration_example.dart`, and `signals_integration_example.dart`. MobX additionally demonstrates extension, getter overrides, and injection in `mobx_integration_example.dart`. These alternatives are demonstrations, not separate required packages.

## Cubit: mixin for one operation

```dart
class UserCubit extends Cubit<OperationState<User>>
    with AsyncOperationMixin<User> {
  UserCubit(this.repository) : super(const IdleOperation());
  final UserRepository repository;

  @override
  Future<User> fetch() => repository.fetchUser();

  @override
  void operationChanged(OperationState<User> previous, OperationState<User> next) {
    emit(next);
  }

  @override
  String errorMessage(Object error, StackTrace trace) => 'Unable to load user';

  @override
  Future<void> close() {
    disposeOperation();
    return super.close();
  }
}
```

`BlocBuilder<UserCubit, OperationState<User>>` renders snapshots; call inherited `load`/`cancel`. No manual generation counter. Keep initial Cubit and operation state aligned when customizing initialization.

Composition is useful for multiple operations or explicit configuration:

```dart
class UserCubit extends Cubit<OperationState<User>> {
  UserCubit(this.repository) : super(const IdleOperation()) {
    operation = AsyncOperation<User>(
      initialState: state,
      onChanged: (_, next) => emit(next),
      errorMessage: (error, trace) => 'Unable to load user',
    );
  }
  final UserRepository repository;
  late final AsyncOperation<User> operation;
  Future<void> load() => operation.run(repository.fetchUser);
  void cancel() => operation.cancel();

  @override
  Future<void> close() {
    operation.dispose();
    return super.close();
  }
}
```

A Bloc using event handlers can also compose operations, but do not retain an event handler's `Emitter` in a long-lived callback: it becomes invalid after that handler completes. Route publications through the Bloc's event model and respect its concurrency rules. The runnable example uses Cubit, not a claim that Cubit wiring can be pasted unchanged into Bloc event handlers.

## Provider / ChangeNotifier

```dart
class UserStore extends ChangeNotifier with AsyncOperationMixin<User> {
  UserStore(this.repository);
  final UserRepository repository;

  @override
  Future<User> fetch() => repository.fetchUser();
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

Create with `ChangeNotifierProvider(create: ...)`; `Consumer<UserStore>` reads `store.operation`. Provider handles disposal for instances it creates. Composition instead keeps an operation field with `onChanged: (_, _) => notifyListeners()` and reads its `.state`; no mirrored snapshot is needed. For manually supplied instances, follow Provider's ownership rules rather than disposing twice.

## Riverpod: tie controllers to a build lifetime

Use a `NotifierProvider.autoDispose<... , OperationState<User>>`. Watch its state and read its notifier for commands.

```dart
class UserNotifier extends Notifier<OperationState<User>> {
  late AsyncOperation<User> operation;

  @override
  OperationState<User> build() {
    final controller = AsyncOperation<User>(
      onChanged: (_, next) => state = next,
      errorMessage: (error, trace) => 'Unable to load user',
    );
    operation = controller;
    ref.onDispose(controller.dispose);
    return controller.state;
  }

  Future<void> load() => operation.run(ref.read(repositoryProvider).fetchUser);
  void cancel() => operation.cancel();
}
```

A Notifier can rebuild without replacing its object. Do not assign a `late final` controller on every build or reuse an already-disposed one. Register disposal on the local instance, not a closure that might later read a replacement field.

The host mixin also works, with explicit controller replacement and hook wiring:

```dart
class UserNotifier extends Notifier<OperationState<User>>
    with AsyncOperationMixin<User> {
  @override
  late AsyncOperation<User> operationController;

  @override
  OperationState<User> build() {
    final controller = AsyncOperation<User>(
      onRead: operationRead,
      onChanged: operationChanged,
      errorMessage: errorMessage,
      onLoading: onLoading,
      onSuccess: onSuccess,
      onError: onError,
      onIdle: onIdle,
    );
    operationController = controller;
    ref.onDispose(controller.dispose);
    return controller.state;
  }

  @override
  Future<User> fetch() => ref.read(repositoryProvider).fetchUser();
  @override
  void operationChanged(OperationState<User> previous, OperationState<User> next) {
    state = next;
  }
}
```

This is a controller replacement at a lifecycle boundary, not a new controller on each getter read. Composition is shorter here; the mixin adds familiar `fetch`, `reload`, setters, and message helpers. The direct-state example uses `ref.mounted` and a generation invalidated on disposal to guard both success and failure.

## Signals: publish snapshots through a signal

```dart
class UserStore with AsyncOperationMixin<User> {
  UserStore(this.repository);
  final UserRepository repository;
  final state = signal<OperationState<User>>(const IdleOperation());

  @override
  Future<User> fetch() => repository.fetchUser();
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

`SignalBuilder(builder: (_) => UserView(store.state.value))` tracks the signal read. Composition uses the same publication slot with `AsyncOperation(onChanged: (_, next) => state.value = next)`. The signal is a framework-facing snapshot, not an independent execution engine. Dispose the operation before its signal. If switching unrelated example owners under one cached SignalBuilder subtree, key that subtree by the selected owner (as the runnable comparison does).

Do not assume MobX's Atom API exists in Signals. A specialized read/write bridge is possible only with that library's supported primitives; publishing a signal is the straightforward supported integration here.

## MobX: make the operation state itself reactive

### Callback factory: no subclass or state mirror

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

This minimal factory exposes only a name. Forward constructor options when an application needs initial state, error formatting, callbacks, or concurrency; do not claim this tiny factory preserves every configuration option.

```dart
final user = MobxOperations.create<User>(name: 'user');
final products = MobxOperations.create<List<Product>>(name: 'products');

OperationState<User> get userState => user.state;
```

An Observer reading `userState` tracks the underlying Atom through the ordinary getter. `@computed` is optional for forwarding; useful for derived values such as combined busy status. Computed getters require the normal `Store`/codegen setup. Neither an observable operation reference nor a computed getter around an untracked operation observes nested mutations.

### Extend AsyncOperation

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

One adapter can be reused by many stores. A store can itself extend it: `abstract class _UserStore extends MobxAsyncOperation<User> with Store`. Add `@computed` projections and the usual generated class alias/part file when needed. MobX `Store` is a mixin, so it does not occupy the superclass slot; Cubit/ChangeNotifier/Notifier do. Extending exposes the full operation mutation API; composition can hide it behind domain methods.

### Reusable reactive host mixin

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

Use `with Store, AsyncOperationMixin<User>, MobxOperationMixin<User>` and implement `fetch`. Dispose through `disposeOperation`. No widget superclass required. For a local one-off bridge, overriding the `operation` getter to report an Atom read then returning `super.operation` also works, provided `operationChanged` reports changes to the same Atom.

### Controller getter override / injection

```dart
class UserStore with Store, AsyncOperationMixin<User> {
  UserStore(this.repository, this.operationController);
  final UserRepository repository;
  @override
  final AsyncOperation<User> operationController;
  @override
  Future<User> fetch() => repository.fetchUser();
}

// Ownership of this instance transfers to the store.
final store = UserStore(repository, MobxAsyncOperation<User>());
```

Alternatively, keep a final private controller and override its getter. All inherited commands, reads, message attachment, and disposal route through `operationController`. Do not override only `operation` to expose another engine. Injection does not automatically wire `operationChanged`, lifecycle callbacks, error formatting, or initial state from the host: configure those on the supplied instance. The unused default `late final` operation is never constructed.

The receiving store must dispose the controller. Return a stable instance within its lifetime, never a new operation per getter call. Use one Atom per independent operation and perform tracked state reads inside the Observer/reaction, not before entering it. Mutable payload internals and lifecycle flags are not made observable by state tracking. Atom notifications do not provide a transaction for unrelated observable updates; use appropriate MobX actions/batching when needed.

## Stream operations in external hosts

`StreamOperationMixin.stream()` conflicts with the `stream` getter inherited from Cubit/BlocBase. Do not apply this mixin directly to a Cubit or Bloc. Compose `StreamOperation<T>`, or delegate to a separate host using the mixin and publish its snapshots into the Cubit. The runnable stream Cubit example demonstrates both alternatives.

Compose `StreamOperation<T>` using the same publication/read bridge as AsyncOperation. Provide a fresh stream factory to `listen`. Await `cancel`/`dispose` where the lifecycle allows it, for example `Future<void> close() async { try { await operation.dispose(); } finally { await super.close(); } }` in Cubit. Synchronous Flutter/ChangeNotifier disposal must invalidate immediately and explicitly route cleanup Future failures to the owning error zone; never silently drop them. The engine rejects stale data, errors, and done callbacks. The host-neutral `StreamOperationMixin<T>` supplies `stream`, `listen`, `cancel`, and awaitable `disposeOperation`, plus publication and read hooks.

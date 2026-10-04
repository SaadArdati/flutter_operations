# flutter_operations use cases

Read the section that matches the state owner and source. The package does not require Bloc and does not require a mixin.

## Widget owns one Future or command

Use `AsyncOperationMixin<T, Widget>` for work whose lifecycle belongs to one widget: HTTP requests, database reads, computations, searches, permission checks, form submissions, saves, deletes, uploads, and similar commands.

```dart
class _ProfilePageState extends State<ProfilePage>
    with AsyncOperationMixin<User, ProfilePage> {
  @override
  Future<User> fetch() => repository.fetchUser(widget.userId);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: operationNotifier,
      builder: (context, state, _) => switch (state) {
        LoadingOperation(data: null) => const LoadingView(),
        ErrorOperation(:final message, data: null) => ErrorView(message),
        LoadingOperation(:final data?) ||
        ErrorOperation(:final data?) ||
        SuccessOperation(:final data) => ProfileView(data),
      },
    );
  }
}
```

The mixin handles startup, stale-result rejection, disposal, cached reloads, errors, callbacks, and optional success messages.

### Wait for user input

For search, confirmation, permission, or tap-triggered work:

```dart
@override
bool get loadOnInit => false;

void search(String value) {
  query = value;
  load(cached: false);
}
```

The initial state is `IdleOperation`. Call `setIdle(cached: true)` to return to ready while retaining data, or `setIdle(cached: false)` to clear it.

## Widget owns a Stream

Use `StreamOperationMixin<T, Widget>` for Firestore snapshots, WebSockets, connectivity, location, sensors, and other repeated sources.

```dart
class _ChatPageState extends State<ChatPage>
    with StreamOperationMixin<List<Message>, ChatPage> {
  @override
  Stream<List<Message>> stream() => repository.watchRoom(widget.roomId);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: operationNotifier,
      builder: (context, state, _) => switch (state) {
        LoadingOperation(data: null) => const LoadingView(),
        ErrorOperation(:final message, data: null) => ErrorView(message),
        LoadingOperation(:final data?) ||
        ErrorOperation(:final data?) ||
        SuccessOperation(:final data) => MessagesView(data),
      },
    );
  }
}
```

Set `listenOnInit => false` to start idle and call `listen()` later. `listen()` starts a new generation and replaces the current subscription. Late data and errors from older generations cannot replace current state. Disposal cancels the active subscription.

`setIdle()` does not cancel a subscription. The package has no public pause or stop API; use the source's own control mechanism or manage the subscription outside the mixin when that lifecycle is required.

### Per-emission messages

```dart
@override
Stream<Message> stream() async* {
  await for (final event in repository.events()) {
    if (event.message case final message?) attachMessage(message);
    yield event.data;
  }
}
```

The call must occur in the active `async*` flow immediately before its `yield`.

## Existing state manager owns the operation

Store `OperationState<T>` directly in Cubit, Bloc, Riverpod, Provider, ChangeNotifier, reducers, controllers, services, or plain Dart. State propagation remains the responsibility of that architecture.

### Cubit or Bloc

```dart
class UserCubit extends Cubit<OperationState<User>> {
  UserCubit(this.repository) : super(const IdleOperation());

  final UserRepository repository;

  Future<void> load() async {
    emit(state.transitionTo.loading());
    try {
      emit(state.transitionTo.success(data: await repository.fetchUser()));
    } catch (error, stackTrace) {
      emit(state.transitionTo.error(
        message: 'Could not load the user',
        error: error,
        stackTrace: stackTrace,
      ));
    }
  }
}
```

### Riverpod Notifier

```dart
class UserNotifier extends Notifier<OperationState<User>> {
  @override
  OperationState<User> build() => const IdleOperation();

  Future<void> load() async {
    state = state.transitionTo.loading();
    try {
      state = state.transitionTo.success(
        data: await ref.read(userRepositoryProvider).fetchUser(),
      );
    } catch (error, stackTrace) {
      state = state.transitionTo.error(
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
```

The operation model does not add stale-request protection to external state holders. If that holder permits concurrent runs, use the architecture's existing cancellation, generation, or concurrency mechanism.

### ChangeNotifier, ValueNotifier, or plain controller

```dart
class UserController extends ValueNotifier<OperationState<User>> {
  UserController(this.repository) : super(const IdleOperation());

  final UserRepository repository;

  Future<void> load() async {
    value = value.transitionTo.loading();
    try {
      value = value.transitionTo.success(data: await repository.fetchUser());
    } catch (error, stackTrace) {
      value = value.transitionTo.error(
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
```

The same transition shape works in Provider models, reducers, services, and plain Dart objects.

## Cached refresh and graceful failure

Loading and error states can carry the previous success value. `transitionTo` preserves it when data is omitted.

```dart
Future<void> refresh() async {
  state = state.transitionTo.loading();
  try {
    state = state.transitionTo.success(data: await repository.fetchItems());
  } catch (error, stackTrace) {
    state = state.transitionTo.error(
      message: 'Refresh failed',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
```

Use `data: null` only when cache must be cleared deliberately:

```dart
state = state.transitionTo.loading(data: null);
```

This models stale-while-refresh and stale-on-error without a separate cache field.

## Commands with no meaningful payload

Use `void` for save, delete, logout, submit, upload, confirmation, and similar commands.

```dart
class _SaveButtonState extends State<SaveButton>
    with AsyncOperationMixin<void, SaveButton> {
  @override
  bool get loadOnInit => false;

  @override
  Future<void> fetch() async {
    await repository.save(widget.draft);
    attachMessage('Saved');
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: operationNotifier,
      builder: (context, state, _) => ElevatedButton(
        onPressed: state.isNotLoading ? load : null,
        child: Text(state.isLoading ? 'Saving...' : 'Save'),
      ),
    );
  }
}
```

Do not add `if (!mounted)` between the awaited command and `attachMessage`; the mixin owns completion safety and the message must remain in the active fetch zone. Use normal mounted checks only for consumer-owned asynchronous callback work that accesses widget state or context.

## Required, optional, and absent success values

```dart
OperationState<User>  requiredUser;
OperationState<User?> optionalUser;
OperationState<void>  saveCommand;
```

- `User`: every success must contain a user.
- `User?`: successful lookup may legitimately find no user.
- `void`: success is completion itself.

Do not model a command with an arbitrary nullable payload merely to permit null.

## Explicit state machines

Use `transitionTo` when the variant changes:

```dart
state = state.transitionTo.loading();
state = state.transitionTo.success(data: result, message: 'Loaded');
state = state.transitionTo.error(message: 'Offline', error: error);
state = state.transitionTo.idle();
```

Use `copyWith` when the variant stays the same:

```dart
final updated = errorState.copyWith(
  message: 'Please try again',
  stackTrace: null,
);
```

Destination availability follows the receiver's static or promoted type. Concrete variants omit their own destination; base `OperationState<T>` exposes every destination.

## Side effects

Use mixin callbacks such as `onSuccess`, `onData`, and `onError` for widget-owned side effects. In Bloc, Riverpod, Provider, or another architecture, use its listener mechanism. Keep navigation, snackbars, and analytics outside rendering branches.

## When not to use it alone

Use a larger orchestration or domain state machine when:

- several operations must coordinate atomically;
- offline synchronization is the main problem;
- retry, debounce, cancellation, or queueing is required;
- domain states do not fit idle/loading/success/error.

Individual `OperationState<T>` fields can still represent component operations inside that larger model.

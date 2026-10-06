# flutter_operations use cases

Read the section that matches the state owner and source.

Prefer success/data UI, including empty-data UI, last when semantically safe. Keep loading/error/idle-specific branches first; preserve error precedence and put idle before its loading supertype. This is a style preference, not a correctness requirement.

- One widget owns a request: use the Future mixin recipe.
- One widget owns live updates: use the Stream mixin recipe.
- An existing state manager owns the work: choose direct state, composed `AsyncOperation`, or the host mixin using [integrations.md](integrations.md).
- A user action starts work: disable automatic startup; choose `void` only when completion itself is the result.
- Refreshing the same resource: retain cache. Changing search criteria or identity: decide explicitly whether to clear it.

Examples use direct display text. In an app, substitute resolved localization strings, not translation keys or exception strings. Manual async snippets below show publication mechanics; retain the host's disposal and stale-result guards in real integrations.

## Widget owns one Future or command

Use `AsyncOperationStateMixin<T, Widget>` for work whose lifecycle belongs to one widget: HTTP requests, database reads, computations, searches, permission checks, form submissions, saves, deletes, uploads, and similar commands.

```dart
class _ProfilePageState extends State<ProfilePage>
    with AsyncOperationStateMixin<User, ProfilePage> {
  @override
  Future<User> fetch() => repository.fetchUser(widget.userId);

  @override
  String errorMessage(Object error, StackTrace stackTrace) =>
      'Failed to load user';

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: operationNotifier,
      builder: (context, state, _) => switch (state) {
        LoadingOperation(data: null) => const LoadingView(),
        ErrorOperation(:final message, data: null) =>
          ErrorView(message ?? 'Unable to load content'),
        OperationState(:final data?) => ProfileView(data),
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

## Host owns a stream subscription

```dart
final users = StreamOperation<List<User>>(
  onChanged: (previous, next) => publish(next),
  errorMessage: (error, trace) => 'Unable to update users',
);
await users.listen(repository.watchUsers);
// At cancellation/disposal boundaries:
await users.cancel();
await users.dispose();
```

The factory is invoked for each actual replacement, not for superseded restart requests. `listen` returns when subscribed; natural completion invokes `onDone` without discarding state. Stream errors publish an error and allow later data recovery. Async cancellation is serialized, so a source whose cancellation never finishes also prevents replacement; shut down the underlying source when its cleanup requires that. Cleanup failures throw rather than pretending resources were released.

Use the same framework publication/read bridges as AsyncOperation. No new state-management dependency or inheritance hierarchy is required. Use `StreamOperationMixin<T>` on external hosts and `StreamOperationStateMixin<T, Widget>` on widgets. For messages, call this instance's `attachMessage` inside its source's active `async*`/transformer zone before the corresponding emission.

## Widget owns a Stream

Use `StreamOperationStateMixin<T, Widget>` for Firestore snapshots, WebSockets, connectivity, location, sensors, and other repeated sources.

```dart
class _ChatPageState extends State<ChatPage>
    with StreamOperationStateMixin<List<Message>, ChatPage> {
  @override
  Stream<List<Message>> stream() => repository.watchRoom(widget.roomId);

  @override
  String errorMessage(Object error, StackTrace stackTrace) =>
      'Failed to load messages';

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: operationNotifier,
      builder: (context, state, _) => switch (state) {
        LoadingOperation(data: null) => const LoadingView(),
        ErrorOperation(:final message, data: null) =>
          ErrorView(message ?? 'Unable to load content'),
        OperationState(:final data?) => MessagesView(data),
      },
    );
  }
}
```

Set `listenOnInit => false` to start idle and call `listen()` later. `listen()` starts a new generation and replaces the current subscription. Late data and errors from older generations cannot replace current state. Disposal cancels the active subscription.

`setIdle()` does not cancel a subscription. Use `await cancel()` to invalidate events and await cancellation. `listen()` also awaits previous cleanup before replacing the subscription; source factories must be restartable.

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

## Standalone execution

```dart
final operation = AsyncOperation<User>(
  concurrency: AsyncOperationConcurrency.latest,
  onChanged: (previous, next) => publish(next),
  errorMessage: (error, trace) => 'Unable to load user',
);

await operation.run(repository.fetchUser);
await operation.run(repository.fetchUser, cached: false);
operation.cancel();
operation.dispose();
```

Dispose at the owning lifecycle boundary, not after each reusable run. `run` returns `Future<void>`; read the result from `state`. Ordinary work failures become `ErrorOperation`; inspect/listen to state rather than expecting a result or using a catch around `run` as the error UI. Callbacks must not throw: they execute inside the operation flow, not an isolated error sink.

`first` ignores a call while running; `latest` starts it and suppresses earlier results. Cancellation invalidates publication, not the source Future. `setIdle()` merely changes state; it does not cancel pending work.

### Success messages

```dart
await operation.run(() async {
  final response = await repository.fetchResponse();
  operation.attachMessage(response.message);
  return response.user;
});
```

A message is scoped to its receiving operation and run. One operation cannot attach a message to another's active run.

## Existing state manager owns the operation

See [integrations.md](integrations.md) for complete ownership/notification recipes and runnable comparisons. Keep one source of execution truth: either the framework's existing async machinery or `AsyncOperation`, not competing generation counters.

### Direct state when execution is already owned

Direct state carries no lifecycle protection. A manual owner must guard success and failure, cancellation, and disposal, as shown in the direct variants of the examples. A minimal controller shape:

```dart
class UserController {
  UserController(this.repository);
  final UserRepository repository;
  OperationState<User> state = const IdleOperation();
  int _generation = 0;
  bool _disposed = false;

  Future<void> load() async {
    if (_disposed) return;
    final generation = ++_generation;
    state = state.transitionTo.loading();
    try {
      final user = await repository.fetchUser();
      if (_disposed || generation != _generation) return;
      state = state.transitionTo.success(data: user);
    } catch (error, trace) {
      if (_disposed || generation != _generation) return;
      state = state.transitionTo.error(
        error: error, stackTrace: trace, message: 'Unable to load user',
      );
    }
  }

  void cancel() {
    if (_disposed) return;
    _generation++;
    state = state.transitionTo.idle();
  }

  void dispose() { _disposed = true; _generation++; }
}
```

Add the framework's publication mechanism where state is assigned. Prefer `AsyncOperation` if this lifecycle machinery would otherwise be newly implemented.

## Cached refresh and graceful failure

Loading and error states can carry the previous success value. `transitionTo` preserves it when data is omitted.

```dart
// Execution owns cache and lifecycle safety.
Future<void> refresh() => operation.run(repository.fetchItems);
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
    with AsyncOperationStateMixin<void, SaveButton> {
  @override
  bool get loadOnInit => false;

  @override
  Future<void> fetch() async {
    await repository.save(widget.draft);
    attachMessage('Saved');
  }

  @override
  String errorMessage(Object error, StackTrace stackTrace) =>
      'Failed to save changes';

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
- retries, debounce, underlying I/O cancellation, or queueing is required;
- domain states do not fit idle/loading/success/error.

Individual `OperationState<T>` fields can still represent component operations inside that larger model.

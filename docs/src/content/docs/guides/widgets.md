---
title: Widgets, refresh & commands
sidebar:
  order: 1
---

## Widget-owned request

The following example assumes application-defined `ProfilePage`, repository, and view types.

```dart
class _ProfilePageState extends State<ProfilePage>
    with AsyncOperationStateMixin<User, ProfilePage> {
  @override
  Future<User> fetch() => widget.repository.fetchUser(widget.userId);

  @override
  String errorMessage(Object error, StackTrace trace) => 'Unable to load user';

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: operationNotifier,
    builder: (context, state, _) => switch (state) {
      LoadingOperation(data: null) => const LoadingView(),
      ErrorOperation(data: null, :final message) => ErrorView(message),
      OperationState(:final data?) => ProfileView(data),
    },
  );
}
```

The adapter starts work, rejects stale results, updates the notifier, and disposes with the widget. Keep `globalRefresh` false for local rebuilding. Set it true only when the whole widget needs state changes.

Prefer success/data UI, including successful empty data, last when semantics allow. Keep idle before loading when distinguished, and preserve intentional error precedence.

## Wait for user input

```dart
@override
bool get loadOnInit => false;

void search(String value) {
  query = value;
  load(cached: false);
}
```

This starts idle. A new search discards previous identity's cache. Normal `reload()` preserves content during refresh and failure. Execution does not debounce input; add debounce at the input owner if required. When widget configuration changes, decide in `didUpdateWidget` whether to reload with cleared cache rather than expecting the adapter to watch identifiers.

## Commands have void success

```dart
class _SaveButtonState extends State<SaveButton>
    with AsyncOperationStateMixin<void, SaveButton> {
  @override
  bool get loadOnInit => false;

  @override
  Future<void> fetch() async {
    await widget.repository.save(widget.draft);
    attachMessage('Saved');
  }

  @override
  String errorMessage(Object error, StackTrace trace) => 'Unable to save';

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: operationNotifier,
    builder: (context, state, _) => ElevatedButton(
      onPressed: state.isNotLoading ? load : null,
      child: Text(state.isLoading ? 'Saving...' : 'Save'),
    ),
  );
}
```

Operation-owned work does not need a duplicate mounted check between its awaited command and message attachment. Consumer-owned asynchronous UI work in callbacks still requires normal lifecycle checks. Do not navigate or show snackbars in a builder.

## Widget-owned stream

Use `StreamOperationStateMixin<List<Message>, ChatPage>`, implement `stream() => widget.repository.watchRoom(widget.roomId)`, and render `operationNotifier` the same way. `listenOnInit => false` starts idle. `await listen()` establishes a replacement; `await cancel()` invalidates and awaits cleanup. `setIdle()` alone leaves the source subscribed.

Use an `async*` source when mapping per-event messages, with attachment immediately before yield. See [Messages & errors](../messages/) and [StreamOperation API](../../reference/stream-operation/).

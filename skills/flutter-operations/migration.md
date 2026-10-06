# Migrating to 4.0

## Published 3.x → 4.0

### Widget Future mixin renamed

```dart
// 3.x: Flutter State only
with AsyncOperationMixin<User, ProfilePage>

// 4.0: Flutter State adapter
with AsyncOperationStateMixin<User, ProfilePage>
```

The widget adapter retains `fetch`, `loadOnInit`, `load`/`reload`, `operation`, `operationNotifier`, setters, callbacks, `attachMessage`, and `globalRefresh`. Keep using `ValueListenableBuilder` for local rebuilding. Its notifier continues to update before the corresponding lifecycle callback, as in 3.x. With `globalRefresh` enabled, whole-widget rebuilding is now scheduled before those callbacks too.

`AsyncOperationMixin<T>` now means the host-neutral mixin, with one type parameter. It has no `loadOnInit`, `operationNotifier`, `globalRefresh`, or automatic disposal. Do not merely remove the widget type argument from a widget's existing mixin declaration; rename to the widget adapter instead.

Rename the 3.x widget `StreamOperationMixin<T, Widget>` to `StreamOperationStateMixin<T, Widget>`; `StreamOperationMixin<T>` is now host-neutral. The widget adapter keeps widget ownership and now delegates to `StreamOperation<T>`. Its `listen` returns `Future<void>` and waits for prior cancellation before subscribing. New `cancel` also returns cleanup completion. Flutter disposal invalidates immediately and forwards asynchronous cleanup errors to the owning zone. External hosts can compose the engine or use `StreamOperationMixin<T>` with explicit publication and awaitable disposal.

### New execution layer

`AsyncOperation<T>` owns one operation's transitions and generations. Call `run(work)` and dispose it at its owner's lifecycle boundary. Choose default `latest` or `first` concurrency. `cancel` invalidates results and becomes idle; it does not cancel underlying I/O. Direct `OperationState<T>` remains supported, with no changes required solely to adopt 4.0.

External hosts can compose operations, extend them, or use `AsyncOperationMixin<T>` with `fetch` and `operationChanged`. Replace hand-written generation/disposal logic only when transferring execution ownership to the operation. Framework notification remains explicit.

The new stream host mixin cannot be applied directly to Cubit/BlocBase because its `stream()` method conflicts with their `stream` getter. Compose the engine or delegate to a separate host instead.

### SDK

The package now requires Dart 3.12 or later, including private named initializing formals used internally. Public named constructor arguments remain `onRead:`, `onChanged:`, `onSuccess:`, `data:`, etc.—do not prefix them with underscores. Use a Flutter SDK that bundles a compatible Dart SDK; the Flutter constraint alone does not override the Dart constraint.

### Callback and stream details

State and lifecycle callbacks run only for unequal snapshots. Repeated equal stream values therefore do not invoke `onData`; observe the source separately if every event matters. `onDone` runs on natural completion, not cancellation, and keeps the last snapshot. Manual setters do not invalidate pending work or cancel subscriptions.

Error snapshots resolve omitted messages through `errorMessage`, but `onError` receives the explicit message argument and can receive null. Default engine formatting is diagnostic `error.toString()`. Callback failures are not an isolated error boundary.

## Unreleased prototype → final 4.0 API

These names existed during development, not in the published 3.x API:

| Prototype | Final |
|---|---|
| `stateRead` / `onStateRead` | `onRead` |
| `stateChanged` / `onStateChanged` | `onChanged(previous, next)` |
| `onChanged(next)` after lifecycle callback | `onChanged(previous, next)` before lifecycle callback |
| `OperationStateChanged<T>` callback typedef | `OperationChanged<T>` |

The host mixin hooks remain `operationRead` / `operationChanged`; do not rename them to the engine hooks. Its `operationController` can be overridden for injection or lifecycle-bound replacement. The supplied controller owns its configuration and callbacks; host hooks are not automatically attached. The default instance is lazy and remains unconstructed when the controller is overridden.

## Verification checklist

- Widget Future mixins use the new two-argument State adapter name.
- Host mixins use one type argument and explicit publication/disposal.
- No one-argument operation `onChanged` callbacks remain.
- MobX tracks reads and changes; annotating the operation field alone is insufficient.
- Cubit state stays `OperationState<T>` if BlocBuilder must react to each transition.
- Riverpod reconstructs and disposes the exact controller per build lifetime.
- Cancel/dispose suppress late completion; callbacks see the assigned state.
- Nullable/void success is handled independently from non-null data presence.

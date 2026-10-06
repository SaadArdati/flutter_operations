# flutter_operations: Common mistakes

## Using object patterns as null checks

Do not write `OperationState(data: Object())`. Use `OperationState(:final data?)` when rendering that data, or `OperationState(data: _?)` when only its presence matters. Use `data: null` for absence and omit the property when data is irrelevant.

Do not mechanically replace `Object()` with `final data` or `_`: those also match null. A shared non-null branch does not cover successful null results (`T?`) or completion-only success (`void`); give those explicit success arms.

## Rebuilding a state just to copy cache

When a current state exists, transition from it. Constructors are for initial states; `copyWith` updates the same variant.

```dart
emit(state.transitionTo.loading());
// After awaiting and checking the owner's lifecycle/concurrency guards:
emit(state.transitionTo.success(data: user));
// In the guarded catch branch:
emit(state.transitionTo.error(
  message: 'Failed to load user',
  error: error,
  stackTrace: stackTrace,
));
```

Loading, idle, and error transitions retain data when omitted. Explicit `data: null` clears it. Success requires a result. Transitions do not add race protection or disposal checks to an external state holder.

## Repeating an inferred type

Put the type on the owner, not on every constructor:

```dart
OperationState<User?> state = const IdleOperation();
OperationState<void> command = const SuccessOperation(data: null);
```

A typed `emit(...)`, return, assignment, or explicitly typed generic call also supplies context. Write `signal<OperationState<User>>(IdleOperation())`, not `signal<OperationState<User>>(IdleOperation<User>())`; the outer call already supplies the payload type. Do not repeat `<User>`, `<User?>`, or `<void>` there. With no contextual type, retain the argument when needed: `final state = IdleOperation<User>();`. Keep types in declarations, casts, and type assertions. Changing the payload type can still require changing the actual success value.

## Displaying diagnostics as an error message

`message` is user-facing text, not an exception dump. Use resolved localized or direct text. Store the original exception and trace separately in `error` and `stackTrace`.

The operation and mixin error formatters default to `error.toString()`. You should ideally override that default if the developer cares:

```dart
@override
String errorMessage(Object error, StackTrace stackTrace) =>
    'Failed to load user';
```

`message ?? 'Failed to load user'` in a renderer only handles null. It cannot sanitize a diagnostic string already stored in `message`.

The message can be used for internal developer logging for easy semantic understanding separate from the error, telling the developer why or what happened that the error object cannot clearly convey. The message can also be used for user-facing content.


Localized user-facing message.
```dart
message: context.l10n('user_load_failed'),
```

Unlocalized user-facing message.
```dart
message: 'User load failed. Please try again later.',
```

Dev only, reports to logging framework if needed.
```dart
message: 'Failed to retieve user data during cubit init.',
```

## Choosing the wrong owner

Use `AsyncOperationStateMixin<T, Widget>` and `StreamOperationStateMixin<T, Widget>` on Flutter State. Use `AsyncOperationMixin<T>` / `StreamOperationMixin<T>` on external hosts, or compose `AsyncOperation<T>` / `StreamOperation<T>` fields. Direct `OperationState<T>` is for owners that already manage execution or deliberately implement its guards; do not force manual generations just because the host is a Cubit or Notifier.

## Expecting nested mutation to notify a framework

`Cubit<AsyncOperation<User>>` does not emit inner transitions. Repeated `emit(state)` is suppressed by equality. Publish `OperationState<User>` snapshots through a composed operation or host mixin instead.

MobX `@observable` on an operation field tracks replacement, not inner changes. The generator rejects observable final fields and observable explicit getters. `@computed` cannot create observability: its dependencies must already report reads. Use an Atom bridge, not a copied state field or artificial revision counter. Ordinary forwarding getters remain reactive when they reach a tracked read. `Store` is a mixin, so it can accompany an operation superclass.

Signals/Cubit/Riverpod snapshots are framework publication slots. Do not treat them as separate execution owners or mutate them independently of the controller when using operation-backed execution.

## Replacing only the visible state getter

Overriding `operation` to return a second controller's state does not reroute commands. Override `operationController` instead. Return the same instance during a host lifecycle. A supplied controller owns its initial state, concurrency, callbacks, and disposal; the mixin does not automatically attach host hooks to it. Its unused `late final` default is never constructed.

## Forgetting host disposal or Riverpod rebuilds

Call `disposeOperation` in Cubit `close` or ChangeNotifier/store disposal; composition disposes the owned operation. Injection transfers ownership; do not share one controller between disposing hosts. Riverpod may rebuild the same Notifier: construct a fresh controller per `build`, capture it in `ref.onDispose(controller.dispose)`, and override the mixin controller when using that pattern. A disposed lazy default cannot be reused after rebuilding.

## Confusing state and execution

`setIdle`, `setSuccess`, and other manual setters do not cancel current work. Use `cancel` to invalidate pending results; external work continues unless separately canceled. State hooks track `state`, not `isRunning`, `isDisposed`, or mutations inside an ordinary mutable payload.

## Splitting callback timing or assuming transactions

Use one `onChanged(previous, next)` notification after state assignment and before lifecycle callbacks. Atom notification can run reactions immediately; it does not make updates to other stores atomic. Apply framework action/batch boundaries where coordinated synchronous writes require them. A synchronous action does not span an await.

## Repeating variants for identical content

After handling variant-specific loading/error/idle behavior, use one `OperationState(:final data?) => DataView(data)` arm instead of OR-ing Loading, Error, and Success patterns that render the same content. Use `:final data` only when the renderer accepts the nullable payload. Keep distinct arms for different overlays or behavior, and account for successful null/void results.

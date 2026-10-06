---
title: State & exhaustive rendering
sidebar:
  order: 1
---

`OperationState<T>` is sealed. Its variants carry a snapshot, not execution or notification machinery.

| Variant | Data | Other fields |
| --- | --- | --- |
| `IdleOperation<T>` | Optional cache (`T?`) | Ready, not actively loading |
| `LoadingOperation<T>` | Optional cache (`T?`) | Work in progress |
| `SuccessOperation<T>` | Exactly `T`, required by constructor | Optional success `message` |
| `ErrorOperation<T>` | Optional cache (`T?`) | Optional `message`, `error`, `stackTrace` |

`IdleOperation` extends `LoadingOperation`. Put idle first when its UI differs. A loading pattern includes idle when no idle arm exists. `isLoading` excludes idle.

## Required, nullable, and void results

```dart
OperationState<User> user = const IdleOperation();
OperationState<User?> lookup = const SuccessOperation(data: null);
OperationState<void> save = const SuccessOperation(data: null);
```

`SuccessOperation<User>(data: null)` is a compile-time error. Success data is nullable only when `T` permits it. `dataOrNull` widens success data to `T?` for uniform cache access.

Prefer success or shared data branches last, including empty-result UI, when this preserves matching behavior. Keep idle before loading when their views differ.

## Share identical content branches

This example assumes `state` is `OperationState<List<User>>` and content does not need refresh/error overlays.

```dart
return switch (state) {
  LoadingOperation(data: null) => const LoadingView(),
  ErrorOperation(data: null, :final message) =>
    ErrorView(message ?? 'Unable to load users'),
  OperationState(:final data?) => UserList(data),
};
```

This is exhaustive for non-nullable success, not for nullable or void success. Add an explicit success arm for successful absence/completion. When the renderer intentionally accepts nullable data, `OperationState(:final data)` can combine cases while preserving the meaning of a null result.

## Preserve distinct behavior

```dart
return switch (state) {
  IdleOperation(data: null) => const StartView(),
  IdleOperation(:final data?) => Preview(data),
  LoadingOperation(data: null) => const LoadingView(),
  LoadingOperation(:final data?) => DataView(data, refreshing: true),
  ErrorOperation(data: null, :final message) => ErrorView(message),
  ErrorOperation(:final data?, :final message) =>
    DataView(data, error: message),
  SuccessOperation(:final data) => DataView(data),
};
```

Keep separate branches when they render different content. A nullable lookup also needs an explicit branch for successful absence.

```dart
return switch (lookup) {
  LoadingOperation(data: null) => const LoadingView(),
  ErrorOperation(:final message) => ErrorView(message),
  SuccessOperation(data: null) => const NoUserView(),
  OperationState(:final data?) => ProfileView(data),
};
```

For a command, match `SuccessOperation()` independently from data presence.

## Pattern vocabulary

| Intent | Pattern |
| --- | --- |
| Bind with declared nullability | `:final data` |
| Bind only a non-null value | `:final data?` |
| Check non-null without binding | `data: _?` |
| Match absence | `data: null` |
| Ignore data | Omit the property |

Bare `_` and `final data` also accept null. Use null-check patterns, not object patterns as null markers.

## Convenience getters and equality

Common getters include `data`, `dataOrNull`, `hasData`, `hasNoData`, `isLoading`, `isIdle`, `isSuccess`, `isError`, and each status's negation (`isNotLoading`, `isNotIdle`, `isNotSuccess`, `isNotError`). Use these for small gates instead of a full rendering switch.

Equality compares variant fields using the payload's own equality. Normal lists use identity equality unless your payload implements deeper equality. State immutability does not freeze mutable payloads. Error equality includes data, message, error, and stack trace; success includes its message. Equal snapshots suppress engine publication and lifecycle callbacks.

---
title: Messages & user-facing errors
sidebar:
  order: 2
---

`message` is optional contextual text. Keep diagnostics in `error` and `stackTrace`; resolve display text through your localization system before storing it. A renderer's null fallback cannot sanitize an exception string already stored in message.

```dart
final operation = AsyncOperation<User>(
  errorMessage: (_, _) => 'Unable to load your profile. Please try again.',
);
```

The default formatter is `error.toString()`, useful diagnostically but not generally suitable for display. Host and widget mixins can override `errorMessage`.

## Attach success messages to their execution owner

```dart
await operation.run(() async {
  final response = await repository.fetchResponse();
  if (response.message case final message?) {
    operation.attachMessage(message);
  }
  return response.user;
});
```

Attachment works only in that operation's active execution zone. An outside call is ignored. One owner cannot attach text to another owner's active run. Async messages belong to the successful run; work errors use error formatting instead.

The host/widget protected helper belongs inside `fetch()`. If multiple messages attach before completion, the latest value wins.

## Stream messages are consumed per emission

```dart
@override
Stream<User> stream() async* {
  await for (final event in repository.events()) {
    if (event.message case final message?) attachMessage(message);
    yield event.user;
  }
}
```

Attach in the active source's zone immediately before its corresponding emission. The message cell is cleared after a data event; it does not leak to the next one. Error and done events also clear it. A producer running in an unrelated zone does not gain attachment rights merely because its stream is subscribed.

## Manual state does not need zones

```dart
state = state.transitionTo.success(data: user, message: 'Loaded');
```

Use lifecycle callbacks or framework listeners to present messages. Equal success data and message suppress a repeated engine transition, so do not treat state snapshots as a guaranteed event bus for duplicate toasts.

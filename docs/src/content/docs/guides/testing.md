---
title: Lifecycle, testing & troubleshooting
sidebar:
  order: 4
---

## Test publication with controlled sources

Use Completers or controlled StreamControllers to make overlap deterministic. Test loading, success, failure, retained cache, explicit cache clearing, cancellation, disposal, and late success **and late error**. For latest mode, complete an older request after a newer one. For first mode, count closure invocation to verify the second call was ignored.

The following Flutter test verifies the latest-request policy with a controlled Future.

```dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_operations/flutter_operations.dart';

void main() {
  test('latest completion owns state', () async {
    final operation = AsyncOperation<int>();
    final old = Completer<int>();
    final first = operation.run(() => old.future);
    await operation.run(() => 2);
    old.complete(1);
    await first;
    expect(operation.state, const SuccessOperation<int>(data: 2));
    operation.dispose();
  });
}
```

Explicit test type arguments here pin the equality assertion rather than repeat an inferred nested constructor type.

## Verify subscription cleanup

Test that replacement waits for delayed cancellation, that superseded restarts never invoke their source factory, and that old data/error/done cannot publish. Verify natural completion preserves state. A cleanup rejection must reject returned lifecycle Futures and prevent replacement; it is not a normal stream error snapshot.

Await cleanup in asynchronous host lifecycles. Call the superclass lifecycle method even if cleanup fails.

```dart
@override
Future<void> close() async {
  try {
    await operation.dispose();
  } finally {
    await super.close();
  }
}
```

Forward asynchronous cleanup failures to an error boundary when the host lifecycle is synchronous.

```dart
@override
void dispose() {
  final zone = Zone.current;
  operation.dispose().then<void>(
    (_) {},
    onError: (Object error, StackTrace trace) =>
      zone.handleUncaughtError(error, trace),
  );
  super.dispose();
}
```

This example assumes `dart:async` and a host with synchronous disposal. The widget stream adapter already does this; do not duplicate it there. A plain `unawaited` documents non-waiting but does not handle failure.

## Direct-state owners need their own guards

If execution is owned manually, increment a generation on new work/cancel/dispose and check disposal plus generation after awaits in both success and catch branches. Then publish through your framework. Transition helpers alone add no safety. Prefer composition when those guards would otherwise be newly invented.

## Troubleshooting checklist

| Symptom | Check |
| --- | --- |
| State changed but UI did not | Wire framework publication/read hooks; operations are not reactive primitives |
| Cubit did not rebuild | Publish snapshots, not the same mutable engine reference |
| MobX computed never updates | Its dependency must report Atom reads and changes |
| Late result overwrote manual idle | Setters do not invalidate; use cancel |
| New stream never subscribes | Prior cleanup is pending or rejected |
| Successful null looks like loading | Match success independently from hasData |
| Riverpod load stops after rebuild | Replace controller per build lifetime; dispose captured instance |
| Widget callback did not fire on initial loading | Equal initial loading suppresses duplicate transition |

## Repository checks

```sh
flutter test
cd example
flutter test
flutter analyze
```

Package suites include `test/unit/async_operation_test.dart`, `stream_operation_test.dart`, `operation_state_test.dart`, and `test/unit/mixins/`. Example integration tests exercise framework bridges and lifecycle behavior. Run both package and example suites after changing execution or integration behavior. The runnable examples are the compilation reference for application integrations.

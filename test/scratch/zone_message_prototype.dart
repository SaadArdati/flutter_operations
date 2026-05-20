// Prototype: zone-based per-call message channel.
//
// Hypothesis: a Zone-stored "message cell" lets the user call attachMessage
// from inside fetch() or stream() without polluting the override signature,
// and stays race-safe under concurrency because each call gets its own cell.
//
// The async* back-pressure assumption is the most fragile bit:
//   - When the generator yields, it pauses until the listener consumes.
//   - When the listener's SYNCHRONOUS body returns, the generator resumes.
//   - If we read cell.value at the TOP of the listener (before any await),
//     the read is paired with the just-yielded value.
//
// Run with:
//   dart test/scratch/zone_message_prototype.dart

// ignore_for_file: avoid_print, non_constant_identifier_names

import 'dart:async';

// ===== Core mechanism =====

class _MessageCell {
  String? value;
}

const _messageKey = Object();

/// User-facing: call from inside fetch() or stream() to attach a message
/// to the current operation (or the very next yield, for streams).
void attachMessage(String message) {
  final cell = Zone.current[_messageKey] as _MessageCell?;
  if (cell == null) {
    // Outside a fetch/stream zone. Silently no-op for now; a real impl
    // could log or throw a debug assertion.
    return;
  }
  cell.value = message;
}

/// Helper for the async one-shot pattern.
Future<(T, String?)> runOneShot<T>(Future<T> Function() body) async {
  final cell = _MessageCell();
  final result = await runZoned(body, zoneValues: {_messageKey: cell});
  return (result, cell.value);
}

/// Helper for the stream pattern. Returns a stream of (T, String?) records
/// where the message is whatever attachMessage was called for THAT yield.
///
/// Critical: the async* generator's body must run in the zone that holds
/// the message cell. Calling factory() inside runZoned only invokes the
/// async* function (which returns a Stream) within that zone; the body
/// runs lazily when something pulls events. We therefore subscribe inside
/// the zone so the entire pull/yield cycle inherits it.
Stream<(T, String?)> wrapStream<T>(Stream<T> Function() factory) {
  final cell = _MessageCell();
  late StreamController<(T, String?)> controller;
  late StreamSubscription<T> sub;

  controller = StreamController<(T, String?)>(
    onListen: () {
      runZoned(() {
        sub = factory().listen(
          (value) {
            final msg = cell.value;
            cell.value = null;
            controller.add((value, msg));
          },
          onError: controller.addError,
          onDone: controller.close,
        );
      }, zoneValues: {_messageKey: cell});
    },
    onCancel: () => sub.cancel(),
  );

  return controller.stream;
}

// ===== Assertion helper =====

int _passed = 0;
int _failed = 0;

void check(bool cond, String label) {
  if (cond) {
    _passed++;
    print('  PASS: $label');
  } else {
    _failed++;
    print('  FAIL: $label');
  }
}

// ===== Tests =====

Future<void> test1_basicPropagation() async {
  print('\n[1] Basic zone propagation');
  final (result, msg) = await runOneShot<int>(() async {
    attachMessage('hello');
    return 42;
  });
  check(result == 42, 'result is 42');
  check(msg == 'hello', 'message is "hello"');
}

Future<void> test2_throughAwait() async {
  print('\n[2] attachMessage survives across await');
  final (result, msg) = await runOneShot<int>(() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    attachMessage('after-await');
    return 99;
  });
  check(result == 99, 'result is 99');
  check(msg == 'after-await', 'message survived the await');
}

Future<void> test3_noMessage() async {
  print('\n[3] No attachMessage call');
  final (result, msg) = await runOneShot<int>(() async => 7);
  check(result == 7, 'result is 7');
  check(msg == null, 'message is null when none attached');
}

Future<void> test4_concurrentRaceSafe() async {
  print('\n[4] Concurrent fetches do not cross-contaminate');
  final futureA = runOneShot<String>(() async {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    attachMessage('msg-A');
    return 'A';
  });
  final futureB = runOneShot<String>(() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    attachMessage('msg-B');
    return 'B';
  });
  final results = await Future.wait([futureA, futureB]);
  check(
    results[0].$1 == 'A' && results[0].$2 == 'msg-A',
    'fetch A keeps msg-A',
  );
  check(
    results[1].$1 == 'B' && results[1].$2 == 'msg-B',
    'fetch B keeps msg-B',
  );
}

Future<void> test5_interleavedAttach() async {
  print('\n[5] Interleaved attach calls (A attaches early, B attaches late)');
  final futureA = runOneShot<String>(() async {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    attachMessage('A-msg');
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return 'A-result';
  });
  final futureB = runOneShot<String>(() async {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    attachMessage('B-msg');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return 'B-result';
  });
  final results = await Future.wait([futureA, futureB]);
  check(
    results[0].$2 == 'A-msg',
    'A still carries A-msg despite B writing later',
  );
  check(results[1].$2 == 'B-msg', 'B carries B-msg');
}

Future<void> test6_outsideZoneNoOp() async {
  print('\n[6] attachMessage outside any zone is a no-op');
  var threw = false;
  try {
    attachMessage('orphan');
  } catch (_) {
    threw = true;
  }
  check(!threw, 'no throw when called outside a zone');
}

Future<void> test7_lastWriteWins() async {
  print(
    '\n[7] Multiple attachMessage calls within one fetch (last write wins)',
  );
  final (_, msg) = await runOneShot<int>(() async {
    attachMessage('first');
    attachMessage('second');
    attachMessage('third');
    return 0;
  });
  check(msg == 'third', 'last attachMessage wins');
}

Future<void> test8_streamPerEmission() async {
  print(
    '\n[8] Stream with attachMessage before each yield (the headline test)',
  );
  Stream<int> userStream() async* {
    attachMessage('msg-1');
    yield 1;
    attachMessage('msg-2');
    yield 2;
    attachMessage('msg-3');
    yield 3;
  }

  final emissions = <(int, String?)>[];
  await for (final event in wrapStream(userStream)) {
    emissions.add(event);
  }
  print('    emissions: $emissions');
  check(emissions.length == 3, 'three emissions');
  check(emissions[0] == (1, 'msg-1'), 'emission 0 paired with msg-1');
  check(emissions[1] == (2, 'msg-2'), 'emission 1 paired with msg-2');
  check(emissions[2] == (3, 'msg-3'), 'emission 2 paired with msg-3');
}

Future<void> test9_streamNoAttach() async {
  print('\n[9] Stream without any attachMessage calls');
  Stream<int> userStream() async* {
    yield 10;
    yield 20;
  }

  final emissions = <(int, String?)>[];
  await for (final event in wrapStream(userStream)) {
    emissions.add(event);
  }
  print('    emissions: $emissions');
  check(emissions[0] == (10, null), 'no message for emission 0');
  check(emissions[1] == (20, null), 'no message for emission 1');
}

Future<void> test10_streamAwaitBeforeYield() async {
  print('\n[10] Stream with await between attachMessage and yield');
  Stream<int> userStream() async* {
    attachMessage('before-await-1');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    yield 1;
    attachMessage('before-await-2');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    yield 2;
  }

  final emissions = <(int, String?)>[];
  await for (final event in wrapStream(userStream)) {
    emissions.add(event);
  }
  print('    emissions: $emissions');
  check(
    emissions[0] == (1, 'before-await-1'),
    'attachMessage survives await before yield',
  );
  check(
    emissions[1] == (2, 'before-await-2'),
    'second attachMessage survives await before yield',
  );
}

Future<void> test11_concurrentStreams() async {
  print('\n[11] Two concurrent listens with isolated cells');
  Stream<int> userStream(String prefix) async* {
    attachMessage('$prefix-1');
    yield 1;
    attachMessage('$prefix-2');
    yield 2;
  }

  final emissionsA = <(int, String?)>[];
  final emissionsB = <(int, String?)>[];
  final futureA = (() async {
    await for (final event in wrapStream(() => userStream('A'))) {
      emissionsA.add(event);
    }
  })();
  final futureB = (() async {
    await for (final event in wrapStream(() => userStream('B'))) {
      emissionsB.add(event);
    }
  })();
  await Future.wait([futureA, futureB]);
  print('    A: $emissionsA');
  print('    B: $emissionsB');
  check(
    emissionsA[0] == (1, 'A-1') && emissionsA[1] == (2, 'A-2'),
    'A messages isolated',
  );
  check(
    emissionsB[0] == (1, 'B-1') && emissionsB[1] == (2, 'B-2'),
    'B messages isolated',
  );
}

Future<void> test12_listenerAsyncBody() async {
  print('\n[12] CRITICAL: listener body does sync cell-read then async work');
  // The wrapStream helper reads cell synchronously at the top of the
  // listener and clears it before any async work. This is the design
  // contract. If we accidentally read it AFTER an await, the second
  // emission would clobber the first. This test verifies the design.
  Stream<int> userStream() async* {
    attachMessage('A');
    yield 1;
    attachMessage('B');
    yield 2;
  }

  final emissions = <(int, String?)>[];
  // Manually consume so we can interleave async work AFTER reading the cell.
  await for (final event in wrapStream(userStream)) {
    // wrapStream already paired the message with the value at synchronous
    // time of receipt; this awaits inside the consumer do NOT affect that
    // pairing.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    emissions.add(event);
  }
  print('    emissions: $emissions');
  check(
    emissions[0] == (1, 'A'),
    'emission 0 still has correct message after consumer await',
  );
  check(
    emissions[1] == (2, 'B'),
    'emission 1 still has correct message after consumer await',
  );
}

Future<void> test13_subscriptionCancelMidStream() async {
  print(
    '\n[13] Cancelling subscription mid-stream then re-listening with fresh cell',
  );
  // Start a stream, take 1 event, cancel. Start a new stream with fresh
  // cell. The fresh cell must NOT see the prior cell's value (which only
  // matters if we accidentally shared cells across listens).
  Stream<int> first() async* {
    attachMessage('first-1');
    yield 1;
    attachMessage('first-2');
    yield 2;
  }

  Stream<int> second() async* {
    attachMessage('second-1');
    yield 1;
    attachMessage('second-2');
    yield 2;
  }

  final firstEmissions = <(int, String?)>[];
  final firstSub = wrapStream(first).listen((e) => firstEmissions.add(e));
  await Future<void>.delayed(const Duration(milliseconds: 20));
  await firstSub.cancel();

  final secondEmissions = <(int, String?)>[];
  await for (final event in wrapStream(second)) {
    secondEmissions.add(event);
  }
  print('    first (cancelled early): $firstEmissions');
  print('    second (full): $secondEmissions');
  check(
    firstEmissions.isNotEmpty && firstEmissions[0] == (1, 'first-1'),
    'first stream got at least one correct emission',
  );
  check(
    secondEmissions.length == 2 &&
        secondEmissions[0] == (1, 'second-1') &&
        secondEmissions[1] == (2, 'second-2'),
    'second stream isolated from first',
  );
}

Future<void> test14_rapidSyncYields() async {
  print('\n[14] Rapid synchronous yields with attachMessage between each');
  // No awaits between attachMessage and yield. This stresses the
  // back-pressure: the generator wants to yield as fast as possible,
  // but should still pause at each yield until the listener consumes.
  Stream<int> userStream() async* {
    for (var i = 0; i < 10; i++) {
      attachMessage('m-$i');
      yield i;
    }
  }

  final emissions = <(int, String?)>[];
  await for (final event in wrapStream(userStream)) {
    emissions.add(event);
  }
  print('    emissions: $emissions');
  check(emissions.length == 10, 'all 10 emissions arrived');
  var allCorrect = true;
  for (var i = 0; i < 10; i++) {
    if (emissions[i] != (i, 'm-$i')) {
      allCorrect = false;
      print('    MISMATCH at $i: ${emissions[i]} expected ($i, m-$i)');
    }
  }
  check(allCorrect, 'every rapid yield paired with its own message');
}

void main() async {
  print('=== Zone-based attachMessage prototype ===');

  print('\n--- Async one-shot ---');
  await test1_basicPropagation();
  await test2_throughAwait();
  await test3_noMessage();
  await test4_concurrentRaceSafe();
  await test5_interleavedAttach();
  await test6_outsideZoneNoOp();
  await test7_lastWriteWins();

  print('\n--- Stream ---');
  await test8_streamPerEmission();
  await test9_streamNoAttach();
  await test10_streamAwaitBeforeYield();
  await test11_concurrentStreams();
  await test12_listenerAsyncBody();
  await test13_subscriptionCancelMidStream();
  await test14_rapidSyncYields();

  print('\n=== Summary: $_passed passed, $_failed failed ===');
}

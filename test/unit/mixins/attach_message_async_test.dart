@Timeout(Duration(seconds: 10))
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_operations/flutter_operations.dart';
import 'package:flutter_test/flutter_test.dart';

class _MessageWidget extends StatefulWidget {
  const _MessageWidget({required this.behavior});

  final Future<String> Function(_MessageWidgetState state) behavior;

  @override
  State<_MessageWidget> createState() => _MessageWidgetState();
}

class _MessageWidgetState extends State<_MessageWidget>
    with AsyncOperationMixin<String, _MessageWidget> {
  /// Test-only hook (public) that invokes the @protected attachMessage from
  /// within the subclass, preserving the production contract.
  void testAttach(String message) => attachMessage(message);

  @override
  Future<String> fetch() => widget.behavior(this);

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Future<_MessageWidgetState> _pump(
  WidgetTester tester,
  Future<String> Function(_MessageWidgetState state) behavior,
) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: _MessageWidget(behavior: behavior),
    ),
  );
  final state = tester.state<_MessageWidgetState>(find.byType(_MessageWidget));
  await tester.pumpAndSettle();
  return state;
}

void main() {
  group('AsyncOperationMixin attachMessage', () {
    testWidgets('returns null message when attachMessage is never called', (
      tester,
    ) async {
      final state = await _pump(tester, (_) async => 'hello');
      final op = state.operation;
      expect(op, isA<SuccessOperation<String>>());
      expect((op as SuccessOperation<String>).message, isNull);
      expect(op.data, equals('hello'));
    });

    testWidgets('attachMessage before await is paired with the success', (
      tester,
    ) async {
      final state = await _pump(tester, (s) async {
        s.testAttach('greeting');
        return 'hello';
      });
      final op = state.operation as SuccessOperation<String>;
      expect(op.message, equals('greeting'));
      expect(op.data, equals('hello'));
    });

    testWidgets('attachMessage after await is paired with the success', (
      tester,
    ) async {
      final state = await _pump(tester, (s) async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        s.testAttach('greeting');
        return 'hello';
      });
      final op = state.operation as SuccessOperation<String>;
      expect(op.message, equals('greeting'));
    });

    testWidgets('last attachMessage call wins inside a single fetch', (
      tester,
    ) async {
      final state = await _pump(tester, (s) async {
        s.testAttach('first');
        s.testAttach('second');
        s.testAttach('third');
        return 'x';
      });
      final op = state.operation as SuccessOperation<String>;
      expect(op.message, equals('third'));
    });

    testWidgets(
      'attachMessage outside a load() call does not leak into the next load',
      (tester) async {
        // Track whether the next fetch should attach a message.
        var callCount = 0;
        final state = await _pump(tester, (s) async {
          callCount++;
          // No testAttach here. Next reload must not inherit any orphan write.
          return 'value-$callCount';
        });

        // Initial load completed with no message attached.
        expect((state.operation as SuccessOperation<String>).message, isNull);

        // Write a message OUTSIDE any active load. Expected: no-op.
        state.testAttach('orphan');

        // Trigger a subsequent load that does NOT attach a message.
        await state.reload();
        await tester.pumpAndSettle();

        final op = state.operation as SuccessOperation<String>;
        // A global-cell regression would leak 'orphan' into the next message.
        expect(op.message, isNull);
        expect(op.data, equals('value-2'));
      },
    );

    testWidgets('zone isolation: loser cannot contaminate winner', (
      tester,
    ) async {
      // The initial load completes immediately and the test then races two
      // concurrent reloads. The LOSER (older generation) writes to its cell
      // while the WINNER (newest generation) is still suspended. If the cell
      // were global, the loser's write would leak into the winner's success.
      final loserGate = Completer<void>();
      final winnerGate = Completer<void>();
      final loserHasWritten = Completer<void>();
      var generation = 0;

      final state = await _pump(tester, (s) async {
        final myGen = ++generation;
        if (myGen == 1) {
          // Initial load, no message attached.
          return 'initial';
        } else if (myGen == 2) {
          // LOSER: wait until released, then write our message and finish.
          await loserGate.future;
          s.testAttach('loser-msg');
          loserHasWritten.complete();
          // Stall a bit so the winner truly resumes AFTER our write.
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return 'loser';
        } else {
          // WINNER (myGen == 3): suspend until told to finish.
          await winnerGate.future;
          s.testAttach('winner-msg');
          return 'winner';
        }
      });

      // Sanity: initial load done.
      expect(generation, equals(1));
      expect((state.operation as SuccessOperation<String>).message, isNull);

      // Kick off LOSER reload (generation 2), then WINNER reload (gen 3).
      unawaited(Future.value(state.reload()));
      await tester.pump();
      unawaited(Future.value(state.reload()));
      await tester.pump();

      // Both fetches are now in-flight. Release the LOSER first so it
      // writes to its (orphaned) cell BEFORE the winner writes to its own.
      loserGate.complete();
      await loserHasWritten.future;
      await tester.pump(const Duration(milliseconds: 30));

      // Now let the WINNER complete.
      winnerGate.complete();
      await tester.pumpAndSettle();

      final op = state.operation as SuccessOperation<String>;
      expect(op.data, equals('winner'));
      // The winner's cell must not be contaminated by the loser's write.
      expect(op.message, equals('winner-msg'));
      expect(op.message, isNot(equals('loser-msg')));
    });

    testWidgets(
      'dispose during fetch with in-flight attachMessage does not crash',
      (tester) async {
        final gate = Completer<void>();

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: _MessageWidget(
              behavior: (s) async {
                s.testAttach('pre-await');
                await gate.future;
                // After this resume, the widget has been disposed. The mounted
                // guard inside load() must drop the result.
                s.testAttach('post-await');
                return 'finished';
              },
            ),
          ),
        );

        // Let initState schedule the microtask load().
        await tester.pump();

        // Replace the widget; triggers dispose while fetch is suspended.
        await tester.pumpWidget(const SizedBox.shrink());

        // Resume the suspended fetch; mounted guard should suppress setSuccess.
        gate.complete();
        await tester.pumpAndSettle();
        // No crash = success.
      },
    );
  });
}

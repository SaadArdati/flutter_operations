@Timeout(Duration(seconds: 10))
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_operations/flutter_operations.dart';
import 'package:flutter_test/flutter_test.dart';

class _StreamWidget extends StatefulWidget {
  const _StreamWidget({required this.behavior});

  final Stream<int> Function(_StreamWidgetState state) behavior;

  @override
  State<_StreamWidget> createState() => _StreamWidgetState();
}

class _StreamWidgetState extends State<_StreamWidget>
    with StreamOperationMixin<int, _StreamWidget> {
  final List<(int, String?)> emissions = <(int, String?)>[];

  /// Test-only hook (public) that invokes the @protected attachMessage from
  /// within the subclass, preserving the production contract.
  void testAttach(String message) => attachMessage(message);

  @override
  Stream<int> stream() => widget.behavior(this);

  @override
  void onData(int value) {
    final op = operation;
    if (op is SuccessOperation<int>) {
      emissions.add((value, op.message));
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Future<_StreamWidgetState> _pump(
  WidgetTester tester,
  Stream<int> Function(_StreamWidgetState state) behavior,
) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: _StreamWidget(behavior: behavior),
    ),
  );
  final state = tester.state<_StreamWidgetState>(find.byType(_StreamWidget));
  await tester.pumpAndSettle();
  return state;
}

void main() {
  group('StreamOperationMixin attachMessage', () {
    testWidgets('per-emission attachMessage is paired with each yield', (
      tester,
    ) async {
      final state = await _pump(tester, (s) async* {
        s.testAttach('m-1');
        yield 1;
        s.testAttach('m-2');
        yield 2;
        s.testAttach('m-3');
        yield 3;
      });

      expect(state.emissions, equals([(1, 'm-1'), (2, 'm-2'), (3, 'm-3')]));
    });

    testWidgets('emissions without attachMessage have null message', (
      tester,
    ) async {
      final state = await _pump(tester, (_) async* {
        yield 10;
        yield 20;
      });

      expect(state.emissions, equals([(10, null), (20, null)]));
    });

    testWidgets('attachMessage survives await between calls and yield', (
      tester,
    ) async {
      final state = await _pump(tester, (s) async* {
        s.testAttach('a');
        await Future<void>.delayed(const Duration(milliseconds: 5));
        yield 1;
        s.testAttach('b');
        await Future<void>.delayed(const Duration(milliseconds: 5));
        yield 2;
      });

      expect(state.emissions, equals([(1, 'a'), (2, 'b')]));
    });

    testWidgets('rapid synchronous yields each get their own message', (
      tester,
    ) async {
      final state = await _pump(tester, (s) async* {
        for (var i = 0; i < 5; i++) {
          s.testAttach('m-$i');
          yield i;
        }
      });

      expect(
        state.emissions,
        equals([(0, 'm-0'), (1, 'm-1'), (2, 'm-2'), (3, 'm-3'), (4, 'm-4')]),
      );
    });

    testWidgets(
      'cell clears between emissions: attached then omitted yields null',
      (tester) async {
        final state = await _pump(tester, (s) async* {
          s.testAttach('one');
          yield 1;
          // No testAttach here, the cell must be cleared between emissions.
          yield 2;
          s.testAttach('three');
          yield 3;
        });

        expect(state.emissions, equals([(1, 'one'), (2, null), (3, 'three')]));
      },
    );

    testWidgets(
      'mid-stream re-listen: previous cell does not contaminate new',
      (tester) async {
        late StreamController<int> first;
        late StreamController<int> second;
        var streamCount = 0;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: _StreamWidget(
              behavior: (s) async* {
                streamCount++;
                if (streamCount == 1) {
                  first = StreamController<int>();
                  await for (final v in first.stream) {
                    s.testAttach('first-$v');
                    yield v;
                  }
                } else {
                  second = StreamController<int>();
                  await for (final v in second.stream) {
                    s.testAttach('second-$v');
                    yield v;
                  }
                }
              },
            ),
          ),
        );
        final state = tester.state<_StreamWidgetState>(
          find.byType(_StreamWidget),
        );
        // Let the initial listen wire up the first controller.
        await tester.pump();
        await tester.pump();

        // Emit on the first stream while it is active.
        first.add(1);
        await tester.pump();
        await tester.pump();

        // Mid-flight re-listen: cancels the first subscription, opens the
        // second. The first controller's stream subscription is gone.
        state.listen();
        await tester.pump();
        await tester.pump();

        // Emit on the second stream.
        second.add(10);
        await tester.pump();
        await tester.pump();

        expect(state.emissions, equals([(1, 'first-1'), (10, 'second-10')]));

        await first.close();
        await second.close();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'attachMessage outside a listen() does not leak into the next listen',
      (tester) async {
        var listenCount = 0;
        final state = await _pump(tester, (s) async* {
          listenCount++;
          // No testAttach here; messages should remain null unless preceded
          // by an in-zone testAttach.
          yield listenCount * 100;
        });

        // After the initial stream completes, write OUTSIDE any active zone.
        state.testAttach('orphan');

        // Re-listen: the new stream does NOT call testAttach.
        state.listen();
        await tester.pumpAndSettle();

        // First listen emission was (100, null); second is (200, null).
        // A global-cell regression would make the second be (200, 'orphan').
        expect(state.emissions, equals([(100, null), (200, null)]));
      },
    );

    testWidgets('attachMessage works inside Stream.map transformer', (
      tester,
    ) async {
      final state = await _pump(
        tester,
        (s) => Stream.fromIterable([1, 2, 3]).map((v) {
          s.testAttach('mapped-$v');
          return v * 10;
        }),
      );

      expect(
        state.emissions,
        equals([(10, 'mapped-1'), (20, 'mapped-2'), (30, 'mapped-3')]),
      );
    });
  });
}

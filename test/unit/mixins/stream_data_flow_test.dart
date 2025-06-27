@Timeout(Duration(seconds: 4))
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_operations/flutter_operations.dart' as ops;

import '../../helpers/test_helpers.dart';

class _TestStreamWidget extends StatefulWidget {
  const _TestStreamWidget({
    required this.streamBuilder,
  });

  final Stream<StreamTestData> Function() streamBuilder;

  @override
  State<_TestStreamWidget> createState() => _TestStreamWidgetState();
}

class _TestStreamWidgetState extends State<_TestStreamWidget>
    with ops.StreamOperationMixin<StreamTestData, _TestStreamWidget> {
  @override
  bool get listenOnInit => false;

  @override
  Stream<StreamTestData> stream() => widget.streamBuilder();

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  group('StreamOperationMixin data flow', () {
    testWidgets('success → async error → cached reload', (tester) async {
      final controllers = <StreamController<StreamTestData>>[
        StreamController<StreamTestData>(),
        StreamController<StreamTestData>(),
        StreamController<StreamTestData>(),
      ];
      int callCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TestStreamWidget(
              streamBuilder: () => controllers[callCount++].stream,
            ),
          ),
        ),
      );

      final state = tester.state<_TestStreamWidgetState>(
        find.byType(_TestStreamWidget),
      );

      state.listen();
      await tester.pump();
      expect(state.operation.isLoading, isTrue);

      controllers[0].add(const StreamTestData(1));
      await tester.pump();
      expect(state.operation.isSuccess, isTrue);
      expect(state.operation.data?.value, equals(1));

      state.listen(cached: true);
      await tester.pump();
      expect(state.operation.isLoading, isTrue);

      controllers[1].addError(Exception('stream failure'));
      await tester.pump();
      expect(state.operation.isError, isTrue);
      expect(
        state.operation.hasData,
        isTrue,
        reason: 'cached data should remain',
      );
      expect(state.operation.data?.value, equals(1));

      state.listen(cached: true);
      await tester.pump();

      controllers[2].add(const StreamTestData(42));
      await tester.pump();

      expect(state.operation.isSuccess, isTrue);
      expect(state.operation.data?.value, equals(42));

      for (final c in controllers) {
        c.close();
      }
    });

    testWidgets('generation guard prefers latest listen()', (tester) async {
      final controllers = <StreamController<StreamTestData>>[
        StreamController<StreamTestData>(),
        StreamController<StreamTestData>(),
      ];
      int callCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TestStreamWidget(
              streamBuilder: () => controllers[callCount++].stream,
            ),
          ),
        ),
      );

      final state = tester.state<_TestStreamWidgetState>(
        find.byType(_TestStreamWidget),
      );

      state.listen();
      await tester.pump();

      state.listen();
      await tester.pump();

      controllers[0].add(const StreamTestData(1));
      await tester.pump();
      expect(state.operation.isLoading, isTrue);

      controllers[1].add(const StreamTestData(2));
      await tester.pump();
      expect(state.operation.isSuccess, isTrue);
      expect(state.operation.data?.value, equals(2));

      for (final c in controllers) {
        c.close();
      }
    });

    testWidgets(
      'listen(cached: false) should discard previous cached data on error',
      (tester) async {
        final controllers = <StreamController<StreamTestData>>[
          StreamController<StreamTestData>(),
          StreamController<StreamTestData>(),
        ];
        int callCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _TestStreamWidget(
                streamBuilder: () => controllers[callCount++].stream,
              ),
            ),
          ),
        );

        final state = tester.state<_TestStreamWidgetState>(
          find.byType(_TestStreamWidget),
        );

        state.listen();
        await tester.pump();
        controllers[0].add(const StreamTestData(3));
        await tester.pump();
        expect(state.operation.isSuccess, isTrue);
        expect(state.operation.data?.value, equals(3));

        state.listen(cached: false);
        await tester.pump();
        controllers[1].addError(Exception('fail'));
        await tester.pump();

        expect(state.operation.isError, isTrue);
        expect(
          state.operation.hasData,
          isFalse,
          reason: 'Data should be discarded when cached:false',
        );

        for (final c in controllers) {
          c.close();
        }
      },
    );
  });
}

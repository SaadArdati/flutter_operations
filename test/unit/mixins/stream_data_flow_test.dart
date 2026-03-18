@Timeout(Duration(seconds: 4))
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_operations/flutter_operations.dart' as ops;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';

class _TestStreamWidget extends StatefulWidget {
  const _TestStreamWidget({required this.streamBuilder});

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

    testWidgets('setLoading(idle: true) sets IdleOperation', (tester) async {
      final controller = StreamController<StreamTestData>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TestStreamWidget(streamBuilder: () => controller.stream),
          ),
        ),
      );

      final state = tester.state<_TestStreamWidgetState>(
        find.byType(_TestStreamWidget),
      );

      // Start with some data
      state.listen();
      await tester.pump();
      controller.add(const StreamTestData(5));
      await tester.pump();
      expect(state.operation.isSuccess, isTrue);

      // setLoading(idle: true) should produce IdleOperation
      state.setLoading(idle: true, cached: true);
      await tester.pump();

      expect(state.operation.isIdle, isTrue);
      expect(state.operation.isLoading, isFalse);
      expect(state.operation.hasData, isTrue);
      expect(state.operation.data?.value, equals(5));

      controller.close();
    });

    testWidgets('setLoading(idle: true, cached: false) discards data', (
      tester,
    ) async {
      final controller = StreamController<StreamTestData>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TestStreamWidget(streamBuilder: () => controller.stream),
          ),
        ),
      );

      final state = tester.state<_TestStreamWidgetState>(
        find.byType(_TestStreamWidget),
      );

      // Start with some data
      state.listen();
      await tester.pump();
      controller.add(const StreamTestData(10));
      await tester.pump();
      expect(state.operation.isSuccess, isTrue);

      // setLoading(idle: true, cached: false) should discard data
      state.setLoading(idle: true, cached: false);
      await tester.pump();

      expect(state.operation.isIdle, isTrue);
      expect(state.operation.hasData, isFalse);

      controller.close();
    });

    testWidgets('setLoading(idle: false) sets LoadingOperation', (
      tester,
    ) async {
      final controller = StreamController<StreamTestData>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TestStreamWidget(streamBuilder: () => controller.stream),
          ),
        ),
      );

      final state = tester.state<_TestStreamWidgetState>(
        find.byType(_TestStreamWidget),
      );

      // setLoading(idle: false) should produce LoadingOperation
      state.setLoading(idle: false);
      await tester.pump();

      expect(state.operation.isLoading, isTrue);
      expect(state.operation.isIdle, isFalse);

      controller.close();
    });
  });
}

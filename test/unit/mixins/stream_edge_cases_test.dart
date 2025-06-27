@Timeout(Duration(seconds: 4))
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_operations/flutter_operations.dart' as ops;

import '../../helpers/test_helpers.dart';

class _DefaultListenWidget extends StatefulWidget {
  const _DefaultListenWidget({required this.controller});

  final StreamController<StreamTestData> controller;

  @override
  State<_DefaultListenWidget> createState() => _DefaultListenWidgetState();
}

class _DefaultListenWidgetState extends State<_DefaultListenWidget>
    with ops.StreamOperationMixin<StreamTestData, _DefaultListenWidget> {
  int loadingCalls = 0;
  int dataCalls = 0;

  @override
  Stream<StreamTestData> stream() => widget.controller.stream;

  @override
  void onLoading() {
    loadingCalls += 1;
    super.onLoading();
  }

  @override
  void onData(StreamTestData value) {
    dataCalls += 1;
    super.onData(value);
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _SetLoadingWidget extends StatefulWidget {
  const _SetLoadingWidget({super.key});

  @override
  State<_SetLoadingWidget> createState() => _SetLoadingWidgetState();
}

class _SetLoadingWidgetState extends State<_SetLoadingWidget>
    with ops.StreamOperationMixin<int, _SetLoadingWidget> {
  int loadingCalls = 0;

  @override
  bool get listenOnInit => false;

  @override
  Stream<int> stream() => const Stream<int>.empty();

  @override
  void onLoading() {
    loadingCalls += 1;
    super.onLoading();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  group('StreamOperationMixin edge cases', () {
    testWidgets(
      'default listenOnInit should auto-listen and transition to success',
      (tester) async {
        final controller = StreamController<StreamTestData>();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: _DefaultListenWidget(controller: controller)),
          ),
        );

        final state = tester.state<_DefaultListenWidgetState>(
          find.byType(_DefaultListenWidget),
        );

        await tester.pump();

        expect(state.operation.isLoading, isTrue);

        controller.add(const StreamTestData(10));
        await tester.pump();

        expect(state.operation.isSuccess, isTrue);
        expect(state.operation.data?.value, equals(10));
        expect(state.dataCalls, equals(1));

        await controller.close();
      },
    );

    testWidgets(
      'setLoading returns early if state is already loading with same data',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: _SetLoadingWidget(key: Key('target'))),
          ),
        );

        final state = tester.state<_SetLoadingWidgetState>(
          find.byKey(const Key('target')),
        );

        state.setLoading();
        await tester.pump();

        expect(state.operation.isLoading, isTrue);
        expect(state.loadingCalls, equals(1));

        final firstOpInstance = state.operation;

        state.setLoading();
        await tester.pump();

        expect(
          state.loadingCalls,
          equals(1),
          reason: 'onLoading should not be called again',
        );
        expect(
          identical(state.operation, firstOpInstance),
          isTrue,
          reason:
              'operation instance should remain the same after redundant setLoading',
        );
      },
    );

    testWidgets(
      'setIdle returns early if state is already idle with same data',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: _SetLoadingWidget(key: Key('idle-target'))),
          ),
        );

        final state = tester.state<_SetLoadingWidgetState>(
          find.byKey(const Key('idle-target')),
        );

        state.setData(1);
        await tester.pump();

        state.setIdle(cached: true);
        await tester.pump();

        expect(state.operation.isIdle, isTrue);
        final firstInstance = state.operation;

        state.setIdle(cached: true);
        await tester.pump();

        expect(identical(state.operation, firstInstance), isTrue);
      },
    );

    testWidgets('setData returns early if same value is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: _SetLoadingWidget(key: Key('data-target'))),
        ),
      );

      final state = tester.state<_SetLoadingWidgetState>(
        find.byKey(const Key('data-target')),
      );

      int notifierEvents = 0;
      state.operationNotifier.addListener(() {
        notifierEvents += 1;
      });

      state.setData(7);
      await tester.pump();
      expect(notifierEvents, equals(1));

      final opInstance = state.operation;

      state.setData(7);
      await tester.pump();

      expect(
        notifierEvents,
        equals(1),
        reason: 'operationNotifier should not emit again',
      );
      expect(identical(state.operation, opInstance), isTrue);
    });
  });
}

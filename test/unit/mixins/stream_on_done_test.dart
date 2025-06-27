@Timeout(Duration(seconds: 4))
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_operations/flutter_operations.dart' as ops;

class _DoneStreamWidget extends StatefulWidget {
  const _DoneStreamWidget({required this.controller});

  final StreamController<int> controller;

  @override
  State<_DoneStreamWidget> createState() => _DoneStreamWidgetState();
}

class _DoneStreamWidgetState extends State<_DoneStreamWidget>
    with ops.StreamOperationMixin<int, _DoneStreamWidget> {
  bool doneCalled = false;

  @override
  bool get listenOnInit => false;

  @override
  Stream<int> stream() => widget.controller.stream;

  @override
  void onDone() {
    doneCalled = true;
    super.onDone();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  group('StreamOperationMixin onDone', () {
    testWidgets('should trigger onDone when stream closes', (tester) async {
      final controller = StreamController<int>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: _DoneStreamWidget(controller: controller)),
        ),
      );

      final state = tester.state<_DoneStreamWidgetState>(
        find.byType(_DoneStreamWidget),
      );

      state.listen();
      await tester.pump();

      await controller.close();
      await tester.pump();

      expect(state.doneCalled, isTrue);
    });
  });
}

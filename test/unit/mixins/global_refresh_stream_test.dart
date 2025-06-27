@Timeout(Duration(seconds: 4))
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_operations/flutter_operations.dart' as ops;

class _GlobalRefreshStreamWidget extends StatefulWidget {
  const _GlobalRefreshStreamWidget({super.key});

  @override
  State<_GlobalRefreshStreamWidget> createState() =>
      _GlobalRefreshStreamWidgetState();
}

class _GlobalRefreshStreamWidgetState extends State<_GlobalRefreshStreamWidget>
    with ops.StreamOperationMixin<int, _GlobalRefreshStreamWidget> {
  int buildCount = 0;
  final _controller = StreamController<int>();

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  bool get listenOnInit => false;

  @override
  bool get globalRefresh => true;

  @override
  Stream<int> stream() => _controller.stream;

  @override
  Widget build(BuildContext context) {
    buildCount += 1;
    return Text('build #$buildCount', key: const Key('build-text'));
  }
}

void main() {
  group('StreamOperationMixin globalRefresh', () {
    testWidgets('should rebuild the widget when globalRefresh is true', (
      tester,
    ) async {
      late _GlobalRefreshStreamWidgetState state;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: _GlobalRefreshStreamWidget(key: Key('target'))),
        ),
      );

      state = tester.state<_GlobalRefreshStreamWidgetState>(
        find.byKey(const Key('target')),
      );

      expect(state.buildCount, equals(1));

      state.listen();
      await tester.pump();

      state._controller.add(1);
      await tester.pump();

      expect(state.buildCount, equals(2));
    });
  });
}

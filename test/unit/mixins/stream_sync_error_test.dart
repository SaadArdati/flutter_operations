@Timeout(Duration(seconds: 4))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_operations/flutter_operations.dart' as ops;

class _SyncErrorStreamWidget extends StatefulWidget {
  const _SyncErrorStreamWidget();

  @override
  State<_SyncErrorStreamWidget> createState() => _SyncErrorStreamWidgetState();
}

class _SyncErrorStreamWidgetState extends State<_SyncErrorStreamWidget>
    with ops.StreamOperationMixin<int, _SyncErrorStreamWidget> {
  @override
  bool get listenOnInit => true;

  @override
  Stream<int> stream() {
    throw Exception('synchronous failure');
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  group('StreamOperationMixin synchronous stream error', () {
    testWidgets('should transition to error state if stream() throws', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: _SyncErrorStreamWidget())),
      );

      final state = tester.state<_SyncErrorStreamWidgetState>(
        find.byType(_SyncErrorStreamWidget),
      );

      expect(state.operation.isError, isTrue);
      expect(
        (state.operation as ops.ErrorOperation).message,
        contains('synchronous failure'),
      );
    });
  });
}

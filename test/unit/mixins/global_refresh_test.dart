@Timeout(Duration(seconds: 4))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_operations/flutter_operations.dart' as ops;

class _GlobalRefreshWidget extends StatefulWidget {
  const _GlobalRefreshWidget({super.key});

  @override
  State<_GlobalRefreshWidget> createState() => _GlobalRefreshWidgetState();
}

class _GlobalRefreshWidgetState extends State<_GlobalRefreshWidget>
    with ops.AsyncOperationMixin<String, _GlobalRefreshWidget> {
  int buildCount = 0;

  @override
  bool get loadOnInit => false;

  @override
  bool get globalRefresh => true;

  @override
  Future<String> fetch() async => 'data';

  @override
  Widget build(BuildContext context) {
    buildCount += 1;
    return Text('build #$buildCount', key: const Key('build-text'));
  }
}

void main() {
  group('AsyncOperationMixin globalRefresh', () {
    testWidgets('should rebuild the widget when globalRefresh is true', (
      tester,
    ) async {
      late _GlobalRefreshWidgetState state;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: _GlobalRefreshWidget(key: Key('target'))),
        ),
      );

      state = tester.state<_GlobalRefreshWidgetState>(
        find.byKey(const Key('target')),
      );

      expect(state.buildCount, equals(1));

      state.setSuccess('result');
      await tester.pump();

      expect(state.buildCount, equals(2));
    });
  });
}

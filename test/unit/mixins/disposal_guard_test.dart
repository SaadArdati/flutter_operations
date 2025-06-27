@Timeout(Duration(seconds: 4))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_operations/flutter_operations.dart' as ops;

import '../../helpers/test_helpers.dart';

class _DisposalWidget extends StatefulWidget {
  const _DisposalWidget({required this.future});

  final Future<TestData> future;

  @override
  State<_DisposalWidget> createState() => _DisposalWidgetState();
}

class _DisposalWidgetState extends State<_DisposalWidget>
    with ops.AsyncOperationMixin<TestData, _DisposalWidget> {
  int successCalls = 0;
  int errorCalls = 0;
  int loadingCalls = 0;

  @override
  bool get loadOnInit => false;

  @override
  Future<TestData> fetch() async => widget.future;

  @override
  void onSuccess(TestData data) {
    successCalls += 1;
    super.onSuccess(data);
  }

  @override
  void onError(Object exception, StackTrace stackTrace, {String? message}) {
    errorCalls += 1;
    super.onError(exception, stackTrace, message: message);
  }

  @override
  void onLoading() {
    loadingCalls += 1;
    super.onLoading();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  group('AsyncOperationMixin disposal guard', () {
    testWidgets('callbacks are not fired after widget is disposed', (
      tester,
    ) async {
      final future = ControllableFuture<TestData>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: _DisposalWidget(future: future.future)),
        ),
      );

      final state = tester.state<_DisposalWidgetState>(
        find.byType(_DisposalWidget),
      );

      state.load();
      await tester.pump();
      expect(state.loadingCalls, equals(1));

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox())),
      );

      future.complete(const TestData('late'));
      await tester.pump();

      expect(state.successCalls, equals(0));
      expect(state.errorCalls, equals(0));
    });
  });
}

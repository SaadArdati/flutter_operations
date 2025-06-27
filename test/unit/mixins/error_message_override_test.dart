@Timeout(Duration(seconds: 4))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_operations/flutter_operations.dart' as ops;

import '../../helpers/test_helpers.dart';

class _ErrorMessageWidget extends StatefulWidget {
  const _ErrorMessageWidget({required this.future});

  final Future<TestData> future;

  @override
  State<_ErrorMessageWidget> createState() => _ErrorMessageWidgetState();
}

class _ErrorMessageWidgetState extends State<_ErrorMessageWidget>
    with ops.AsyncOperationMixin<TestData, _ErrorMessageWidget> {
  String? lastErrorMessage;

  @override
  bool get loadOnInit => false;

  @override
  Future<TestData> fetch() async => widget.future;

  @override
  String errorMessage(Object exception, StackTrace stackTrace) =>
      'CUSTOM: ${exception.toString()}';

  @override
  void onError(Object exception, StackTrace stackTrace, {String? message}) {
    lastErrorMessage = message;
    super.onError(exception, stackTrace, message: message);
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  group('AsyncOperationMixin custom errorMessage override', () {
    testWidgets(
      'ErrorOperation.message should use override and propagate to onError',
      (tester) async {
        final future = ControllableFuture<TestData>();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: _ErrorMessageWidget(future: future.future)),
          ),
        );

        final state = tester.state<_ErrorMessageWidgetState>(
          find.byType(_ErrorMessageWidget),
        );

        state.load();
        await tester.pump();
        future.completeError(Exception('failure'));
        await tester.pump();

        expect(state.operation.isError, isTrue);
        const expected = 'CUSTOM: Exception: failure';
        expect((state.operation as ops.ErrorOperation).message, expected);
        expect(state.lastErrorMessage, expected);
      },
    );
  });
}

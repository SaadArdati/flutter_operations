@Timeout(Duration(seconds: 4))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_operations/flutter_operations.dart' as ops;

import '../../helpers/test_helpers.dart';

class _CallbackAsyncWidget extends StatefulWidget {
  const _CallbackAsyncWidget({required this.future});

  final Future<TestData> future;

  @override
  State<_CallbackAsyncWidget> createState() => _CallbackAsyncWidgetState();
}

class _CallbackAsyncWidgetState extends State<_CallbackAsyncWidget>
    with ops.AsyncOperationMixin<TestData, _CallbackAsyncWidget> {
  int loadingCalls = 0;
  int successCalls = 0;
  int errorCalls = 0;
  int idleCalls = 0;

  @override
  bool get loadOnInit => false;

  @override
  Future<TestData> fetch() async => widget.future;

  @override
  void onLoading() {
    loadingCalls += 1;
    super.onLoading();
  }

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
  void onIdle() {
    idleCalls += 1;
    super.onIdle();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  group('AsyncOperationMixin lifecycle callbacks', () {
    testWidgets('onLoading/onSuccess/onError/onIdle are invoked', (
      tester,
    ) async {
      final future = ControllableFuture<TestData>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: _CallbackAsyncWidget(future: future.future)),
        ),
      );

      final state = tester.state<_CallbackAsyncWidgetState>(
        find.byType(_CallbackAsyncWidget),
      );

      state.load();
      await tester.pump();

      expect(state.loadingCalls, equals(1));
      expect(state.successCalls, equals(0));
      expect(state.errorCalls, equals(0));
      expect(state.idleCalls, equals(0));

      future.complete(const TestData('data'));
      await tester.pump();

      expect(state.successCalls, equals(1));

      final future2 = ControllableFuture<TestData>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: _CallbackAsyncWidget(future: future2.future)),
        ),
      );

      final newState = tester.state<_CallbackAsyncWidgetState>(
        find.byType(_CallbackAsyncWidget),
      );

      newState.load();
      await tester.pump();
      future2.completeError(Exception('failure'));
      await tester.pump();

      expect(newState.errorCalls, equals(1));

      newState.setIdle();
      await tester.pump();
      expect(newState.idleCalls, equals(1));
    });
  });
}

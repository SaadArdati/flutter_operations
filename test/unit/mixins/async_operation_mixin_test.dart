@Timeout(Duration(seconds: 4))
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_operations/flutter_operations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';

class TestAsyncWidget extends StatefulWidget {
  final Future<TestData> Function()? fetchOverride;
  final bool? loadOnInitOverride;
  final bool? globalRefreshOverride;

  const TestAsyncWidget({
    super.key,
    this.fetchOverride,
    this.loadOnInitOverride,
    this.globalRefreshOverride,
  });

  @override
  State<TestAsyncWidget> createState() => _TestAsyncWidgetState();
}

class _TestAsyncWidgetState extends State<TestAsyncWidget>
    with AsyncOperationMixin<TestData, TestAsyncWidget> {
  @override
  bool get loadOnInit => widget.loadOnInitOverride ?? super.loadOnInit;

  @override
  bool get globalRefresh => widget.globalRefreshOverride ?? super.globalRefresh;

  @override
  Future<TestData> fetch() async {
    if (widget.fetchOverride != null) {
      return await widget.fetchOverride!();
    }
    return const TestData('default');
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

void main() {
  group('AsyncOperationMixin Unit Tests', () {
    group('Initialization Behavior', () {
      testWidgets(
        'should initialize with loading state when loadOnInit is true',
        (tester) async {
          final future = ControllableFuture<TestData>();

          await tester.pumpWidget(
            TestAsyncWidget(
              loadOnInitOverride: true,
              fetchOverride: () => future.future,
            ),
          );

          final state = tester.state<_TestAsyncWidgetState>(
            find.byType(TestAsyncWidget),
          );
          expect(state.operation.isLoading, isTrue);
          expect(state.operation.hasData, isFalse);

          future.complete(const TestData('loaded'));
          await tester.pumpAndSettle();

          expect(state.operation.isSuccess, isTrue);
          expect(state.operation.data?.value, equals('loaded'));
        },
      );

      testWidgets(
        'should initialize with idle state when loadOnInit is false',
        (tester) async {
          await tester.pumpWidget(
            const TestAsyncWidget(loadOnInitOverride: false),
          );

          final state = tester.state<_TestAsyncWidgetState>(
            find.byType(TestAsyncWidget),
          );
          expect(state.operation.isIdle, isTrue);
          expect(state.operation.hasData, isFalse);
        },
      );
    });

    group('State Management', () {
      testWidgets('should handle successful data loading', (tester) async {
        final future = ControllableFuture<TestData>();

        await tester.pumpWidget(
          TestAsyncWidget(
            loadOnInitOverride: false,
            fetchOverride: () => future.future,
          ),
        );

        final state = tester.state<_TestAsyncWidgetState>(
          find.byType(TestAsyncWidget),
        );

        state.load();
        await tester.pump();

        expect(state.operation.isLoading, isTrue);

        future.complete(const TestData('success'));
        await tester.pumpAndSettle();

        expect(state.operation.isSuccess, isTrue);
        expect(state.operation.data?.value, equals('success'));
      });

      testWidgets('should handle error during loading', (tester) async {
        final future = ControllableFuture<TestData>();

        await tester.pumpWidget(
          TestAsyncWidget(
            loadOnInitOverride: false,
            fetchOverride: () => future.future,
          ),
        );

        final state = tester.state<_TestAsyncWidgetState>(
          find.byType(TestAsyncWidget),
        );

        state.load();
        await tester.pump();

        expect(state.operation.isLoading, isTrue);

        future.completeError(Exception('Load failed'));
        await tester.pumpAndSettle();

        expect(state.operation.isError, isTrue);
        expect(
          (state.operation as ErrorOperation).message,
          contains('Load failed'),
        );
      });

      testWidgets('should preserve cached data during reload with error', (
        tester,
      ) async {
        final futures = [
          ControllableFuture<TestData>(),
          ControllableFuture<TestData>(),
        ];
        int callCount = 0;

        await tester.pumpWidget(
          TestAsyncWidget(
            loadOnInitOverride: false,
            fetchOverride: () => futures[callCount++].future,
          ),
        );

        final state = tester.state<_TestAsyncWidgetState>(
          find.byType(TestAsyncWidget),
        );

        state.load();
        await tester.pump();
        futures[0].complete(const TestData('cached'));
        await tester.pumpAndSettle();

        expect(state.operation.isSuccess, isTrue);
        expect(state.operation.data?.value, equals('cached'));

        state.reload(cached: true);
        await tester.pump();
        futures[1].completeError(Exception('Reload failed'));
        await tester.pumpAndSettle();

        expect(state.operation.isError, isTrue);
        expect(state.operation.hasData, isTrue);
        expect(state.operation.data?.value, equals('cached'));
      });
    });

    group('Manual State Operations', () {
      testWidgets('should handle manual success state setting', (tester) async {
        await tester.pumpWidget(
          const TestAsyncWidget(loadOnInitOverride: false),
        );

        final state = tester.state<_TestAsyncWidgetState>(
          find.byType(TestAsyncWidget),
        );

        state.setSuccess(const TestData('manual'));
        await tester.pump();

        expect(state.operation.isSuccess, isTrue);
        expect(state.operation.data?.value, equals('manual'));
      });

      testWidgets('should handle manual error state setting', (tester) async {
        await tester.pumpWidget(
          const TestAsyncWidget(loadOnInitOverride: false),
        );

        final state = tester.state<_TestAsyncWidgetState>(
          find.byType(TestAsyncWidget),
        );

        state.setError(
          Exception('Manual error'),
          StackTrace.current,
          message: 'Manual error message',
        );
        await tester.pump();

        expect(state.operation.isError, isTrue);
        expect(
          (state.operation as ErrorOperation).message,
          equals('Manual error message'),
        );
      });

      testWidgets('should handle manual idle state setting', (tester) async {
        await tester.pumpWidget(
          const TestAsyncWidget(loadOnInitOverride: false),
        );

        final state = tester.state<_TestAsyncWidgetState>(
          find.byType(TestAsyncWidget),
        );

        state.setSuccess(const TestData('data'));
        await tester.pump();

        state.setIdle(cached: true);
        await tester.pump();

        expect(state.operation.isIdle, isTrue);
        expect(state.operation.hasData, isTrue);
        expect(state.operation.data?.value, equals('data'));
      });
    });

    group('Race Condition Prevention', () {
      testWidgets('should prevent race conditions with generation tracking', (
        tester,
      ) async {
        final futures = [
          ControllableFuture<TestData>(),
          ControllableFuture<TestData>(),
        ];
        int callCount = 0;

        await tester.pumpWidget(
          TestAsyncWidget(
            loadOnInitOverride: false,
            fetchOverride: () => futures[callCount++].future,
          ),
        );

        final state = tester.state<_TestAsyncWidgetState>(
          find.byType(TestAsyncWidget),
        );

        state.load();
        await tester.pump();

        state.load();
        await tester.pump();

        futures[0].complete(const TestData('first'));
        await tester.pump();

        futures[1].complete(const TestData('second'));
        await tester.pumpAndSettle();

        expect(state.operation.isSuccess, isTrue);
        expect(state.operation.data?.value, equals('second'));
      });

      testWidgets('should ignore operations after widget disposal', (
        tester,
      ) async {
        final future = ControllableFuture<TestData>();

        await tester.pumpWidget(
          TestAsyncWidget(
            loadOnInitOverride: true,
            fetchOverride: () => future.future,
          ),
        );

        await tester.pumpWidget(Container());

        future.complete(const TestData('after disposal'));
        await tester.pump();

        expect(find.byType(TestAsyncWidget), findsNothing);
      });
    });

    group('Lifecycle Callbacks', () {
      testWidgets('should call appropriate lifecycle callbacks', (
        tester,
      ) async {
        final future = ControllableFuture<TestData>();

        await tester.pumpWidget(
          TestAsyncWidget(
            loadOnInitOverride: false,
            fetchOverride: () => future.future,
          ),
        );

        final state = tester.state<_TestAsyncWidgetState>(
          find.byType(TestAsyncWidget),
        );

        state.load();
        await tester.pump();

        expect(state.operation.isLoading, isTrue);

        future.complete(const TestData('callback test'));
        await tester.pumpAndSettle();

        expect(state.operation.isSuccess, isTrue);
      });
    });

    group('Error Message Handling', () {
      testWidgets('should generate appropriate error messages', (tester) async {
        await tester.pumpWidget(
          const TestAsyncWidget(loadOnInitOverride: false),
        );

        final state = tester.state<_TestAsyncWidgetState>(
          find.byType(TestAsyncWidget),
        );

        final exception = Exception('Test exception');
        final stackTrace = StackTrace.current;
        final message = state.errorMessage(exception, stackTrace);

        expect(message, contains('Test exception'));
      });
    });

    group('ValueNotifier Integration', () {
      testWidgets('should update operationNotifier correctly', (tester) async {
        await tester.pumpWidget(
          const TestAsyncWidget(loadOnInitOverride: false),
        );

        final state = tester.state<_TestAsyncWidgetState>(
          find.byType(TestAsyncWidget),
        );
        final notifications = <OperationState<TestData>>[];

        state.operationNotifier.addListener(() {
          notifications.add(state.operationNotifier.value);
        });

        state.setLoading();
        state.setSuccess(const TestData('test'));
        state.setError(Exception('error'), StackTrace.current);
        state.setIdle();

        await tester.pump();

        expect(notifications.length, greaterThan(0));
        expect(notifications.any((n) => n.isLoading), isTrue);
        expect(notifications.any((n) => n.isSuccess), isTrue);
        expect(notifications.any((n) => n.isError), isTrue);
        expect(notifications.any((n) => n.isIdle), isTrue);
      });
    });
  });
}

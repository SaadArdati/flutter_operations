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

      testWidgets('should handle manual success state with message', (
        tester,
      ) async {
        await tester.pumpWidget(
          const TestAsyncWidget(loadOnInitOverride: false),
        );

        final state = tester.state<_TestAsyncWidgetState>(
          find.byType(TestAsyncWidget),
        );

        state.setSuccess(
          const TestData('manual'),
          message: 'Manual success message',
        );
        await tester.pump();

        expect(state.operation.isSuccess, isTrue);
        expect(state.operation.data?.value, equals('manual'));
        expect(
          (state.operation as SuccessOperation).message,
          equals('Manual success message'),
        );
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

    group('fetchWithMessage', () {
      testWidgets('should use fetchWithMessage when overridden', (
        tester,
      ) async {
        await tester.pumpWidget(
          const _FetchWithMessageWidget(loadOnInitOverride: false),
        );

        final state = tester.state<_FetchWithMessageWidgetState>(
          find.byType(_FetchWithMessageWidget),
        );

        state.load();
        await tester.pumpAndSettle();

        expect(state.operation.isSuccess, isTrue);
        expect(state.operation.data?.value, equals('from fetchWithMessage'));
        expect(
          (state.operation as SuccessOperation).message,
          equals('Success message from fetchWithMessage'),
        );
      });

      testWidgets(
        'should throw StateError if both fetch and fetchWithMessage are overridden',
        (tester) async {
          await tester.pumpWidget(
            const _BothMethodsWidget(loadOnInitOverride: false),
          );

          final state = tester.state<_BothMethodsWidgetState>(
            find.byType(_BothMethodsWidget),
          );

          expect(() => state.load(), throwsStateError);
        },
      );

      testWidgets(
        'should throw StateError if neither fetch nor fetchWithMessage are overridden',
        (tester) async {
          await tester.pumpWidget(
            const _NoMethodWidget(loadOnInitOverride: false),
          );

          final state = tester.state<_NoMethodWidgetState>(
            find.byType(_NoMethodWidget),
          );

          expect(() => state.load(), throwsStateError);
        },
      );

      testWidgets(
        'should handle fetchWithMessage throwing exceptions correctly',
        (tester) async {
          await tester.pumpWidget(
            const _FetchWithMessageErrorWidget(loadOnInitOverride: false),
          );

          final state = tester.state<_FetchWithMessageErrorWidgetState>(
            find.byType(_FetchWithMessageErrorWidget),
          );

          state.load();
          await tester.pumpAndSettle();

          expect(state.operation.isError, isTrue);
          expect(
            (state.operation as ErrorOperation).message,
            contains('Network error'),
          );
        },
      );

      testWidgets(
        'should handle fetch throwing exceptions when fetchWithMessage not overridden',
        (tester) async {
          await tester.pumpWidget(
            const _FetchErrorWidget(loadOnInitOverride: false),
          );

          final state = tester.state<_FetchErrorWidgetState>(
            find.byType(_FetchErrorWidget),
          );

          state.load();
          await tester.pumpAndSettle();

          expect(state.operation.isError, isTrue);
          expect(
            (state.operation as ErrorOperation).message,
            contains('Custom fetch error'),
          );
        },
      );

      testWidgets(
        'should verify error message when both methods are overridden',
        (tester) async {
          await tester.pumpWidget(
            const _BothMethodsWidget(loadOnInitOverride: false),
          );

          final state = tester.state<_BothMethodsWidgetState>(
            find.byType(_BothMethodsWidget),
          );

          expect(
            () => state.load(),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('Both fetch() and fetchWithMessage() are overridden'),
              ),
            ),
          );
        },
      );

      testWidgets(
        'should verify error message when neither method is overridden',
        (tester) async {
          await tester.pumpWidget(
            const _NoMethodWidget(loadOnInitOverride: false),
          );

          final state = tester.state<_NoMethodWidgetState>(
            find.byType(_NoMethodWidget),
          );

          expect(
            () => state.load(),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains(
                  'Neither fetch() nor fetchWithMessage() are overridden',
                ),
              ),
            ),
          );
        },
      );

      testWidgets('should handle fetchWithMessage returning null message', (
        tester,
      ) async {
        await tester.pumpWidget(
          const _FetchWithMessageNullWidget(loadOnInitOverride: false),
        );

        final state = tester.state<_FetchWithMessageNullWidgetState>(
          find.byType(_FetchWithMessageNullWidget),
        );

        state.load();
        await tester.pumpAndSettle();

        expect(state.operation.isSuccess, isTrue);
        expect((state.operation as SuccessOperation).message, isNull);
      });

      testWidgets(
        'should handle fetchWithMessage throwing StateError (internal exception)',
        (tester) async {
          await tester.pumpWidget(
            const _FetchWithMessageStateErrorWidget(loadOnInitOverride: false),
          );

          final state = tester.state<_FetchWithMessageStateErrorWidgetState>(
            find.byType(_FetchWithMessageStateErrorWidget),
          );

          // StateError should be re-thrown, not caught as regular error
          expect(() => state.load(), throwsStateError);
        },
      );

      testWidgets('should handle fetchWithMessage throwing FormatException', (
        tester,
      ) async {
        await tester.pumpWidget(
          const _FetchWithMessageFormatErrorWidget(loadOnInitOverride: false),
        );

        final state = tester.state<_FetchWithMessageFormatErrorWidgetState>(
          find.byType(_FetchWithMessageFormatErrorWidget),
        );

        state.load();
        await tester.pumpAndSettle();

        expect(state.operation.isError, isTrue);
        expect(
          (state.operation as ErrorOperation).message,
          contains('Invalid format'),
        );
      });

      testWidgets('should handle fetchWithMessage throwing ArgumentError', (
        tester,
      ) async {
        await tester.pumpWidget(
          const _FetchWithMessageArgumentErrorWidget(loadOnInitOverride: false),
        );

        final state = tester.state<_FetchWithMessageArgumentErrorWidgetState>(
          find.byType(_FetchWithMessageArgumentErrorWidget),
        );

        state.load();
        await tester.pumpAndSettle();

        expect(state.operation.isError, isTrue);
        // ArgumentError wraps the message with "Invalid argument(s):"
        final errorMessage = (state.operation as ErrorOperation).message ?? '';
        expect(errorMessage, contains('null value not allowed'));
      });

      testWidgets(
        'should handle fetch throwing FormatException when fetchWithMessage not overridden',
        (tester) async {
          await tester.pumpWidget(
            const _FetchFormatErrorWidget(loadOnInitOverride: false),
          );

          final state = tester.state<_FetchFormatErrorWidgetState>(
            find.byType(_FetchFormatErrorWidget),
          );

          state.load();
          await tester.pumpAndSettle();

          expect(state.operation.isError, isTrue);
          expect(
            (state.operation as ErrorOperation).message,
            contains('Parsing failed'),
          );
        },
      );
    });
  });
}

class _FetchWithMessageWidget extends StatefulWidget {
  final bool? loadOnInitOverride;

  const _FetchWithMessageWidget({this.loadOnInitOverride});

  @override
  State<_FetchWithMessageWidget> createState() =>
      _FetchWithMessageWidgetState();
}

class _FetchWithMessageWidgetState extends State<_FetchWithMessageWidget>
    with AsyncOperationMixin<TestData, _FetchWithMessageWidget> {
  @override
  bool get loadOnInit => widget.loadOnInitOverride ?? super.loadOnInit;

  @override
  Future<OperationResult<TestData>> fetchWithMessage() async {
    return OperationResult(
      const TestData('from fetchWithMessage'),
      message: 'Success message from fetchWithMessage',
    );
  }

  @override
  Widget build(BuildContext context) => Container();
}

class _BothMethodsWidget extends StatefulWidget {
  final bool? loadOnInitOverride;

  const _BothMethodsWidget({this.loadOnInitOverride});

  @override
  State<_BothMethodsWidget> createState() => _BothMethodsWidgetState();
}

class _BothMethodsWidgetState extends State<_BothMethodsWidget>
    with AsyncOperationMixin<TestData, _BothMethodsWidget> {
  @override
  bool get loadOnInit => widget.loadOnInitOverride ?? super.loadOnInit;

  @override
  Future<TestData> fetch() async => const TestData('from fetch');

  @override
  Future<OperationResult<TestData>> fetchWithMessage() async {
    return OperationResult(
      const TestData('from fetchWithMessage'),
      message: 'Should error',
    );
  }

  @override
  Widget build(BuildContext context) => Container();
}

class _NoMethodWidget extends StatefulWidget {
  final bool? loadOnInitOverride;

  const _NoMethodWidget({this.loadOnInitOverride});

  @override
  State<_NoMethodWidget> createState() => _NoMethodWidgetState();
}

class _NoMethodWidgetState extends State<_NoMethodWidget>
    with AsyncOperationMixin<TestData, _NoMethodWidget> {
  @override
  bool get loadOnInit => widget.loadOnInitOverride ?? super.loadOnInit;

  // Neither fetch() nor fetchWithMessage() are overridden

  @override
  Widget build(BuildContext context) => Container();
}

class _FetchWithMessageErrorWidget extends StatefulWidget {
  final bool? loadOnInitOverride;

  const _FetchWithMessageErrorWidget({this.loadOnInitOverride});

  @override
  State<_FetchWithMessageErrorWidget> createState() =>
      _FetchWithMessageErrorWidgetState();
}

class _FetchWithMessageErrorWidgetState
    extends State<_FetchWithMessageErrorWidget>
    with AsyncOperationMixin<TestData, _FetchWithMessageErrorWidget> {
  @override
  bool get loadOnInit => widget.loadOnInitOverride ?? super.loadOnInit;

  @override
  Future<OperationResult<TestData>> fetchWithMessage() async {
    throw Exception('Network error: Connection timed out');
  }

  @override
  Widget build(BuildContext context) => Container();
}

class _FetchErrorWidget extends StatefulWidget {
  final bool? loadOnInitOverride;

  const _FetchErrorWidget({this.loadOnInitOverride});

  @override
  State<_FetchErrorWidget> createState() => _FetchErrorWidgetState();
}

class _FetchErrorWidgetState extends State<_FetchErrorWidget>
    with AsyncOperationMixin<TestData, _FetchErrorWidget> {
  @override
  bool get loadOnInit => widget.loadOnInitOverride ?? super.loadOnInit;

  @override
  Future<TestData> fetch() async {
    throw Exception('Custom fetch error');
  }

  @override
  Widget build(BuildContext context) => Container();
}

class _FetchWithMessageNullWidget extends StatefulWidget {
  final bool? loadOnInitOverride;

  const _FetchWithMessageNullWidget({this.loadOnInitOverride});

  @override
  State<_FetchWithMessageNullWidget> createState() =>
      _FetchWithMessageNullWidgetState();
}

class _FetchWithMessageNullWidgetState
    extends State<_FetchWithMessageNullWidget>
    with AsyncOperationMixin<TestData, _FetchWithMessageNullWidget> {
  @override
  bool get loadOnInit => widget.loadOnInitOverride ?? super.loadOnInit;

  @override
  Future<OperationResult<TestData>> fetchWithMessage() async {
    return OperationResult(
      const TestData('data without message'),
      message: null,
    );
  }

  @override
  Widget build(BuildContext context) => Container();
}

class _FetchWithMessageStateErrorWidget extends StatefulWidget {
  final bool? loadOnInitOverride;

  const _FetchWithMessageStateErrorWidget({this.loadOnInitOverride});

  @override
  State<_FetchWithMessageStateErrorWidget> createState() =>
      _FetchWithMessageStateErrorWidgetState();
}

class _FetchWithMessageStateErrorWidgetState
    extends State<_FetchWithMessageStateErrorWidget>
    with AsyncOperationMixin<TestData, _FetchWithMessageStateErrorWidget> {
  @override
  bool get loadOnInit => widget.loadOnInitOverride ?? super.loadOnInit;

  @override
  Future<OperationResult<TestData>> fetchWithMessage() async {
    throw StateError('Invalid state');
  }

  @override
  Widget build(BuildContext context) => Container();
}

class _FetchWithMessageFormatErrorWidget extends StatefulWidget {
  final bool? loadOnInitOverride;

  const _FetchWithMessageFormatErrorWidget({this.loadOnInitOverride});

  @override
  State<_FetchWithMessageFormatErrorWidget> createState() =>
      _FetchWithMessageFormatErrorWidgetState();
}

class _FetchWithMessageFormatErrorWidgetState
    extends State<_FetchWithMessageFormatErrorWidget>
    with AsyncOperationMixin<TestData, _FetchWithMessageFormatErrorWidget> {
  @override
  bool get loadOnInit => widget.loadOnInitOverride ?? super.loadOnInit;

  @override
  Future<OperationResult<TestData>> fetchWithMessage() async {
    throw FormatException('Invalid format: JSON parsing failed');
  }

  @override
  Widget build(BuildContext context) => Container();
}

class _FetchWithMessageArgumentErrorWidget extends StatefulWidget {
  final bool? loadOnInitOverride;

  const _FetchWithMessageArgumentErrorWidget({this.loadOnInitOverride});

  @override
  State<_FetchWithMessageArgumentErrorWidget> createState() =>
      _FetchWithMessageArgumentErrorWidgetState();
}

class _FetchWithMessageArgumentErrorWidgetState
    extends State<_FetchWithMessageArgumentErrorWidget>
    with AsyncOperationMixin<TestData, _FetchWithMessageArgumentErrorWidget> {
  @override
  bool get loadOnInit => widget.loadOnInitOverride ?? super.loadOnInit;

  @override
  Future<OperationResult<TestData>> fetchWithMessage() async {
    throw ArgumentError('Invalid argument: null value not allowed');
  }

  @override
  Widget build(BuildContext context) => Container();
}

class _FetchFormatErrorWidget extends StatefulWidget {
  final bool? loadOnInitOverride;

  const _FetchFormatErrorWidget({this.loadOnInitOverride});

  @override
  State<_FetchFormatErrorWidget> createState() =>
      _FetchFormatErrorWidgetState();
}

class _FetchFormatErrorWidgetState extends State<_FetchFormatErrorWidget>
    with AsyncOperationMixin<TestData, _FetchFormatErrorWidget> {
  @override
  bool get loadOnInit => widget.loadOnInitOverride ?? super.loadOnInit;

  @override
  Future<TestData> fetch() async {
    throw FormatException('Parsing failed: invalid data structure');
  }

  @override
  Widget build(BuildContext context) => Container();
}

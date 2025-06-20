@Timeout(Duration(seconds: 4))
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_operations/flutter_operations.dart';
import 'package:flutter_test/flutter_test.dart';

class TestData {
  final String value;

  const TestData(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TestData && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'TestData($value)';
}

// Test widget using AsyncOperationMixin with globalRefresh = true
class GlobalRefreshTestWidget extends StatefulWidget {
  final Future<TestData> Function()? mockFetch;
  final bool? mockLoadOnInit;

  const GlobalRefreshTestWidget({
    super.key,
    this.mockFetch,
    this.mockLoadOnInit,
  });

  @override
  State<GlobalRefreshTestWidget> createState() =>
      _GlobalRefreshTestWidgetState();
}

class _GlobalRefreshTestWidgetState extends State<GlobalRefreshTestWidget>
    with AsyncOperationMixin<TestData, GlobalRefreshTestWidget> {
  @override
  bool get loadOnInit => widget.mockLoadOnInit ?? super.loadOnInit;

  @override
  bool get globalRefresh => true; // Test global refresh behavior

  @override
  Future<TestData> fetch() async {
    if (widget.mockFetch != null) {
      return await widget.mockFetch!();
    }
    return const TestData('default');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            // Display current state
            switch (operation) {
              LoadingOperation(data: null) => const Text('Loading'),
              LoadingOperation(:var data?) => Text(
                'Loading with ${data.value}',
              ),
              SuccessOperation(:var data) => Text('Success: ${data.value}'),
              ErrorOperation(:var message, data: null) => Text(
                'Error: $message',
              ),
              ErrorOperation(:var message, :var data?) => Text(
                'Error: $message with ${data.value}',
              ),
            },

            // Action buttons
            ElevatedButton(
              key: const Key('reload_cached'),
              onPressed: () => reload(cached: true),
              child: const Text('Reload Cached'),
            ),
            ElevatedButton(
              key: const Key('reload_fresh'),
              onPressed: () => reload(cached: false),
              child: const Text('Reload Fresh'),
            ),
            ElevatedButton(
              key: const Key('manual_success'),
              onPressed: () => setSuccess(const TestData('manual')),
              child: const Text('Set Success'),
            ),
            ElevatedButton(
              key: const Key('manual_error'),
              onPressed: () => setError(
                Exception('Manual error'),
                StackTrace.current,
                message: 'Manual error message',
              ),
              child: const Text('Set Error'),
            ),
          ],
        ),
      ),
    );
  }
}

// Test widget using AsyncOperationMixin with ValueListenableBuilder
class ValueListenableTestWidget extends StatefulWidget {
  final Future<TestData> Function()? mockFetch;
  final bool? mockLoadOnInit;

  const ValueListenableTestWidget({
    super.key,
    this.mockFetch,
    this.mockLoadOnInit,
  });

  @override
  State<ValueListenableTestWidget> createState() =>
      _ValueListenableTestWidgetState();
}

class _ValueListenableTestWidgetState extends State<ValueListenableTestWidget>
    with AsyncOperationMixin<TestData, ValueListenableTestWidget> {
  @override
  bool get loadOnInit => widget.mockLoadOnInit ?? super.loadOnInit;

  @override
  bool get globalRefresh => false; // Test ValueListenableBuilder approach

  @override
  Future<TestData> fetch() async {
    if (widget.mockFetch != null) {
      return await widget.mockFetch!();
    }
    return const TestData('default');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder<OperationState<TestData>>(
          valueListenable: operationNotifier,
          builder: (context, state, child) {
            return Column(
              children: [
                // Display current state
                switch (state) {
                  LoadingOperation(data: null) => const Text('Loading'),
                  LoadingOperation(:var data?) => Text(
                    'Loading with ${data.value}',
                  ),
                  SuccessOperation(:var data) => Text('Success: ${data.value}'),
                  ErrorOperation(:var message, data: null) => Text(
                    'Error: $message',
                  ),
                  ErrorOperation(:var message, :var data?) => Text(
                    'Error: $message with ${data.value}',
                  ),
                },

                // Action buttons
                ElevatedButton(
                  key: const Key('reload_button'),
                  onPressed: () => reload(),
                  child: const Text('Reload'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

void main() {
  group('AsyncOperationMixin Widget Integration Tests', () {
    group('GlobalRefresh Behavior', () {
      testWidgets(
        'should show loading state initially when loadOnInit is true',
        (tester) async {
          final completer = Completer<TestData>();

          await tester.pumpWidget(
            GlobalRefreshTestWidget(mockFetch: () => completer.future),
          );

          expect(find.text('Loading'), findsOneWidget);
          expect(find.text('Success:'), findsNothing);
          expect(find.text('Error:'), findsNothing);

          // Complete the fetch
          completer.complete(const TestData('test'));
          await tester.pumpAndSettle();

          expect(find.text('Success: test'), findsOneWidget);
          expect(find.text('Loading'), findsNothing);
        },
      );

      testWidgets('should not auto-load when loadOnInit is false', (
        tester,
      ) async {
        bool fetchCalled = false;

        await tester.pumpWidget(
          GlobalRefreshTestWidget(
            mockLoadOnInit: false,
            mockFetch: () async {
              fetchCalled = true;
              return const TestData('test');
            },
          ),
        );

        await tester.pump();

        // Should show idle loading state (no explicit text for this, but fetch shouldn't be called)
        expect(fetchCalled, isFalse);

        // Manually trigger reload
        await tester.tap(find.byKey(const Key('reload_cached')));
        await tester.pumpAndSettle();

        expect(fetchCalled, isTrue);
        expect(find.text('Success: test'), findsOneWidget);
      });

      testWidgets('should handle successful data loading', (tester) async {
        final completer = Completer<TestData>();

        await tester.pumpWidget(
          GlobalRefreshTestWidget(mockFetch: () => completer.future),
        );

        // Initially loading
        expect(find.text('Loading'), findsOneWidget);

        // Complete the operation
        completer.complete(const TestData('success data'));
        await tester.pumpAndSettle();

        // Should show success
        expect(find.text('Success: success data'), findsOneWidget);
        expect(find.text('Loading'), findsNothing);
      });

      testWidgets('should handle errors gracefully', (tester) async {
        final completer = Completer<TestData>();

        await tester.pumpWidget(
          GlobalRefreshTestWidget(mockFetch: () => completer.future),
        );

        // Initially loading
        expect(find.text('Loading'), findsOneWidget);

        // Complete with error
        completer.completeError(Exception('Network error'));
        await tester.pumpAndSettle();

        // Should show error
        expect(
          find.textContaining('Error: Exception: Network error'),
          findsOneWidget,
        );
        expect(find.text('Loading'), findsNothing);
      });

      testWidgets('should preserve cached data during reload', (tester) async {
        int callCount = 0;
        final reloadCompleter = Completer<TestData>();

        await tester.pumpWidget(
          GlobalRefreshTestWidget(
            mockFetch: () {
              callCount++;
              if (callCount == 1) {
                return Future.value(const TestData('first'));
              } else {
                return reloadCompleter.future;
              }
            },
          ),
        );

        // Wait for initial load
        await tester.pumpAndSettle();
        expect(find.text('Success: first'), findsOneWidget);

        // Trigger cached reload
        await tester.tap(find.byKey(const Key('reload_cached')));
        await tester.pump(); // Just one frame to see loading state

        // Should show loading with cached data
        expect(find.text('Loading with first'), findsOneWidget);

        // Complete reload
        reloadCompleter.complete(const TestData('second'));
        await tester.pumpAndSettle();
        expect(find.text('Success: second'), findsOneWidget);
      });

      testWidgets('should not preserve cached data when cached=false', (
        tester,
      ) async {
        int callCount = 0;
        final reloadCompleter = Completer<TestData>();

        await tester.pumpWidget(
          GlobalRefreshTestWidget(
            mockFetch: () {
              callCount++;
              if (callCount == 1) {
                return Future.value(const TestData('first'));
              } else {
                return reloadCompleter.future;
              }
            },
          ),
        );

        // Wait for initial load
        await tester.pumpAndSettle();
        expect(find.text('Success: first'), findsOneWidget);

        // Trigger fresh reload
        await tester.tap(find.byKey(const Key('reload_fresh')));
        await tester.pump(); // Just one frame to see loading state

        // Should show loading without cached data
        expect(find.text('Loading'), findsOneWidget);
        expect(find.text('Loading with first'), findsNothing);

        // Complete reload
        reloadCompleter.complete(const TestData('second'));
        await tester.pumpAndSettle();
        expect(find.text('Success: second'), findsOneWidget);
      });

      testWidgets('should handle race conditions properly', (tester) async {
        final completer1 = Completer<TestData>();
        final completer2 = Completer<TestData>();
        int callCount = 0;

        await tester.pumpWidget(
          GlobalRefreshTestWidget(
            mockFetch: () async {
              callCount++;
              if (callCount == 1) {
                return completer1.future;
              } else {
                return completer2.future;
              }
            },
          ),
        );

        await tester.pump();

        // Start second load before first completes
        await tester.tap(find.byKey(const Key('reload_fresh')));
        await tester.pump();

        // Complete first request (should be ignored)
        completer1.complete(const TestData('first'));
        await tester.pump();

        // Complete second request (should be used)
        completer2.complete(const TestData('second'));
        await tester.pumpAndSettle();

        expect(find.text('Success: second'), findsOneWidget);
        expect(find.text('Success: first'), findsNothing);
      });

      testWidgets('should handle manual state updates', (tester) async {
        await tester.pumpWidget(GlobalRefreshTestWidget(mockLoadOnInit: false));

        // Manually set success
        await tester.tap(find.byKey(const Key('manual_success')));
        await tester.pump();

        expect(find.text('Success: manual'), findsOneWidget);

        // Manually set error
        await tester.tap(find.byKey(const Key('manual_error')));
        await tester.pump();

        expect(
          find.text('Error: Manual error message with manual'),
          findsOneWidget,
        );
      });

      testWidgets('should show error with cached data on reload failure', (
        tester,
      ) async {
        int callCount = 0;
        final reloadCompleter = Completer<TestData>();

        await tester.pumpWidget(
          GlobalRefreshTestWidget(
            mockFetch: () {
              callCount++;
              if (callCount == 1) {
                return Future.value(const TestData('success'));
              } else {
                return reloadCompleter.future;
              }
            },
          ),
        );

        // Wait for initial success
        await tester.pumpAndSettle();
        expect(find.text('Success: success'), findsOneWidget);

        // Trigger reload that will fail
        await tester.tap(find.byKey(const Key('reload_cached')));
        reloadCompleter.completeError(Exception('Reload failed'));
        await tester.pumpAndSettle();

        // Should show error with cached data
        expect(
          find.textContaining('Error: Exception: Reload failed with success'),
          findsOneWidget,
        );
      });
    });

    group('ValueListenableBuilder Behavior', () {
      testWidgets('should work with ValueListenableBuilder approach', (
        tester,
      ) async {
        int callCount = 0;
        final completer1 = Completer<TestData>();
        final completer2 = Completer<TestData>();

        await tester.pumpWidget(
          ValueListenableTestWidget(
            mockFetch: () {
              callCount++;
              if (callCount == 1) {
                return completer1.future;
              } else {
                return completer2.future;
              }
            },
          ),
        );

        // Initially loading
        expect(find.text('Loading'), findsOneWidget);

        // Complete the operation
        completer1.complete(const TestData('valuelistenable test'));
        await tester.pumpAndSettle();

        // Should show success
        expect(find.text('Success: valuelistenable test'), findsOneWidget);

        // Test reload functionality
        await tester.tap(find.byKey(const Key('reload_button')));
        await tester.pump();

        // Should show loading with cached data
        expect(find.text('Loading with valuelistenable test'), findsOneWidget);

        // Complete the reload
        completer2.complete(const TestData('valuelistenable test'));
        await tester.pumpAndSettle();
        expect(find.text('Success: valuelistenable test'), findsOneWidget);
      });

      testWidgets('should update UI only through ValueListenableBuilder', (
        tester,
      ) async {
        int buildCount = 0;
        final completer = Completer<TestData>();

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              buildCount++;
              return ValueListenableTestWidget(
                mockFetch: () => completer.future,
              );
            },
          ),
        );

        final initialBuildCount = buildCount;

        // Complete the operation
        completer.complete(const TestData('build count test'));
        await tester.pumpAndSettle();

        // Build count should not increase significantly since globalRefresh = false
        // (Only initial builds and ValueListenableBuilder rebuilds)
        expect(buildCount, lessThanOrEqualTo(initialBuildCount + 1));
        expect(find.text('Success: build count test'), findsOneWidget);
      });
    });

    group('Edge Cases and Error Scenarios', () {
      testWidgets('should handle widget disposal during async operation', (
        tester,
      ) async {
        final completer = Completer<TestData>();

        await tester.pumpWidget(
          GlobalRefreshTestWidget(mockFetch: () => completer.future),
        );

        expect(find.text('Loading'), findsOneWidget);

        // Remove widget from tree
        await tester.pumpWidget(const SizedBox());

        // Complete the operation after disposal
        completer.complete(const TestData('after disposal'));
        await tester.pump();

        // Should not cause any errors or crashes
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle synchronous fetch operations', (tester) async {
        await tester.pumpWidget(
          GlobalRefreshTestWidget(
            mockFetch: () => Future.value(const TestData('sync')),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Success: sync'), findsOneWidget);
      });

      testWidgets('should handle fetch that throws synchronously', (
        tester,
      ) async {
        await tester.pumpWidget(
          GlobalRefreshTestWidget(
            mockFetch: () => throw Exception('Sync error'),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.textContaining('Error: Exception: Sync error'),
          findsOneWidget,
        );
      });

      testWidgets('should handle multiple rapid reload calls', (tester) async {
        int callCount = 0;
        final completer3 = Completer<TestData>();

        await tester.pumpWidget(
          GlobalRefreshTestWidget(
            mockLoadOnInit: false,
            mockFetch: () {
              callCount++;
              if (callCount < 3) {
                return Future.value(TestData('call $callCount'));
              } else {
                return completer3.future;
              }
            },
          ),
        );

        // Trigger multiple rapid reloads
        await tester.tap(find.byKey(const Key('reload_fresh')));
        await tester.tap(find.byKey(const Key('reload_fresh')));
        await tester.tap(find.byKey(const Key('reload_fresh')));

        // Complete the final operation
        completer3.complete(const TestData('call 3'));
        await tester.pumpAndSettle();

        // Should only show the result of the last call due to race condition handling
        expect(find.text('Success: call 3'), findsOneWidget);
      });
    });
  });
}

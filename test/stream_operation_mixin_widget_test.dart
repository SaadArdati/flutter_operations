@Timeout(Duration(seconds: 4))
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_operations/flutter_operations.dart';
import 'package:flutter_test/flutter_test.dart';

class StreamTestData {
  final int value;
  const StreamTestData(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is StreamTestData && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'StreamTestData($value)';
}

// Test widget using StreamOperationMixin with globalRefresh = true
class GlobalRefreshStreamWidget extends StatefulWidget {
  final Stream<StreamTestData> Function()? mockStream;
  final bool? mockListenOnInit;

  const GlobalRefreshStreamWidget({
    super.key,
    this.mockStream,
    this.mockListenOnInit,
  });

  @override
  State<GlobalRefreshStreamWidget> createState() =>
      _GlobalRefreshStreamWidgetState();
}

class _GlobalRefreshStreamWidgetState extends State<GlobalRefreshStreamWidget>
    with StreamOperationMixin<StreamTestData, GlobalRefreshStreamWidget> {
  @override
  bool get listenOnInit => widget.mockListenOnInit ?? super.listenOnInit;

  @override
  bool get globalRefresh => true; // Test global refresh behavior

  @override
  Stream<StreamTestData> stream() {
    if (widget.mockStream != null) {
      return widget.mockStream!();
    }
    return Stream.value(const StreamTestData(0));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            // Display current state
            switch (operation) {
              IdleOperation(data: null) => const Text('Idle'),
              IdleOperation(:var data?) => Text('Idle with ${data.value}'),
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
              key: const Key('listen_cached'),
              onPressed: () => listen(cached: true),
              child: const Text('Listen Cached'),
            ),
            ElevatedButton(
              key: const Key('listen_fresh'),
              onPressed: () => listen(cached: false),
              child: const Text('Listen Fresh'),
            ),
            ElevatedButton(
              key: const Key('manual_success'),
              onPressed: () => setData(const StreamTestData(999)),
              child: const Text('Set Success'),
            ),
            ElevatedButton(
              key: const Key('manual_error'),
              onPressed: () => setError(
                Exception('Manual stream error'),
                StackTrace.current,
                message: 'Manual stream error message',
              ),
              child: const Text('Set Error'),
            ),
            ElevatedButton(
              key: const Key('set_idle'),
              onPressed: () => setIdle(),
              child: const Text('Set Idle'),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  group('StreamOperationMixin Widget Integration Tests', () {
    testWidgets(
      'should show loading state initially when listenOnInit is true',
      (tester) async {
        final controller = StreamController<StreamTestData>();

        await tester.pumpWidget(
          GlobalRefreshStreamWidget(mockStream: () => controller.stream),
        );

        expect(find.text('Loading'), findsOneWidget);
        expect(find.text('Success:'), findsNothing);
        expect(find.text('Error:'), findsNothing);
        expect(find.text('Idle'), findsNothing);

        // Emit a value
        controller.add(const StreamTestData(42));
        await tester.pumpAndSettle();

        expect(find.text('Success: 42'), findsOneWidget);
        expect(find.text('Loading'), findsNothing);

        await controller.close();
      },
    );

    testWidgets('should show idle state when listenOnInit is false', (
      tester,
    ) async {
      bool streamCreated = false;

      await tester.pumpWidget(
        GlobalRefreshStreamWidget(
          mockListenOnInit: false,
          mockStream: () {
            streamCreated = true;
            return Stream.value(const StreamTestData(42));
          },
        ),
      );

      await tester.pump();

      // Should show idle state initially
      expect(find.text('Idle'), findsOneWidget);
      expect(find.text('Loading'), findsNothing);
      
      // Stream should not be created yet
      expect(streamCreated, isFalse);

      // Manually trigger listen
      await tester.tap(find.byKey(const Key('listen_cached')));
      await tester.pumpAndSettle();

      expect(streamCreated, isTrue);
      expect(find.text('Success: 42'), findsOneWidget);
    });

    testWidgets('should handle stream data updates', (tester) async {
      final controller = StreamController<StreamTestData>();

      await tester.pumpWidget(
        GlobalRefreshStreamWidget(mockStream: () => controller.stream),
      );

      // Initially loading
      expect(find.text('Loading'), findsOneWidget);

      // Emit first value
      controller.add(const StreamTestData(1));
      await tester.pump();
      await tester.pump(); // Extra pump to ensure stream processing
      expect(find.text('Success: 1'), findsOneWidget);

      await controller.close();
    });

    testWidgets('should preserve cached data during reconnection', (
      tester,
    ) async {
      int streamCount = 0;

      await tester.pumpWidget(
        GlobalRefreshStreamWidget(
          mockStream: () {
            streamCount++;
            // Use async stream to allow observing loading state
            return Stream.fromFuture(
              Future.delayed(
                const Duration(milliseconds: 10),
                () => StreamTestData(100 + streamCount),
              ),
            );
          },
        ),
      );

      // Wait for initial load
      await tester.pumpAndSettle();
      expect(find.text('Success: 101'), findsOneWidget);

      // Trigger reconnection with cached data
      await tester.tap(find.byKey(const Key('listen_cached')));
      await tester.pump(); // Should show loading with cached data
      
      expect(find.text('Loading with 101'), findsOneWidget);

      // Wait for new data
      await tester.pumpAndSettle();
      expect(find.text('Success: 102'), findsOneWidget);
    });

    testWidgets('should handle manual state transitions', (tester) async {
      await tester.pumpWidget(
        GlobalRefreshStreamWidget(
          mockListenOnInit: false,
          mockStream: () => Stream.value(const StreamTestData(0)),
        ),
      );

      // Initially idle
      expect(find.text('Idle'), findsOneWidget);

      // Set manual success
      await tester.tap(find.byKey(const Key('manual_success')));
      await tester.pump();
      expect(find.text('Success: 999'), findsOneWidget);

      // Set manual error
      await tester.tap(find.byKey(const Key('manual_error')));
      await tester.pump();
      expect(find.text('Error: Manual stream error message with 999'), findsOneWidget);

      // Set back to idle with cached data
      await tester.tap(find.byKey(const Key('set_idle')));
      await tester.pump();
      expect(find.text('Idle with 999'), findsOneWidget);
    });

    testWidgets('should handle error states correctly', (tester) async {
      late StreamController<StreamTestData> controller;
      
      await tester.pumpWidget(
        GlobalRefreshStreamWidget(
          mockStream: () {
            controller = StreamController<StreamTestData>();
            return controller.stream;
          },
        ),
      );

      // Initially loading
      expect(find.text('Loading'), findsOneWidget);

      // Emit data first
      controller.add(const StreamTestData(42));
      await tester.pump();
      expect(find.text('Success: 42'), findsOneWidget);

      // Trigger error with cached data
      await tester.tap(find.byKey(const Key('manual_error')));
      await tester.pump();
      expect(find.text('Error: Manual stream error message with 42'), findsOneWidget);

      await controller.close();
    });
  });
}

@Timeout(Duration(seconds: 4))
library;

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

void main() {
  group('AsyncOperationMixin', () {
    test('should handle successful operations', () async {
      final states = <OperationState<TestData>>[];

      // Initial loading state
      states.add(const LoadingOperation<TestData>(idle: false));

      // Success state
      final result = const TestData('success');
      states.add(SuccessOperation<TestData>(data: result));

      expect(states.first, isA<LoadingOperation<TestData>>());
      expect(states.last, isA<SuccessOperation<TestData>>());
      expect(
        (states.last as SuccessOperation<TestData>).data.value,
        equals('success'),
      );
    });

    test('should handle error operations', () async {
      final states = <OperationState<TestData>>[];

      // Initial loading state
      states.add(const LoadingOperation<TestData>(idle: false));

      // Error state
      final errorState = ErrorOperation<TestData>(
        message: 'Test error',
        exception: Exception('Test'),
        stackTrace: StackTrace.current,
      );
      states.add(errorState);

      expect(states.first, isA<LoadingOperation<TestData>>());
      expect(states.last, isA<ErrorOperation<TestData>>());
      expect(
        (states.last as ErrorOperation<TestData>).message,
        equals('Test error'),
      );
    });

    test('should handle cached data during operations', () async {
      const cachedData = TestData('cached');

      // Loading with cached data
      const loadingWithCache = LoadingOperation<TestData>(
        data: cachedData,
        idle: false,
      );

      // Error with cached data
      const errorWithCache = ErrorOperation<TestData>(
        message: 'Network error',
        data: cachedData,
      );

      expect(loadingWithCache.hasData, isTrue);
      expect(loadingWithCache.data, equals(cachedData));

      expect(errorWithCache.hasData, isTrue);
      expect(errorWithCache.data, equals(cachedData));
    });

    test('should handle state equality correctly', () {
      const state1 = LoadingOperation<TestData>(
        data: TestData('test'),
        idle: false,
      );
      const state2 = LoadingOperation<TestData>(
        data: TestData('test'),
        idle: false,
      );
      const state3 = LoadingOperation<TestData>(
        data: TestData('other'),
        idle: false,
      );

      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
    });

    test('should handle operation state transitions', () {
      final states = <String>[];

      // Simulate state transitions
      final operations = <OperationState<TestData>>[
        const LoadingOperation(idle: false),
        const SuccessOperation(data: TestData('result')),
        const LoadingOperation(
          data: TestData('result'),
          idle: false,
        ), // Reload with cache
        const ErrorOperation(
          message: 'Failed',
          data: TestData('result'),
        ), // Error with cache
      ];

      for (final op in operations) {
        final description = switch (op) {
          LoadingOperation(data: null) => 'Initial loading',
          LoadingOperation(:var data?) =>
            'Reloading with cached data: ${data.value}',
          SuccessOperation(:var data) => 'Success: ${data.value}',
          ErrorOperation(:var message, data: null) => 'Error: $message',
          ErrorOperation(:var message, :var data?) =>
            'Error: $message (showing cached: ${data.value})',
        };

        states.add(description);
      }

      expect(states, hasLength(4));
      expect(states[0], equals('Initial loading'));
      expect(states[1], equals('Success: result'));
      expect(states[2], equals('Reloading with cached data: result'));
      expect(states[3], equals('Error: Failed (showing cached: result)'));
    });
  });
}

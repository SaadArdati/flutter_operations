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
      states.add(const LoadingOperation<TestData>());

      // Success state
      final result = const TestData('success');
      states.add(SuccessOperation<TestData>(data: result));

      expect(states.first, isA<LoadingOperation<TestData>>());
      expect(states.first.isLoading, isTrue);
      expect(states.first.isIdle, isFalse);
      expect(states.first.isSuccess, isFalse);
      expect(states.first.isError, isFalse);

      expect(states.last, isA<SuccessOperation<TestData>>());
      expect(states.last.isLoading, isFalse);
      expect(states.last.isSuccess, isTrue);
      expect(states.last.isError, isFalse);
      expect(
        (states.last as SuccessOperation<TestData>).data.value,
        equals('success'),
      );
    });

    test('should handle error operations', () async {
      final states = <OperationState<TestData>>[];

      // Initial loading state
      states.add(const LoadingOperation<TestData>());

      // Error state
      final errorState = ErrorOperation<TestData>(
        message: 'Test error',
        exception: Exception('Test'),
        stackTrace: StackTrace.current,
      );
      states.add(errorState);

      expect(states.first, isA<LoadingOperation<TestData>>());
      expect(states.first.isLoading, isTrue);
      expect(states.first.isError, isFalse);

      expect(states.last, isA<ErrorOperation<TestData>>());
      expect(states.last.isLoading, isFalse);
      expect(states.last.isError, isTrue);
      expect(states.last.isSuccess, isFalse);
      expect(
        (states.last as ErrorOperation<TestData>).message,
        equals('Test error'),
      );
    });

    test('should handle idle operations', () async {
      final states = <OperationState<TestData>>[];

      // Idle state with no data
      states.add(const IdleOperation<TestData>());

      // Idle state with cached data
      const cachedData = TestData('cached');
      states.add(const IdleOperation<TestData>(data: cachedData));

      expect(states.first, isA<IdleOperation<TestData>>());
      expect(states.first.isIdle, isTrue);
      expect(states.first.isLoading, isFalse);
      expect(states.first.isNotIdle, isFalse);
      expect(states.first.hasData, isFalse);
      expect(states.first.hasNoData, isTrue);

      expect(states.last, isA<IdleOperation<TestData>>());
      expect(states.last.isIdle, isTrue);
      expect(states.last.hasData, isTrue);
      expect(states.last.data, equals(cachedData));
    });

    test('should handle cached data during operations', () async {
      const cachedData = TestData('cached');

      // Loading with cached data
      const loadingWithCache = LoadingOperation<TestData>(
        data: cachedData,
      );

      // Error with cached data
      const errorWithCache = ErrorOperation<TestData>(
        message: 'Network error',
        data: cachedData,
      );

      // Idle with cached data
      const idleWithCache = IdleOperation<TestData>(data: cachedData);

      expect(loadingWithCache.hasData, isTrue);
      expect(loadingWithCache.data, equals(cachedData));
      expect(loadingWithCache.isLoading, isTrue);

      expect(errorWithCache.hasData, isTrue);
      expect(errorWithCache.data, equals(cachedData));
      expect(errorWithCache.isError, isTrue);

      expect(idleWithCache.hasData, isTrue);
      expect(idleWithCache.data, equals(cachedData));
      expect(idleWithCache.isIdle, isTrue);
    });

    test('should handle state equality correctly', () {
      const state1 = LoadingOperation<TestData>(
        data: TestData('test'),
      );
      const state2 = LoadingOperation<TestData>(
        data: TestData('test'),
      );
      const state3 = LoadingOperation<TestData>(
        data: TestData('other'),
      );

      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));

      // Test IdleOperation equality
      const idle1 = IdleOperation<TestData>();
      const idle2 = IdleOperation<TestData>();
      const idle3 = IdleOperation<TestData>(data: TestData('test'));

      expect(idle1, equals(idle2));
      expect(idle1, isNot(equals(idle3)));
    });

    test('should handle empty success operations', () {
      const emptySuccess = SuccessOperation<TestData?>.empty();
      const regularSuccess = SuccessOperation<TestData>(data: TestData('test'));

      expect(emptySuccess.empty, isTrue);
      expect(emptySuccess.isSuccess, isTrue);
      expect(emptySuccess.hasData, isFalse);
      expect(emptySuccess.hasNoData, isTrue);

      expect(regularSuccess.empty, isFalse);
      expect(regularSuccess.isSuccess, isTrue);
      expect(regularSuccess.hasData, isTrue);
      expect(regularSuccess.data.value, equals('test'));

      // Should throw when accessing data on empty success
      expect(() => SuccessOperation<String>.empty().data, throwsA(isA<StateError>()));
    });

    test('should handle operation state transitions', () {
      final states = <String>[];

      // Simulate state transitions including idle
      final operations = <OperationState<TestData>>[
        const IdleOperation(),
        const LoadingOperation(),
        const SuccessOperation(data: TestData('result')),
        const LoadingOperation(
          data: TestData('result'),
        ), // Reload with cache
        const ErrorOperation(
          message: 'Failed',
          data: TestData('result'),
        ), // Error with cache
        const IdleOperation(data: TestData('result')), // Back to idle
      ];

      for (final op in operations) {
        final description = switch (op) {
          IdleOperation(data: null) => 'Idle with no data',
          IdleOperation(:var data?) => 'Idle with cached data: ${data.value}',
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

      expect(states, hasLength(6));
      expect(states[0], equals('Idle with no data'));
      expect(states[1], equals('Initial loading'));
      expect(states[2], equals('Success: result'));
      expect(states[3], equals('Reloading with cached data: result'));
      expect(states[4], equals('Error: Failed (showing cached: result)'));
      expect(states[5], equals('Idle with cached data: result'));
    });

    test('should handle convenience getters correctly', () {
      const loading = LoadingOperation<TestData>();
      const idle = IdleOperation<TestData>();
      const success = SuccessOperation<TestData>(data: TestData('test'));
      const error = ErrorOperation<TestData>(message: 'error');

      // isLoading tests
      expect(loading.isLoading, isTrue);
      expect(loading.isNotLoading, isFalse);
      expect(idle.isLoading, isFalse);
      expect(idle.isNotLoading, isTrue);
      expect(success.isLoading, isFalse);
      expect(error.isLoading, isFalse);

      // isIdle tests
      expect(loading.isIdle, isFalse);
      expect(loading.isNotIdle, isTrue);
      expect(idle.isIdle, isTrue);
      expect(idle.isNotIdle, isFalse);
      expect(success.isIdle, isFalse);
      expect(error.isIdle, isFalse);

      // isSuccess tests
      expect(loading.isSuccess, isFalse);
      expect(loading.isNotSuccess, isTrue);
      expect(idle.isSuccess, isFalse);
      expect(success.isSuccess, isTrue);
      expect(success.isNotSuccess, isFalse);
      expect(error.isSuccess, isFalse);

      // isError tests
      expect(loading.isError, isFalse);
      expect(loading.isNotError, isTrue);
      expect(idle.isError, isFalse);
      expect(success.isError, isFalse);
      expect(error.isError, isTrue);
      expect(error.isNotError, isFalse);
    });
  });
}

@Timeout(Duration(seconds: 4))
library;

import 'package:flutter_operations/flutter_operations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OperationState', () {
    group('LoadingOperation', () {
      test('should create loading state with no data', () {
        const state = LoadingOperation<String>();

        expect(state.data, isNull);
        expect(state.hasData, isFalse);
        expect(state.hasNoData, isTrue);
        expect(state.isLoading, isTrue);
        expect(state.isNotLoading, isFalse);
        expect(state.isIdle, isFalse);
        expect(state.isNotIdle, isTrue);
        expect(state.isSuccess, isFalse);
        expect(state.isError, isFalse);
      });

      test('should create loading state with cached data', () {
        const state = LoadingOperation<String>(data: 'cached');

        expect(state.data, equals('cached'));
        expect(state.hasData, isTrue);
        expect(state.hasNoData, isFalse);
        expect(state.isLoading, isTrue);
        expect(state.isIdle, isFalse);
      });

      test('should handle equality correctly', () {
        const state1 = LoadingOperation<String>();
        const state2 = LoadingOperation<String>();
        const state3 = LoadingOperation<String>(data: 'test');

        expect(state1, equals(state2));
        expect(state1, isNot(equals(state3)));
      });
    });

    group('IdleOperation', () {
      test('should create idle state with no data', () {
        const state = IdleOperation<String>();

        expect(state.data, isNull);
        expect(state.hasData, isFalse);
        expect(state.hasNoData, isTrue);
        expect(state.isLoading, isFalse);
        expect(state.isNotLoading, isTrue);
        expect(state.isIdle, isTrue);
        expect(state.isNotIdle, isFalse);
        expect(state.isSuccess, isFalse);
        expect(state.isError, isFalse);
      });

      test('should create idle state with cached data', () {
        const state = IdleOperation<String>(data: 'cached');

        expect(state.data, equals('cached'));
        expect(state.hasData, isTrue);
        expect(state.hasNoData, isFalse);
        expect(state.isIdle, isTrue);
        expect(state.isLoading, isFalse);
      });

      test('should be instance of LoadingOperation', () {
        const state = IdleOperation<String>();
        expect(state, isA<LoadingOperation<String>>());
      });
    });

    group('SuccessOperation', () {
      test('should create success state with data', () {
        const state = SuccessOperation<String>(data: 'success');

        expect(state.data, equals('success'));
        expect(state.hasData, isTrue);
        expect(state.hasNoData, isFalse);
        expect(state.empty, isFalse);
        expect(state.isLoading, isFalse);
        expect(state.isIdle, isFalse);
        expect(state.isSuccess, isTrue);
        expect(state.isNotSuccess, isFalse);
        expect(state.isError, isFalse);
      });

      test('should create empty success state', () {
        const state = SuccessOperation<String?>.empty();

        expect(state.empty, isTrue);
        expect(state.isSuccess, isTrue);
        expect(state.hasData, isFalse);
        expect(state.hasNoData, isTrue);
      });

      test('should throw error when accessing data in empty state', () {
        const state = SuccessOperation<String>.empty();

        expect(() => state.data, throwsA(isA<StateError>()));
      });

      test('should guarantee non-null data for non-empty state', () {
        const state = SuccessOperation<String>(data: 'test');
        String data = state.data; // Should not require null check

        expect(data, equals('test'));
      });

      test('should handle equality correctly', () {
        const state1 = SuccessOperation<String>(data: 'test');
        const state2 = SuccessOperation<String>(data: 'test');
        const state3 = SuccessOperation<String>(data: 'other');
        const state4 = SuccessOperation<String?>.empty();
        const state5 = SuccessOperation<String?>.empty();

        expect(state1, equals(state2));
        expect(state1, isNot(equals(state3)));
        expect(state4, equals(state5));
        expect(state1, isNot(equals(state4)));
      });
    });

    group('ErrorOperation', () {
      test('should create error state with message only', () {
        const state = ErrorOperation<String>(message: 'Error occurred');

        expect(state.message, equals('Error occurred'));
        expect(state.exception, isNull);
        expect(state.stackTrace, isNull);
        expect(state.data, isNull);
        expect(state.hasData, isFalse);
        expect(state.hasNoData, isTrue);
        expect(state.isLoading, isFalse);
        expect(state.isIdle, isFalse);
        expect(state.isSuccess, isFalse);
        expect(state.isError, isTrue);
        expect(state.isNotError, isFalse);
      });

      test('should create error state with all details', () {
        final exception = Exception('Test exception');
        final stackTrace = StackTrace.current;
        final state = ErrorOperation<String>(
          message: 'Error occurred',
          exception: exception,
          stackTrace: stackTrace,
          data: 'cached',
        );

        expect(state.message, equals('Error occurred'));
        expect(state.exception, equals(exception));
        expect(state.stackTrace, equals(stackTrace));
        expect(state.data, equals('cached'));
        expect(state.hasData, isTrue);
        expect(state.hasNoData, isFalse);
        expect(state.isError, isTrue);
      });

      test('should handle equality correctly', () {
        final exception = Exception('Test');
        final stackTrace = StackTrace.current;
        
        final state1 = ErrorOperation<String>(
          message: 'Error',
          exception: exception,
          stackTrace: stackTrace,
        );
        final state2 = ErrorOperation<String>(
          message: 'Error',
          exception: exception,
          stackTrace: stackTrace,
        );
        final state3 = ErrorOperation<String>(message: 'Different error');

        expect(state1, equals(state2));
        expect(state1, isNot(equals(state3)));
      });
    });

    group('State transitions and pattern matching', () {
      test('should handle comprehensive state transitions', () {
        final states = <String>[];

        // Simulate various state transitions
        final operations = <OperationState<String>>[
          const IdleOperation<String>(),
          const LoadingOperation<String>(),
          const SuccessOperation<String>(data: 'result'),
          const LoadingOperation<String>(data: 'result'), // Reload with cache
          const ErrorOperation<String>(
            message: 'Failed',
            data: 'result',
          ), // Error with cache
          const IdleOperation<String>(data: 'result'), // Back to idle with cache
        ];

        for (final op in operations) {
          final description = switch (op) {
            IdleOperation(data: null) => 'Idle with no data',
            IdleOperation(:var data?) => 'Idle with cached data: $data',
            LoadingOperation(data: null) => 'Initial loading',
            LoadingOperation(:var data?) =>
              'Reloading with cached data: $data',
            SuccessOperation(:var data) => 'Success: $data',
            ErrorOperation(:var message, data: null) => 'Error: $message',
            ErrorOperation(:var message, :var data?) =>
              'Error: $message (showing cached: $data)',
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
    });
  });
}

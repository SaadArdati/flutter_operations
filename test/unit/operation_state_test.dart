@Timeout(Duration(seconds: 4))
library;

import 'package:flutter_operations/flutter_operations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('OperationState', () {
    group('Convenience Getters', () {
      runStatePropertyTests(commonStateTestCases);
    });

    group('LoadingOperation', () {
      test('should handle equality correctly', () {
        const state1 = LoadingOperation<TestData>(data: TestData('test'));
        const state2 = LoadingOperation<TestData>(data: TestData('test'));
        const state3 = LoadingOperation<TestData>(data: TestData('other'));
        const state4 = LoadingOperation<TestData>();

        expect(state1, equals(state2));
        expect(state1, isNot(equals(state3)));
        expect(state1, isNot(equals(state4)));
      });

      test('should support inheritance hierarchy', () {
        const loading = LoadingOperation<TestData>();
        const idle = IdleOperation<TestData>();

        expect(loading, isA<OperationState<TestData>>());
        expect(idle, isA<LoadingOperation<TestData>>());
        expect(idle, isA<OperationState<TestData>>());
      });
    });

    group('IdleOperation', () {
      test('should extend LoadingOperation but be distinguishable', () {
        const idle = IdleOperation<TestData>();
        const loading = LoadingOperation<TestData>();

        expect(idle, isA<LoadingOperation<TestData>>());
        expect(idle.isIdle, isTrue);
        expect(idle.isLoading, isFalse);
        expect(loading.isIdle, isFalse);
        expect(loading.isLoading, isTrue);
      });

      test('should handle equality correctly', () {
        const idle1 = IdleOperation<TestData>();
        const idle2 = IdleOperation<TestData>();
        const idle3 = IdleOperation<TestData>(data: TestData('test'));

        expect(idle1, equals(idle2));
        expect(idle1, isNot(equals(idle3)));
      });
    });

    group('SuccessOperation', () {
      test('should guarantee non-null data for non-empty state', () {
        const state = SuccessOperation<TestData>(data: TestData('test'));
        TestData data = state.data;

        expect(data.value, equals('test'));
        expect(state.empty, isFalse);
        expect(state.hasData, isTrue);
      });

      test('should handle empty success state correctly', () {
        const emptySuccess = SuccessOperation<TestData?>.empty();
        const regularSuccess = SuccessOperation<TestData>(
          data: TestData('test'),
        );

        expect(emptySuccess.empty, isTrue);
        expect(emptySuccess.isSuccess, isTrue);
        expect(emptySuccess.hasData, isFalse);
        expect(emptySuccess.hasNoData, isTrue);

        expect(regularSuccess.empty, isFalse);
        expect(regularSuccess.isSuccess, isTrue);
        expect(regularSuccess.hasData, isTrue);
        expect(regularSuccess.data.value, equals('test'));
      });

      test('should throw StateError when accessing data in empty state', () {
        const state = SuccessOperation<String>.empty();
        expect(() => state.data, throwsA(isA<StateError>()));
      });

      test('should handle equality correctly', () {
        const state1 = SuccessOperation<TestData>(data: TestData('test'));
        const state2 = SuccessOperation<TestData>(data: TestData('test'));
        const state3 = SuccessOperation<TestData>(data: TestData('other'));
        const state4 = SuccessOperation<TestData?>.empty();
        const state5 = SuccessOperation<TestData?>.empty();

        expect(state1, equals(state2));
        expect(state1, isNot(equals(state3)));
        expect(state4, equals(state5));
        expect(state1, isNot(equals(state4)));
      });

      group('dataOrNull', () {
        test('should return data for non-empty success state', () {
          const state = SuccessOperation<TestData>(data: TestData('test'));

          expect(state.dataOrNull, isNotNull);
          expect(state.dataOrNull?.value, equals('test'));
          expect(state.dataOrNull, equals(state.data));
        });

        test('should return null for empty success state', () {
          const state = SuccessOperation<String>.empty();

          expect(state.dataOrNull, isNull);
          expect(state.empty, isTrue);
        });

        test('should allow safe access without checking empty flag', () {
          const states = <SuccessOperation<String>>[
            SuccessOperation<String>(data: 'hello'),
            SuccessOperation<String>.empty(),
          ];

          // This should not throw for either state
          final results = states
              .map((s) => s.dataOrNull?.toUpperCase())
              .toList();

          expect(results[0], equals('HELLO'));
          expect(results[1], isNull);
        });
      });

      group('empty state equality and hashCode', () {
        test('should compare empty states without throwing', () {
          const empty1 = SuccessOperation<String>.empty();
          const empty2 = SuccessOperation<String>.empty();
          const empty3 = SuccessOperation<String>.empty(message: 'done');

          // These comparisons should not throw
          expect(empty1 == empty2, isTrue);
          expect(empty1 == empty3, isFalse);
          expect(empty1, equals(empty2));
          expect(empty1, isNot(equals(empty3)));
        });

        test('should compute hashCode for empty states without throwing', () {
          const empty1 = SuccessOperation<String>.empty();
          const empty2 = SuccessOperation<String>.empty();
          const empty3 = SuccessOperation<String>.empty(message: 'done');

          // These should not throw
          expect(empty1.hashCode, equals(empty2.hashCode));
          expect(empty1.hashCode, isNot(equals(empty3.hashCode)));
        });

        test('should work correctly in Sets and Maps', () {
          const empty1 = SuccessOperation<String>.empty();
          const empty2 = SuccessOperation<String>.empty();
          const withData = SuccessOperation<String>(data: 'test');

          // Build set programmatically to test deduplication behavior
          final set = <SuccessOperation<String>>{}..add(empty1)..add(
              empty2) // Should be deduplicated (equal to empty1)
            ..add(withData);
          expect(set.length, equals(2)); // empty1 and empty2 are equal

          // Build map programmatically to test key deduplication
          final map = <SuccessOperation<String>, String>{}
            ..[empty1] = 'first'
            ..[empty2] =
                'second' // Should overwrite first (equal key)
            ..[withData] = 'third';
          expect(map.length, equals(2));
          expect(map[empty1], equals('second'));
        });
      });

      group('empty state with message', () {
        test('should support optional message in empty state', () {
          const state = SuccessOperation<String>.empty(message: 'Item deleted');

          expect(state.empty, isTrue);
          expect(state.message, equals('Item deleted'));
          expect(state.dataOrNull, isNull);
        });

        test('should differentiate empty states by message', () {
          const state1 = SuccessOperation<String>.empty();
          const state2 = SuccessOperation<String>.empty(message: 'Done');
          const state3 = SuccessOperation<String>.empty(message: 'Done');

          expect(state1, isNot(equals(state2)));
          expect(state2, equals(state3));
        });
      });

      group('toString', () {
        test('should produce readable output for non-empty state', () {
          const state = SuccessOperation<String>(
            data: 'hello',
            message: 'fetched',
          );

          expect(state.toString(), contains('hello'));
          expect(state.toString(), contains('fetched'));
          expect(state.toString(), contains('empty: false'));
        });

        test('should produce readable output for empty state', () {
          const state = SuccessOperation<String>.empty(message: 'deleted');

          // Should not throw and should be readable
          final str = state.toString();
          expect(str, contains('deleted'));
          expect(str, contains('empty: true'));
          expect(str, contains('null'));
        });
      });
    });

    group('ErrorOperation', () {
      test('should create error state with all details', () {
        final exception = Exception('Test exception');
        final stackTrace = StackTrace.current;
        final state = ErrorOperation<TestData>(
          message: 'Error occurred',
          exception: exception,
          stackTrace: stackTrace,
          data: TestData('cached'),
        );

        expect(state.message, equals('Error occurred'));
        expect(state.exception, equals(exception));
        expect(state.stackTrace, equals(stackTrace));
        expect(state.data?.value, equals('cached'));
        expect(state.hasData, isTrue);
        expect(state.isError, isTrue);
      });

      test('should handle minimal error state', () {
        const state = ErrorOperation<TestData>(message: 'Error occurred');

        expect(state.message, equals('Error occurred'));
        expect(state.exception, isNull);
        expect(state.stackTrace, isNull);
        expect(state.data, isNull);
        expect(state.hasData, isFalse);
        expect(state.isError, isTrue);
      });

      test('should handle equality correctly', () {
        final exception = Exception('Test');
        final stackTrace = StackTrace.current;

        final state1 = ErrorOperation<TestData>(
          message: 'Error',
          exception: exception,
          stackTrace: stackTrace,
        );
        final state2 = ErrorOperation<TestData>(
          message: 'Error',
          exception: exception,
          stackTrace: stackTrace,
        );
        final state3 = ErrorOperation<TestData>(message: 'Different error');

        expect(state1, equals(state2));
        expect(state1, isNot(equals(state3)));
      });
    });

    group('Pattern Matching & State Transitions', () {
      test(
        'should handle comprehensive state transitions with pattern matching',
        () {
          final stateDescriptions = <String>[];

          final operations = <OperationState<TestData>>[
            const IdleOperation<TestData>(),
            const LoadingOperation<TestData>(),
            const SuccessOperation<TestData>(data: TestData('result')),
            const LoadingOperation<TestData>(data: TestData('result')),
            const ErrorOperation<TestData>(
              message: 'Failed',
              data: TestData('result'),
            ),
            const IdleOperation<TestData>(data: TestData('result')),
          ];

          for (final op in operations) {
            final description = switch (op) {
              IdleOperation(data: null) => 'Idle with no data',
              IdleOperation(:var data?) =>
                'Idle with cached data: ${data.value}',
              LoadingOperation(data: null) => 'Initial loading',
              LoadingOperation(:var data?) =>
                'Reloading with cached data: ${data.value}',
              SuccessOperation(:var data) => 'Success: ${data.value}',
              ErrorOperation(:var message, data: null) => 'Error: $message',
              ErrorOperation(:var message, :var data?) =>
                'Error: $message (showing cached: ${data.value})',
            };

            stateDescriptions.add(description);
          }

          expect(stateDescriptions, hasLength(6));
          expect(stateDescriptions[0], equals('Idle with no data'));
          expect(stateDescriptions[1], equals('Initial loading'));
          expect(stateDescriptions[2], equals('Success: result'));
          expect(
            stateDescriptions[3],
            equals('Reloading with cached data: result'),
          );
          expect(
            stateDescriptions[4],
            equals('Error: Failed (showing cached: result)'),
          );
          expect(stateDescriptions[5], equals('Idle with cached data: result'));
        },
      );

      test('should handle pattern matching with empty success', () {
        final operations = <OperationState<String?>>[
          const SuccessOperation<String?>.empty(),
          const SuccessOperation<String?>(data: 'data'),
        ];

        final descriptions = operations
            .map(
              (op) => switch (op) {
                SuccessOperation(empty: true) => 'Empty success',
                SuccessOperation(:var data) => 'Success with data: $data',
                _ => 'Other state',
              },
            )
            .toList();

        expect(descriptions[0], equals('Empty success'));
        expect(descriptions[1], equals('Success with data: data'));
      });
    });

    group('Cached Data Handling', () {
      test('should preserve cached data across different state types', () {
        const cachedData = TestData('cached');

        final states = [
          const LoadingOperation<TestData>(data: cachedData),
          const ErrorOperation<TestData>(message: 'Error', data: cachedData),
          const IdleOperation<TestData>(data: cachedData),
        ];

        for (final state in states) {
          expect(state.hasData, isTrue);
          expect(state.data, equals(cachedData));
        }
      });
    });

    group('HashCode', () {
      test('equal states should have identical hashCodes', () {
        const a = LoadingOperation<TestData>(data: TestData('x'));
        const b = LoadingOperation<TestData>(data: TestData('x'));

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different states should have different hashCodes', () {
        const a = SuccessOperation<TestData>(data: TestData('value1'));
        const b = SuccessOperation<TestData>(data: TestData('value2'));

        expect(a, isNot(equals(b)));
        expect(a.hashCode, isNot(equals(b.hashCode)));
      });
    });
  });
}

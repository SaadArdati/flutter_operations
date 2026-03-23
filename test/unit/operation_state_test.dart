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
      test('should create ValueSuccessOperation via redirecting factory', () {
        const state = SuccessOperation<TestData>(data: TestData('test'));

        expect(state, isA<ValueSuccessOperation<TestData>>());
        expect(state.empty, isFalse);
        expect(state.hasData, isTrue);
        expect(state.isSuccess, isTrue);
      });

      test('should create VoidSuccessOperation via redirecting factory', () {
        const state = SuccessOperation<TestData?>.empty();

        expect(state, isA<VoidSuccessOperation<TestData?>>());
        expect(state.empty, isTrue);
        expect(state.isSuccess, isTrue);
        expect(state.hasData, isFalse);
        expect(state.hasNoData, isTrue);
      });

      test('should guarantee non-null data on ValueSuccessOperation', () {
        const state = ValueSuccessOperation<TestData>(data: TestData('test'));
        TestData data = state.data;

        expect(data.value, equals('test'));
        expect(state.empty, isFalse);
        expect(state.hasData, isTrue);
      });

      test('should return null data on VoidSuccessOperation', () {
        const state = VoidSuccessOperation<String>();

        expect(state.data, isNull);
        expect(state.empty, isTrue);
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

      test('should allow safe nullable access across success variants', () {
        const states = <SuccessOperation<String>>[
          SuccessOperation<String>(data: 'hello'),
          SuccessOperation<String>.empty(),
        ];

        // data is T? on the base SuccessOperation — safe for both
        final results = states.map((s) => s.data?.toUpperCase()).toList();

        expect(results[0], equals('HELLO'));
        expect(results[1], isNull);
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
          final set = <SuccessOperation<String>>{}
            ..add(empty1)
            ..add(empty2) // Should be deduplicated (equal to empty1)
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
          expect(state.data, isNull);
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
        test('should produce readable output for ValueSuccessOperation', () {
          const state = SuccessOperation<String>(
            data: 'hello',
            message: 'fetched',
          );

          expect(state.toString(), contains('ValueSuccessOperation'));
          expect(state.toString(), contains('hello'));
          expect(state.toString(), contains('fetched'));
        });

        test('should produce readable output for VoidSuccessOperation', () {
          const state = SuccessOperation<String>.empty(message: 'deleted');

          final str = state.toString();
          expect(str, contains('VoidSuccessOperation'));
          expect(str, contains('deleted'));
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
              VoidSuccessOperation(:var message) => 'Empty success: $message',
              ValueSuccessOperation(:var data) => 'Success: ${data.value}',
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
                VoidSuccessOperation() => 'Empty success',
                ValueSuccessOperation(:var data) => 'Success with data: $data',
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

      test('ValueSuccessOperation and VoidSuccessOperation should differ', () {
        const value = SuccessOperation<String?>(data: null);
        const void_ = SuccessOperation<String?>.empty();

        expect(value, isNot(equals(void_)));
        expect(value.hashCode, isNot(equals(void_.hashCode)));
      });

      test('LoadingOperation and IdleOperation should differ', () {
        const loading = LoadingOperation<TestData>();
        const idle = IdleOperation<TestData>();

        expect(loading, isNot(equals(idle)));
        expect(loading.hashCode, isNot(equals(idle.hashCode)));
      });

      test('hashCode is stable across multiple calls', () {
        const state = SuccessOperation<TestData>(data: TestData('stable'));
        expect(state.hashCode, equals(state.hashCode));
      });

      test('equal ErrorOperations have same hashCode', () {
        final exception = Exception('Test');
        final state1 = ErrorOperation<TestData>(
          message: 'err',
          exception: exception,
        );
        final state2 = ErrorOperation<TestData>(
          message: 'err',
          exception: exception,
        );

        expect(state1, equals(state2));
        expect(state1.hashCode, equals(state2.hashCode));
      });

      test('equal IdleOperations have same hashCode', () {
        const idle1 = IdleOperation<TestData>(data: TestData('x'));
        const idle2 = IdleOperation<TestData>(data: TestData('x'));

        expect(idle1, equals(idle2));
        expect(idle1.hashCode, equals(idle2.hashCode));
      });
    });

    group('Cross-type inequality', () {
      test('different state types are never equal', () {
        const loading = LoadingOperation<String>(data: 'x');
        const idle = IdleOperation<String>(data: 'x');
        const success = SuccessOperation<String>(data: 'x');
        const error = ErrorOperation<String>(data: 'x');

        // Loading vs others
        expect(loading, isNot(equals(idle)));
        expect(loading, isNot(equals(success)));
        expect(loading, isNot(equals(error)));

        // Idle vs others
        expect(idle, isNot(equals(success)));
        expect(idle, isNot(equals(error)));

        // Success vs Error
        expect(success, isNot(equals(error)));
      });
    });

    group('Reflexive equality', () {
      test('each state type is equal to itself', () {
        final loading = LoadingOperation<String>(data: 'x');
        final idle = IdleOperation<String>(data: 'x');
        final success = ValueSuccessOperation<String>(data: 'x');
        final void_ = VoidSuccessOperation<String>();
        final error = ErrorOperation<String>(message: 'err');

        expect(loading, equals(loading));
        expect(idle, equals(idle));
        expect(success, equals(success));
        expect(void_, equals(void_));
        expect(error, equals(error));
      });
    });

    group('Const canonicalization', () {
      test('identical const instances are the same object', () {
        expect(
          identical(
            const LoadingOperation<String>(),
            const LoadingOperation<String>(),
          ),
          isTrue,
        );
        expect(
          identical(
            const IdleOperation<String>(),
            const IdleOperation<String>(),
          ),
          isTrue,
        );
        expect(
          identical(
            const ValueSuccessOperation<String>(data: 'x'),
            const ValueSuccessOperation<String>(data: 'x'),
          ),
          isTrue,
        );
        expect(
          identical(
            const VoidSuccessOperation<String>(),
            const VoidSuccessOperation<String>(),
          ),
          isTrue,
        );
        expect(
          identical(
            const ErrorOperation<String>(message: 'e'),
            const ErrorOperation<String>(message: 'e'),
          ),
          isTrue,
        );
      });
    });

    group('toString', () {
      test('LoadingOperation includes class name and data', () {
        const state = LoadingOperation<String>(data: 'cached');
        expect(state.toString(), contains('LoadingOperation'));
        expect(state.toString(), contains('cached'));
      });

      test('IdleOperation includes class name and data', () {
        const state = IdleOperation<String>(data: 'cached');
        expect(state.toString(), contains('IdleOperation'));
        expect(state.toString(), contains('cached'));
      });

      test('ErrorOperation includes class name and all fields', () {
        final state = ErrorOperation<String>(
          message: 'fail',
          exception: Exception('boom'),
          data: 'cached',
        );
        expect(state.toString(), contains('ErrorOperation'));
        expect(state.toString(), contains('fail'));
        expect(state.toString(), contains('boom'));
        expect(state.toString(), contains('cached'));
      });

      test('LoadingOperation with null data does not throw', () {
        const state = LoadingOperation<String>();
        expect(state.toString(), contains('null'));
      });

      test('ErrorOperation with all nulls does not throw', () {
        const state = ErrorOperation<String>();
        expect(state.toString(), isNotEmpty);
      });
    });

    group('Edge cases', () {
      test('hasData is true for empty list (non-null)', () {
        const state = SuccessOperation<List<String>>(data: []);
        expect(state.hasData, isTrue);
        expect(state.hasNoData, isFalse);
      });

      test(
        'nullable T: SuccessOperation(data: null) differs from .empty()',
        () {
          const withNull = SuccessOperation<String?>(data: null);
          const empty = SuccessOperation<String?>.empty();

          expect(withNull, isA<ValueSuccessOperation<String?>>());
          expect(empty, isA<VoidSuccessOperation<String?>>());
          expect(withNull, isNot(equals(empty)));
        },
      );
    });
  });
}

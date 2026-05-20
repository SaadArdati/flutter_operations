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
      test('returns exactly T for non-nullable T', () {
        const state = SuccessOperation<TestData>(data: TestData('test'));
        final TestData data = state.data;

        expect(data.value, equals('test'));
        expect(state.hasData, isTrue);
        expect(state.isSuccess, isTrue);
      });

      test('returns T? for nullable T and data may be null', () {
        const withValue = SuccessOperation<TestData?>(data: TestData('x'));
        const withNull = SuccessOperation<TestData?>(data: null);

        expect(withValue.data?.value, equals('x'));
        expect(withValue.hasData, isTrue);

        expect(withNull.data, isNull);
        expect(withNull.hasData, isFalse);
        expect(withNull.isSuccess, isTrue);
      });

      test('data getter never throws', () {
        const state = SuccessOperation<TestData?>(data: null);
        expect(() => state.data, returnsNormally);
      });

      test('equality is determined by data and message', () {
        const s1 = SuccessOperation<TestData>(data: TestData('test'));
        const s2 = SuccessOperation<TestData>(data: TestData('test'));
        const s3 = SuccessOperation<TestData>(data: TestData('other'));
        const s4 = SuccessOperation<TestData>(
          data: TestData('test'),
          message: 'fetched',
        );

        expect(s1, equals(s2));
        expect(s1, isNot(equals(s3)));
        expect(s1, isNot(equals(s4)));
      });

      test('nullable-T null instances compare and hash equally', () {
        const n1 = SuccessOperation<TestData?>(data: null);
        const n2 = SuccessOperation<TestData?>(data: null);
        const n3 = SuccessOperation<TestData?>(data: null, message: 'done');

        expect(n1, equals(n2));
        expect(n1.hashCode, equals(n2.hashCode));
        expect(n1, isNot(equals(n3)));
      });

      test('works correctly as set and map key', () {
        const a = SuccessOperation<String?>(data: null);
        const b = SuccessOperation<String?>(data: null);
        const c = SuccessOperation<String?>(data: 'x');

        final set = <SuccessOperation<String?>>{}
          ..add(a)
          ..add(b)
          ..add(c);
        expect(set.length, equals(2));

        final map = <SuccessOperation<String?>, String>{}
          ..[a] = 'first'
          ..[b] = 'second'
          ..[c] = 'third';
        expect(map.length, equals(2));
        expect(map[a], equals('second'));
      });

      test('toString includes data and message', () {
        const s = SuccessOperation<String>(data: 'hello', message: 'fetched');

        expect(s.toString(), contains('hello'));
        expect(s.toString(), contains('fetched'));
      });

      group('void parameter (fire-and-forget)', () {
        test('constructs without throwing and matches in switch', () {
          const state = SuccessOperation<void>(data: null);

          expect(state.isSuccess, isTrue);
          expect(() => state.data, returnsNormally);

          final OperationState<void> typed = state;
          final description = switch (typed) {
            IdleOperation() => 'idle',
            LoadingOperation() => 'loading',
            SuccessOperation() => 'done',
            ErrorOperation() => 'error',
          };
          expect(description, equals('done'));
        });

        test('equality and hashCode work for void instances', () {
          const a = SuccessOperation<void>(data: null);
          const b = SuccessOperation<void>(data: null);
          const c = SuccessOperation<void>(data: null, message: 'completed');

          expect(a, equals(b));
          expect(a.hashCode, equals(b.hashCode));
          expect(a, isNot(equals(c)));
        });

        test('flows through OperationState<void> as a sealed match', () {
          final states = <OperationState<void>>[
            const IdleOperation<void>(),
            const LoadingOperation<void>(),
            const SuccessOperation<void>(data: null),
            const ErrorOperation<void>(message: 'boom'),
          ];

          final labels = states
              .map(
                (s) => switch (s) {
                  IdleOperation() => 'i',
                  LoadingOperation() => 'l',
                  SuccessOperation() => 's',
                  ErrorOperation() => 'e',
                },
              )
              .toList();

          expect(labels, equals(['i', 'l', 's', 'e']));
        });
      });

      group('dataOrNull', () {
        test('returns data when present', () {
          const state = SuccessOperation<TestData>(data: TestData('test'));

          expect(state.dataOrNull, isNotNull);
          expect(state.dataOrNull?.value, equals('test'));
          expect(state.dataOrNull, equals(state.data));
        });

        test('returns null for SuccessOperation<T?>(data: null)', () {
          const state = SuccessOperation<String?>(data: null);

          expect(state.dataOrNull, isNull);
        });

        test('allows uniform safe access across success variants', () {
          const states = <SuccessOperation<String?>>[
            SuccessOperation<String?>(data: 'hello'),
            SuccessOperation<String?>(data: null),
          ];

          final results = states
              .map((s) => s.dataOrNull?.toUpperCase())
              .toList();

          expect(results[0], equals('HELLO'));
          expect(results[1], isNull);
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

      test('should handle pattern matching with nullable success data', () {
        final operations = <OperationState<String?>>[
          const SuccessOperation<String?>(data: null),
          const SuccessOperation<String?>(data: 'data'),
        ];

        final descriptions = operations
            .map(
              (op) => switch (op) {
                SuccessOperation(data: null) => 'Success with null data',
                SuccessOperation(:var data) => 'Success with data: $data',
                _ => 'Other state',
              },
            )
            .toList();

        expect(descriptions[0], equals('Success with null data'));
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

      test('Loading and Idle with same data are unequal and hash apart', () {
        const loading = LoadingOperation<int>(data: 5);
        const idle = IdleOperation<int>(data: 5);

        expect(loading, isNot(equals(idle)));
        expect(loading.hashCode, isNot(equals(idle.hashCode)));
      });
    });

    group('Pattern matching variants', () {
      // Showcases the different match styles supported by the sealed
      // hierarchy. Each style is also documented in the README.

      test('OperationState(:final data?) catches every data-bearing state', () {
        // The data-presence pattern collapses across all four state
        // types, so callers who only care about "is there data?" can
        // skip per-state matching entirely.
        final operations = <OperationState<String>>[
          const LoadingOperation<String>(),
          const LoadingOperation<String>(data: 'cached'),
          const IdleOperation<String>(),
          const IdleOperation<String>(data: 'cached'),
          const SuccessOperation<String>(data: 'value'),
          const ErrorOperation<String>(message: 'oops'),
          const ErrorOperation<String>(message: 'oops', data: 'cached'),
        ];

        final labels = operations
            .map(
              (op) => switch (op) {
                OperationState(:final data?) => 'data: $data',
                OperationState() => 'no-data',
              },
            )
            .toList();

        expect(labels, [
          'no-data',
          'data: cached',
          'no-data',
          'data: cached',
          'data: value',
          'no-data',
          'data: cached',
        ]);
      });

      test(
        'multi-pattern || combines data-bearing states across state types',
        () {
          // When you want different *renderers* per state but the same
          // *handler* for the "has-data" arms, use the OR pattern.
          final operations = <OperationState<String>>[
            const LoadingOperation<String>(data: 'a'),
            const SuccessOperation<String>(data: 'b'),
            const ErrorOperation<String>(message: 'err', data: 'c'),
            const LoadingOperation<String>(),
          ];

          final labels = operations
              .map(
                (op) => switch (op) {
                  LoadingOperation(:final data?) ||
                  SuccessOperation(:final data) ||
                  ErrorOperation(:final data?) => 'show $data',
                  _ => 'spinner',
                },
              )
              .toList();

          expect(labels, ['show a', 'show b', 'show c', 'spinner']);
        },
      );

      test(
        'error-first then data-presence keeps the error banner authoritative',
        () {
          // A common UI pattern: errors always win over cached data,
          // even when the error itself carries cache. Match
          // ErrorOperation first; the catch-all below picks up
          // success and loading-with-cache.
          final operations = <OperationState<int>>[
            const LoadingOperation<int>(data: 1),
            const ErrorOperation<int>(message: 'err', data: 2),
            const SuccessOperation<int>(data: 3),
            const IdleOperation<int>(),
          ];

          final labels = operations
              .map(
                (op) => switch (op) {
                  ErrorOperation(:final message) => 'error: $message',
                  OperationState(:final data?) => 'show $data',
                  _ => 'loading',
                },
              )
              .toList();

          expect(labels, ['show 1', 'error: err', 'show 3', 'loading']);
        },
      );

      test('guards (when) filter on data content', () {
        // Guards let you branch on properties of the payload without
        // unwrapping in the body.
        final operations = <OperationState<List<int>>>[
          const SuccessOperation<List<int>>(data: []),
          const SuccessOperation<List<int>>(data: [1, 2, 3]),
        ];

        final labels = operations
            .map(
              (op) => switch (op) {
                SuccessOperation(:final data) when data.isEmpty => 'empty list',
                SuccessOperation(:final data) => '${data.length} items',
                _ => 'other',
              },
            )
            .toList();

        expect(labels, ['empty list', '3 items']);
      });

      test(
        'convenience getters offer an imperative alternative to patterns',
        () {
          // Patterns are not mandatory. For simple UI gates (e.g.
          // "disable a button while loading"), the boolean getters are
          // often clearer than a full switch.
          const loading = LoadingOperation<int>(data: 5);
          const success = SuccessOperation<int>(data: 7);
          const error = ErrorOperation<int>(message: 'oops');
          const idle = IdleOperation<int>();

          expect(loading.isLoading, isTrue);
          expect(loading.isSuccess, isFalse);
          expect(loading.dataOrNull, equals(5));

          expect(success.isSuccess, isTrue);
          expect(success.hasData, isTrue);

          expect(error.isError, isTrue);
          expect(error.dataOrNull, isNull);

          expect(idle.isIdle, isTrue);
          expect(idle.isLoading, isFalse);
        },
      );

      test(
        'narrow patterns inside the same switch distinguish Idle from Loading',
        () {
          // IdleOperation extends LoadingOperation, so order matters:
          // match IdleOperation first if you want to treat them
          // differently. Otherwise LoadingOperation will subsume both.
          final operations = <OperationState<String>>[
            const IdleOperation<String>(),
            const LoadingOperation<String>(),
            const IdleOperation<String>(data: 'cached'),
            const LoadingOperation<String>(data: 'cached'),
          ];

          final labels = operations
              .map(
                (op) => switch (op) {
                  IdleOperation(data: null) => 'idle',
                  IdleOperation(:final data?) => 'idle($data)',
                  LoadingOperation(data: null) => 'loading',
                  LoadingOperation(:final data?) => 'reloading($data)',
                  _ => 'other',
                },
              )
              .toList();

          expect(labels, [
            'idle',
            'loading',
            'idle(cached)',
            'reloading(cached)',
          ]);
        },
      );

      test('collapsed loading: skip the Idle distinction when not needed', () {
        // If the screen does not need a separate idle state, match
        // LoadingOperation alone and Idle will fall in (it extends
        // LoadingOperation).
        final operations = <OperationState<String>>[
          const IdleOperation<String>(),
          const LoadingOperation<String>(),
          const LoadingOperation<String>(data: 'cached'),
        ];

        final labels = operations
            .map(
              (op) => switch (op) {
                LoadingOperation(data: null) => 'spinner',
                LoadingOperation(:final data?) => 'spinner+$data',
                _ => 'other',
              },
            )
            .toList();

        expect(labels, ['spinner', 'spinner', 'spinner+cached']);
      });
    });
  });
}

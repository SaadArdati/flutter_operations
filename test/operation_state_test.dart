@Timeout(Duration(seconds: 4))
library;

import 'package:flutter_operations/flutter_operations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OperationState', () {
    group('LoadingOperation', () {
      test('should create loading state with no data', () {
        const state = LoadingOperation<String>(idle: false);

        expect(state.data, isNull);
        expect(state.hasData, isFalse);
        expect(state.idle, isFalse);
      });

      test('should create loading state with cached data', () {
        const state = LoadingOperation<String>(data: 'cached', idle: false);

        expect(state.data, equals('cached'));
        expect(state.hasData, isTrue);
        expect(state.idle, isFalse);
      });

      test('should create idle loading state', () {
        const state = LoadingOperation<String>(idle: true);

        expect(state.data, isNull);
        expect(state.hasData, isFalse);
        expect(state.idle, isTrue);
      });
    });

    group('SuccessOperation', () {
      test('should create success state with data', () {
        const state = SuccessOperation<String>(data: 'success');

        expect(state.data, equals('success'));
        expect(state.hasData, isTrue);
      });

      test('should guarantee non-null data', () {
        const state = SuccessOperation<String>(data: 'test');
        String data = state.data; // Should not require null check

        expect(data, equals('test'));
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
      });
    });
  });
}

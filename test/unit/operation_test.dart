import 'package:flutter_operations/flutter_operations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final stream in [false, true]) {
    test(
      '${stream ? 'stream' : 'async'} shares the Operation contract',
      () async {
        var reads = 0;
        final events = <String>[];
        final Operation<int> operation = stream
            ? StreamOperation<int>(
                onRead: () => reads++,
                onChanged: (_, _) => events.add('changed'),
                onLoading: () => events.add('loading'),
                onError: (_, _, {message}) => events.add('error:$message'),
                errorMessage: (_, _) => 'formatted',
              )
            : AsyncOperation<int>(
                onRead: () => reads++,
                onChanged: (_, _) => events.add('changed'),
                onLoading: () => events.add('loading'),
                onError: (_, _, {message}) => events.add('error:$message'),
                errorMessage: (_, _) => 'formatted',
              );

        expect(operation.state.isIdle, isTrue);
        expect(reads, 1);
        operation.setLoading();
        operation.setLoading();
        expect(reads, 1); // Internal publication does not create tracked reads.
        expect(events, ['changed', 'loading']);
        operation.setError(StateError('failed'), StackTrace.current);
        expect(events, ['changed', 'loading', 'changed', 'error:null']);
        expect((operation.state as ErrorOperation<int>).message, 'formatted');
        operation.setIdle();
        expect(operation.state.isIdle, isTrue);

        if (operation is StreamOperation<int>) {
          await operation.dispose();
        } else {
          (operation as AsyncOperation<int>).dispose();
        }
        final changes = events.length;
        operation.setLoading();
        operation.setIdle();
        expect(events.length, changes);
        expect(operation.isDisposed, isTrue);
      },
    );
  }
}

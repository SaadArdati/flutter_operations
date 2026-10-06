import 'dart:async';

import 'package:example/shared/stream_operation_view.dart';
import 'package:example/stream/bloc_stream_integration_example.dart';
import 'package:example/stream/mobx_stream_integration_example.dart';
import 'package:example/stream/provider_stream_integration_example.dart';
import 'package:example/stream/riverpod_stream_integration_example.dart';
import 'package:example/stream/signals_stream_integration_example.dart';
import 'package:flutter/material.dart';
import 'package:flutter_operations/flutter_operations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart';

class _CounterRepository implements CounterRepository {
  final sources = <StreamController<int>>[];
  Completer<void>? cleanup;
  int cancellations = 0;

  @override
  Stream<int> watch() {
    final source = StreamController<int>(
      onCancel: () {
        cancellations++;
        return cleanup?.future;
      },
    );
    sources.add(source);
    return source.stream;
  }

  Future<void> close() async {
    for (final source in sources) {
      await source.close();
    }
  }
}

void main() {
  for (final (name, page) in <(String, Widget Function(CounterRepository))>[
    ('Cubit', (r) => BlocStreamIntegrationExample(repository: r)),
    ('Provider', (r) => ProviderStreamIntegrationExample(repository: r)),
    ('Riverpod', (r) => RiverpodStreamIntegrationExample(repository: r)),
    ('Signals', (r) => SignalsStreamIntegrationExample(repository: r)),
    ('MobX', (r) => MobxStreamIntegrationExample(repository: r)),
  ]) {
    for (final mixin in [false, true]) {
      testWidgets('$name ${mixin ? 'mixin' : 'composition'} stream lifecycle', (
        tester,
      ) async {
        final repository = _CounterRepository();
        addTearDown(repository.close);
        await tester.pumpWidget(MaterialApp(home: page(repository)));
        if (mixin) {
          await tester.tap(find.text('Host mixin'));
          await tester.pump();
        }
        await tester.tap(find.text('Listen / restart'));
        await tester.pump();
        expect(repository.sources, hasLength(1));
        repository.sources.last.add(7);
        await tester.pump();
        expect(find.text('Counter: 7'), findsOneWidget);

        repository.sources.last.addError(StateError('Offline'));
        await tester.pump();
        expect(find.textContaining('Last counter: 7'), findsOneWidget);
        repository.sources.last.add(8);
        await tester.pump();
        expect(find.text('Counter: 8'), findsOneWidget);

        // Replacement does not subscribe before pending cleanup finishes.
        repository.cleanup = Completer<void>();
        await tester.tap(find.text('Listen / restart'));
        await tester.pump();
        expect(repository.sources, hasLength(1));
        repository.sources.first.add(99);
        await tester.pump();
        expect(find.text('Counter: 99'), findsNothing);
        repository.cleanup!.complete();
        await tester.pump();
        expect(repository.sources, hasLength(2));
        repository.cleanup = null;
        repository.sources.last.add(9);
        await tester.pump();
        expect(find.text('Counter: 9'), findsOneWidget);

        await tester.tap(find.text('Cancel'));
        await tester.pump();
        expect(find.text('Ready to listen.'), findsOneWidget);
        repository.sources.last.add(100);
        await tester.pump();
        expect(find.text('Counter: 100'), findsNothing);

        await tester.tap(find.text('Listen / restart'));
        await tester.pump();
        repository.cleanup = Completer<void>();
        await tester.pumpWidget(const SizedBox());
        repository.sources.last.addError(StateError('Disposed'));
        repository.cleanup!.complete();
        await tester.pump();
        expect(repository.cancellations, 3);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final mixin in [false, true]) {
    test(
      'Cubit close awaits ${mixin ? 'mixin' : 'composed'} cleanup',
      () async {
        final repository = _CounterRepository();
        final cubit = mixin ? null : CounterCubit(repository);
        final mixed = mixin ? MixinCounterCubit(repository) : null;
        await (mixed?.listen() ?? cubit!.listen());
        repository.cleanup = Completer<void>();
        var closed = false;
        final closing = (mixed?.close() ?? cubit!.close()).then(
          (_) => closed = true,
        );
        await Future<void>.delayed(Duration.zero);
        expect(closed, isFalse);
        repository.cleanup!.complete();
        await closing;
        expect(closed, isTrue);
        await repository.close();
      },
    );
  }

  test(
    'synchronous Provider disposal surfaces cleanup failure to owner zone',
    () async {
      final repository = _CounterRepository();
      final reported = Completer<Object>();
      await runZonedGuarded<Future<void>>(() async {
        final owner = CounterChangeNotifier(repository);
        await owner.listen();
        repository.cleanup = Completer<void>();
        owner.dispose();
        expect(owner.operation.isDisposed, isTrue);
        repository.cleanup!.completeError(StateError('Cleanup failed'));
      }, (error, trace) => reported.complete(error));
      expect(await reported.future, isA<StateError>());
      await repository.close();
    },
  );

  test(
    'MobX Atom hooks track composed and mixin reads independently',
    () async {
      final repository = _CounterRepository();
      final composed = CounterMobxStore(repository);
      final mixed = MixinCounterMobxStore(repository);
      final states = <bool>[];
      final mixinStates = <bool>[];
      final stop = autorun((_) => states.add(composed.state.isIdle));
      final stopMixin = autorun((_) => mixinStates.add(mixed.operation.isIdle));
      await composed.listen();
      expect(states, [true, false]);
      expect(mixinStates, [true]);
      await mixed.listen();
      expect(mixinStates, [true, false]);
      stop();
      stopMixin();
      await composed.dispose();
      await mixed.disposeOperation();
      await repository.close();
    },
  );

  for (final mixin in [false, true]) {
    test(
      'Riverpod rebuild replaces ${mixin ? 'mixin' : 'composed'} controller',
      () async {
        final repository = _CounterRepository();
        final container = ProviderContainer(
          overrides: [counterRepositoryProvider.overrideWithValue(repository)],
        );
        final provider = mixin
            ? mixinCounterStreamProvider
            : counterStreamProvider;
        final subscription = container.listen(provider, (_, _) {});
        final before = mixin
            ? container
                  .read(mixinCounterStreamProvider.notifier)
                  .operationController
            : container.read(counterStreamProvider.notifier).operation;
        await before.listen(repository.watch);
        container.invalidate(provider);
        container.read(provider);
        final after = mixin
            ? container
                  .read(mixinCounterStreamProvider.notifier)
                  .operationController
            : container.read(counterStreamProvider.notifier).operation;
        expect(identical(before, after), isFalse);
        expect(before.isDisposed, isTrue);
        await after.listen(repository.watch);
        expect(after.state, isA<LoadingOperation<int>>());
        subscription.close();
        container.dispose();
        await repository.close();
      },
    );
  }
}

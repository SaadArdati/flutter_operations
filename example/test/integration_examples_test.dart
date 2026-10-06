import 'package:example/async/bloc_integration_example.dart';
import 'package:example/async/mobx_integration_example.dart';
import 'package:example/async/provider_integration_example.dart';
import 'package:example/async/riverpod_integration_example.dart';
import 'package:example/async/signals_integration_example.dart';
import 'package:example/async/standalone_async_operation_example.dart';
import 'package:example/async/widget_operations_example.dart';
import 'package:example/main.dart';
import 'package:example/stream/standalone_stream_operation_example.dart';
import 'package:example/stream/widget_stream_example.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart';

void main() {
  testWidgets('standalone stream listens, cancels and disposes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: StandaloneStreamOperationExample()),
    );
    await tester.tap(find.text('Listen'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('Counter: 0'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(find.text('Ready to listen.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Ready to listen.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('home navigates to widget-owned Future', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.tap(find.text('Widget-owned Future'));
    await tester.pumpAndSettle();
    expect(find.text('Rebuild whole widget'), findsOneWidget);
    expect(find.text('Set idle'), findsOneWidget);
    await tester.tap(find.text('Run'));
    await tester.pump();
    expect(find.text('Loading user...'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.text('Loading user...'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('search clear invalidates pending results', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SearchExample()));
    await tester.enterText(find.byType(TextField), 'books');
    await tester.tap(find.text('Search'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Clear'));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Enter a query to search.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('widget stream updates and disposes', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WidgetStreamExample()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('Counter: 0'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  test('MobX computed getters track independent operation states', () {
    final store = MultipleOperationsStore();
    final userStates = <bool>[];
    final productStates = <bool>[];
    final stopUser = autorun((_) => userStates.add(store.userState.isIdle));
    final stopProducts = autorun(
      (_) => productStates.add(store.productsState.isIdle),
    );
    addTearDown(() {
      stopUser();
      stopProducts();
      store.dispose();
    });

    store.user.setLoading();
    expect(userStates, [true, false]);
    expect(productStates, [true]);

    store.products.setLoading();
    store.user.cancel();
    expect(userStates, [true, false, true]);
    expect(productStates, [true, false]);
  });

  for (final (name, page) in <(String, Widget)>[
    ('Provider', const ProviderIntegrationExample()),
    ('Riverpod', const RiverpodIntegrationExample()),
    ('Signals', const SignalsIntegrationExample()),
  ]) {
    for (final label in [
      'Direct state',
      'Composed operation',
      'Operation mixin',
    ]) {
      testWidgets('$name $label cancels and disposes pending work', (
        tester,
      ) async {
        await tester.pumpWidget(MaterialApp(home: page));
        await tester.tap(find.byType(DropdownButton<int>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Run'));
        await tester.pump();
        expect(find.text('Loading user...'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pump();
        expect(find.text('Ready to load a user.'), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
        expect(find.text('Ready to load a user.'), findsOneWidget);

        await tester.tap(find.text('Run'));
        await tester.pump();
        expect(find.text('Loading user...'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('lists standalone, MobX, and Bloc integrations', (tester) async {
    await tester.pumpWidget(const ExampleApp());

    for (final title in [
      'Standalone AsyncOperation',
      'Bloc Integration',
      'Provider Integration',
      'Riverpod Integration',
      'Signals Integration',
      'MobX Integration',
    ]) {
      await tester.scrollUntilVisible(
        find.text(title),
        100,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text(title), findsOneWidget);
    }
  });

  testWidgets('Bloc integration compares direct and composed Cubits', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: BlocIntegrationExample()));

    expect(find.text('Direct Cubit'), findsOneWidget);
    expect(find.text('AsyncOperation-backed'), findsOneWidget);

    await tester.tap(find.text('AsyncOperation-backed'));
    await tester.pumpAndSettle();

    expect(find.text('Run'), findsOneWidget);
  });

  testWidgets('Mixin-backed Cubit cancels and disposes pending work', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: BlocIntegrationExample()));
    await tester.tap(find.text('Mixin-backed'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Run'));
    await tester.pump();
    expect(find.text('Loading user...'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(find.text('Ready to load a user.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Ready to load a user.'), findsOneWidget);

    await tester.tap(find.text('Run'));
    await tester.pump();
    expect(find.text('Loading user...'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('MobX Observer reacts to run and cancellation', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MobxIntegrationExample()));
    expect(find.text('Ready to load a user.'), findsOneWidget);

    await tester.tap(find.text('Run'));
    await tester.pump();
    expect(find.text('Loading user...'), findsOneWidget);
    expect(find.text('Ready to load a user.'), findsNothing);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(find.text('Ready to load a user.'), findsOneWidget);
    expect(find.text('Loading user...'), findsNothing);

    // The mock takes at most two seconds. Its cancelled result must stay hidden.
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Ready to load a user.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final label in [
    'Mixin + Atom',
    'Codegen: operation fields',
    'Extends + Store',
    'Reactive mixin',
    'Override controller',
    'Injected controller',
  ]) {
    testWidgets('$label publishes changes and disposes safely', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: MobxIntegrationExample()),
      );
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Run'));
      await tester.pump();
      expect(find.text('Loading user...'), findsOneWidget);

      if (label == 'Codegen: operation fields') {
        await tester.tap(find.text('Load products'));
        await tester.pump();
        expect(find.text('Loading products...'), findsOneWidget);
      }

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(find.text('Ready to load a user.'), findsOneWidget);
      if (label == 'Codegen: operation fields') {
        expect(find.text('Loading products...'), findsOneWidget);
      }

      await tester.tap(find.text('Run'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    });
  }

  for (final (name, page) in <(String, Widget)>[
    ('Standalone', const StandaloneAsyncOperationExample()),
    ('Bloc', const BlocIntegrationExample()),
    ('MobX', const MobxIntegrationExample()),
    ('Provider', const ProviderIntegrationExample()),
    ('Riverpod', const RiverpodIntegrationExample()),
    ('Signals', const SignalsIntegrationExample()),
  ]) {
    testWidgets('$name integration mounts', (tester) async {
      await tester.pumpWidget(MaterialApp(home: page));

      expect(find.text('Run'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  }
}

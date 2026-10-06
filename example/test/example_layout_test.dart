import 'package:example/async/bloc_integration_example.dart';
import 'package:example/async/mobx_integration_example.dart';
import 'package:example/async/provider_integration_example.dart';
import 'package:example/async/riverpod_integration_example.dart';
import 'package:example/async/signals_integration_example.dart';
import 'package:example/async/widget_operations_example.dart';
import 'package:example/main.dart';
import 'package:example/shared/models.dart';
import 'package:example/shared/stream_operation_view.dart';
import 'package:example/shared/user_operation_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_operations/flutter_operations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [360.0, 1600.0]) {
    testWidgets('profile states fit a $width wide viewport', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const user = User(
        name: 'A longer display name',
        email: 'someone@example.com',
      );
      for (final state in <OperationState<User>>[
        const IdleOperation(),
        const LoadingOperation(),
        const LoadingOperation(data: user),
        const ErrorOperation(
          message: 'Unable to refresh this profile.',
          data: user,
        ),
        const SuccessOperation(data: user),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UserOperationView(
                operation: state,
                run: () {},
                cancel: () {},
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(FilledButton)).width, lessThan(200));
      }
    });
  }

  testWidgets('catalog is bounded on desktop', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const ExampleApp());
    expect(tester.getSize(find.byType(ListView)).width, lessThanOrEqualTo(960));
    expect(tester.takeException(), isNull);
  });

  for (final page in <Widget>[
    const BlocIntegrationExample(),
    const MobxIntegrationExample(),
    const ProviderIntegrationExample(),
    const RiverpodIntegrationExample(),
    const SignalsIntegrationExample(),
    const WidgetAsyncExample(),
    const SearchExample(),
  ]) {
    testWidgets('${page.runtimeType} fits a narrow viewport', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(home: page));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('stream states fit narrow layouts in both themes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final brightness in Brightness.values) {
      for (final state in <OperationState<int>>[
        const IdleOperation(),
        const LoadingOperation(),
        const ErrorOperation(message: 'Connection interrupted', data: 7),
        const SuccessOperation(data: 8),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
              body: CounterOperationView(
                operation: state,
                listen: () async {},
                cancel: () async {},
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    }
  });
}

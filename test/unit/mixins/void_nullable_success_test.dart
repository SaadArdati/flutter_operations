@Timeout(Duration(seconds: 10))
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_operations/flutter_operations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises the two type-parameter choices that replaced 1.x's
/// `SuccessOperation.empty()`: fire-and-forget (`<void>`) and legitimately
/// optional payloads (`<T?>`), driven through the mixin's own `load()` path
/// rather than by hand-constructing states.

class _VoidWidget extends StatefulWidget {
  const _VoidWidget({required this.behavior});

  final Future<void> Function(_VoidWidgetState state) behavior;

  @override
  State<_VoidWidget> createState() => _VoidWidgetState();
}

class _VoidWidgetState extends State<_VoidWidget>
    with AsyncOperationMixin<void, _VoidWidget> {
  void testAttach(String message) => attachMessage(message);

  @override
  Future<void> fetch() => widget.behavior(this);

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _NullableWidget extends StatefulWidget {
  const _NullableWidget({required this.behavior});

  final Future<String?> Function() behavior;

  @override
  State<_NullableWidget> createState() => _NullableWidgetState();
}

class _NullableWidgetState extends State<_NullableWidget>
    with AsyncOperationMixin<String?, _NullableWidget> {
  @override
  Future<String?> fetch() => widget.behavior();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Future<_VoidWidgetState> _pumpVoid(
  WidgetTester tester,
  Future<void> Function(_VoidWidgetState state) behavior,
) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: _VoidWidget(behavior: behavior),
    ),
  );
  final state = tester.state<_VoidWidgetState>(find.byType(_VoidWidget));
  await tester.pumpAndSettle();
  return state;
}

Future<_NullableWidgetState> _pumpNullable(
  WidgetTester tester,
  Future<String?> Function() behavior,
) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: _NullableWidget(behavior: behavior),
    ),
  );
  final state = tester.state<_NullableWidgetState>(
    find.byType(_NullableWidget),
  );
  await tester.pumpAndSettle();
  return state;
}

void main() {
  group('AsyncOperationMixin<void>', () {
    testWidgets('fire-and-forget fetch reaches SuccessOperation<void>', (
      tester,
    ) async {
      final state = await _pumpVoid(tester, (_) async {});
      expect(state.operation, isA<SuccessOperation<void>>());
      expect(state.operation.hasNoData, isTrue);
    });

    testWidgets('attachMessage still pairs on the void success path', (
      tester,
    ) async {
      final state = await _pumpVoid(tester, (s) async {
        s.testAttach('deleted');
      });
      expect((state.operation as SuccessOperation<void>).message, 'deleted');
    });

    testWidgets('a failing void fetch produces ErrorOperation<void>', (
      tester,
    ) async {
      final state = await _pumpVoid(tester, (_) async {
        throw Exception('boom');
      });
      expect(state.operation, isA<ErrorOperation<void>>());
    });
  });

  group('AsyncOperationMixin<String?>', () {
    testWidgets('a null result is an honest SuccessOperation with null data', (
      tester,
    ) async {
      final state = await _pumpNullable(tester, () async => null);
      final op = state.operation;
      expect(op, isA<SuccessOperation<String?>>());
      expect(op.hasNoData, isTrue);
      expect((op as SuccessOperation<String?>).data, isNull);
    });

    testWidgets('a non-null result flows through unchanged', (tester) async {
      final state = await _pumpNullable(tester, () async => 'alice');
      final op = state.operation as SuccessOperation<String?>;
      expect(op.data, 'alice');
    });
  });
}

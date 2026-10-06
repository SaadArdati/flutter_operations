import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_operations/flutter_operations.dart';

import '../shared/services.dart';
import '../shared/stream_operation_view.dart';

class StandaloneStreamOperationExample extends StatefulWidget {
  const StandaloneStreamOperationExample({super.key});

  @override
  State<StandaloneStreamOperationExample> createState() =>
      _StandaloneStreamOperationExampleState();
}

class _StandaloneStreamOperationExampleState
    extends State<StandaloneStreamOperationExample> {
  late final operation = StreamOperation<int>(
    onChanged: (_, _) => setState(() {}),
    errorMessage: (_, _) => 'Unable to update counter.',
  );

  @override
  void dispose() {
    // Flutter cannot await dispose. Surface cleanup failures to its error zone.
    final zone = Zone.current;
    operation.dispose().then<void>(
      (_) {},
      onError: (Object error, StackTrace trace) =>
          zone.handleUncaughtError(error, trace),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Standalone StreamOperation')),
    body: CounterOperationView(
      operation: operation.state,
      listen: () => operation.listen(MockStreamService.counter),
      cancel: operation.cancel,
      listenLabel: 'Listen',
      note: 'Each subscription starts a new counter.',
    ),
  );
}

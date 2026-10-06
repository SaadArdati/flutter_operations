import 'package:flutter/material.dart';
import 'package:flutter_operations/flutter_operations.dart';

import '../shared/services.dart';
import '../shared/stream_operation_view.dart';

class WidgetStreamExample extends StatefulWidget {
  const WidgetStreamExample({super.key});

  @override
  State<WidgetStreamExample> createState() => _WidgetStreamExampleState();
}

class _WidgetStreamExampleState extends State<WidgetStreamExample>
    with StreamOperationStateMixin<int, WidgetStreamExample> {
  @override
  Stream<int> stream() => MockStreamService.counter();
  @override
  String errorMessage(Object error, StackTrace trace) =>
      'Unable to update counter.';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Widget-owned Stream')),
    body: ValueListenableBuilder(
      valueListenable: operationNotifier,
      builder: (_, state, _) => CounterOperationView(
        operation: state,
        listen: listen,
        listenLabel: 'Restart stream',
        note: 'Flutter owns this subscription and cleans it up on disposal.',
      ),
    ),
  );
}

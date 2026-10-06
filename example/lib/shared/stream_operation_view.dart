import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_operations/flutter_operations.dart';

import 'example_layout.dart';
import 'widgets.dart';

abstract class CounterRepository {
  Stream<int> watch();
}

/// A recoverable source error does not end the subscription.
class DemoCounterRepository implements CounterRepository {
  const DemoCounterRepository();

  @override
  Stream<int> watch() =>
      Stream<int>.periodic(const Duration(seconds: 1), (tick) {
        if (tick == 2) throw StateError('Connection interrupted');
        return tick;
      });
}

abstract final class StreamCleanup {
  /// Synchronous Flutter lifecycles cannot await; retain the owning error zone.
  static void report(Future<void> cleanup) {
    final zone = Zone.current;
    cleanup.then<void>(
      (_) {},
      onError: (Object error, StackTrace trace) =>
          zone.handleUncaughtError(error, trace),
    );
  }
}

class CounterOperationView extends StatelessWidget {
  const CounterOperationView({
    super.key,
    required this.operation,
    required this.listen,
    this.cancel,
    this.listenLabel = 'Listen / restart',
    this.note = 'The demo interrupts at tick 2, then recovers at tick 3.',
  });

  final OperationState<int> operation;
  final Future<void> Function() listen;
  final Future<void> Function()? cancel;
  final String listenLabel;
  final String? note;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            switch (operation) {
              IdleOperation() => const OperationMessage(
                icon: Icons.sensors_outlined,
                title: 'Follow live updates',
                message: 'Ready to listen.',
              ),
              LoadingOperation(data: null) => const LoadingStateWidget(
                message: 'Waiting for the first update...',
              ),
              LoadingOperation(:final data?) => LoadingStateWidget(
                message: 'Reconnecting: $data',
              ),
              ErrorOperation(:final message, :final data) => ErrorStateWidget(
                message:
                    '${message ?? 'Unable to update counter.'}'
                    '${data == null ? '' : '\nLast counter: $data'}',
              ),
              OperationState(:final data?) => OperationMessage(
                icon: Icons.sensors,
                title: 'Counter: $data',
                message: 'Listening for updates',
              ),
            },
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () => StreamCleanup.report(listen()),
                  icon: const Icon(Icons.refresh),
                  label: Text(listenLabel),
                ),
                if (cancel != null)
                  OutlinedButton(
                    onPressed: () => StreamCleanup.report(cancel!()),
                    child: const Text('Cancel'),
                  ),
              ],
            ),
            if (note != null)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(
                  note!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class StreamIntegrationPage extends StatefulWidget {
  const StreamIntegrationPage({
    super.key,
    required this.title,
    required this.builder,
  });

  final String title;
  final Widget Function(BuildContext context, bool mixin) builder;

  @override
  State<StreamIntegrationPage> createState() => _StreamIntegrationPageState();
}

class _StreamIntegrationPageState extends State<StreamIntegrationPage> {
  bool mixin = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: ExampleBody(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Composition')),
                  ButtonSegment(value: true, label: Text('Host mixin')),
                ],
                selected: {mixin},
                onSelectionChanged: (selection) =>
                    setState(() => mixin = selection.single),
              ),
            ),
          ),
          Expanded(child: widget.builder(context, mixin)),
        ],
      ),
    ),
  );
}

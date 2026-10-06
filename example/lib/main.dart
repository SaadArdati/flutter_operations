import 'package:flutter/material.dart';

import 'async/bloc_integration_example.dart';
import 'async/mobx_integration_example.dart';
import 'async/provider_integration_example.dart';
import 'async/riverpod_integration_example.dart';
import 'async/signals_integration_example.dart';
import 'async/standalone_async_operation_example.dart';
import 'async/widget_operations_example.dart';
import 'shared/example_layout.dart';
import 'stream/bloc_stream_integration_example.dart';
import 'stream/mobx_stream_integration_example.dart';
import 'stream/provider_stream_integration_example.dart';
import 'stream/riverpod_stream_integration_example.dart';
import 'stream/signals_stream_integration_example.dart';
import 'stream/standalone_stream_operation_example.dart';
import 'stream/widget_stream_example.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Flutter Operations Examples',
    debugShowCheckedModeBanner: false,
    home: const ExampleHome(),
  );
}

class ExampleHome extends StatelessWidget {
  const ExampleHome({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Flutter Operations Examples')),
    body: ExampleBody(
      child: ListView(
        children: const [
          _SectionTitle('Async operations'),
          _ExampleTile(
            'Standalone AsyncOperation',
            'Own execution through composition, without a mixin.',
            StandaloneAsyncOperationExample(),
          ),
          _ExampleTile(
            'Widget-owned Future',
            'Compare local notification with whole-widget rebuilding.',
            WidgetAsyncExample(),
          ),
          _ExampleTile(
            'Search on demand',
            'Start idle; clear pending results when the query changes.',
            SearchExample(),
          ),
          _ExampleTile(
            'Bloc Integration',
            'Compare direct state, composition, and the host mixin.',
            BlocIntegrationExample(),
          ),
          _ExampleTile(
            'Provider Integration',
            'Compare three approaches with ChangeNotifier ownership.',
            ProviderIntegrationExample(),
          ),
          _ExampleTile(
            'Riverpod Integration',
            'Compare three approaches with Notifier build lifetimes.',
            RiverpodIntegrationExample(),
          ),
          _ExampleTile(
            'Signals Integration',
            'Compare three approaches with reactive signal snapshots.',
            SignalsIntegrationExample(),
          ),
          _ExampleTile(
            'MobX Integration',
            'Explore Atoms, computed getters, inheritance, mixins, and injection.',
            MobxIntegrationExample(),
          ),
          _SectionTitle('Stream operations'),
          _ExampleTile(
            'Standalone StreamOperation',
            'Awaitable subscription ownership and cleanup.',
            StandaloneStreamOperationExample(),
          ),
          _ExampleTile(
            'Widget-owned Stream',
            'Automatic lifecycle ownership and restart.',
            WidgetStreamExample(),
          ),
          _ExampleTile(
            'Bloc Stream Integration',
            'Compare composition and host mixin; recover from errors.',
            BlocStreamIntegrationExample(),
          ),
          _ExampleTile(
            'Provider Stream Integration',
            'Compare composition and host mixin; recover from errors.',
            ProviderStreamIntegrationExample(),
          ),
          _ExampleTile(
            'Riverpod Stream Integration',
            'Compare composition and host mixin; recover from errors.',
            RiverpodStreamIntegrationExample(),
          ),
          _ExampleTile(
            'Signals Stream Integration',
            'Compare composition and host mixin; recover from errors.',
            SignalsStreamIntegrationExample(),
          ),
          _ExampleTile(
            'MobX Stream Integration',
            'Compare composition and host mixin; recover from errors.',
            MobxStreamIntegrationExample(),
          ),
        ],
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
  );
}

class _ExampleTile extends StatelessWidget {
  const _ExampleTile(this.title, this.description, this.page);
  final String title;
  final String description;
  final Widget page;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    leading: const Icon(Icons.code),
    title: Text(title),
    subtitle: Text(description),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page)),
  );
}

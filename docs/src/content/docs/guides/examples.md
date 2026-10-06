---
title: Runnable example catalog
sidebar:
  order: 6
---

The repository's example app compares ownership approaches using shared models and rendering. These are implementations, not extra core packages. Guide snippets omit application scaffolding and are not standalone programs unless explicitly labeled complete.

## Launch the example app

```sh
cd example
flutter pub get
flutter run
```

Choose a supported target in your environment. MobX generated code is included; regenerate after annotation changes with `dart run build_runner build --delete-conflicting-outputs` from example. Do not hand-edit generated files.

## Future examples

| Topic | Repository path |
| --- | --- |
| Standalone controller | `example/lib/async/standalone_async_operation_example.dart` |
| Widget request, rebuild options, and search | `example/lib/async/widget_operations_example.dart` |
| Cubit direct/composed/mixin | `example/lib/async/bloc_integration_example.dart` |
| Provider direct/composed/mixin | `example/lib/async/provider_integration_example.dart` |
| Riverpod direct/composed/mixin | `example/lib/async/riverpod_integration_example.dart` |
| Signals direct/composed/mixin | `example/lib/async/signals_integration_example.dart` |
| MobX composition/hooks/extension/injection | `example/lib/async/mobx_integration_example.dart` |

## Stream examples

| Topic | Repository path |
| --- | --- |
| Standalone subscription | `example/lib/stream/standalone_stream_operation_example.dart` |
| Widget subscription | `example/lib/stream/widget_stream_example.dart` |
| Cubit composition and delegated host mixin | `example/lib/stream/bloc_stream_integration_example.dart` |
| Provider composition/host mixin | `example/lib/stream/provider_stream_integration_example.dart` |
| Riverpod composition/host mixin | `example/lib/stream/riverpod_stream_integration_example.dart` |
| Signals composition/host mixin | `example/lib/stream/signals_stream_integration_example.dart` |
| MobX composition/host mixin | `example/lib/stream/mobx_stream_integration_example.dart` |

Cubit cannot directly use the stream host mixin because its existing stream getter conflicts with the mixin's stream method. The domain-host delegation comparison is deliberate.

## Tests are the implementation reference

`example/test/integration_examples_test.dart` exercises framework publication and owner disposal. Package execution/state/widget suites live under `test/unit/`. Run current tests before relying on modifications. The site checks internal links and builds navigation and highlighted code. It does not compile Dart snippets.

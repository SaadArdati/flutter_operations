---
title: Installation & first operation
sidebar:
  order: 1
---

## Requirements

Use **Dart 3.12 or later** and a Flutter SDK that bundles a compatible Dart SDK. The package's Flutter constraint does not override its Dart constraint. Check `flutter --version` before upgrading.

```sh
flutter pub add flutter_operations:^4.0.0
```

```dart
import 'package:flutter_operations/flutter_operations.dart';
```

These guides describe the 4.0 API. If that version is not available on pub.dev, use a local checkout with a path dependency.

```yaml
dependencies:
  flutter_operations:
    path: ../flutter_operations
```

## A complete execution example

```dart
import 'package:flutter_operations/flutter_operations.dart';

Future<void> main() async {
  final operation = AsyncOperation<String>(
    onChanged: (previous, next) => print(next),
    errorMessage: (_, _) => 'Unable to load greeting',
  );
  try {
    await operation.run(() async => 'Hello');
    switch (operation.state) {
      case LoadingOperation():
        break;
      case ErrorOperation(:final message):
        print(message);
      case SuccessOperation(:final data):
        print(data);
    }
  } finally {
    operation.dispose();
  }
}
```

`run` returns `Future<void>`, not the payload. Ordinary work errors become error state. In an app, dispose at the owner's lifetime boundary, not after every reusable run. See [Choose an owner](../ownership/).

## Run this documentation locally

Run the following commands from the repository root.

```sh
cd docs
npm ci
npm run dev
```

Astro 7 requires a compatible modern Node release; Node 24.15 LTS was used to build this site. Check the installed Astro engine requirement when selecting an older Node release. `npm run build` emits `docs/dist`. `npm run preview` serves the build. `npm run check` validates internal page links and required coverage. Search uses Pagefind, indexed during production build; use preview to verify search.

For a subpath host, build with `DOCS_BASE=/flutter_operations npm run build`. Set `DOCS_SITE=https://your-docs-domain.example` when a real host is chosen so canonical URLs and the sitemap can be generated. A missing-site sitemap warning is expected for the local-only default. Upload `dist` contents to a static host later. No hosting provider or public domain is assumed. These commands do not deploy anything.

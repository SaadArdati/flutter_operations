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


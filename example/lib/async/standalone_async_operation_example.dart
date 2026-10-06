import 'package:flutter/material.dart';
import 'package:flutter_operations/flutter_operations.dart';

import '../shared/models.dart';
import '../shared/services.dart';
import '../shared/user_operation_view.dart';

class StandaloneAsyncOperationExample extends StatefulWidget {
  const StandaloneAsyncOperationExample({super.key});

  @override
  State<StandaloneAsyncOperationExample> createState() =>
      _StandaloneAsyncOperationExampleState();
}

class _StandaloneAsyncOperationExampleState
    extends State<StandaloneAsyncOperationExample> {
  late final AsyncOperation<User> operation;

  @override
  void initState() {
    super.initState();
    operation = AsyncOperation<User>(onChanged: (_, _) => setState(() {}));
  }

  @override
  void dispose() {
    operation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Standalone AsyncOperation')),
      body: UserOperationView(
        operation: operation.state,
        run: () => operation.run(MockApiService.fetchUser),
        cancel: operation.cancel,
      ),
    );
  }
}

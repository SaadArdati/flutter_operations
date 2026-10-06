import 'package:flutter/material.dart';
import 'package:flutter_operations/flutter_operations.dart';

import 'example_layout.dart';
import 'models.dart';
import 'widgets.dart';

class UserOperationView extends StatelessWidget {
  const UserOperationView({
    super.key,
    required this.operation,
    required this.run,
    required this.cancel,
    this.cancelLabel = 'Cancel',
  });

  final OperationState<User> operation;
  final VoidCallback run;
  final VoidCallback cancel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    final content = switch (operation) {
      IdleOperation() => const OperationMessage(
        icon: Icons.person_outline,
        title: 'Load a profile',
        message: 'Ready to load a user.',
      ),
      LoadingOperation(data: null) => const LoadingStateWidget(
        message: 'Loading user...',
      ),
      LoadingOperation(:final data?) => UserCard(
        user: data,
        isRefreshing: true,
      ),
      ErrorOperation(:final message, data: null) => ErrorStateWidget(
        message: message ?? 'Unknown error occurred',
      ),
      ErrorOperation(:final message, :final data?) => Column(
        children: [
          ErrorStateWidget(
            message: message ?? 'Unknown error occurred',
            showAsWarning: true,
          ),
          UserCard(user: data),
        ],
      ),
      SuccessOperation(:final data) => UserCard(user: data),
    };

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              content,
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: run,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Run'),
                  ),
                  OutlinedButton(onPressed: cancel, child: Text(cancelLabel)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
